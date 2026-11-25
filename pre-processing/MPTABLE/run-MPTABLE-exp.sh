#!/bin/bash
#SBATCH --job-name=MPTABLE
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:10:00
#SBATCH --mail-type=END

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-MPTABLE-exp.sh
#
# PURPOSE:
#  Create one Noah-MP table (MPTABLE.TBL) per year, with the CO2
#  of that year taken from the WRF file CAMtr_volume_mixing_ratio.
#  Called from:
#   - launch-MPTABLE-exp.sh
#
# USAGE:
#  sbatch run-MPTABLE-exp.sh <experiment> <year_beg> <year_end> <path_scripts>
#   experiment   : historical | ssp119 | ssp126 | ssp245 | ssp370 | ssp585
#   year_beg     : start year
#   year_end     : end year
#   path_scripts : folder with these scripts, MPTABLE_LAI.TBL and the CAMtr files
#
# INPUTS (in path_scripts):
#  - MPTABLE_LAI.TBL                   : Noah-MP table with the LAI corrected for Europe and
#                                        the placeholder _CHANGE-CO2_ in the CO2 line
#  - CAMtr_volume_mixing_ratio.<SSP>   : yearly CO2 (ppmv), from WRF/run
#
# OUTPUTS:
#  - Yearly : MPTABLE.TBL_<experiment>_<YYYY>
#
# NOTES:
#  - historical uses the SSP370 file (all CAMtr files have the same values until 2014).
#  - CO2 is written as <ppmv>e-06 (mol/mol), as in the original MPTABLE.
#
# VERSIONS:
#  Created  2025/02/06 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: awk, sed

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-MPTABLE-exp.sh
experiment=$1     # experiment (historical | ssp*)
year_beg=$2       # start year
year_end=$3       # end year
path_scripts=$4   # folder with these scripts, MPTABLE_LAI.TBL and the CAMtr files

if [[ -z "${experiment}" || -z "${year_beg}" || -z "${year_end}" || -z "${path_scripts}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <year_beg> <year_end> <path_scripts>"
 echo "         experiment   : historical | ssp119 | ssp126 | ssp245 | ssp370 | ssp585"
 echo "         year_beg     : start year"
 echo "         year_end     : end year"
 echo "         path_scripts : folder with these scripts, MPTABLE_LAI.TBL and the CAMtr files"
 exit 1
fi

### CAMtr file of the scenario (historical uses SSP370)
if [[ "${experiment}" == "historical" ]]; then
 camtr_ssp="ssp370"
else
 camtr_ssp="${experiment}"
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_dout="/media/Synology15/MPI-HR_CMIP6/MPTABLE/${experiment}"           ## <<< output: MPTABLE files
mkdir -p "${path_dout}"

### FIXED VALUES (do not change)
table_base="MPTABLE_LAI.TBL"                                       # base table (LAI corrected for Europe)
camtr_file="CAMtr_volume_mixing_ratio.${camtr_ssp^^}"               # yearly CO2 (file names use SSP in capitals)

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-MPTABLE-exp.sh ${experiment} ${year_beg}-${year_end}"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}"
mkdir -p "${path_w}"
cd "${path_w}" || exit 1

### Base table and CO2 file
for file in "${table_base}" "${camtr_file}"; do
 if [ ! -f "${path_scripts}/${file}" ]; then
  echo "[ERROR] ${path_scripts}/${file} not found"
  exit 1
 fi
done
ln -sf "${path_scripts}/${table_base}" .
ln -sf "${path_scripts}/${camtr_file}" .

#----------------------------------------------------------------
#                        MPTABLE PER YEAR                       |
#----------------------------------------------------------------
for year in $(seq ${year_beg} ${year_end}); do
 ### CO2 of the year (ppmv, column 2 of the CAMtr file)
 co2=$(awk -v y="${year}" '$1 == y {printf "%.3f", $2}' "${camtr_file}")
 if [ -z "${co2}" ]; then
  echo "[WARN] No CO2 value for ${year} in ${camtr_file}, skipped"
  continue
 fi
 ### Base table with the CO2 of the year
 file_out="MPTABLE.TBL_${experiment}_${year}"
 sed "s/_CHANGE-CO2_/${co2}/g" "${table_base}" > "${file_out}"
 echo "[INFO] Created ${file_out} (CO2 = ${co2} ppmv)"
done

### Move the tables to the output folder
mv MPTABLE.TBL_${experiment}_* "${path_dout}/." 2>/dev/null || true

echo "[INFO] Done. MPTABLE files in: ${path_dout}"

exit 0
