#!/bin/bash
#SBATCH --job-name=aerosols
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=12:00:00
#SBATCH --mail-type=END
#SBATCH --exclusive

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-aerosols4wrf-exp.sh
#
# PURPOSE:
#  Create WRF aerosol input files (auxinput15, variable AOD5502D) with
#  daily AOD at 550 nm on the WRF grid, from monthly data of:
#   - the GCM MPI-ESM1-2-HR (CMIP6 AERmon od550aer), or
#   - the MERRA-2 reanalysis (JUELICH or NASA files).
#  Called from:
#   - launch-aerosols4wrf-exp.sh
#
# USAGE:
#  sbatch run-aerosols4wrf-exp.sh <data> <target> <domain> <year_beg> <year_end> <path_scripts> [<date_beg> <date_end>]
#   data         : historical | ssp126 | ssp245 | ssp370 | ssp585 (GCM) or MERRA
#   target       : LUCAS | SP | P | ... (name of the geo_em file)
#   domain       : d01 | d02
#   year_beg     : start year
#   year_end     : end year
#   path_scripts : folder with these scripts and the NCL scripts
#   date_beg     : optional, first day of a specific period (YYYY-MM-DD)
#   date_end     : optional, last day of a specific period (YYYY-MM-DD)
#
# INPUTS (folders set in USER CONFIGURATIONS):
#  - GCM: od550aer_AERmon_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMM>-<YYYYMM>.nc
#  - MERRA, one file per month (JUELICH if it exists, otherwise NASA):
#     JUELICH : MERRA2_OPPMONTH_wb10.<YYYYMM>.nc.gz (or .nc), variable AOD (1980-2020)
#     NASA    : MERRA2_400.instM_2d_gas_Nx.<YYYYMM>.nc (or MERRA2_401.*), variable AODANA
#               (downloaded if missing; needs an Earthdata login in ~/.netrc)
#  - In path_geo: geo_em.<domain>.<target>.nc (or geo_em.<domain>.EUR-12-v4.1.nc for target=LUCAS)
#  - In path_scripts: grid_corners.ncl, set_attributes.ncl
#
# OUTPUTS (NetCDF without .nc, <name> = scenario for GCM, target for MERRA):
#  - Monthly         : AOD_<name>_<YYYYMM>_<domain>
#  - Yearly          : AOD_<name>_<YYYY>_<domain>                 (merge_yearly="True")
#  - Specific period : AOD_<name>_<YYYYMMDD>_<YYYYMMDD>_<domain>  (date_beg/date_end, no yearly file)
#
# NOTES:
#  - Daily values are the monthly value repeated every day (00 UTC).
#  - Each monthly file ends on the 1st day of the next month.
#  - The numeric time (time, XTIME) is added after NCL so that CDO shows the dates.
#
# VERSIONS:
#  Created  2023/10/06 - Josipa Milovac (milovacj@unican.es)
#  Modified 2025/06/16 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: cdo, nco, ncl, wget
module load intel_v2025.0.4/cdo/v2.4.4
module load intel_v2025.0.4/nco/v5.3.0
module load others/miniforge3/v3.12.8

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-aerosols4wrf-exp.sh
data=$1           # GCM experiment (historical | ssp*) or MERRA
target=$2         # name of the geo_em file (LUCAS | SP | P | ...)
domain=$3         # WRF domain (d01 | d02)
year_beg=$4       # start year
year_end=$5       # end year
path_scripts=$6   # folder with these scripts and the NCL scripts
date_beg=$7       # optional: first day of a specific period (YYYY-MM-DD)
date_end=$8       # optional: last day of a specific period (YYYY-MM-DD)

if [[ -z "${data}" || -z "${target}" || -z "${domain}" || -z "${year_beg}" || -z "${year_end}" || -z "${path_scripts}" ]]; then
 echo "Usage:"
 echo "  $0 <data> <target> <domain> <year_beg> <year_end> <path_scripts> [<date_beg> <date_end>]"
 echo "         data         : historical | ssp126 | ssp245 | ssp370 | ssp585 | MERRA"
 echo "         target       : LUCAS | SP | P | ..."
 echo "         domain       : d01 | d02"
 echo "         path_scripts : folder with these scripts and the NCL scripts"
 echo "         date_beg     : optional, first day of a specific period (YYYY-MM-DD)"
 echo "         date_end     : optional, last day of a specific period (YYYY-MM-DD)"
 exit 1
