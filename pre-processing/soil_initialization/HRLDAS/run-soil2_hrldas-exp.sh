#!/bin/bash
#SBATCH --job-name=soil2
#SBATCH --account=spptbent
#SBATCH --mail-type=ALL
#SBATCH --time=48:00:00
#SBATCH --qos=np
#SBATCH --nodes=10
#SBATCH --ntasks-per-node=128
#SBATCH --hint=nomultithread
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-soil2_hrldas-exp.sh
#
# PURPOSE:
#  Run the soil initialization using HRLDAS: the LDASIN files of one year are
#  looped spinup_loops times, starting from the wrfinput of the simulation.
#  Called from:
#   - launch-soil-exp.sh (step 2)
#
# USAGE:
#  sbatch run-soil2_hrldas-exp.sh <experiment> <year> <path_scripts>
#   experiment   : historical | ssp245 | ssp370 | ...
#   year         : year of the LDASIN files (step 1)
#   path_scripts : folder with these scripts, namelist.hrldas.in and the NoahmpTable files
#
# INPUTS (folders set in USER CONFIGURATIONS):
#  - In <experiment>_<year>/wrf_infiles: <YYYYMMDDHH>.LDASIN_DOMAIN1 (step 1)
#  - file_wrfinput: wrfinput of the simulation to initialise (HRLDAS setup file)
#  - In path_scripts: namelist.hrldas.in, NoahmpTable_LAI.TBL | NoahmpTable_orig.TBL
#  - In path_camtr  : CAMtr_volume_mixing_ratio.<SSP> (yearly CO2, folder MPTABLE)
#
# OUTPUTS:
#  - In <experiment>_<year>/wrf_outfiles: <YYYYMMDDHH>.LDASOUT_DOMAIN1.loop<NNNN>
#
# NOTES:
#  - The Noah-MP options of namelist.hrldas.in must be the same as in the WRF namelist (&noah_mp of PHASE-2).
#  - The CO2 of the table (_CHANGE-CO2_) is the CO2 of the year looped, constant during the spin-up.
#    historical uses the SSP370 CAMtr file (same values until 2014).
#
# VERSIONS:
#  Created   2025/06/16 - Luana C. Santos (lssantos@ciencias.ulisboa.pt) & Jorge Navarro
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: HRLDAS (hrldas.exe), srun; environment used to compile HRLDAS
source ${HOME}/.bash_compile_hrldas

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-soil-exp.sh
experiment=$1    # experiment (historical | ssp*)
year=$2          # year of the LDASIN files
path_scripts=$3  # folder with these scripts, namelist.hrldas.in and the NoahmpTable files

