#!/bin/bash

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
#
# PURPOSE
#   Create WRF-compatible aerosol input (auxinput15) from monthly
#  GCM AERmon od550aer (AOD @ 550 nm) for a given scenario.
#
# USAGE
#   ./create_aerosol4wrf_input.sh <scenario>
#  scenario: historical | ssp126 | ssp245 | ssp370 | ssp585
#
# INPUTS (set paths in the "Directories" section)
#   1) AERmon od550aer monthly inputs (by scenario)
#     - od550aer_AERmon_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMM>.nc
#
#   2) Required files:
#     - geo_em.<domain>.EUR-12-v4.1.nc  #!Target grid descriptor for remapping/interpolation
#     - grid_corners.ncl                #!Builds out_grid.nc (grid corners) used by CDO for remap weights
#     - set_attributes.ncl              #!Cleans and standardizes NetCDF attributes after processing
#     - wrfinput_<domain>_201501        #!WRF input file used to copy/align global attributes and metadata
#
# OUTPUTS
#   - auxinput15 files, monthly or yearly (set merge_yearly=True/False)
#   - Monthly: AOD_<scenario>_<YYYYMM>_<domain>
#   - Yearly : AOD_<scenario>_<YYYY>_<domain>
#
# REQUIREMENTS
#   - cdo
#   - nco (ncrcat/ncks)
#   - ncl (set_attributes.ncl)
#   - coreutils
#
# NOTES
#   - Ensure geo_em and wrfinput_d01_201501 correspond to the same domain
#   - grid_corners.ncl is used to derive remap support files (out_grid.nc)
#   - set_attributes.ncl standardizes attributes to match WRF conventions
#   - Numeric time is injected AFTER NCL so tools (CDO) don’t show zeros
#
# VERSIONS
#   Created  2023/10/06 - Josipa Milovac (milovacj@unican.es)
#   Modified 2025/06/16 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro

#----------------------------------------------------------------
#                        USER CONFIGURATIONS                    |
#----------------------------------------------------------------
### Load modules
#module purge
#module load cdo nco ncl

### Data
model="MPI-ESM1-2-HR"
domain="d01"
aod_varname="od550aer"
scenario=$1                 # <<< Set the scenario
start_year=2015             # <<< Set the start year
start_month=01              # <<< Set the start month
end_year=2100               # <<< Set the end year
end_month=12                # <<< Set the end month
merge_yearly="True"        # <<< Set to "True" to merge outputs yearly
do_prepare="True"           # <<< Set to "False" to skip CDO prep stage
raw_data_name="${aod_varname}_AERmon_${model}_${scenario}_r1i1p1f1_gn"
start_date=$start_year-$start_month-01_00:00:00
end_date=$end_year-$end_month-01_00:00:00

### Directories
wrkdir=$(pwd)
path_w="${wrkdir}/${scenario}"; mkdir -p ${path_w}
path_s="/home/lsantos/scripts/pre-run-issues/aerosols"          # <<< Set the path of the scripts and needed files
path_i="/media/Synology15/MPI-HR_CMIP6/raw/aer550/${scenario}"  # <<< Set the path of the input data
path_o="/media/Synology15/MPI-HR_CMIP6/aerosols/${scenario}"    # <<< Set the path for the output data
mkdir -p ${path_o}


#----------------------------------------------------------------
#                           FUNCTIONS                           |
#----------------------------------------------------------------
# Utility: robust record-dimension maker for 'Time' (if present)
function mk_rec_dmn_if_Time(){
  file_out=$1
  if ncdump -h "${file_out}" | grep -qE 'dimensions:.*\bTime\s*='; then
   ncks -O --mk_rec_dmn Time "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}" || true
  fi
}