fi

### Period: full years, or a specific period (years and months then come from the dates)
month_beg=01; month_end=12
if [[ -n "${date_beg}" || -n "${date_end}" ]]; then
 if [[ -z "${date_beg}" || -z "${date_end}" ]]; then
  echo "[ERROR] Give both date_beg and date_end (YYYY-MM-DD), or none of them"
  exit 1
 fi
 year_beg=$(date -d "${date_beg}" +%Y);  month_beg=$(date -d "${date_beg}" +%m)
 year_end=$(date -d "${date_end}" +%Y);  month_end=$(date -d "${date_end}" +%m)
fi

### Data source: MERRA reanalysis, or a scenario of the GCM
ssp="${data}"
if [[ "${data}" == "MERRA" ]]; then
 mode="MERRA"; model="MERRA"
else
 mode="GCM";   model="MPI-ESM1-2-HR"
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_geo="/home/lsantos/data/geo_em"                              ## <<< geo_em files of the targets (WRF grids)
if [[ "${mode}" == "GCM" ]]; then
 path_din_gcm="/media/Synology15/MPI-HR_CMIP6/raw/aer550/${ssp}"  ## <<< input: raw AERmon od550aer files
 path_dout_gcm="/media/Synology15/MPI-HR_CMIP6/aerosols/${ssp}"   ## <<< output: AOD files
 mkdir -p "${path_dout_gcm}"
fi
if [[ "${mode}" == "MERRA" ]]; then
 path_din_merra="/media/Synology09/MERRA"                         ## <<< input: MERRA2 files (JUELICH and NASA)
 path_dout_merra="${path_din_merra}/AOD_${target}"                ## <<< output: AOD files
 mkdir -p "${path_dout_merra}"
fi

### SETTINGS
merge_yearly="True"     ## <<< "True": also merge the monthly files into one file per year (not with date_beg/date_end)
do_prepare="True"       ## <<< GCM: "True" splits the raw files into monthly files; "False" if already done
do_download="True"      ## <<< MERRA: "True" downloads the missing NASA months

### FIXED VALUES (do not change)
aod_varname="od550aer"                                            # GCM variable name
prefix="${aod_varname}_AERmon_${model}_${ssp}_r1i1p1f1_gn"        # GCM file names
url_nasa="https://goldsmr4.gesdisc.eosdis.nasa.gov/data/MERRA2_MONTHLY/M2IMNXGAS.5.12.4"   # NASA download site

