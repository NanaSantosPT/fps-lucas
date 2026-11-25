#!/bin/bash
#SBATCH --job-name=soil1
#SBATCH --account=spptbent
#SBATCH --mail-type=ALL
#SBATCH --time=24:00:00
#SBATCH --qos=nf
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --hint=nomultithread
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-soil1_ldasin-exp.sh
#
# PURPOSE:
#  Create the LDASIN forcing files of HRLDAS from the hourly WRF output (wrfhrly).
#  N.B. the grids must match PERFECTLY in dimension.
#  Called from:
#   - launch-soil-exp.sh (step 1)
#
# USAGE:
#  sbatch run-soil1_ldasin-exp.sh <experiment> <year>
#   experiment : historical | ssp245 | ssp370 | ...
#   year       : year of the WRF run with the wrfhrly files
#
# INPUTS (folder set in USER CONFIGURATIONS):
#  - In path_dhrly: wrfhrly_d01_<YYYY-MM-DD_HH:MM:SS> (hourly, from WRF with WRF/namelist_soil.input.in)
#
# OUTPUTS:
#  - In <experiment>_<year>/wrf_infiles: <YYYYMMDDHH>.LDASIN_DOMAIN<n>
#
# NOTES:
#  Tasks:
#  1. Loop through list of WRF output files
#  2. From WRF Filename create and LDASIN filename (2004093001.LDASIN_DOMAIN2)
#  3. Extract 7 met forcing variables from full WRF output file
#  4. Merge convective and non-convective precip and create interval values...
#  5. Rename variables to LDASIN conventions
#  6. Adjust any units
#  Previously run as ./read_priscilla.csh
#
# VERSIONS:
#  Created   2011/06/01 - D. Gochis
#  Updated   2012/11/09 - D. Gochis
#  Modified  2018/06/19 - Priscilla A. Mooney
#  Modified  2025/06/16 - Luana C. Santos (lssantos@ciencias.ulisboa.pt) & Rita M. Cardoso
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: cdo, nco
module load cdo nco

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-soil-exp.sh
experiment=$1  # experiment (historical | ssp*)
year=$2        # year of the WRF run with the wrfhrly files

if [[ -z "${experiment}" || -z "${year}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <year>"
 echo "         experiment : historical | ssp245 | ssp370 | ..."
 echo "         year       : year of the WRF run with the wrfhrly files"
 exit 1
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_dhrly="${SCRATCH}/LUCAS-phase2/wrf_soil_${experiment}_${year}"   ## <<< input: wrfhrly files of the WRF run

### SETTINGS
domain="d01"           ## <<< WRF domain

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-soil1_ldasin-exp.sh ${experiment} ${year}"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}_${year}"
path_in="${path_w}/wrf_infiles"       # LDASIN files (INDIR of HRLDAS)
mkdir -p "${path_in}"
cd "${path_in}" || exit 1

### wrfhrly files
nfiles=$(ls "${path_dhrly}"/wrfhrly_${domain}_* 2>/dev/null | wc -l)
if [ "${nfiles}" -eq 0 ]; then
 echo "[ERROR] no wrfhrly_${domain}_* files in ${path_dhrly}"
 exit 1
fi
echo "[INFO] ${nfiles} wrfhrly files in ${path_dhrly}"

### Old LDASIN files and temporary files
rm -f [0-9]*.LDASIN_DOMAIN* DELETABLE.nc precip*.nc

#----------------------------------------------------------------
#                         LDASIN FILES                          |
#----------------------------------------------------------------
flag=0
for path_file in $(ls "${path_dhrly}"/wrfhrly_${domain}_*); do
 file=$(basename "${path_file}")
 dom=${file:10:1}
 yy=${file:12:4}
 mm=${file:17:2}
 dd=${file:20:2}
 hh=${file:23:2}
 file2="${yy}${mm}${dd}${hh}.LDASIN_DOMAIN${dom}"
 echo "[INFO] ${file} -> ${file2}"

 cdo -s -L copy -selname,Q2,T2,SWDOWN,GLW,U10,V10,PSFC ${path_file} DELETABLE.nc
 cdo -s -L add -selname,RAINC ${path_file} -mulc,1000 -selname,I_RAINC ${path_file} RAINC.nc
 cdo -s -L add -selname,RAINNC ${path_file} -mulc,1000 -selname,I_RAINNC ${path_file} RAINNC.nc
 cdo -s -L add RAINC.nc RAINNC.nc precip.nc
 rm RAINC.nc RAINNC.nc

 ### Precipitation of the last hour (accumulated now - accumulated one hour before)
 if [ ${flag} -ge 1 ]; then
  cdo -s sub precip.nc precip_old.nc precip_diff_tmp.nc
  mv precip.nc precip_old.nc
 else
  cp precip.nc precip_diff_tmp.nc
  flag=1
  mv precip.nc precip_old.nc
 fi

 ### mm per hour -> mm s-1
 cdo -s divc,3600 precip_diff_tmp.nc precip_diff.nc

 cdo -s merge precip_diff.nc DELETABLE.nc ${file2}

 rm precip_diff.nc precip_diff_tmp.nc DELETABLE.nc

 ### Rename variables to LDASIN conventions
 ncrename -v Q2,Q2D ${file2}
 ncrename -v T2,T2D ${file2}
 ncrename -v U10,U2D ${file2}
 ncrename -v V10,V2D ${file2}
 ncrename -v GLW,LWDOWN ${file2}
 ncrename -v RAINC,RAINRATE ${file2}

 ncatted -a TITLE,global,m,c,"v20150518" ${file2}
done

rm -f precip_old.nc

echo "[INFO] Done. $(ls [0-9]*.LDASIN_DOMAIN* | wc -l) LDASIN files in: ${path_in}"

exit 0
