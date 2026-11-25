#!/bin/bash
#SBATCH --job-name=launch-aerosols
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:05:00

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  launch-aerosols4wrf-exp.sh
#
# PURPOSE:
#  Submit run-aerosols4wrf-exp.sh to create the WRF aerosol input
#  files (auxinput15) from GCM (MPI-ESM1-2-HR) or MERRA-2 AOD data.
#
# USAGE:
#  sbatch launch-aerosols4wrf-exp.sh
#
# VERSIONS:
#  Created  2025/11/13 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
dir_scripts="/media/Synology09/lsantos/github/fps-lucas/pre-processing/aerosols"  ## <<< folder with these scripts
dir_work="/media/vor_disk1/data/lsantos/aerosols"                                 ## <<< folder where the jobs run (temporary files)

### E-MAIL
mail_user="lssantos@ciencias.ulisboa.pt"                                          ## <<< e-mail sent by SLURM at the end of each job

### ARGUMENTS - MPI-ESM1-2-HR (historical 1850-2014 | ssp 2015-2100)
#data=historical       ## <<< historical | ssp245 | ssp370
#target=LUCAS          ## <<< LUCAS | SP | P | ... (name of the geo_em file)
#domain=d01            ## <<< d01 | d02
#year_beg=1950         ## <<< start year
#year_end=2014         ## <<< end year

### ARGUMENTS - MERRA (1980 onwards)
data=MERRA             ## <<< MERRA
target=SP              ## <<< LUCAS | SP | P | ... (name of the geo_em file)
domain=d01             ## <<< d01 | d02
year_beg=1980          ## <<< start year
year_end=2025          ## <<< end year

### SPECIFIC PERIOD (optional, GCM or MERRA)
#   Empty: monthly and yearly files for year_beg..year_end
#   Set  : monthly files and one file AOD_<name>_<YYYYMMDD>_<YYYYMMDD>_<domain> (year_beg/year_end are ignored)
date_beg=""            ## <<< first day (YYYY-MM-DD), e.g. 2021-12-20
date_end=""            ## <<< last day  (YYYY-MM-DD), e.g. 2022-01-10

#----------------------------------------------------------------
#                          SUBMIT JOB                           |
#----------------------------------------------------------------
sbatch --job-name="aer-${data}-${target}_${domain}" \
       --chdir="${dir_work}" --mail-user="${mail_user}" \
       "${dir_scripts}/run-aerosols4wrf-exp.sh" \
       "${data}" "${target}" "${domain}" "${year_beg}" "${year_end}" "${dir_scripts}" "${date_beg}" "${date_end}"

echo "[INFO] Submitted aerosol job: ${data} ${target} ${domain} ${year_beg}-${year_end} ${date_beg} ${date_end}"

#----------------------------------------------------------------
#                          TIME NEEDED                          |
#----------------------------------------------------------------
# GCM (MPI-ESM1-2-HR): ~1h30 for 1 scenario between 2015-2100
#   > ex.: ssp245 between 2015-2100
#   > ex.: ssp370 between 2015-2100
#
# MERRA JUELICH: ~1 min per month (mostly gunzip of the 1.2 GB files)
#   > ex.: SP (São Paulo) d01 between 1980-2020: ~6h30 (one job per domain; ask 12h)
#   > ex.: SP (São Paulo) d02 between 1980-2020: ~6h30
#
# MERRA NASA: ~2 min per year (3 MB files, already downloaded)
#   > ex.: P  (Paris) d01 between 2021-2025: ~10min
#   > ex.: P  (Paris) d02 between 2021-2025: ~10min
