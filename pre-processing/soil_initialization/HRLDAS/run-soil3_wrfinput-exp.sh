#!/bin/bash
#SBATCH --job-name=soil3
#SBATCH --account=spptbent
#SBATCH --mail-type=ALL
#SBATCH --time=01:00:00
#SBATCH --qos=nf
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --hint=nomultithread
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-soil3_wrfinput-exp.sh
#
# PURPOSE:
#  Prepare soil initialization fields for WRF from the last LDASOUT output of HRLDAS.
#  Called from:
#   - launch-soil-exp.sh (step 3)
#
# USAGE:
#  sbatch run-soil3_wrfinput-exp.sh <experiment> <year>
#   experiment : historical | ssp245 | ssp370 | ...
#   year       : year of the HRLDAS run (step 2)
#
# INPUTS:
#  - In <experiment>_<year>/wrf_outfiles: last <YYYYMMDDHH>.LDASOUT_DOMAIN1.loop<NNNN> (step 2)
#  - In <experiment>_<year>/wrf_infiles : wrfinput_d01 (copy of the wrfinput of the simulation, step 2)
#
# OUTPUTS:
#  - In <experiment>_<year>: wrfinput_d01_hrldas (wrfinput with the soil and snow of HRLDAS)
#
# NOTES:
#  Tasks:
#  1. Extracts soil & snow variables
#  2. Reorders dimensions for compatibility
#  3. Renames and documents fields
#  4. Cleans up data to avoid WRF crashing due to negative/missing values
#  5. Patches soil temperatures with SST
#  Use wrfinput_d01_hrldas as the wrfinput_d01 of the simulation.
#
# VERSIONS:
#  Created   2025/06/16 - Luana C. Santos (lssantos@ciencias.ulisboa.pt) & Rita M. Cardoso
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: nco
module load nco

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-soil-exp.sh
experiment=$1  # experiment (historical | ssp*)
year=$2        # year of the HRLDAS run

