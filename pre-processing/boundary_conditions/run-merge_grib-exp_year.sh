#!/bin/bash
#SBATCH --job-name=merge_gribs
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64,mp64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=24:00:00
#SBATCH --mail-type=END
#SBATCH --exclusive

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-merge_grib-exp_year.sh
#
# PURPOSE:
#  Merge monthly GRIBs and other processed fields into
#  yearly sequences for a given experiment and year, producing global
#  and EU subdomain GRIBs suitable for WRF.
#  Called from:
#   - launch2-merge_grib-exp.sh
#
# USAGE:
#  sbatch run-merge_grib-exp_year.sh <experiment> <year> [date] [hour]
#   experiment : historical | ssp126 | ssp245 | ssp370 | ssp585
#   year       : YYYY
#   date       : optional, one day of that year (YYYYMMDD); empty = all the year
#   hour       : optional, one hour of that day (00 | 06 | 12 | 18); empty = the 4 hours
#
# INPUTS (folders set in USER CONFIGURATIONS):
#  - In path_din: done_c6, done_c6_133, done_etc, done_land, done_fx (MPI GRIBs)
#                 wget_huss, wget_tas, wget_uas, wget_vas, wget_mrsol (from run-nc2grib-exp_var.sh)
#
# OUTPUTS:
#   - Global and EU GRIBs written to:
#      ${path_dout}/glob , ${path_dout}/EU
#   - File names like:
#      MPI-HR_<experiment>_<YYYYMMDD_HH>_glob.grb
#      MPI-HR_<experiment>_<YYYYMMDD_HH>_EU.grb
#
# NOTES:
#   - 00:00 timestamps use 23:56 from the previous day (time shift of 240 s)
#     to ensure temporal continuity.
#   - Wind components are converted via dv2uv; spectral fields are converted
#     to gridpoint via sp2gp.
#   - Derived fields (e.g., MSL, skin temperature, ice mask) are computed
#     from the merged products as needed.
#   - The EU subdomain box is defined in the "User configurations" section.
#
# VERSIONS:
#  Created   2025/03/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro
#  Modified  2026/03/02 - Luana C. Santos: single day/hour (optional date and hour, was single-merge_grib-ssp.sh)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                        MPI INPUT VARIABLES                    |
#----------------------------------------------------------------
## Gribs (done_ folders)
#1 .._rcm_c6 contains:
#      130 (air temperature) [K]
#      138 (vorticity) [s-1]
#      155 (divergence) [s-1]
#2 .._rcm_c6_133 contains:
#      133 (specific humidity) [kg/kg]
#      134 (surface pressure) [Pa]
#3 .._rcm_etc contains:
#      102 (surface temperature of ice) [K]
#      103 (surface temperature of water) [K]
#      139 (surface temperature of land) [K]
#      140 (soil wetness) [m]
#      141 (snow depth) [m]
#     x153 (cloud water) [kg/kg]
#     x154 (cloud ice) [kg/kg]
#     x193 (skin reservoir content) [m]
#      210 (ice cover) [fraction]
#     x211 (ice depth) [m]
#     x214 (water equivalent of snow on ice) [m]
#4 .._rcm_land contains:
#       68 (soil temperature, 5 levels) [K]
#5 .._rcm_fx contains:
#      129 (surface geopotential, orography) [m2/s2]
#      172 (land/sea mask) [1/0]
#     x229 (field capacity of soil) [229]
#     x232 (fraction of land covered by glaciers) 
#
## wget (download)
#1 ..surface contains:
#      165 (10m u-velocity) [m/s]
#      166 (10m v-velocity) [m/s]
#      167 (2m temperature) [K]
#       54 (2m specific humidity) [kg/kg]
#2 ..soil contains:
#       84 (soil moisture content [m]) [kg/m2]

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: cdo (shifttime, selyear/selmon/selday/selhour, dv2uv, sp2gp, sealevelpressure, sellonlatbox), eccodes (grib_set), coreutils
module load intel_v2025.0.4/cdo/v2.4.4
module load intel_v2025.0.4/eccodes/v2.39.0

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch2-merge_grib-exp.sh
experiment=$1  # experiment (historical | ssp*)
year=$2        # year (YYYY)
date_sel=$3    # optional: one day of that year (YYYYMMDD); empty = all the year
hour_sel=$4    # optional: one hour of that day (00 | 06 | 12 | 18); empty = the 4 hours

