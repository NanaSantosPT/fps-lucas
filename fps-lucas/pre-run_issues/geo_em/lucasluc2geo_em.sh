#!/bin/bash

#----------------------------------------------------------------
#                          INFORMATIONS                         |
#----------------------------------------------------------------
#
# PURPOSE
#   Generate yearly WRF geo files (geo_em.*.nc) using LUCAS_LUC land use
#  for a selected scenario. Years are taken from the input file names.
#
# USAGE
#   ./lucasluc2geo_em.sh <scenario>
#  scenario: historical | ssp126 | ssp245 | ssp370 | ssp585
#
# INPUTS (set paths in the "Directories" section)
#   1) LUCAS_LUC inputs (by scenario)
#     - LUCAS_LUC_v1.1_<scenario>_Europe_0.1deg_<block>.nc
#
#   2) Required files:
#     - geo_em.<domain>.EUR-12-v4.1.nc        #!Template/grid to match EUR-12 domain (base fields copied from here)
#     - grid_corners.ncl                      #!Builds out_grid.nc (grid corners) used by CDO for remap weights
#     - water_ice.nc                          #!Auxiliary mask fields for water/ice handling in the final geo_em
#     - WRF_LUCAS_PFTs_v3_water_ice_landmask  #!Fortran binary that reads luc_input.nc and writes LUCAS PFTs + water/ice/landmask into geo_em
#
# OUTPUTS
#   - geo_em.<domain>_<scenario>_<year>.nc written to ${path_o}
#
# REQUIREMENTS
#   - cdo (splityear, remap*)
#   - nco (ncks)
#   - ncl
#   - Fortran binary above
#   - coreutils
#
# NOTES
#   - Set CDO remap method in the script (e.g., method=\"con\" or \"bil\").
#   - The script splits yearly, remaps to EUR-12, links the result as luc_input.nc,
#    copies the template geo_em, and appends LUCAS variables into the final file.
#
# VERSIONS
#   Created   2024/02/10 - Josipa Milovac (milovacj@unican.es)
#   Modified  2025/02/01 - Luana C. Santos (lssantos@ciencias.ulisboa.pt), Rita M. Cardoso & Jorge Navarro

#----------------------------------------------------------------
#                        USER CONFIGURATIONS                    |
#----------------------------------------------------------------
### Load modules
#module purge
#module load cdo nco ncl

### Data
scenario=$1   # <<< Set the scenario as "historical,ssp126,ssp245,ssp370,ssp585"
domain="d01"  # <<< Set the domain as "d01,..."
method="con"  # <<< Set the CDO remap method: "con" (conservative), "bil" (bilinear), ...

### Directories
wrkdir=$(pwd)
path_w="${wrkdir}/${scenario}"; mkdir -p ${path_w}
path_s="/home/lsantos/scripts/pre-run-issues/geo_em"             # <<< (Optional) Set the path to auxiliary files, to link them if needed
path_i="/media/tor_disk2/data/wrf/LUCAS/LUC/${scenario}"         # <<< Set the path of the input data
path_o="/media/tor_disk2/data/wrf/LUCAS/LUC/${scenario}/geo_em"  # <<< Set the path for the output data

#----------------------------------------------------------------
#                            SCRIPT                             |
#----------------------------------------------------------------
echo ">>> Processing: lucasluc2geo_em.sh ${scenario}"

## 1) Symbolic link the needed data
cd ${path_w}
ln -sf ${path_s}/geo_em.${domain}.EUR-12-v4.1.nc .
ln -sf ${path_s}/grid_corners.ncl .
ln -sf ${path_s}/water_ice.nc .
ln -sf ${path_s}/WRF_LUCAS_PFTs_v3_water_ice_landmask .

## 2) Build target WRF grid descriptor (out_grid.nc)
echo " - Extracting information for the inteprolation and deriving WRF target grid (out_grid.nc)"
cdo selname,LANDUSEF,XLAT_M,XLONG_M geo_em.${domain}.EUR-12-v4.1.nc LANDUSEF_WRF.nc
ncl grid_corners.ncl  #! expects LANDUSEF_WRF.nc → writes out_grid.nc

## 3) Remap water/ice auxiliary to target grid
echo " - Interpolating water/ice mask file to WRF grid"
cdo remap${method},out_grid.nc water_ice.nc ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc

## 4) Split multi-year LUCAS files into yearly files
echo " - Splitting LUCAS_LUC multi-year files to yearly files"
ln -sf ${path_i}/LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_* .
YEARS_BLOCKS=('2016_2025' '2026_2035' '2036_2045' '2046_2055' '2056_2065' '2066_2075' '2076_2085' '2086_2095' '2096_2100')
for block in "${YEARS_BLOCKS[@]}"; do
 cdo -s splityear "LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_${block}.nc" "LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_"
done
rm -f LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9].nc

## Process each year individually
YEARS=($(seq 2016 1 2100))
for year in "${YEARS[@]}"; do
 echo " - Creating ${year}"
 
 ## 5) Remap yearly LUCAS_LUC to target WRF grid
 echo " - Interpolating LUCAS_LUC (${year}) to WRF grid"
 cdo -s remap${method},out_grid.nc "LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_${year}.nc" "LUCAS_LUC_v1.1_${scenario}_EUR-12_${year}.nc"
 rm -f "LUCAS_LUC_v1.1_${scenario}_Europe_0.1deg_${year}.nc"
 
 ## 6) Provide luc_input.nc expected by the Fortran recategorization tool
 ln -sf "LUCAS_LUC_v1.1_${scenario}_EUR-12_${year}.nc" luc_input.nc
 
 ## 7) Run Fortran recategorization (produces LU_INDEX/LANDUSEF/LANDMASK)
 echo " - Recategorizing with Fortran tool (LU_INDEX/LANDUSEF/LANDMASK)"
 ./WRF_LUCAS_PFTs_v3_water_ice_landmask
 
 ## 8) Copy template geo_em and inject LUCAS variables into final yearly file
 echo " - Creating per-year geo_em and injecting land-use variables"
 cp "geo_em.${domain}.EUR-12-v4.1.nc" "geo_em.${domain}_${scenario}_${year}.nc"
 for varname in LU_INDEX LANDUSEF LANDMASK; do
  ncks -C -A -v "${varname}" "WRF_LUCAS_LUC_${varname}_v2.nc" "geo_em.${domain}_${scenario}_${year}.nc"
  rm -f "WRF_LUCAS_LUC_${varname}_v2.nc"
 done
 rm -f LUCAS_LUC_v1.1_${scenario}_EUR-12_${year}.nc
done

## 9) Move final yearly geo_em files to the target output folder
mv -f geo_em.${domain}_${scenario}_* ${path_o}/

##10) Optional cleanup of intermediate files generated during processing
# rm -f LANDUSEF_WRF.nc out_grid.nc ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc luc_input.nc grid_corners.ncl

echo ">>> Done. Outputs in: ${path_o}"
