#!/bin/bash
#SBATCH --job-name=LUC_geo
#SBATCH --output=%x.%j.log
#SBATCH --partition=np64
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --time=00:30:00
#SBATCH --mail-type=END

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
# NAME:
#  run-lucasluc2geo_em-exp.sh
#
# PURPOSE:
#  Create one WRF geo_em file per year with the LUCAS_LUC v1.1 land use
#  of a scenario (LU_INDEX, LANDUSEF and LANDMASK replaced in the EUR-12 geo_em).
#  Called from:
#   - launch-lucasluc2geo_em-exp.sh
#
# USAGE:
#  sbatch run-lucasluc2geo_em-exp.sh <experiment> <path_scripts>
#   experiment   : historical | ssp119 | ssp126 | ssp245 | ssp370 | ssp585
#   path_scripts : folder with these scripts, grid_corners.ncl, water_ice.nc and the Fortran program
#
# INPUTS (folders set in USER CONFIGURATIONS):
#  - In path_din: LUCAS_LUC_v1.1_<experiment>_Europe_0.1deg_<YYYY>_<YYYY>.nc (blocks of years)
#  - In path_geo: geo_em.<domain>.EUR-12-v4.1.nc (EUR-12 grid; all other fields are copied from it)
#  - In path_scripts:
#     grid_corners.ncl                     : WRF grid corners (out_grid.nc) for the CDO remap
#     water_ice.nc                         : water and ice fractions (ESA CCI)
#     WRF_LUCAS_PFTs_v3_water_ice_landmask : Fortran program (build it with the Makefile)
#
# OUTPUTS:
#  - Yearly : geo_em.<domain>_<experiment>_<YYYY>.nc
#
# NOTES:
#  - The LUCAS_LUC blocks are split into yearly files and remapped to the WRF grid (method).
#  - The Fortran program reads luc_input.nc, LANDUSEF_WRF.nc and the remapped water_ice file,
#    and writes LU_INDEX, LANDUSEF and LANDMASK, which are appended to a copy of the geo_em.
#
# VERSIONS:
#  Created   2024/02/10 - Josipa Milovac (milovacj@unican.es)
#  Modified  2025/02/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro
#----------------------------------------------------------------

#----------------------------------------------------------------
#                          ENVIRONMENT                          |
#----------------------------------------------------------------
### Tools needed: cdo, nco, ncl
module load intel_v2025.0.4/cdo/v2.4.4
module load intel_v2025.0.4/nco/v5.3.0
module load others/miniforge3/v3.12.8

#----------------------------------------------------------------
#                           ARGUMENTS                           |
#----------------------------------------------------------------
### Arguments given by launch-lucasluc2geo_em-exp.sh
experiment=$1     # experiment (historical | ssp*)
path_scripts=$2   # folder with these scripts, grid_corners.ncl, water_ice.nc and the Fortran program

if [[ -z "${experiment}" || -z "${path_scripts}" ]]; then
 echo "Usage:"
 echo "  $0 <experiment> <path_scripts>"
 echo "         experiment   : historical | ssp119 | ssp126 | ssp245 | ssp370 | ssp585"
 echo "         path_scripts : folder with these scripts, grid_corners.ncl, water_ice.nc and the Fortran program"
 exit 1
fi

#----------------------------------------------------------------
#                       USER CONFIGURATIONS                     |
#----------------------------------------------------------------
### DIRECTORIES
path_geo="/home/lsantos/data/geo_em"                                      ## <<< geo_em files (WRF grids)
path_din="/media/Synology16/LUCAS/Maps_Peter/LUCAS_LUC_v1.1"              ## <<< input: LUCAS_LUC files
path_dout="/media/Synology16/LUCAS/Maps_Peter/LUCAS_LUC_v1.1_geo/${experiment}"  ## <<< output: geo_em files
mkdir -p "${path_dout}"

### SETTINGS
domain="d01"      ## <<< WRF domain
method="con"      ## <<< CDO remap method: "con" (conservative), "bil" (bilinear), ...

### FIXED VALUES (do not change)
# Blocks of years of the LUCAS_LUC v1.1 files and years to create
if [ "${experiment}" == "historical" ]; then
 years_blocks=('1950_1959' '1960_1969' '1970_1979' '1980_1989' '1990_1999' '2000_2009' '2010_2015')
 year_beg=1950
 year_end=2014
