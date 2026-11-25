#!/bin/bash
#SBATCH --job-name=launch-MPTABLE
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:05:00

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch-MPTABLE-exp.sh
#
# PURPOSE:
#  Submit run-MPTABLE-exp.sh to create one Noah-MP table (MPTABLE.TBL)
#  per year, with the CO2 of that year (CAMtr_volume_mixing_ratio).
#
# USAGE:
#  sbatch launch-MPTABLE-exp.sh
#
# VERSIONS:
#  Created  2025/02/06 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="/media/Synology09/lsantos/github/fps-lucas/pre-processing/MPTABLE"  ## <<< folder with these scripts
dir_work="/media/vor_disk1/data/lsantos/tables"                                 ## <<< folder where the jobs run (temporary files)

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                        ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS
experiment=historical  ## <<< historical | ssp119 | ssp126 | ssp245 | ssp370 | ssp585
year_beg=1950          ## <<< start year
year_end=2015          ## <<< end year

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
sbatch --job-name="MPTABLE-${experiment}" \
       --chdir="${dir_work}" --mail-user="${mail_user}" \
       "${dir_scripts}/run-MPTABLE-exp.sh" \
       "${experiment}" "${year_beg}" "${year_end}" "${dir_scripts}"

echo "[INFO] Submitted MPTABLE job: ${experiment} ${year_beg}-${year_end}"

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# ~10 s for 1 scenario between 1950-2100
#   > ex.: historical between 1950-2015 (uses the SSP370 CO2 values)
#   > ex.: ssp245 between 1950-2100
#   > ex.: ssp370 between 1950-2100