if [[ -z "${experiment}" || -z "${year}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <year>"
 echo "         experiment : historical | ssp245 | ssp370 | ..."
 echo "         year       : year of the HRLDAS run (step 2)"
 exit 1
fi

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-soil3_wrfinput-exp.sh ${experiment} ${year}"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}_${year}"
path_in="${path_w}/wrf_infiles"       # wrfinput_d01 (copy made in step 2)
path_out="${path_w}/wrf_outfiles"     # LDASOUT files (step 2)
cd "${path_w}" || exit 1

### Last LDASOUT from HRLDAS (the last one written) and wrfinput
LDASOUT=$(ls -1t "${path_out}"/*.LDASOUT_DOMAIN* 2>/dev/null | head -1)
wrfinput="${path_in}/wrfinput_d01"
if [ -z "${LDASOUT}" ]; then
 echo "[ERROR] no LDASOUT files in ${path_out} (run step 2 first)"
 exit 1
fi
if [ ! -f "${wrfinput}" ]; then
 echo "[ERROR] ${wrfinput} not found (run step 2 first)"
 exit 1
fi
echo "[INFO] LDASOUT : ${LDASOUT}"
echo "[INFO] wrfinput: ${wrfinput}"

### Files of a previous run
rm -f soil_ini.nc soil_wrf_ini.nc temp.nc temp1.nc temp2.nc temp3.nc wrfinput_d01_hrldas

#----------------------------------------------------------------
#                     SOIL AND SNOW FIELDS                      |
#----------------------------------------------------------------
### Extract needed variables - soil_ini.nc
ncks -A -v SOIL_T,SOIL_M,SOIL_W,SNOWH,SNEQV ${LDASOUT} soil_ini.nc

### Copy dimensions - soil_wrf_ini.nc
ncpdq -O -a Time,soil_layers_stag,south_north,west_east soil_ini.nc soil_wrf_ini.nc

### Rename variables - soil_wrf_ini.nc
ncrename -v SOIL_T,TSLB soil_wrf_ini.nc
ncrename -v SOIL_M,SMOIS soil_wrf_ini.nc
ncrename -v SOIL_W,SH2O soil_wrf_ini.nc
ncrename -v SNEQV,SNOW soil_wrf_ini.nc

ncatted -O -a MemoryOrder,SH2O,o,c,"XYZ" soil_wrf_ini.nc
ncatted -O -a description,SH2O,o,c,"SOIL LIQUID WATER" soil_wrf_ini.nc
ncatted -O -a units,SH2O,o,c,"m3 m-3" soil_wrf_ini.nc
ncatted -O -a stagger,SH2O,o,c,"Z" soil_wrf_ini.nc
ncatted -O -a coordinates,SH2O,o,c,"XLONG XLAT XTIME" soil_wrf_ini.nc
ncatted -O -a MemoryOrder,SMOIS,o,c,"XYZ" soil_wrf_ini.nc
ncatted -O -a description,SMOIS,o,c,"SOIL MOISTURE" soil_wrf_ini.nc
ncatted -O -a units,SMOIS,o,c,"m3 m-3" soil_wrf_ini.nc
ncatted -O -a stagger,SMOIS,o,c,"Z" soil_wrf_ini.nc
ncatted -O -a coordinates,SMOIS,o,c,"XLONG XLAT XTIME" soil_wrf_ini.nc
ncatted -O -a MemoryOrder,TSLB,o,c,"XYZ" soil_wrf_ini.nc
ncatted -O -a description,TSLB,o,c,"SOIL TEMPERATURE" soil_wrf_ini.nc
ncatted -O -a coordinates,TSLB,o,c,"XLONG XLAT XTIME" soil_wrf_ini.nc
ncatted -O -a MemoryOrder,SNOWH,o,c,"XY " soil_wrf_ini.nc
ncatted -O -a description,SNOWH,o,c,"PHYSICAL SNOW DEPTH" soil_wrf_ini.nc
ncatted -O -a MemoryOrder,SNOWH,o,c,"XY " soil_wrf_ini.nc
ncatted -O -a coordinates,SNOWH,o,c,"XLONG XLAT XTIME" soil_wrf_ini.nc
ncatted -O -a MemoryOrder,SNOW,o,c,"XY " soil_wrf_ini.nc
ncatted -O -a description,SNOW,o,c,"SNOW WATER EQUIVALENT" soil_wrf_ini.nc
ncatted -O -a units,SNOW,o,c,"kg m-2" soil_wrf_ini.nc
ncatted -O -a stagger,SNOW,o,c,"" soil_wrf_ini.nc
ncatted -O -a coordinates,SNOW,o,c,"XLONG XLAT XTIME" soil_wrf_ini.nc

### Clean up: no negative/missing values
ncap2 -O -h -s 'where(SH2O <= 0) SH2O=1' soil_wrf_ini.nc temp1.nc
ncap2 -O -h -s 'where(SMOIS <= 0) SMOIS=1' temp1.nc temp2.nc
ncap2 -O -h -s 'where(SNOW <= 0) SNOW=0' temp2.nc temp3.nc
ncap2 -O -h -s 'where(SNOWH <= 0) SNOWH=0' temp3.nc soil_wrf_ini.nc

ncatted -h -a,global,d,, soil_wrf_ini.nc

### Patch soil temperatures with SST
ncks -A -v SST ${wrfinput} soil_wrf_ini.nc

ncap2 -O -h -s 'where(TSLB <= 0) TSLB=SST' soil_wrf_ini.nc temp.nc

#----------------------------------------------------------------
#                        WRFINPUT FILE                          |
#----------------------------------------------------------------
### Copy of the wrfinput with the HRLDAS fields
cp ${wrfinput} wrfinput_d01_hrldas
ncks -M -m -C -A -h temp.nc wrfinput_d01_hrldas

rm -f soil_ini.nc temp1.nc temp2.nc temp3.nc

echo "[INFO] Done. wrfinput with the HRLDAS soil: ${path_w}/wrfinput_d01_hrldas"

exit 0
