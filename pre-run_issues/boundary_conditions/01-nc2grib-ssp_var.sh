#!/bin/bash

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
#
# PURPOSE
#   Convert MPI-ESM1-2-HR NetCDF 5-year chunks into monthly GRIB1 for a given scenario and variable.
#   Fixes the “Jan 1st 00Z in December” issue by merging first and then splitting.
#
# USAGE
#   ./01-nc2grib-ssp_var.sh <scenario> <variable>
#  scenario: historical | ssp126 | ssp245 | ssp370 | ssp585
#  variable: huss | tas | uas | vas | mrsol  (6hrPlevPt products)
#
# INPUTS (set paths in the "Directories" section below)
#   - Raw 6hrPlevPt NetCDF chunks under ${path_i}, named like:
#  <var>_6hrPlevPt_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMMDDHHmm>-<YYYYMMDDHHmm>.nc
#
# OUTPUTS
#   - Monthly GRIB1 files in ${data_out} (and optionally moved to ${path_o}), named like:
#  <var>_6hrPlevPt_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMM>.grb
#
# REQUIREMENTS
#   - cdo (tested with -f grb1 copy, setparam, setltype, setlevel)
#   - coreutils
#
# NOTES
#   Parameter/level mapping used here:
#    - uas : code 165.128 @ ltype=1 (surface)
#    - vas : code 166.128 @ ltype=1 (surface)
#    - tas : code 167.128 @ ltype=1 (surface)
#    - huss: code  54.128 @ ltype=1 (surface)
#    - mrsol: code 84.128 @ ltype=111 (soil layer), keeps multiple soil levels
#   Intermediate symlinks are created in ${path_w}
#   Final GRIBs are moved to ${data_out} and (optionally) to ${path_o}.
#
# VERSIONS
#   Created  2025/03/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro

#----------------------------------------------------------------
#                        USER CONFIGURATIONS                    |
#----------------------------------------------------------------
### Load modules
#module purge
#module load cdo

### Data
scenario=$1   # <<< Set the scenario
variable=$2   # <<< Set the variable
prefix="${variable}_6hrPlevPt_MPI-ESM1-2-HR_${scenario}_r1i1p1f1_gn_"

### Directories
wrkdir=$(pwd)
path_w="${wrkdir}/${scenario}/${variable}"; mkdir -p ${path_w}
path_i="/media/Synology15/MPI-HR_CMIP6/raw/MPI_vars/${scenario}"                  # <<< Set the path of the input data
path_o="/media/Synology15/MPI-HR_CMIP6/teste/ready_${scenario}/wget_${variable}"  # <<< Set the path for the output data
mkdir -p ${path_o}

### z-axis for soil data (temperature and moisture) - MPI-ESM1-2-HR
cat << EOF > myzaxis_soil.dat
zaxistype = depth_below_land
size      = 5
name      = depth
longname  = depth_below_land
units     = cm
levels    = 3 19 78 268 698
EOF


#----------------------------------------------------------------
#                            SCRIPT                             |
#----------------------------------------------------------------
echo ">>> Processing: 01-nc2grib-ssp_var.sh ${scenario} ${variable}"

## 1) Symbolic link all NetCDF chunks of the variable (5-year blocks)
cd ${path_w}
ln -sf ${path_i}/${variable}*.nc .

## 2) Merge all chunks (ensures 01 Jan 00Z goes to January)
echo " - merging all chunks (cdo mergetime)..."
cdo -s -O mergetime ${prefix}*.nc merged_${variable}.nc
rm -f ${variable}_*.nc

## 3) Split into yearly files
# >>> creates files like: <prefix>_YYYY.nc
echo " - splitting by year (cdo splityear)..."
cdo -s splityear merged_${variable}.nc ${prefix}

## 4) Split into monthly files for ALL yearly files
# >>> creates files like: <prefix>_YYYY_MM.nc
echo " - splitting by month (cdo splitmon)..."
for yfile in ${prefix}[0-9][0-9][0-9][0-9].nc; do
 cdo -s splitmon "${yfile}" "${yfile%.nc}_"
done

## 5) Remove yearly files
rm -f ${prefix}[0-9][0-9][0-9][0-9].nc

## 6) Rename monthly files to be consistent with other datasets
# >>> creates files from <prefix>_YYYY_MM.nc to <prefix>_YYYYMM.nc
echo " - renaming monthly files to *_YYYYMM.nc..."
for mfile in ${prefix}[0-9][0-9][0-9][0-9]_[0-9][0-9].nc; do
 fname="$(echo "${mfile}" | sed 's/_\([0-9]\{4\}\)_\([0-9]\{2\}\)\.nc$/_\1\2.nc/')"
 mv -f "${mfile}" "${fname}"
done

## 7) Convert each monthly NC to GRIB1 with correct parameter & level type
# >>> Mapping:
#  - uas:   165.128 @ ltype=105 (heightAboveGround), level=10
#  - vas:   166.128 @ ltype=105 (heightAboveGround), level=10
#  - tas:   167.128 @ ltype=105 (heightAboveGround), level=2
#  - huss:   54.128 @ ltype=105 (heightAboveGround), level=2
#  - mrsol:  84.128 @ ltype=111 (soil layer), keep multiple soil levels
echo " - converting monthly NC → GRIB1 with param/ltype/level..."
case "${variable}" in
 uas)   param=165.128; ltype=1 ;; # height=10
 vas)   param=166.128; ltype=1 ;; # height=10
 tas)   param=167.128; ltype=1 ;; # height=2
 huss)  param=54.128;  ltype=1 ;; # height=2
 mrsol) param=84.128;  ltype=111 ;;
 *) echo "ERROR: variable '${variable}' not supported."; exit 2 ;;
esac
for file_nc in ${prefix}[0-9][0-9][0-9][0-9][0-9][0-9].nc; do
 file_grb="${file_nc%.nc}.grb"
 if [[ "${variable}" == "mrsol" ]]; then
  cdo -s -L -f grb1 copy -setzaxis,${wrkdir}/myzaxis_soil.dat -setparam,${param} -setltype,${ltype} "${file_nc}" "${file_grb}"
 else
  cdo -s -L -f grb1 copy -setparam,${param} -setltype,${ltype} "${file_nc}" "${file_grb}"
  #cdo -s -L -f grb1 copy -setparam,${param} -setltype,${ltype} -setlevel,${heigth} "${file_nc}" "${file_grb}"
 fi
done

## 8) Clean folder
rm -f *.nc

## 9) Move GRIBs to final destination
mv -f *.grb "${path_o}/" 2>/dev/null || true
echo ">>> Done. Output GRIBs in: ${path_o}"

