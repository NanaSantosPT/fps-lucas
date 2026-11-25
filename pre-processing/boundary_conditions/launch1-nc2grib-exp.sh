#!/bin/bash
#SBATCH --job-name=launch-nc2grib
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64,mp64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:05:00

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch1-nc2grib-exp.sh
#
# PURPOSE:
#  Launch run-nc2grib-exp_var.sh via SLURM to convert MPI-ESM1-2-HR
#  NetCDF variables into monthly GRIB1 files for a given experiment.
#
# USAGE:
#  sbatch launch1-nc2grib-exp.sh
#
# VERSIONS:
#  Created  2025/11/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="/media/Synology09/lsantos/github/fps-lucas/pre-processing/boundary_conditions"  ## <<< folder with these scripts
dir_work="/media/vor_disk1/data/lsantos/nc2grib"                                            ## <<< folder where the jobs run (temporary files)

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                                    ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS
experiment=historical           ## <<< historical/ssp245/ssp370
declare -a variables=('hus')    ## <<< list of variables to process
#declare -a variables=('huss' 'tas' 'uas' 'vas' 'mrsol' 'hus')

### SPECIFIC MONTH (optional)
#   Empty: all the months of the NetCDF files
#   Set  : only this month, for each variable of the list
yyyymm=""                       ## <<< one month (YYYYMM), e.g. 208108

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
for var in "${variables[@]}"; do
 sbatch --job-name="nc2grib-${experiment}_${var}" \
        --chdir="${dir_work}" --mail-user="${mail_user}" \
        "${dir_scripts}/run-nc2grib-exp_var.sh" \
        "${experiment}" "${var}" "${yyyymm}"
 echo "[INFO] Submitted nc2grib job: ${experiment} ${var} ${yyyymm}"
done

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# 01h30 per 1 variable (huss|tas|uas|vas) between 1850-2015
# 04h30 per 1 variable (mrsol) between 1850-2015
# 04h30 per 1 variable (huss|tas|uas|vas) between 2015-2100
# 05h30 per 1 variable (mrsol) between 2015-2100