if [[ -z "${experiment}" || -z "${year}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <year> [date] [hour]"
 echo "         experiment : historical | ssp126 | ssp245 | ssp370 | ssp585"
 echo "         year       : YYYY"
 echo "         date       : optional, one day of that year (YYYYMMDD)"
 echo "         hour       : optional, one hour of that day (00 | 06 | 12 | 18)"
 exit 1
fi
if [[ -n "${date_sel}" && "${date_sel:0:4}" != "${year}" ]]; then
 echo "[ERROR] date ${date_sel} is not in year ${year}"
 exit 1
fi
if [[ -n "${hour_sel}" && -z "${date_sel}" ]]; then
 echo "[ERROR] hour ${hour_sel} needs a date (YYYYMMDD)"
 exit 1
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_din="/media/Synology15/MPI-HR_CMIP6/teste/ready_${experiment}"  ## <<< Set the path of the input data
path_dout="/media/Synology15/MPI-HR_CMIP6/MPI/${experiment}"         ## <<< Set the path for the output data
mkdir -p ${path_dout}/glob; mkdir -p ${path_dout}/EU

### SETTINGS
lon1=-55.0;lon2=70.0;lat1=15.0;lat2=90.0                          ## <<< EU subdomain box

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}/${year}"; mkdir -p ${path_w}

### Months and hours to process (all, or the ones of date/hour)
if [ -n "${date_sel}" ]; then
 list_months=${date_sel:4:2}
else
 list_months=$(seq -w 1 12)
fi
if [ -n "${hour_sel}" ]; then
 list_hours=${hour_sel}
else
 list_hours=$(seq -w 0 6 18)
fi

#----------------------------------------------------------------
#                          PROCESSING                           |
#----------------------------------------------------------------
echo "=============================================="
echo " [INFO] Processing: ${experiment} ${year} ${date_sel} ${hour_sel}"
echo "=============================================="

## 0) Symbolic link of the raw data
cd ${path_w}
if [ "${experiment}" == "historical" ]; then
 ln -sf ${path_din}/done_c6/amip_r1i1p1f1-HR_eh6_rcm_c5_*.grb .
 ln -sf ${path_din}/done_c6_133/amip_r1i1p1f1-HR_eh6_rcm_c5_133_*.grb .
 ln -sf ${path_din}/done_etc/amip_r1i1p1f1-HR_eh6_rcm_etc_*.grb .
 ln -sf ${path_din}/done_land/amip_r1i1p1f1-HR_jsb_rcm_land_*.grb .
 ln -sf ${path_din}/done_fx/amip-HR_rcm_fx_1.grb .
else
 ln -sf ${path_din}/done_c6/${experiment}_r1i1p1f1-HR_eh6_rcm_c6_*.grb .
 ln -sf ${path_din}/done_c6_133/${experiment}_r1i1p1f1-HR_eh6_rcm_c6_133_*.grb .
 ln -sf ${path_din}/done_etc/${experiment}_r1i1p1f1-HR_eh6_rcm_etc_*.grb .
 ln -sf ${path_din}/done_land/${experiment}_r1i1p1f1-HR_jsb_rcm_land_*.grb .
 ln -sf ${path_din}/done_fx/${experiment}-HR_rcm_fx_1.grb .
fi
ln -sf ${path_din}/wget_uas/uas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_*.grb .
ln -sf ${path_din}/wget_vas/vas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_*.grb .
ln -sf ${path_din}/wget_tas/tas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_*.grb .
ln -sf ${path_din}/wget_huss/huss_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_*.grb .
ln -sf ${path_din}/wget_mrsol/mrsol_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_*.grb .

#................................................................
# Loop months                                                   .
#................................................................
#!Loop over months (01 to 12)
for month in ${list_months}; do
 days_in_month=$(date -d "$year-$month-01 +1 month -1 day" "+%d")
 #...............................................................
 # Loop days                                                    .
 #...............................................................
 #!Loop over days (01 to last day of the month)
 if [ -n "${date_sel}" ]; then
  list_days=${date_sel:6:2}
 else
  list_days=$(seq -w 1 $days_in_month)
 fi
 for day in ${list_days}; do
  #..............................................................
  # Loop hours                                                  .
  #..............................................................
  #!Loop over hours (00 06 12 18)
  for hour in ${list_hours}; do
   
   ## 1) Check dates for the cases with a 4min time shift
   # Default reference date is the same as the current one
   r_year=${year}
   r_month=${month}
   r_day=${day}
   
   # If hour=00:00:00, use 23:56:00 from the previous day
   if [ "$hour" == "00" ]; then
    ## Check if it's the first loop iteration (no previous data available)
    ## 2009 = first year of historical; 2015 = first year of scenarios
    if ([ "$year" -eq "2008" ] || [ "$year" -eq "2015" ]) && [ "$month" -eq "01" ] && [ "$day" -eq "01" ]; then
     echo " - [INFO] Skipping first 00:00:00 because no previous day data is available"
     continue
    fi
    
    # Shift to previous day
    prev_date=$(date -d "$year-$month-$day -1 day" "+%Y %m %d")
    r_year=$(date -d "$year-$month-$day -1 day" "+%Y")
    r_month=$(date -d "$year-$month-$day -1 day" "+%m")
    r_day=$(date -d "$year-$month-$day -1 day" "+%d")
   fi
   
   echo " - [INFO] Date: ${year}-${month}-${day}_${hour}; Day before if needed: ${r_year}-${r_month}-${r_day}"
   
   
   ## 2) Data from done folders
   #>>> done_c6: 130/138/155 -> 130/131/132
   if [ "${experiment}" == "historical" ]; then
    file=amip_r1i1p1f1-HR_eh6_rcm_c5_${r_year}${r_month}.grb
   else
    file=${experiment}_r1i1p1f1-HR_eh6_rcm_c6_${r_year}${r_month}.grb
   fi
   cdo -s -R -L shifttime,240s ${file} ${file}2
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file}2 tmp1
   cdo -s -L -dv2uv tmp1 tmp2
   cdo -s -L -sp2gp tmp2 keep_01.grb
   #! To compute 151(msl): 130
   cdo -selcode,130 keep_01.grb msl_130.grb
   rm tmp1 tmp2 ${file}2
   #cdo vct keep_01.grb > coeffs.txt
   
   #>>> done_c6_133: 133/134
   if [ "${experiment}" == "historical" ]; then
    file=amip_r1i1p1f1-HR_eh6_rcm_c5_133_${r_year}${r_month}.grb
   else
    file=${experiment}_r1i1p1f1-HR_eh6_rcm_c6_133_${r_year}${r_month}.grb
   fi
   cdo -s -R -L shifttime,240s ${file} ${file}2
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file}2 keep_02.grb
   #! To compute 151(msl): 134 (on hibrid level)
   cdo -selcode,134 keep_02.grb tmp
   grib_set -s indicatorOfTypeOfLevel=109,level=1 tmp msl_134.grb  #Re-labels the level to "Soil Layer 1" for 134=surface_pressure
   rm tmp ${file}2
   
   #>>> done_etc: 153/154/102/103/139/140/141/193/210/211/214
   if [ "${experiment}" == "historical" ]; then
    file=amip_r1i1p1f1-HR_eh6_rcm_etc_${r_year}${r_month}.grb
   else
    file=${experiment}_r1i1p1f1-HR_eh6_rcm_etc_${r_year}${r_month}.grb
   fi
   cdo -s -L shifttime,240s ${file} ${file}2
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file}2 keep_03.grb
   #! To compute skin temperature
   cdo -s -L -f grb1 copy -selcode,103 keep_03.grb skin_103.grb
   cdo -s -L -f grb1 copy -selcode,139 keep_03.grb skin_139.grb
   #! To compute ice mask
   cdo -s -L -f grb1 copy -selcode,102 keep_03.grb skin_102.grb
   cdo -s -L -f grb1 copy -selcode,210 keep_03.grb ice_210.grb
   rm ${file}2
   
   #>>> done_land: 68
   if [ "${experiment}" == "historical" ]; then
    file=amip_r1i1p1f1-HR_jsb_rcm_land_${r_year}${r_month}.grb
   else
    file=${experiment}_r1i1p1f1-HR_jsb_rcm_land_${r_year}${r_month}.grb
   fi
   cdo -s -L shifttime,240s ${file} ${file}2
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file}2 keep_04.grb
   rm ${file}2
   
   #>>> done_fx: 129/172/229/232
   if [ "${experiment}" == "historical" ]; then
    file=amip-HR_rcm_fx_1.grb
   else
    file=${experiment}-HR_rcm_fx_1.grb
   fi
   grib_set -s date=${year}${month}${day},hour=${hour} ${file} keep_05.grb
   #! To compute 151(msl): 129 (on hibrid level)
   cdo -selcode,129 keep_05.grb tmp
   grib_set -s indicatorOfTypeOfLevel=109,level=1 tmp msl_129.grb #Re-labels the level to "Soil Layer 1" for 129=geopotential
   #! To compute skin temperature
   cdo -s -L -f grb1 copy -selcode,172 keep_05.grb land_172.grb
   rm tmp
   
   #>>> Compute 151 (msl) from 129(geo_pot), 134(sur_press), 130(air_temp)
   cdo -s -L -O merge msl_*.grb tmp
   cdo -s -L -sealevelpressure tmp keep_06.grb #sea level pressure (SLP) from surface pressure, temperature, and geopotential height.
   rm tmp msl_*
   
   #>>> Compute Skin Temperature
   #! Skin temperature
   cdo -setcode,1 -ifthenelse land_172.grb skin_139.grb skin_103.grb keep_11.grb
   #! Ice mask (fraction>=0.75)
   cdo -s -L -f grb1 gec,0.75 ice_210.grb ice_mask.grb
   cdo -setcode,2 -ifthenelse ice_mask.grb skin_102.grb keep_11.grb keep_12.grb
   rm ice_210.grb ice_mask.grb land_172.grb skin_*
   
   
   ## 3) Data from the wget folders
   #>>> Surface variables: huss tas uas vas mrsol - wget has the correct time
   file=huss_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_${year}${month}.grb
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file} tmp
   cdo -s -L -chlevel,2,0 tmp keep_21.grb
   rm tmp
   file=tas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_${year}${month}.grb
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file} tmp
   cdo -s -L -chlevel,2,0 tmp keep_22.grb
   rm tmp
   file=uas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_${year}${month}.grb
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file} tmp
   cdo -s -L -chlevel,10,0 tmp keep_23.grb
   rm tmp
   file=vas_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_${year}${month}.grb
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file} tmp
   cdo -s -L -chlevel,10,0 tmp keep_24.grb
   rm tmp
   file=mrsol_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_${year}${month}.grb
   cdo -s -L -selyear,${year} -selmon,${month} -selday,${day} -selhour,${hour} ${file} tmp0
   #! Correct soil moisture: from kg/m2 -> divide by both water density (1000kg/m3) and soil level thickness (m) -> kg/m2 / kg/m2 = fraction
   cdo -s -L -divc,60 -sellevel,3 tmp0 layer_1.grb     # 1000 * 0.06 =   60
   cdo -s -L -divc,260 -sellevel,19 tmp0 layer_2.grb   # 1000 * 0.26 =  260
   cdo -s -L -divc,1000 -sellevel,78 tmp0 layer_3.grb  # 1000 * 1.00 = 1000
   cdo -s -L -divc,2810 -sellevel,268 tmp0 layer_4.grb # 1000 * 2.81 = 2810
   cdo -s -L -divc,5700 -sellevel,698 tmp0 layer_5.grb # 1000 * 5.70 = 5700
   cdo -s -L -f grb1 merge layer_*.grb tmp1
   rm tmp0 layer_*.grb
   #! Correct negative values of SM (code 84)
   cdo setrtoc,-99.0,0,0.00001 -selcode,84 tmp1 SMkk
   cdo replace tmp1 SMkk keep_25.grb
   rm tmp1 SMkk
   
   
   ## 4) Merge data and defines centre=MPI-ESM1-2-HR model
   cdo -s -L -O merge keep_*.grb tmp
   cdo -s -L -setattribute,Institut=MPIMET tmp MPI-HR_${experiment}_${year}${month}${day}_${hour}_glob.grb
   rm tmp keep_*.grb
   
   
   ## 5) Cut data for EUROPE
   cdo -sellonlatbox,${lon1},${lon2},${lat1},${lat2} MPI-HR_${experiment}_${year}${month}${day}_${hour}_glob.grb MPI-HR_${experiment}_${year}${month}${day}_${hour}_EU.grb

  done #hour
 done #day
 
 
 ## 6) Move data every month
 mv MPI-HR*_glob.grb ${path_dout}/glob
 mv MPI-HR*_EU.grb ${path_dout}/EU
 #sleep 5

done #month


## 7) Clear raw data
rm -f ${experiment}*.grb amip*.grb uas* vas* tas* huss* mrsol*
echo "=============================================="
echo " [INFO] Done. Output GRIBs in: ${path_dout}"
echo "=============================================="

exit 0