if [[ -z "${experiment}" || -z "${year}" || -z "${path_scripts}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <year> <path_scripts>"
 echo "         experiment   : historical | ssp245 | ssp370 | ..."
 echo "         year         : year of the LDASIN files (step 1)"
 echo "         path_scripts : folder with these scripts, namelist.hrldas.in and the NoahmpTable files"
 exit 1
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_hrldas="${HPCPERM}/hrldas/hrldas"                                         ## <<< HRLDAS folder (with run/hrldas.exe)
file_wrfinput="${SCRATCH}/LUCAS-phase2/real_${experiment}_${year}/wrfinput_d01"  ## <<< wrfinput of the simulation to initialise
path_camtr="${path_scripts}/../../MPTABLE"                                     ## <<< folder with the CAMtr files (yearly CO2)

### SETTINGS
table="NoahmpTable_LAI.TBL"   ## <<< NoahmpTable_LAI.TBL (LAI of Josipa Milovac, as WRF) | NoahmpTable_orig.TBL (original LAI)
start_mm=01                   ## <<< start of HRLDAS: month
start_dd=01                   ## <<< start of HRLDAS: day
start_hh=06                   ## <<< start of HRLDAS: hour (first LDASIN hour)
spinup_loops=20               ## <<< number of loops over the year

### FIXED VALUES (do not change)
# Days of the year looped by HRLDAS
if (( (year % 400 == 0) || (year % 4 == 0 && year % 100 != 0) )); then
 kday=366
else
 kday=365
fi
loop_last=$(printf "loop%04d" ${spinup_loops})   # suffix of the LDASOUT files of the last loop
# CAMtr file of the experiment (historical: SSP370, same values until 2014)
if [[ "${experiment}" == "historical" ]]; then
 camtr_ssp="ssp370"
else
 camtr_ssp="${experiment}"
fi
camtr_file="${path_camtr}/CAMtr_volume_mixing_ratio.${camtr_ssp^^}"   # file names use SSP in capitals

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-soil2_hrldas-exp.sh ${experiment} ${year} (${kday} days x ${spinup_loops} loops, ${table})"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}_${year}"
path_in="${path_w}/wrf_infiles"       # LDASIN files (INDIR of HRLDAS), from step 1
path_out="${path_w}/wrf_outfiles"     # LDASOUT files (OUTDIR of HRLDAS)

### Inputs
nfiles=$(ls "${path_in}"/[0-9]*.LDASIN_DOMAIN* 2>/dev/null | wc -l)
if [ "${nfiles}" -eq 0 ]; then
 echo "[ERROR] no LDASIN files in ${path_in} (run step 1 first)"
 exit 1
fi
if [ ! -f "${file_wrfinput}" ]; then
 echo "[ERROR] ${file_wrfinput} not found (check file_wrfinput)"
 exit 1
fi
if [ ! -x "${path_hrldas}/run/hrldas.exe" ]; then
 echo "[ERROR] ${path_hrldas}/run/hrldas.exe not found (check path_hrldas)"
 exit 1
fi
if [ ! -f "${path_scripts}/${table}" ]; then
 echo "[ERROR] ${path_scripts}/${table} not found (check table)"
 exit 1
fi
if [ ! -f "${camtr_file}" ]; then
 echo "[ERROR] ${camtr_file} not found (check path_camtr)"
 exit 1
fi
echo "[INFO] ${nfiles} LDASIN files in ${path_in}"

### CO2 of the year (ppmv, column 2 of the CAMtr file)
co2=$(awk -v y="${year}" '$1 == y {printf "%.3f", $2}' "${camtr_file}")
if [ -z "${co2}" ]; then
 echo "[ERROR] no CO2 value for ${year} in ${camtr_file}"
 exit 1
fi
echo "[INFO] CO2 of ${year}: ${co2} ppmv ($(basename ${camtr_file}))"

### Clean the outputs of a previous run
rm -rf "${path_out}"
mkdir -p "${path_out}"

### Copy of the wrfinput (HRLDAS setup file; step 3 writes the soil into a copy of it)
cp "${file_wrfinput}" "${path_in}/wrfinput_d01"
### Correct wrfinput_d01 (if HRLDAS does not accept its TITLE)
#ncatted -a TITLE,global,m,c,"v20150518" "${path_in}/wrfinput_d01"

### Namelist and table
cd "${path_w}" || exit 1
sed -e "s|_SETUP_FILE_|${path_in}/wrfinput_d01|" \
    -e "s|_INDIR_|${path_in}|" \
    -e "s|_OUTDIR_|${path_out}|" \
    -e "s|_START_YY_|${year}|" \
    -e "s|_START_MM_|${start_mm}|" \
    -e "s|_START_DD_|${start_dd}|" \
    -e "s|_START_HH_|${start_hh}|" \
    -e "s|_KDAY_|${kday}|" \
    -e "s|_LOOPS_|${spinup_loops}|" \
    "${path_scripts}/namelist.hrldas.in" > namelist.hrldas
sed "s/_CHANGE-CO2_/${co2}/g" "${path_scripts}/${table}" > NoahmpTable.TBL

#----------------------------------------------------------------
#                            HRLDAS                             |
#----------------------------------------------------------------
echo "[INFO] Starting HRLDAS in: $(pwd)"

### DEBUG: libraries of the executable
ldd ${path_hrldas}/run/hrldas.exe

srun ${path_hrldas}/run/hrldas.exe

### Check: LDASOUT files of the last loop
nlast=$(ls "${path_out}"/*.LDASOUT_DOMAIN*.${loop_last} 2>/dev/null | wc -l)
if [ "${nlast}" -eq 0 ]; then
 echo "[ERROR] HRLDAS did not finish: no LDASOUT files of the last loop (*.${loop_last}) in ${path_out}"
 exit 1
fi
echo "[INFO] Done. HRLDAS finished: ${nlast} LDASOUT files of the last loop in ${path_out}"

exit 0
