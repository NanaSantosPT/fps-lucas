#!/bin/bash
#SBATCH --job-name=nc2grib
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64,mp64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=06:00:00
#SBATCH --mail-type=END
#SBATCH --exclusive

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-nc2grib-exp_var.sh
#
# PURPOSE:
#  Convert MPI-ESM1-2-HR NetCDF 5-year chunks into monthly GRIB1 for a given experiment and variable.
#  Fixes the "Jan 1st 00Z in December" issue by merging first and then splitting.
#  Called from:
#   - launch1-nc2grib-exp.sh
#
# USAGE:
#  sbatch run-nc2grib-exp_var.sh <experiment> <variable> [yyyymm]
#   experiment : historical | ssp126 | ssp245 | ssp370 | ssp585
#   variable   : huss | tas | uas | vas | mrsol (6hrPlevPt) or hus (6hrLev)
#   yyyymm     : optional, one month (YYYYMM); empty = all the months
#
# INPUTS (folders set in USER CONFIGURATIONS):
#  - In path_din: <variable>_6hrPlevPt_MPI-ESM1-2-HR_<experiment>_r1i1p1f1_gn_<YYYYMMDDHHMM>-<YYYYMMDDHHMM>.nc (5-year chunks)
#                 hus_6hrLev_MPI-ESM1-2-HR_<experiment>_r1i1p1f1_gn_<YYYY>.nc (yearly)
#
# OUTPUTS:
#  - In path_dout/wget_<variable>: <variable>_6hrPlevPt_MPI-ESM1-2-HR_<experiment>_r1i1p1f1_gn_<YYYYMM>.grb
#  - In path_dout/done_c6_133    : amip_r1i1p1f1-HR_eh6_rcm_c5_133_<YYYYMM>.grb (hus)
#
# NOTES:
#   Parameter/level mapping used here:
#    - uas :  code 165.128 @ ltype=1   (surface)
#    - vas :  code 166.128 @ ltype=1   (surface)
#    - tas :  code 167.128 @ ltype=1   (surface)
#    - huss:  code  54.128 @ ltype=1   (surface)
#    - mrsol: code  84.128 @ ltype=111 (soil layer), keeps multiple soil levels
#    - hus :  code 133.128 @ ltype=109 (hybrid)
#    - ps :   code 134.128 @ ltype=1   (surface)
#   Intermediate symlinks are created in ${path_w}
#   Final GRIBs are moved to ${path_dout}.
#   hus: done_c6_133 of the historical (not in the MPI archives); the GRIBs get the done_c6_133 name.
#
# VERSIONS:
#  Created   2025/03/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro
#  Modified  2026/03/02 - Luana C. Santos: single month (optional yyyymm, was single-nc2grib-ssp.sh)
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: cdo (-f grb1 copy, setparam, setltype, setzaxis, invertlat), coreutils
module load intel_v2025.0.4/cdo/v2.4.4

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch1-nc2grib-exp.sh
experiment=$1  # experiment (historical | ssp*)
variable=$2    # variable (huss | tas | uas | vas | mrsol | hus)
yyyymm=$3      # optional: one month (YYYYMM); empty = all the months

if [[ -z "${experiment}" || -z "${variable}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <variable> [yyyymm]"
 echo "         experiment : historical | ssp126 | ssp245 | ssp370 | ssp585"
 echo "         variable   : huss | tas | uas | vas | mrsol | hus"
 echo "         yyyymm     : optional, one month (YYYYMM)"
 exit 1
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_din="/media/Synology15/MPI-HR_CMIP6/raw/MPI_vars/${experiment}"        ## <<< input: raw NetCDF
path_dout="/media/Synology15/MPI-HR_CMIP6/teste/ready_${experiment}"        ## <<< output: base folder (wget_<variable>, done_c6_133)

### FIXED VALUES (do not change)
# File prefix and output sub-folder (depend on the variable)
case "${variable}" in
 huss|tas|uas|vas|mrsol)
  prefix="${variable}_6hrPlevPt_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_"
  folder_out="wget_${variable}";;
 hus)
  prefix="${variable}_6hrLev_MPI-ESM1-2-HR_${experiment}_r1i1p1f1_gn_"
  folder_out="done_c6_133";;
 *)
  echo "[ERROR] variable '${variable}' not supported."; exit 1 ;;