# Function to set start time on files that may lack valid numeric time (pre-NCL stage)
function set_start_time(){
  ifile=$1
  cdo -s setdate,${start_date//_*/} ${ifile} temp.nc
  cdo -s settime,${start_date//*_/} temp.nc ${ifile}
  rm temp.nc
}

# Function to interpolate [first,last] monthly values to a daily series
function timeRange2Interval(){
  ifile=$1; ofile=$2; sdate=$3; edate=$4; interval=$5
  nrec=$(cdo -s ntime ${ifile})
  test ${nrec} -eq 0 && nrec=1
  cdo -s seltimestep,1 ${ifile} fout1
  cdo -s setdate,${sdate} fout1 fout2
  cdo -s settime,$(echo ${sdate} | awk -FT '{print $2}') fout2 fout0
  cdo -s seltimestep,${nrec} ${ifile} fout1
  cdo -s setdate,${edate} fout1 fout2
  cdo -s settime,$(echo ${edate} | awk -FT '{print $2}') fout2 fout1
  cdo -s mergetime fout0 fout1 fout3
  cdo -s inttime,$(cdo -s showdate fout0 | tr -d ' '),00:00:00,${interval} fout3  ${ofile}
  rm fout0 fout1 fout2 fout3
}

# Function to clean attributes that are noisy for downstream tools
function delete_atts(){
  file_out=$1
  ncatted -O -h -a "corner_*",global,d,,                 "${file_out}" || true
  ncatted -O -h -a "FLAG_*",global,d,,                   "${file_out}" || true
  ncatted -O -h -a "SIMULATION_START_DATE",global,d,,    "${file_out}" || true
  ncatted -O -h -a "GRIDTYPE",global,d,,                 "${file_out}" || true
  ncatted -O -h -a "sr_*",global,d,,                     "${file_out}" || true
  ncatted -O -h -a "sr_*",AOD5502D,d,,                   "${file_out}" || true
  ncatted -O -h -a "stagger",AOD5502D,m,c,""             "${file_out}" || true
  ncatted -O -h -a "_FillValue",AOD5502D,m,f,"NaN"       "${file_out}" || true
  ncatted -O -h -a "coordinates",AOD5502D,d,,            "${file_out}" || true
  #ncks -O --mk_rec_dmn Time "${file_out}" tmp.nc && mv tmp.nc "${file_out}"
  #ncks -O --mk_rec_dmn Time -C -v Times,AOD5502D "${file_out}" tmp.nc && mv tmp.nc "${file_out}"
  #ncks -O -h --mk_rec_dmn Time ${file_out} -o temp.nc; mv temp.nc ${file_out}
}

# Utility: after NCL, add numeric axes for CDO while keeping Times(char) for WRF
# - Creates time(Time) in HOURS since YYYY-01-01 00:00:00 (common origin per year)
# - time values include month offset so all months are consistent for ncrcat
# - Creates XTIME(Time) mirroring time (hours) for WRF-style workflows
# - Sets AOD5502D:coordinates to include 'time' (and XTIME)
# - Never edits Times(char); only adds numeric coords
function add_numeric_time_for_cdo(){
  file_out="$1"  # e.g., ${filename_out}.nc
  year="$2"; month="$3"
  #! Detect Time length robustly
  nTime=$(ncks -M --trd "${file_out}" 2>/dev/null | awk '/^dim/ && /[[:space:]]Time,[[:space:]]size/ {print $NF; exit}')
  if [ -z "${nTime}" ]; then
    nTime=$(ncdump -h "${file_out}" 2>/dev/null | sed -n 's/^[[:space:]]*Time[[:space:]]*=\s*\([0-9][0-9]*\).*/\1/p' | head -n1)
  fi
  if [ -z "${nTime}" ] || ! [[ "${nTime}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not detect Time length in ${file_out}" >&2
    return 1
  fi
  echo "  -> Detected Time length = ${nTime}"
  #! Ensure DateStrLen is 19 if present (YYYY-mm-dd_HH:MM:SS)
  if ncdump -h "${file_out}" | grep -q 'DateStrLen ='; then
    ncks -O -d DateStrLen,0,18 "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
  fi
  #! Compute month offset in HOURS since YYYY-01-01 00:00:00
  #   %j = day-of-year (001..366); (doy-1)*24 gives hour offset at month start
  doy0=$(date -d "${year}-${month}-01 00:00:00" +%j)
  offset_hours=$(( (10#$doy0 - 1) * 24 ))
  #! Create numeric variables time(Time) and XTIME(Time) with common origin
  ncap2 -O -s "time[\$Time]=0.0; XTIME[\$Time]=0.0f;" "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
  ncap2 -O -s "for(i=0;i<${nTime};i++){ time(i)=${offset_hours}+i*24.0; XTIME(i)=time(i); }" "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
  #! CF attrs so CDO recognizes the time axis (common origin per year)
  ncatted -O -a units,time,c,c,"hours since ${year}-01-01 00:00:00" "${file_out}"
  ncatted -O -a calendar,time,c,c,"proleptic_gregorian"            "${file_out}"
  ncatted -O -a axis,time,c,c,"T"                                  "${file_out}"
  ncatted -O -a standard_name,time,c,c,"time"                      "${file_out}"
  #! XTIME attrs (same origin for simplicity)
  ncatted -O -a units,XTIME,c,c,"hours since ${year}-01-01 00:00:00" "${file_out}"
  ncatted -O -a calendar,XTIME,c,c,"proleptic_gregorian"            "${file_out}"
  #! Point AOD to numeric coords; keep Times(char) untouched
  if ncdump -h "${file_out}" | grep -q '^float[[:space:]]\+XTIME('; then
    ncatted -O -a coordinates,AOD5502D,c,c,"time XTIME" "${file_out}"
  else
    ncatted -O -a coordinates,AOD5502D,c,c,"time"       "${file_out}"
  fi
  #! Make Time the record dimension (helps ncrcat later)
  ncks -O --mk_rec_dmn Time "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}" || true
}


#----------------------------------------------------------------
#                       PREPARE AOD DATA                        |
#----------------------------------------------------------------
if [ "${do_prepare}" == "True" ]; then
 echo ">>> Preparing AOD data"
 cd ${path_w}
 
 ## Symbolic link the raw data
 ln -sf ${path_i}/*.nc .
 
 ## cdo splityear
 for filename in *.nc; do
  cdo splityear $filename "${filename::-16}"
 done
 
 ## cdo splitmon
 for year in $(seq $start_year $end_year); do
  filename="od550aer_AERmon_${model}_${scenario}_r1i1p1f1_gn_${year}.nc"
  cdo splitmon $filename "${filename::-3}"
 done
 
 ## Clear yearly (_YYYY.nc) and block (_YYYY01-YYYY12.nc) files
 for year in $(seq $start_year $end_year); do
  rm -f *_$year.nc
 done
 rm -f ${raw_data_name}_[0-9][0-9][0-9][0-9]01-[0-9][0-9][0-9][0-9]12.nc

fi


#----------------------------------------------------------------
#                            SCRIPT                             |
#----------------------------------------------------------------
echo ">>> Processing: create_aerosol4wrf_input.sh ${scenario}"

## 1) Symbolic link the needed data
cd ${path_w}
ln -sf ${path_s}/geo_em.${domain}.EUR-12-v4.1.nc "./geo_em.${domain}.nc"  #geo_file for grid_corners.ncl
ln -sf ${path_s}/*.ncl .                                                  #grid_corners.ncl, set_attributes.ncl
ln -sf ${path_s}/wrfinput_${domain}_201501 "./wrfinput_${domain}"         #wrfinput

## Loops for YYYYMM
for year in $(seq $start_year $end_year); do         #!Loop over years (YYYYi to YYYYf)
 monthly_files=""
 for month in $(seq -w $start_month $end_month); do  #!Loop over months (MMi to MMf)
  
  ## 2) Define file names
  filename_in="${raw_data_name}_${year}${month}.nc"
  filename_out="AOD_${scenario}_${year}${month}_${domain}"
  echo " - creating ${filename_out}"
  
  ## 3) Clean noisy coords/vars before CDO (avoids warnings, quieter logs)
  #ncatted -a coordinates,,d,, "${filename_in}" temp_in.nc                   #!remove 'coordinates' (global)
  ncatted -O -a coordinates,${aod_varname},d,, "${filename_in}" temp_in.nc  #!remove 'coordinates' (AOD var)
  ncks -C -O -x -v wavelength,time_bnds temp_in.nc temp_in.nc 2>/dev/null || true
  rm -f ${filename_in}
  
  ## 4) Select AOD variable
  cdo -selname,${aod_varname} temp_in.nc temp_aod.nc
  rm -f temp_in.nc
  
  ## 5) Interpolate monthly to daily
  set_start_time temp_aod.nc
  sdate=$(date -d "${year}-${month}-01 00:00:00" +%Y-%m-%d_%H:%M:%S)
  edate=$(date -d "${year}-${month}-01 +1 month" +%Y-%m-%d_%H:%M:%S)
  timeRange2Interval temp_aod.nc temp_daily.nc ${sdate/_/T} ${edate/_/T} 1day
  rm -f temp_aod.nc
  
  ## 6) Build WRF grid descriptor and remap
  [ -f file_grid.nc ] || ncl 'srcFile="geo_em.'${domain}'.nc"' grid_corners.ncl
  [ -f weights.nc ] || cdo -s genbil,file_grid.nc temp_daily.nc weights.nc
  cdo -s remap,file_grid.nc,weights.nc temp_daily.nc temp_remap.nc
  rm -f temp_daily.nc
  
  ## 7) Rename variable to AOD5502D
  cdo chname,${aod_varname},AOD5502D temp_remap.nc temp_aod5502d.nc
  rm -f temp_remap.nc
  
  ## 8) NCL (Josipa): add WRF metadata + Times (char)
  ncl 'file_input="temp_aod5502d.nc"' 'domain="'${domain}'"' 'file_out="'${filename_out}'"' 'model="GCM"' set_attributes.ncl
  rm -f temp_aod5502d.nc
  
  ## 9) Add numeric time for CDO (+ XTIME), keep Times(char)
  add_numeric_time_for_cdo "${filename_out}.nc" "${year}" "${month}"
  
  ##10) Final cleanup on the NCL output
  delete_atts "${filename_out}.nc"
  
  ##11) Final monthly name
  mv "${filename_out}.nc" ${filename_out}
  monthly_files="${monthly_files} ${filename_out}"
 done
 
 ##12) (Optional) Merge yearly
 if [ "${merge_yearly}" == "True" ]; then
  filename_merge="AOD_${scenario}_${year}_${domain}"
  monthly_files_trimmed=""
  for f in ${monthly_files}; do
   trim="${f}_trim.nc"
   ncks -O -d Time,0,-2 "${f}" "${trim}"                              #! drop last step of each month to avoid duplicate day at boundaries
   ncks -O --mk_rec_dmn Time "${trim}" tmp.$$ && mv tmp.$$ "${trim}"  #! force Time to be the unlimited/record dimension
   monthly_files_trimmed="${monthly_files_trimmed} ${trim}"
  done
  ncrcat -O ${monthly_files_trimmed} "${filename_merge}"
  ncks -O --mk_rec_dmn Time "${filename_merge}" tmp.$$ && mv tmp.$$ "${filename_merge}" || true
  delete_atts "${filename_merge}"
  rm -f ${monthly_files_trimmed}
 fi
  
 ##13) Move data every year
 mv AOD_${scenario}_${year}* ${path_o}/.

done

echo ">>> Done. Output AODs in: ${path_o}"

