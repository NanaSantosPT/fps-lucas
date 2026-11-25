#!/bin/bash
#SBATCH --job-name=launch-merge_grib
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64,mp64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:05:00

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch2-merge_grib-exp.sh
#
# PURPOSE:
#  Launch run-merge_grib-exp_year.sh via SLURM to merge monthly
#  GRIB files into yearly sequences for a given experiment.
#
# USAGE:
#  sbatch launch2-merge_grib-exp.sh
#
# VERSIONS:
#  Created  2025/11/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="/media/Synology09/lsantos/github/fps-lucas/pre-processing/boundary_conditions"  ## <<< folder with these scripts
dir_work="/media/vor_disk1/data/lsantos/merge_gribs"                                        ## <<< folder where the jobs run (temporary files)

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                                    ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS
experiment=historical  ## <<< historical/ssp245/ssp370
declare -a years_list=($(seq 2009 2014))  ## <<< historical (1850 2014)
#declare -a years_list=($(seq 2015 2100)) ## <<< ssp245/ssp370 (2015 2100)

### SPECIFIC DAY (optional)
#   Empty: all the days of each year of years_list
#   Set  : only this day (years_list is ignored), all 4 hours or only one
date=""          ## <<< one day (YYYYMMDD), e.g. 20810815
hour=""          ## <<< one hour of that day: 00 | 06 | 12 | 18 (empty = the 4 hours)

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
if [ -n "${date}" ]; then
 years_list=(${date:0:4})
fi

for year in "${years_list[@]}"; do
 sbatch --job-name="MPI_grib-${experiment}_${year}" \
        --chdir="${dir_work}" --mail-user="${mail_user}" \
        "${dir_scripts}/run-merge_grib-exp_year.sh" \
        "${experiment}" "${year}" "${date}" "${hour}"
 echo "[INFO] Submitted merge_grib job: ${experiment} ${year} ${date} ${hour}"
done

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# 19h00 per 1 year (YYYY)
# ~3 min per 1 day (4 hours)
