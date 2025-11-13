#!/bin/bash

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
#
# PURPOSE
#   Generate per-year Noah-MP MPTABLE files with CO2 replaced from
#  CAMtr_volume_mixing_ratio.<scenario> lookup.
#
# USAGE
#   ./create_yearly_MPTABLE.sh <scenario>
#  scenario:   ssp126 | ssp245 | ssp370 | ssp585
#
# INPUTS (set paths in the "Directories" section)
#   1) Required files:
#     - MPTABLE_LAI.TBL                       #! Base MPTABLE file to duplicate, already modified with LAI section for EUROPE
#     - CAMtr_volume_mixing_ratio.<scenario>  #! WRF/run file with yearly CO2 values
#
# OUTPUTS
#   - Yearly : MPTABLE.TBL_<scenario>_<YYYY>
#
# REQUIREMENTS
#   - coreutils (awk, sed, etc.)
#
# NOTES
#   - Ensure the base MPTABLE_LAI.TBL has the LAI section modified for EUROPE.
#   - Placeholder "_CHANGE-CO2_" in template will be replaced by CO2 values.
#
# VERSIONS
#   Created  2025/02/06 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro

#----------------------------------------------------------------
#                        USER CONFIGURATIONS                    |
#----------------------------------------------------------------
### Load modules
#module purge
#module load cdo nco ncl

### Data
scenario=$1       # <<< Set the scenario
start_year=1950   # <<< Set the start year
end_year=2100     # <<< Set the end year

### Directories
wrkdir=$(pwd)
path_w="${wrkdir}/${scenario}"; mkdir -p ${path_w}
path_s="/home/lsantos/scripts/pre-run-issues/tables"          # <<< Set the path of the scripts and needed files
path_o="/media/Synology15/MPI-HR_CMIP6/MPTABLE/${scenario}"   # <<< Set the path for the output data
mkdir -p ${path_o}

#----------------------------------------------------------------
#                            SCRIPT                             |
#----------------------------------------------------------------
echo ">>> Processing: create_yearly_MPTABLE.sh ${scenario}"

## 1) Symbolic link the needed data
cd ${path_w}
ln -sf ${path_s}/CAMtr_volume_mixing_ratio.${scenario^^} "./CAMtr_file"  #! WRF/run file with CO2 to replace
ln -sf ${path_s}/MPTABLE_LAI.TBL "./MPTABLE_orig"                        #! Base MPTABLE template

## Loops for YYYYMM
for year in $(seq $start_year $end_year); do         #!Loop over years (YYYYi to YYYYf)
 
 ## 2) Extract the CO₂ value for the current year
 co2=$(awk -v y="$year" '$1 == y {printf "%.3f", $2}' "./CAMtr_file")
 
 ## 3) Check if a CO₂ value was found
 if [ -z "$co2" ]; then
  echo " - Warning: CO₂ value for year $year not found. Skipping."
  continue
 fi
 
 ## 4) Replace the placeholder in the template and save to the new file
 MPTABLE_out=MPTABLE.TBL_${scenario}_${year}
 sed "s/_CHANGE-CO2_/${co2}/g" "MPTABLE_orig" > "${MPTABLE_out}"
 echo " - Generated ${MPTABLE_out} with CO₂ = $co2 ppmv"
done

## 5) Move data to final destination
mv MPTABLE.TBL_${scenario}* ${path_o}/.

echo ">>> Done. Output MPTABLEs in: ${path_o}"

