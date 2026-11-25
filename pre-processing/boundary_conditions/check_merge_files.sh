#!/bin/bash
#SBATCH --job-name=check_merge_files
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:30:00
#SBATCH --mail-type=END
#SBATCH --mail-user=lssantos@ciencias.ulisboa.pt

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  check_merge_files.sh
#
# PURPOSE:
#  Check the completeness of merged GRIB files on synology15.
#  For each year it checks:
#  1) Files with abnormally small sizes (likely incomplete/corrupted)
#  2) Missing timesteps (expected every 6h: 00 06 12 18)
#
# USAGE:
#  sbatch check_merge_files.sh
#
# INPUTS (folder set in USER CONFIGURATIONS):
#  - In path_din/EU: MPI-HR_<experiment>_<YYYYMMDD_HH>_EU.grb (from run-merge_grib-exp_year.sh)
#
# OUTPUTS:
#  Report printed to stdout (and captured in the SLURM log).
#
# VERSIONS:
#  Created  2026/02/27 - Luana C. Santos (lssantos@ciencias.ulisboa.pt)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: bc, coreutils (stat, sort, date)

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### ARGUMENTS
experiment=ssp370      ## <<< historical | ssp245 | ssp370
year_beg=2094          ## <<< first year to check
year_end=2094          ## <<< last  year to check

### DIRECTORIES
path_din="/media/Synology15/MPI-HR_CMIP6/MPI/${experiment}"  ## <<< output folder of run-merge_grib-exp_year.sh (path_dout)

### SETTINGS
# Threshold: flag files that deviate more than this fraction from the median
threshold_fraction=0.015  ## <<< Files below 95% of the median are flagged (5% tolerance)

#----------------------------------------------------------------
#                          PROCESSING                           |
#----------------------------------------------------------------
echo "================================================================"
echo " [CHECK] Experiment: ${experiment}  |  Years: ${year_beg}-${year_end}"
echo " [CHECK] Path:       ${path_din}"
echo "================================================================"
echo ""

total_files=0
total_flagged=0
total_missing=0

#for subdomain in glob EU; do
for subdomain in EU; do
 dir="${path_din}/${subdomain}"
 
 if [ ! -d "${dir}" ]; then
  echo " [WARN] Directory not found: ${dir}"
  continue
 fi
 
 echo "--------------------------------------------------------------"
 echo " Subdomain: ${subdomain}  (${dir})"
 echo "--------------------------------------------------------------"
 
 for year in $(seq ${year_beg} ${year_end}); do
  # Collect all files for this year
  files=( $(ls -1 ${dir}/MPI-HR_${experiment}_${year}*_${subdomain}.grb 2>/dev/null) )
  nfiles=${#files[@]}
  
  if [ ${nfiles} -eq 0 ]; then
   echo " [WARN] Year ${year}: NO FILES FOUND"
   continue
  fi
  
  # Get sizes into an array
  sizes=()
  for f in "${files[@]}"; do
   sz=$(stat --format="%s" "$f")
   sizes+=($sz)
  done
  
  # Compute median size
  sorted_sizes=($(printf '%s\n' "${sizes[@]}" | sort -n))
  mid=$(( nfiles / 2 ))
  if (( nfiles % 2 == 1 )); then
   median=${sorted_sizes[$mid]}
  else
   median=$(( (sorted_sizes[mid-1] + sorted_sizes[mid]) / 2 ))
  fi
  
  # Threshold: files must be at least (1 - threshold_fraction) * median
  min_ok=$(echo "${median} * (1 - ${threshold_fraction})" | bc | cut -d. -f1)
  
  # Count flagged (small files)
  flagged=0
  flagged_list=""
  for i in "${!files[@]}"; do
   if [ ${sizes[$i]} -lt ${min_ok} ]; then
    flagged=$((flagged + 1))
    flagged_list="${flagged_list}     *** SMALL: $(basename ${files[$i]})  size=${sizes[$i]}  (median=${median})
"
   fi
  done
  
  #.............................................................
  # Check for missing timesteps                                .
  #.............................................................
  # Build list of expected timesteps for this year
  # Hours: 00 06 12 18 for every day
  # Exception: first day of first year skips 00h (no previous data)
  missing=0
  missing_list=""
  
  # Determine if we need to skip the first 00h
  skip_first_00=false
  if [ "${experiment}" == "historical" ] && [ "$year" -eq "2009" ]; then
   skip_first_00=true
  elif [ "${experiment}" != "historical" ] && [ "$year" -eq "2015" ]; then
   skip_first_00=true
  fi
  
  for month in $(seq -w 1 12); do
   days_in_month=$(date -d "$year-$month-01 +1 month -1 day" "+%d")
   for day in $(seq -w 1 $days_in_month); do
    for hour in 00 06 12 18; do
     # Skip first 00h if applicable
     if [ "$skip_first_00" = true ] && [ "$month" == "01" ] && [ "$day" == "01" ] && [ "$hour" == "00" ]; then
      continue
     fi
     
     expected_file="${dir}/MPI-HR_${experiment}_${year}${month}${day}_${hour}_${subdomain}.grb"
     if [ ! -f "${expected_file}" ]; then
      missing=$((missing + 1))
      missing_list="${missing_list}     *** MISSING: MPI-HR_${experiment}_${year}${month}${day}_${hour}_${subdomain}.grb
"
     fi
    done
   done
  done
  
  total_files=$((total_files + nfiles))
  total_flagged=$((total_flagged + flagged))
  total_missing=$((total_missing + missing))
  
  # Print summary for this year
  if [ ${flagged} -gt 0 ] || [ ${missing} -gt 0 ]; then
   echo " [PROBLEM] Year ${year} ${subdomain}: ${nfiles} files, median=${median} bytes, ${flagged} SMALL, ${missing} MISSING"
   printf "%s" "${flagged_list}"
   printf "%s" "${missing_list}"
  else
   echo " [  OK  ] Year ${year} ${subdomain}: ${nfiles} files, median=${median} bytes"
  fi
  
 done #year
 echo ""
done #subdomain

echo "================================================================"
echo " [SUMMARY] Total files checked: ${total_files}"
echo " [SUMMARY] Total files SMALL:   ${total_flagged}"
echo " [SUMMARY] Total files MISSING: ${total_missing}"
echo "================================================================"

exit 0
