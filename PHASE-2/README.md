# LUCAS Phase 2

Realistic land use change experiments on a continental scale, driven by CMIP6 GCM data (and, optionally, by ERA5), following the protocol:
Rechid D., Katragkou E., Davin E.L., Hoffmann P., Reinhart V., van Meijgaard E. (2026) *Modelling the impact of land-use and land-cover changes on climate using an ensemble of regional climate models: Experiment Protocol CORDEX LUCAS Phase 2*. Zenodo. https://doi.org/10.5281/zenodo.23801952

## Experiment setup (protocol)
Name                | Values                                                                 | Description
--------------------|------------------------------------------------------------------------|-------------
Domain              | EURO-CORDEX                                                            | WRF model domain
Resolution          | 0.11° (~12.5 km)                                                       | Horizontal grid spacing
Forcing             | CMIP6 GCM: MPI-ESM1.2-HR r1i1p1f1 (optional: r2i1p1f1)<br>Evaluation: ERA5.1 (optional) | Boundary conditions
Simulation_period   | Historical: 1950–2014<br>Scenario: 2015–2100<br>Evaluation: 1981–2020 | Transient simulations, preceded by model-specific spin-up
Scenario            | SSP1-2.6 (other SSPs optional)                                         | CMIP6 scenario
Land_Use_Forcing    | Dynamic (`-LUC`): LUCAS LUC V1.1, annual PFT maps, 1950–2100 (from LUH2)<br>Static (`-LU2015`): LUCAS LUC V1.1 for 2015 | Land use input
LUC_Update_Freq     | Annual                                                                 | Frequency of land cover updates
GHG                 | As in the driving CMIP6 model                                          | Greenhouse gas forcing
Aerosols            | EURO-CORDEX guidelines (Katragkou et al. 2024)                         | Aerosol forcing

## Experiments (protocol)
Experiment       | Driving data              | Land use                        | Period
-----------------|---------------------------|---------------------------------|----------
EVAL-LUC         | ERA5.1 (optional)         | LUCAS LUC PFTs, annual          | 1981–2020
EVAL-LU2015      | ERA5.1 (optional)         | LUCAS LUC PFTs, 2015            | 1981–2020
HIST-LUC         | MPI-ESM1.2-HR historical  | LUCAS LUC PFTs, annual          | 1950–2014
HIST-LU2015      | MPI-ESM1.2-HR historical  | LUCAS LUC PFTs, 2015            | 1950–2014
SSP126-LUC       | MPI-ESM1.2-HR SSP1-2.6    | LUCAS LUC PFTs, annual (SSP1-2.6) | 2015–2100
SSP126-LU2015    | MPI-ESM1.2-HR SSP1-2.6    | LUCAS LUC PFTs, 2015            | 2015–2100

Simulations with annual land use changes are identified by adding `-LUC` to the `source_id` of the model (CORDEX-CMIP6 archiving specifications).

**Land use data** (WDCC, registration at DKRZ):
- Historical 1950–2015: [LUCAS LUC historical, Europe, V1.1](https://doi.org/10.26050/WDCC/LUC_hist_EU_v1.1)
- Scenarios 2015–2100: [LUCAS LUC future, Europe, V1.1](https://doi.org/10.26050/WDCC/LUC_future_EU_v1.1)

**WRF (MODIS categories), from the protocol:**
- Evergreen and deciduous shrubland PFTs → "Open shrubland"; C3 grass → "Grassland"; irrigated and non-irrigated cropland → cropland.
- Mixed forest and cropland/natural vegetation mosaic are set to zero (no such types in LUCAS LUC).
- Snow and ice are not in LUCAS LUC: added to `LANDUSEF`, with `surface_input_source = 1` in `namelist.input`.

In this repository: yearly `geo_em` files in `pre-processing/geo_em`, MPTABLE with the LAI corrected for Europe and the yearly CO2 in `pre-processing/MPTABLE`, aerosols in `pre-processing/aerosols`.

## Simulations IDL-FCUL / CIEMAT
WRF v4.5.1.4 with Noah-MP, MPI-ESM1-2-HR r1i1p1f1.

Name              | Institution | Protocol                  | Period    | Driving data                              | Land use                | LAI
------------------|-------------|---------------------------|-----------|-------------------------------------------|-------------------------|----------
lucas-historical  | IDL-FCUL    | HIST-LUC                  | 1950–2014 | MPI-ESM1-2-HR historical, pressure levels | LUCAS LUC v1.1, yearly  | corrected
lucas-ssp370      | IDL-FCUL    | SSP370-LUC (optional SSP) | 2015–2100 | MPI-ESM1-2-HR SSP3-7.0, model levels      | LUCAS LUC v1.1, yearly  | corrected
lucas-ssp245      | CIEMAT      | SSP245-LUC (optional SSP) | 2015–2100 | MPI-ESM1-2-HR SSP2-4.5, model levels      | LUCAS LUC v1.1, yearly  | corrected

## Files

File | Use
-----|----
`namelist.wps`                  | WPS for the SSP runs (model levels: ungrib + `calc_ecmwf_p`, `&mod_levs`)
`namelist.wps_historical`       | WPS for the historical run (intermediate files on pressure levels, no ungrib)
`namelist.input.in`             | WRF for the SSP runs (`num_metgrid_levels = 96`)
`namelist.input.in_historical`  | WRF for the historical run (`num_metgrid_levels = 26`, `sfcp_to_sfcp`)
`myoutfields.txt`               | Output fields (`iofields_filename`)
`WPS-tables/Vtable.MPI-HR.ml.ls`          | Vtable for the MPI-ESM1-2-HR model-level GRIB files
`WPS-tables/MPI-HR_coeffs`                | Hybrid level coefficients for `calc_ecmwf_p.exe` (link as `ecmwf_coeffs`)
`WPS-tables/METGRID.TBL.ARW.MPI`          | METGRID.TBL for the SSP runs (with soil layers)
`WPS-tables/METGRID.TBL.ARW.MPI_historical` | METGRID.TBL for the historical run

The namelists are templates: values written as `${...}` (namelist.wps) or `_NAME_` (namelist.input.in) are filled by the run scripts (dates, paths, AOD and output-field files).

## Lake temperature
`util/tavgsfc.py` computes `TAVGSFC` (15-day running mean of near-surface temperature) from the `met_em` files, used by `real.exe` for the inland lakes. Run it once per year on all `met_em` files, including the 15 days before, and do not use `-O` when processing in chunks.