esac
path_dout="${path_dout}/${folder_out}"; mkdir -p ${path_dout}

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}/${variable}"; mkdir -p ${path_w}
cd ${path_w}

### Z-AXIS FOR SOIL DATA (temperature and moisture) - MPI-ESM1-2-HR
cat << EOF > myzaxis_soil.dat
zaxistype = depth_below_land
size      = 5
name      = depth
longname  = depth_below_land
units     = cm
levels    = 3 19 78 268 698
EOF

### Z-AXIS FOR HYBRID LEVELS (hus) - MPI-ESM1-2-HR
# GRIB1 encodes hybrid levels as integers; remap float coords to indices 1-95
cat << EOF > myzaxis_hybrid.dat
zaxistype = hybrid
size      = 95
name      = lev
longname  = hybrid_sigma_pressure_coordinate
units     = 1
levels    = $(seq -s ' ' 1 95)
vctsize   = 192
vct       = 0 0 0 72.0635986328125 271.62646484375 638.14892578125 1195.88989257812 1954.80493164062 2911.56909179688 4050.71801757812
            5345.9140625 6761.33984375 8253.2109375 9756.421875 11218.07421875 12573 13765.30859375 14753.79296875 15520.1796875
            16058.29296875 16370.24609375 16464.95703125 16355.96484375 16062.0859375 15604.63671875 15005.62109375 14289.19140625
            13479.76171875 12606.0390625 11698.04296875 10779.6796875 9876.25 9013.734375 8205.07421875 7464.85546875 6789.26171875
            6172.4453125 5610.73046875 5098.9921875 4632.50390625 4207.26171875 3819.623046875 3466.259765625 3144.14184570312
            2850.50659179688 2582.83544921875 2338.83251953125 2116.4052734375 1913.6455078125 1728.814453125 1560.32666015625
            1406.88818359375 1267.2919921875 1140.41430664062 1025.20947265625 920.7060546875 826.002685546875 740.26416015625
            662.718017578125 592.64990234375 529.400390625 472.361328125 420.973388671875 374.721435546875 333.132568359375
            295.77294921875 262.245361328125 232.185531616211 205.261016845703 181.168090820312 159.629776000977 140.393798828125
            123.230606079102 107.931594848633 94.3074035644531 82.1863403320312 71.4129333496094 61.8465270996094 53.3600463867188
            45.8387756347656 39.1793365478516 33.3141021728516 28.175537109375 23.6971588134766 19.8144378662109 16.465576171875
            13.5920419692993 11.1389989852905 9.05558681488037 7.29508113861084 5.81494045257568 4.57676124572754 3.54616451263428
            2.69261074066162 1.989182472229 0
            1 0.992299973964691 0.97299998998642 0.944199979305267 0.907700002193451 0.865000009536743 0.817200005054474
            0.765399992465973 0.710600018501282 0.653599977493286 0.595099985599518 0.535899996757507 0.476700007915497 0.418773472309113
            0.362762808799744 0.309877693653107 0.261051654815674 0.216900408267975 0.177573144435883 0.143075287342072 0.113242208957672
            0.0878006815910339 0.0664987564086914 0.0490049496293068 0.0349361412227154 0.0239001959562302 0.0155558660626411
            0.0094863623380661 0.00530741736292839 0.00262146862223744 0.00110446941107512 0.00034243892878294 4.64404874946922e-05
            0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
            0 0 0 0 0 0 0 0
##axis = Z
##formula = p = ap + b*ps
EOF

#----------------------------------------------------------------
#                          PROCESSING                           |
#----------------------------------------------------------------
echo "=============================================="
echo " [INFO] Processing: ${experiment} ${variable} ${yyyymm}"
echo "=============================================="

## 1) Symbolic link all NetCDF chunks of the variable (5-year blocks)
ln -sf ${path_din}/${prefix}*.nc .