else
 years_blocks=('2016_2025' '2026_2035' '2036_2045' '2046_2055' '2056_2065' '2066_2075' '2076_2085' '2086_2095' '2096_2100')
 year_beg=2016
 year_end=2100
fi
geo_file="geo_em.${domain}.EUR-12-v4.1.nc"                                 # EUR-12 geo_em (in path_geo)
program="WRF_LUCAS_PFTs_v3_water_ice_landmask"                             # Fortran program (in path_scripts)

#----------------------------------------------------------------
#                          PREPARATION                          |
#----------------------------------------------------------------
echo "[INFO] run-lucasluc2geo_em-exp.sh ${experiment} ${year_beg}-${year_end}"

### Working folder (inside the folder where the job runs)
path_w="$(pwd)/${experiment}"
mkdir -p "${path_w}"
cd "${path_w}" || exit 1

### geo_em, NCL script, water/ice file and Fortran program
if [ ! -f "${path_geo}/${geo_file}" ]; then
 echo "[ERROR] ${path_geo}/${geo_file} not found (check path_geo and domain)"
 exit 1
fi
if [ ! -x "${path_scripts}/${program}" ]; then
 echo "[ERROR] ${path_scripts}/${program} not found (build it with make in ${path_scripts})"
 exit 1
fi
ln -sf "${path_geo}/${geo_file}" .
ln -sf "${path_scripts}/grid_corners.ncl" .
ln -sf "${path_scripts}/water_ice.nc" .
ln -sf "${path_scripts}/${program}" .

### WRF grid (out_grid.nc) from the geo_em
echo "[INFO] Creating the WRF grid (out_grid.nc)"
cdo selname,LANDUSEF,XLAT_M,XLONG_M "${geo_file}" LANDUSEF_WRF.nc
ncl grid_corners.ncl    # reads LANDUSEF_WRF.nc, writes out_grid.nc

### Water/ice fractions on the WRF grid
echo "[INFO] Remapping water_ice.nc to the WRF grid"
cdo "remap${method},out_grid.nc" water_ice.nc ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc

### LUCAS_LUC blocks of years -> yearly files
echo "[INFO] Splitting the LUCAS_LUC files by year"
ln -sf "${path_din}/LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_"* .
for block in "${years_blocks[@]}"; do
 cdo -s splityear "LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_${block}.nc" "LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_"
done
rm -f LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9].nc    # links to the blocks

#----------------------------------------------------------------
#                        GEO_EM PER YEAR                        |
#----------------------------------------------------------------
for year in $(seq ${year_beg} ${year_end}); do
 file_out="geo_em.${domain}_${experiment}_${year}.nc"
 echo "[INFO] Creating ${file_out}"
 ### LUCAS_LUC of the year on the WRF grid
 cdo -s "remap${method},out_grid.nc" "LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_${year}.nc" "LUCAS_LUC_v1.1_${experiment}_EUR-12_${year}.nc"
 rm -f "LUCAS_LUC_v1.1_${experiment}_Europe_0.1deg_${year}.nc"
 ### Fortran program: LU_INDEX, LANDUSEF and LANDMASK (reads luc_input.nc)
 ln -sf "LUCAS_LUC_v1.1_${experiment}_EUR-12_${year}.nc" luc_input.nc
 ./${program}
 ### Copy of the geo_em with the new land use variables
 cp "${geo_file}" "${file_out}"
 for varname in LU_INDEX LANDUSEF LANDMASK; do
  ncks -C -A -v "${varname}" "WRF_LUCAS_LUC_${varname}_v2.nc" "${file_out}"
  rm -f "WRF_LUCAS_LUC_${varname}_v2.nc"
 done
 rm -f "LUCAS_LUC_v1.1_${experiment}_EUR-12_${year}.nc"
done

### Move the geo_em files to the output folder
mv -f geo_em.${domain}_${experiment}_* "${path_dout}/." 2>/dev/null || true

### Intermediate files (uncomment to remove them)
# rm -f LANDUSEF_WRF.nc out_grid.nc ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc luc_input.nc grid_corners.ncl

echo "[INFO] Done. geo_em files in: ${path_dout}"

exit 0
