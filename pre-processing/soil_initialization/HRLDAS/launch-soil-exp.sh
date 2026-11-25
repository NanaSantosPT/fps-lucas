#!/bin/bash
#SBATCH --job-name=launch-soil
#SBATCH --account=spptbent
#SBATCH --time=00:05:00
#SBATCH --qos=nf
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --hint=nomultithread
#SBATCH --output=%x.%j.log
#SBATCH --error=%x.%j.log

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch-soil-exp.sh
#
# PURPOSE:
#  Submit one step of the soil initialisation with HRLDAS (offline Noah-MP):
#   1: run-soil1_ldasin-exp.sh   : wrfhrly files of a WRF year -> LDASIN forcing files
#   2: run-soil2_hrldas-exp.sh   : HRLDAS loops over that year (spin-up)
#   3: run-soil3_wrfinput-exp.sh : soil and snow of the last LDASOUT -> wrfinput
#  Run the steps in order, checking each one before the next.
#
# USAGE:
#  sbatch launch-soil-exp.sh
#
# VERSIONS:
#  Created  2025/11/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="${HPCPERM}/CORDEX/scripts/fps-lucas/pre-processing/soil_initialization/HRLDAS"  ## <<< folder with these scripts
dir_work="${SCRATCH}/LUCAS-phase2/soil"                                                      ## <<< folder where the jobs run

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                                     ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS
experiment=ssp370      ## <<< historical | ssp245 | ssp370 | ...
year=2015              ## <<< year of the WRF run with the wrfhrly files (looped by HRLDAS)
step=1                 ## <<< 1: wrfhrly -> LDASIN | 2: HRLDAS | 3: LDASOUT -> wrfinput

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
case "${step}" in
 1) run_file="run-soil1_ldasin-exp.sh";;
 2) run_file="run-soil2_hrldas-exp.sh";;
 3) run_file="run-soil3_wrfinput-exp.sh";;
 *) echo "[ERROR] step must be 1, 2 or 3 (got '${step}')"; exit 1;;
esac

mkdir -p "${dir_work}"
sbatch --job-name="soil${step}-${experiment}_${year}" \
       --chdir="${dir_work}" --mail-user="${mail_user}" \
       "${dir_scripts}/${run_file}" \
       "${experiment}" "${year}" "${dir_scripts}"

echo "[INFO] Submitted soil step ${step} (${run_file}): ${experiment} ${year}"

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# Not measured yet (SLURM limits in the runs: step 1 24h, step 2 48h on 10 nodes, step 3 1h)