## 1b) [OPTIONAL] For hus from NC source: apply shifttime to match downloaded GRIB structure
#if [[ "${variable}" == "hus" ]]; then
# for f in ${prefix}*.nc; do cdo -s shifttime,-240s "$f" tmp_sh.nc && mv tmp_sh.nc "$f"; done
#fi

if [ -z "${yyyymm}" ]; then
 #...............................................................
 # All the months                                               .
 #...............................................................
 ## 2) Merge all chunks (ensures 01 Jan 00Z goes to January)
 if [ -f "merged_${variable}.nc" ] || [[ "${variable}" == "hus" ]]; then
  echo " - [SKIP] merge not needed (merged file exists or hus is already annual)"
 else
  echo " - [INFO] merging all chunks (cdo mergetime)..."
  cdo -s -O mergetime ${prefix}*.nc merged_${variable}.nc
  rm -f ${prefix}*.nc
 fi

 ## 3) Split into yearly files
 #>>> creates files like: <prefix>_YYYY.nc
 yearly_count=$(ls ${prefix}[0-9][0-9][0-9][0-9].nc 2>/dev/null | wc -l)
 if [ "$yearly_count" -ne 0 ] || [[ "${variable}" == "hus" ]]; then
  echo " - [SKIP] splityear not needed (yearly files exist or hus is already annual)"
 else
  echo " - [INFO] splitting by year (cdo splityear)..."
  cdo -s splityear merged_${variable}.nc ${prefix}
 fi

 ## 4) Split into monthly files
 #>>> creates files like: <prefix>_YYYY_MM.nc
 monthly_count=$(ls ${prefix}[0-9][0-9][0-9][0-9]_[0-9][0-9].nc 2>/dev/null | wc -l)
 if [ "$monthly_count" -ne 0 ]; then
  echo " - [SKIP] monthly files already exist (${monthly_count} found)"
 else
  echo " - [INFO] splitting by month (cdo splitmon)..."
  for yfile in ${prefix}[0-9][0-9][0-9][0-9].nc; do
   cdo -s splitmon "${yfile}" "${yfile%.nc}_"
  done
 fi

 ## 5) Remove yearly files
 rm -f ${prefix}[0-9][0-9][0-9][0-9].nc

 ## 6) Rename monthly files to be consistent with other datasets
 #>>> creates files from <prefix>_YYYY_MM.nc to <prefix>_YYYYMM.nc
 remaining=$(ls ${prefix}[0-9][0-9][0-9][0-9]_[0-9][0-9].nc 2>/dev/null | wc -l)
 if [ "$remaining" -eq 0 ]; then
  echo " - [SKIP] monthly files already renamed (${remaining} old names found)"
 else
  echo " - [INFO] renaming monthly files to *_YYYYMM.nc..."
  for mfile in ${prefix}[0-9][0-9][0-9][0-9]_[0-9][0-9].nc; do
   fname="$(echo "${mfile}" | sed 's/_\([0-9]\{4\}\)_\([0-9]\{2\}\)\.nc$/_\1\2.nc/')"
   mv -f "${mfile}" "${fname}"
  done
 fi

