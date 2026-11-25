#!/bin/bash
#SBATCH --job-name=launch-LUC_geo
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:05:00

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch-lucasluc2geo_em-exp.sh
#
# PURPOSE:
#  Submit run-lucasluc2geo_em-exp.sh to create one WRF geo_em file
#  per year with the LUCAS_LUC v1.1 land use of a scenario.
#
# USAGE:
#  sbatch launch-lucasluc2geo_em-exp.sh
#
# VERSIONS:
#  Created  2025/02/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="/media/Synology09/lsantos/github/fps-lucas/pre-processing/geo_em"  ## <<< folder with these scripts
dir_work="/media/vor_disk1/data/lsantos/geo_em"                                ## <<< folder where the jobs run (temporary files)

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                       ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS
experiment=historical  ## <<< historical (1950-2014) | ssp119 | ssp126 | ssp245 | ssp370 | ssp585 (2016-2100)

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
sbatch --job-name="LUC_geo-${experiment}" \
       --chdir="${dir_work}" --mail-user="${mail_user}" \
       "${dir_scripts}/run-lucasluc2geo_em-exp.sh" \
       "${experiment}" "${dir_scripts}"

echo "[INFO] Submitted LUC_geo job: ${experiment}"

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# ~15 min for 1 scenario
#   > ex.: historical between 1950-2014
#   > ex.: ssp245 between 2016-2100
#   > ex.: ssp370 between 2016-2100