#----------------------------------------------------------------
#                           FUNCTIONS                           |
#----------------------------------------------------------------
# Usage: set_start_time <file> <date>
# Sets the date and time of the (single) time step of <file> to <date> (YYYY-MM-DD_hh:mm:ss).
set_start_time() {
 local ifile=$1
 local sdate=$2
 cdo -s setdate,${sdate//_*/} "${ifile}" temp.nc
 cdo -s settime,${sdate//*_/} temp.nc "${ifile}"
 rm -f temp.nc
}

# Usage: timeRange2Interval <file_in> <file_out> <date_beg> <date_end> <interval>
# Puts the field of <file_in> at <date_beg> and at <date_end> (YYYY-MM-DDThh:mm:ss) and fills
# the steps in between every <interval> (e.g. 1day). With one monthly field, all days get the same value.
timeRange2Interval() {
 local ifile=$1; local ofile=$2; local sdate=$3; local edate=$4; local interval=$5
 local nrec=$(cdo -s ntime ${ifile})
 test ${nrec} -eq 0 && nrec=1
 cdo -s seltimestep,1 ${ifile} fout1
 cdo -s setdate,${sdate} fout1 fout2
 cdo -s settime,$(echo ${sdate} | awk -FT '{print $2}') fout2 fout0
 cdo -s seltimestep,${nrec} ${ifile} fout1
 cdo -s setdate,${edate} fout1 fout2
 cdo -s settime,$(echo ${edate} | awk -FT '{print $2}') fout2 fout1
 cdo -s mergetime fout0 fout1 fout3
 cdo -s inttime,$(cdo -s showdate fout0 | tr -d ' '),00:00:00,${interval} fout3 ${ofile}
 rm -f fout0 fout1 fout2 fout3
}

# Usage: delete_atts <file>
# Removes the geo_em attributes that do not apply to the AOD file and fixes those of AOD5502D.
delete_atts() {
 local file_out=$1
 ncatted -O -h -a "corner_*",global,d,,                 "${file_out}" || true
 ncatted -O -h -a "FLAG_*",global,d,,                   "${file_out}" || true
 ncatted -O -h -a "SIMULATION_START_DATE",global,d,,    "${file_out}" || true
 ncatted -O -h -a "GRIDTYPE",global,d,,                 "${file_out}" || true
 ncatted -O -h -a "sr_*",global,d,,                     "${file_out}" || true
 ncatted -O -h -a "sr_*",AOD5502D,d,,                   "${file_out}" || true
 ncatted -O -h -a "stagger",AOD5502D,m,c,""             "${file_out}" || true
 ncatted -O -h -a "_FillValue",AOD5502D,m,f,"NaN"       "${file_out}" || true
 ncatted -O -h -a "coordinates",AOD5502D,d,,            "${file_out}" || true
}

# Usage: add_numeric_time_for_cdo <file> <year> <month>
# Adds the numeric variables time and XTIME (hours since <year>-01-01, one step per day from
# the 1st day of <month>), so that CDO shows the dates. WRF only reads Times.
add_numeric_time_for_cdo() {
 local file_out=$1
 local year=$2; local month=$3
 ### Times must have 19 characters (YYYY-MM-DD_hh:mm:ss)
 if ncdump -h "${file_out}" | grep -q 'DateStrLen ='; then
  ncks -O -d DateStrLen,0,18 "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
 fi
 ### Hours from <year>-01-01 to the 1st day of <month>
 local offset_hours=$(( ( $(date -u -d "${year}-${month}-01" +%s) - $(date -u -d "${year}-01-01" +%s) ) / 3600 ))
 ### time and XTIME: one value per step of Time, every 24 hours
 ncap2 -O -s "time[\$Time]=0.0; XTIME[\$Time]=0.0f;" "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
 ncap2 -O -s "for(i=0;i<\$Time.size;i++){ time(i)=${offset_hours}+i*24.0; XTIME(i)=time(i); }" "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}"
 ncatted -O -a units,time,c,c,"hours since ${year}-01-01 00:00:00"  "${file_out}"
 ncatted -O -a calendar,time,c,c,"proleptic_gregorian"             "${file_out}"
 ncatted -O -a axis,time,c,c,"T"                                   "${file_out}"
 ncatted -O -a standard_name,time,c,c,"time"                       "${file_out}"
 ncatted -O -a units,XTIME,c,c,"hours since ${year}-01-01 00:00:00" "${file_out}"
 ncatted -O -a calendar,XTIME,c,c,"proleptic_gregorian"            "${file_out}"
 ### Time as record (unlimited) dimension, needed to join files with ncrcat
 ncks -O --mk_rec_dmn Time "${file_out}" tmp.$$ && mv tmp.$$ "${file_out}" || true
}

# Usage: merge_yearly_files <file_merge> "<monthly_files>" <output_dir>
# Joins the monthly files of one year into <file_merge> (without the extra 1st day of the next
# month, except in December) and moves it to <output_dir>. Skips it if it already exists there.
merge_yearly_files() {
 local file_merge=$1
 local monthly_files=$2
 local output_dir=$3
 local monthly_files_trimmed=""
 local f trim
 if [ -f "${output_dir}/${file_merge}" ]; then
  echo "[INFO] ${file_merge} already exists in ${output_dir}, skipped"
  return 0
 fi
 echo "[INFO] Merging the monthly files into ${file_merge}"
 for f in ${monthly_files}; do
  trim="${f}_trim.nc"
  if [[ "${f}" =~ _[0-9]{4}12_ ]]; then
   ncks -O "${f}" "${trim}"
  else
   ncks -O -d Time,0,-2 "${f}" "${trim}" 2>/dev/null || ncks -O "${f}" "${trim}"
  fi
  ncks -O --mk_rec_dmn Time "${trim}" tmp.$$ && mv tmp.$$ "${trim}" || true
  monthly_files_trimmed="${monthly_files_trimmed} ${trim}"
 done
 ncrcat -O ${monthly_files_trimmed} "${file_merge}"
 ncks -O --mk_rec_dmn Time "${file_merge}" tmp.$$ && mv tmp.$$ "${file_merge}" || true
 rm -f ${monthly_files_trimmed}
 mv "${file_merge}" "${output_dir}/."
}

# Usage: make_period_file <name> <output_dir>
# Joins the monthly files AOD_<name>_<YYYYMM>_<domain> of <output_dir> and keeps only the days
# from date_beg to date_end. Output (in <output_dir>): AOD_<name>_<YYYYMMDD>_<YYYYMMDD>_<domain>
make_period_file() {
 local name=$1
 local output_dir=$2
 local file_period="AOD_${name}_$(date -d "${date_beg}" +%Y%m%d)_$(date -d "${date_end}" +%Y%m%d)_${domain}"
 local files_trimmed=""
 local year month m_beg m_end file_month first_day i_beg i_end
 echo "[INFO] Creating ${file_period}"
 ### Copy each month without its last step (the 1st day of the next month)
 for year in $(seq ${year_beg} ${year_end}); do
  m_beg=01; m_end=12
  [ ${year} -eq ${year_beg} ] && m_beg=${month_beg}
  [ ${year} -eq ${year_end} ] && m_end=${month_end}
  for month in $(seq -w ${m_beg} ${m_end}); do
   file_month="${output_dir}/AOD_${name}_${year}${month}_${domain}"
   if [ ! -f "${file_month}" ]; then
    echo "[ERROR] ${file_month} is missing, ${file_period} not created"
    rm -f ${files_trimmed}
    return 1
   fi
   ncks -O -d Time,0,-2 "${file_month}" "period_${year}${month}.nc"
   files_trimmed="${files_trimmed} period_${year}${month}.nc"
  done
 done
 ### Join the months: one step per day, from the 1st day of the first month
 ncrcat -O ${files_trimmed} period_all.nc
 rm -f ${files_trimmed}
 ### Keep only date_beg..date_end (step index = days since the 1st day of the first month)
 first_day="${year_beg}-${month_beg}-01"
 i_beg=$(( ( $(date -u -d "${date_beg}" +%s) - $(date -u -d "${first_day}" +%s) ) / 86400 ))
 i_end=$(( ( $(date -u -d "${date_end}" +%s) - $(date -u -d "${first_day}" +%s) ) / 86400 ))
 ncks -O -d Time,${i_beg},${i_end} period_all.nc "${file_period}"
 rm -f period_all.nc
 ### Numeric time again for CDO (hours since date_beg; the months may be from different years)
 ncap2 -O -s "for(i=0;i<\$Time.size;i++){ time(i)=i*24.0; XTIME(i)=time(i); }" "${file_period}" tmp.$$ && mv tmp.$$ "${file_period}"
 ncatted -O -a units,time,o,c,"hours since ${date_beg} 00:00:00"  "${file_period}"
 ncatted -O -a units,XTIME,o,c,"hours since ${date_beg} 00:00:00" "${file_period}"
 ncks -O --mk_rec_dmn Time "${file_period}" tmp.$$ && mv tmp.$$ "${file_period}" || true
 mv "${file_period}" "${output_dir}/."
}

# Usage: download_merra_nasa <year> <month>
# Downloads one MERRA2 M2IMNXGAS month from NASA into path_din_merra (saved as .nc).
# Most months are stream 400; some were reprocessed as stream 401. Returns 1 if both fail.
download_merra_nasa() {
 local year=$1; local month=$2
 local wget_opt="-q --load-cookies ${HOME}/.urs_cookies --save-cookies ${HOME}/.urs_cookies --keep-session-cookies --auth-no-challenge=on"
 local stream file_nasa
 for stream in 400 401; do
  file_nasa="MERRA2_${stream}.instM_2d_gas_Nx.${year}${month}"
  if wget ${wget_opt} -O "${path_din_merra}/${file_nasa}.nc" "${url_nasa}/${year}/${file_nasa}.nc4"; then
   echo "[INFO] Downloaded ${file_nasa}.nc"
   return 0
  fi
  rm -f "${path_din_merra}/${file_nasa}.nc"
 done
 return 1
}

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-aerosols4wrf-exp.sh ${data} ${target} ${domain} ${year_beg}-${year_end} ${date_beg} ${date_end}"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${ssp}_${target}_${domain}_${year_beg}-${year_end}"
mkdir -p "${path_w}"
cd "${path_w}" || exit 1

### geo_em file of the target (LUCAS uses the EURO-CORDEX EUR-12 grid) and NCL scripts
if [ "${target}" == "LUCAS" ]; then
 geo_file="geo_em.${domain}.EUR-12-v4.1.nc"
else
 geo_file="geo_em.${domain}.${target}.nc"
fi
if [ ! -f "${path_geo}/${geo_file}" ]; then
 echo "[ERROR] ${path_geo}/${geo_file} not found (check path_geo, target and domain)"
 exit 1
fi
ln -sf "${path_geo}/${geo_file}" "./geo_em.${domain}.nc"
ln -sf "${path_scripts}"/*.ncl .

#----------------------------------------------------------------
#                        GCM (MPI-ESM1-2-HR)                    |
#----------------------------------------------------------------
if [ "${mode}" == "GCM" ]; then
 ### Link the raw data and split it into monthly files
 if [ "${do_prepare}" == "True" ]; then
  echo "[INFO] Preparing the GCM data"
  ln -sf "${path_din_gcm}"/*.nc .
  ### Split by year
  yearly_count=$(ls ${prefix}_[0-9][0-9][0-9][0-9].nc 2>/dev/null | wc -l)
  if [ "${yearly_count}" -ne 0 ]; then
   echo "[INFO] Yearly files already exist (${yearly_count}), skipped"
  else
   echo "[INFO] Splitting by year (cdo splityear)"
   for file_nc in ${prefix}*.nc; do
    [ -f "${file_nc}" ] || continue
    cdo -s splityear "${file_nc}" "${file_nc::-16}"    # name without "_YYYYMM-YYYYMM.nc"
   done
  fi
  ### Split by month
  monthly_count=$(ls ${prefix}_[0-9][0-9][0-9][0-9][0-9][0-9].nc 2>/dev/null | wc -l)
  if [ "${monthly_count}" -ne 0 ]; then
   echo "[INFO] Monthly files already exist (${monthly_count}), skipped"
  else
   echo "[INFO] Splitting by month (cdo splitmon)"
   for year in $(seq ${year_beg} ${year_end}); do
    file_nc="${prefix}_${year}.nc"
    [ -f "${file_nc}" ] && cdo -s splitmon "${file_nc}" "${file_nc::-3}"    # name without ".nc"
   done
  fi
  ### Remove the yearly files and the links to the raw files
  echo "[INFO] Removing the intermediate yearly files"
  for year in $(seq ${year_beg} ${year_end}); do
   rm -f *_${year}.nc
  done
  rm -f ${prefix}_[0-9][0-9][0-9][0-9]01-[0-9][0-9][0-9][0-9]12.nc
 fi

 ### Monthly files -> AOD files on the WRF grid
 for year in $(seq ${year_beg} ${year_end}); do
  monthly_files=""
  ### Months of this year: all, or only part of the first/last year of a specific period
  m_beg=01; m_end=12
  [ ${year} -eq ${year_beg} ] && m_beg=${month_beg}
  [ ${year} -eq ${year_end} ] && m_end=${month_end}
  for month in $(seq -w ${m_beg} ${m_end}); do
   file_nc="${prefix}_${year}${month}.nc"
   [ ! -f "${file_nc}" ] && continue
   file_out="AOD_${ssp}_${year}${month}_${domain}"
   echo "[INFO] Creating ${file_out}"
   ### Remove unwanted coordinates and variables
   ncatted -O -a coordinates,${aod_varname},d,, "${file_nc}" temp_in.nc
   ncks -C -O -x -v wavelength,time_bnds temp_in.nc temp_in.nc 2>/dev/null || true
   rm -f "${file_nc}"
   ### Select the AOD variable
   cdo -s selname,${aod_varname} temp_in.nc temp_aod.nc
   rm -f temp_in.nc
   ### Daily steps, from the 1st day of the month to the 1st day of the next month
   sdate=$(date -d "${year}-${month}-01 00:00:00" +%Y-%m-%d_%H:%M:%S)
   edate=$(date -d "${year}-${month}-01 +1 month" +%Y-%m-%d_%H:%M:%S)
   set_start_time temp_aod.nc "${sdate}"
   timeRange2Interval temp_aod.nc temp_daily.nc ${sdate/_/T} ${edate/_/T} 1day
   rm -f temp_aod.nc
   ### Remap to the WRF grid (grid and weights are computed once)
   [ -f file_grid.nc ] || ncl 'srcFile="geo_em.'${domain}'.nc"' grid_corners.ncl
   [ -f weights.nc ] || cdo -s genbil,file_grid.nc temp_daily.nc weights.nc
   cdo -s remap,file_grid.nc,weights.nc temp_daily.nc temp_remap.nc
   rm -f temp_daily.nc
   ### Rename to the WRF variable name
   cdo -s chname,${aod_varname},AOD5502D temp_remap.nc temp_aod5502d.nc
   rm -f temp_remap.nc
   ### WRF attributes and Times (NCL), numeric time for CDO
   ncl 'file_input="temp_aod5502d.nc"' 'domain="'${domain}'"' 'file_out="'${file_out}'"' 'model="GCM"' set_attributes.ncl
   rm -f temp_aod5502d.nc
   add_numeric_time_for_cdo "${file_out}.nc" "${year}" "${month}"
   delete_atts "${file_out}.nc"
   mv "${file_out}.nc" "${file_out}"    # WRF expects no extension
   monthly_files="${monthly_files} ${file_out}"
  done
  ### Yearly file (not for a specific period)
  if [ "${merge_yearly}" == "True" ] && [ -z "${date_beg}" ]; then
   merge_yearly_files "AOD_${ssp}_${year}_${domain}" "${monthly_files}" "${path_dout_gcm}"
  fi
  ### Move the monthly files to the output folder
  mv AOD_${ssp}_${year}* "${path_dout_gcm}/." 2>/dev/null || true
 done

 ### Specific period: one file with the days date_beg..date_end
 if [ -n "${date_beg}" ]; then
  make_period_file "${ssp}" "${path_dout_gcm}"
 fi

 echo "[INFO] Done. AOD files in: ${path_dout_gcm}"
fi

#----------------------------------------------------------------
#                             MERRA                             |
#----------------------------------------------------------------
if [ "${mode}" == "MERRA" ]; then
 ### Monthly files -> AOD files on the WRF grid
 for year in $(seq ${year_beg} ${year_end}); do
  monthly_files=""
  ### Months of this year: all, or only part of the first/last year of a specific period
  m_beg=01; m_end=12
  [ ${year} -eq ${year_beg} ] && m_beg=${month_beg}
  [ ${year} -eq ${year_end} ] && m_end=${month_end}
  for month in $(seq -w ${m_beg} ${m_end}); do
   ### Possible input files of the month
   merra_base="${path_din_merra}/MERRA2_OPPMONTH_wb10.${year}${month}.nc"
   nasa_400="${path_din_merra}/MERRA2_400.instM_2d_gas_Nx.${year}${month}.nc"
   nasa_401="${path_din_merra}/MERRA2_401.instM_2d_gas_Nx.${year}${month}.nc"
   ### No file for this month: download it from NASA
   if [ ! -f "${merra_base}.gz" ] && [ ! -f "${merra_base}" ] && \
      [ ! -f "${nasa_400}" ] && [ ! -f "${nasa_401}" ] && [ "${do_download}" == "True" ]; then
    download_merra_nasa ${year} ${month}
   fi
   ### Input file and variable: JUELICH (.gz or .nc) first, then NASA (stream 400 or 401)
   if [ -f "${merra_base}.gz" ]; then
    merra_file="${merra_base}.gz"; merra_source="JUELICH"; aod_varname_merra="AOD"
   elif [ -f "${merra_base}" ]; then
    merra_file="${merra_base}";    merra_source="JUELICH"; aod_varname_merra="AOD"
   elif [ -f "${nasa_400}" ]; then
    merra_file="${nasa_400}";      merra_source="NASA";    aod_varname_merra="AODANA"
   elif [ -f "${nasa_401}" ]; then
    merra_file="${nasa_401}";      merra_source="NASA";    aod_varname_merra="AODANA"
   else
    echo "[WARN] No MERRA2 file (JUELICH or NASA) for ${year}${month}, skipped"
    continue
   fi
   ### Output file already done: skip the month
   file_out="AOD_${target}_${year}${month}_${domain}"
   if [ -f "${path_dout_merra}/${file_out}" ]; then
    echo "[INFO] ${file_out} already exists, skipped"
    monthly_files="${monthly_files} ${file_out}"
    continue
   fi
   echo "[INFO] Creating ${file_out} from $(basename "${merra_file}") (${merra_source})"
   ### Decompress if needed
   if [[ "${merra_file}" == *.gz ]]; then
    gunzip -c "${merra_file}" > temp_merra_raw.nc
   else
    cp "${merra_file}" temp_merra_raw.nc
   fi
   ### Remove unwanted coordinates
   ncatted -O -a coordinates,,d,, temp_merra_raw.nc temp_in.nc
   rm -f temp_merra_raw.nc
   ### NASA files have a time dimension of size 1: remove it, as in the JUELICH files
   if [ "${merra_source}" == "NASA" ]; then
    ncwa -O -a time temp_in.nc temp_notime.nc
    ncks -O -x -v time temp_notime.nc temp_in.nc
    rm -f temp_notime.nc
   fi
   ### Select the AOD variable
   cdo -s selname,${aod_varname_merra} temp_in.nc temp_aod.nc
   rm -f temp_in.nc
   ### Daily steps, from the 1st day of the month to the 1st day of the next month
   sdate=$(date -d "${year}-${month}-01 00:00:00" +%Y-%m-%d_%H:%M:%S)
   edate=$(date -d "${year}-${month}-01 +1 month" +%Y-%m-%d_%H:%M:%S)
   set_start_time temp_aod.nc "${sdate}"
   timeRange2Interval temp_aod.nc temp_daily.nc ${sdate/_/T} ${edate/_/T} 1day
   rm -f temp_aod.nc
   ### Remap to the WRF grid (grid and weights are computed once)
   [ -f file_grid.nc ] || ncl 'srcFile="geo_em.'${domain}'.nc"' grid_corners.ncl
   [ -f weights.nc ] || cdo -s genbil,file_grid.nc temp_daily.nc weights.nc
   cdo -s remap,file_grid.nc,weights.nc temp_daily.nc temp_remap.nc
   rm -f temp_daily.nc
   ### Rename to the WRF variable name
   cdo -s chname,${aod_varname_merra},AOD5502D temp_remap.nc temp_aod5502d.nc
   rm -f temp_remap.nc
   ### WRF attributes and Times (NCL), numeric time for CDO
   ncl 'file_input="temp_aod5502d.nc"' 'domain="'${domain}'"' 'file_out="'${file_out}'"' 'model="MERRA"' set_attributes.ncl
   rm -f temp_aod5502d.nc
   add_numeric_time_for_cdo "${file_out}.nc" "${year}" "${month}"
   delete_atts "${file_out}.nc"
   mv "${file_out}.nc" "${file_out}"    # WRF expects no extension
   monthly_files="${monthly_files} ${file_out}"
  done
  ### Yearly file (not for a specific period)
  if [ "${merge_yearly}" == "True" ] && [ -z "${date_beg}" ]; then
   merge_yearly_files "AOD_${target}_${year}_${domain}" "${monthly_files}" "${path_dout_merra}"
  fi
  ### Move the monthly files to the output folder
  mv AOD_${target}_${year}* "${path_dout_merra}/." 2>/dev/null || true
 done

 ### Specific period: one file with the days date_beg..date_end
 if [ -n "${date_beg}" ]; then
  make_period_file "${target}" "${path_dout_merra}"
 fi

 echo "[INFO] Done. AOD files in: ${path_dout_merra}"
fi

exit 0