else
 #...............................................................
 # Single month (yyyymm)                                        .
 #...............................................................
 ## 2) Get the single monthly NetCDF file
 #     NOTE: The raw 5-year chunks have the 00Z of Jan 1st at the END of the
 #     previous chunk (e.g., 2080-01-01 00:00 is in the 2075-2079 chunk).
 #     We must mergetime the chunks first so that splityear/splitmon puts
 #     every timestep in the correct month — same logic as the full pipeline.
 file_nc="${prefix}${yyyymm}.nc"
 yyyy="${yyyymm:0:4}"
 mm="${yyyymm:4:2}"

 if [ -f "${file_nc}" ]; then
  echo " - [SKIP] monthly NC already exists: ${file_nc}"
 elif [[ "${variable}" == "hus" ]]; then
  # hus data is already annual — but Jan still needs 2 years merged
  if [ "${mm}" == "01" ]; then
   prev_yyyy=$((10#${yyyy} - 1))
   echo " - [INFO] January requested — merging years ${prev_yyyy} and ${yyyy} to fix 00Z boundary..."
   cdo -s -O mergetime ${prefix}${prev_yyyy}*.nc ${prefix}${yyyy}*.nc tmp_merged_hus.nc
   cdo -s -selyear,${yyyy} -selmon,${mm} tmp_merged_hus.nc "${file_nc}"
   rm -f tmp_merged_hus.nc
  else
   annual_file="${prefix}${yyyy}.nc"
   if [ ! -f "${annual_file}" ]; then
    echo " - [INFO] annual file not found; extracting year ${yyyy} from chunk..."
    chunk=$(ls ${prefix}*.nc 2>/dev/null | head -1)
    if [ -z "${chunk}" ]; then
     echo " - [ERROR] no NetCDF file found for ${variable} ${yyyy}"; exit 1
    fi
    cdo -s selyear,${yyyy} "${chunk}" "${annual_file}"
   fi
   echo " - [INFO] extracting month ${mm} from ${annual_file}..."
   cdo -s selmon,${mm} "${annual_file}" "${file_nc}"
  fi
 else
  # For other variables (huss|tas|uas|vas|mrsol):
  # Find only the chunk(s) relevant to the target year.
  # Chunk filenames: ${prefix}YYYYMMDDHHMM-YYYYMMDDHHMM.nc
  # For January we also need the previous chunk (00Z of Jan 1st is there).

  # Build list of years to search for in chunk filenames
  check_years=("${yyyy}")
  [ "${mm}" == "01" ] && check_years+=("$((10#${yyyy} - 1))")

  target_chunks=()
  for chunk in $(ls ${prefix}*.nc 2>/dev/null | sort); do
   range="${chunk#${prefix}}"
   range="${range%.nc}"
   sy=$(echo "${range}" | cut -d'-' -f1 | cut -c1-4)
   ey=$(echo "${range}" | cut -d'-' -f2 | cut -c1-4)
   for cy in "${check_years[@]}"; do
    if [ "${cy}" -ge "${sy}" ] && [ "${cy}" -le "${ey}" ]; then
     target_chunks+=("${chunk}")
     break
    fi
   done
  done

  if [ ${#target_chunks[@]} -eq 0 ]; then
   echo " - [ERROR] no chunks found containing year ${yyyy}"; exit 1
  fi
  echo " - [INFO] using ${#target_chunks[@]} chunk(s): ${target_chunks[*]}"

  if [ ${#target_chunks[@]} -eq 1 ]; then
   # Single chunk — extract directly, no merge needed
   cdo -s -selyear,${yyyy} -selmon,${mm} "${target_chunks[0]}" "${file_nc}"
  else
   # January: merge only the 2 adjacent chunks, then extract
   echo " - [INFO] January — merging 2 chunks to fix 00Z boundary..."
   cdo -s -O mergetime "${target_chunks[@]}" tmp_2chunks.nc
   cdo -s -selyear,${yyyy} -selmon,${mm} tmp_2chunks.nc "${file_nc}"
   rm -f tmp_2chunks.nc
  fi
 fi

 if [ ! -f "${file_nc}" ]; then
  echo " - [ERROR] monthly NC file ${file_nc} not found after extraction"; exit 1
 fi
 echo " - [INFO] source file: ${file_nc}"
fi

## 7) Convert each monthly NC to GRIB1 with correct parameter & level type
#>>> Mapping:
#  - uas:   165.128 @ ltype=105 (heightAboveGround), level=10
#  - vas:   166.128 @ ltype=105 (heightAboveGround), level=10
#  - tas:   167.128 @ ltype=105 (heightAboveGround), level=2
#  - huss:   54.128 @ ltype=105 (heightAboveGround), level=2
#  - mrsol:  84.128 @ ltype=111 (soil layer), keep multiple soil levels
#  - hus:   133.128 @ ltype=109 (hybrid) + 134.128 @ ltype=1 (surface, ps)
echo " - [INFO] converting monthly NC → GRIB1 with param/ltype/level..."
grb_count=$(ls ${prefix}[0-9][0-9][0-9][0-9][0-9][0-9].grb 2>/dev/null | wc -l)
nc_count=$(ls ${prefix}[0-9][0-9][0-9][0-9][0-9][0-9].nc 2>/dev/null | wc -l)
if [ "$nc_count" -gt 0 ]; then
 for file_nc in ${prefix}[0-9][0-9][0-9][0-9][0-9][0-9].nc; do
  file_grb="${file_nc%.nc}.grb"
  if [ -f "${file_grb}" ]; then
   echo " --- [SKIP] ${file_grb} already exists"
   continue
  fi
  case "${variable}" in
   uas)   cdo -s -L -f grb1 copy -setparam,165.128 -setltype,1 "${file_nc}" tmp_pre_inv.grb;;
   vas)   cdo -s -L -f grb1 copy -setparam,166.128 -setltype,1 "${file_nc}" tmp_pre_inv.grb;;
   tas)   cdo -s -L -f grb1 copy -setparam,167.128 -setltype,1 "${file_nc}" tmp_pre_inv.grb;;
   huss)  cdo -s -L -f grb1 copy -setparam,54.128 -setltype,1 "${file_nc}" tmp_pre_inv.grb;;
   mrsol) cdo -s -L -f grb1 copy -setzaxis,${path_w}/myzaxis_soil.dat -setparam,84.128 -setltype,111 "${file_nc}" tmp_pre_inv.grb;;
   hus) # hus (code 133.128, 95 hybrid levels) + ps (code 134.128, surface)
    # Both variables are in the same NetCDF file and must stay together in the GRIB
    # Step A: select each variable in NC (avoids coord vars ap/b leaking into GRIB)
    cdo -s -L -delname,ps -selname,hus "${file_nc}" tmp_hus_only.nc
    cdo -s -L -selname,ps  "${file_nc}" tmp_ps_only.nc
    # Step B: convert clean NC to GRIB1 with proper param/ltype and integer levels + VCT
    # setzaxis remaps float levels (0.99...) to integer indices (1-95) for GRIB1
    cdo -s -L -f grb1 copy -setzaxis,${path_w}/myzaxis_hybrid.dat -setparam,133.128 -setltype,109 tmp_hus_only.nc tmp_hus.grb
    cdo -s -L -f grb1 copy -setparam,134.128 -setltype,1   tmp_ps_only.nc  tmp_ps.grb
    cdo -s -L -O merge tmp_hus.grb tmp_ps.grb tmp_pre_inv.grb
    rm -f tmp_hus.grb tmp_ps.grb tmp_hus_only.nc tmp_ps_only.nc ;;
  esac
  # Invert latitudes: S->N (NetCDF) to N->S (matching done_* GRIBs)
  cdo -s -L -invertlat tmp_pre_inv.grb "${file_grb}"
  rm -f tmp_pre_inv.grb
 done
else
 echo " - [WARN] no NC files to convert (${grb_count} GRBs already exist)"
fi

## 8) Clean NC files
rm -f *.nc

## 9) Rename output for hus (to match done_c6_133 naming convention)
# From: hus_6hrLev_MPI-ESM1-2-HR_<experiment>_r1i1p1f1_gn_YYYYMM.grb
# To:   amip_r1i1p1f1-HR_eh6_rcm_c5_133_YYYYMM.grb
if [[ "${variable}" == "hus" ]]; then
 echo " - [INFO] renaming GRIBs to done_c6_133 naming convention..."
 for gfile in ${prefix}[0-9][0-9][0-9][0-9][0-9][0-9].grb; do
  [ -f "${gfile}" ] || continue
  yyyymm=$(echo "${gfile}" | grep -oP '\d{6}(?=\.grb$)')
  newname="amip_r1i1p1f1-HR_eh6_rcm_c5_133_${yyyymm}.grb"
  mv -f "${gfile}" "${newname}"
 done
fi

## 10) Move GRIBs to final destination
mv -f *.grb "${path_dout}/" 2>/dev/null || true
echo "=============================================="
echo " [INFO] Done. Output GRIBs in: ${path_dout}"
echo "=============================================="

exit 0
