# Pre-processing

Workflows to prepare the WRF input data of LUCAS Phase 2 from **CMIP6 MPI-ESM1-2-HR** (and MERRA-2 for the aerosols): boundary conditions, aerosol forcing (`auxinput15`), yearly `geo_em` files with the LUCAS land use, Noah-MP tables with yearly CO2, and the soil spin-up with HRLDAS.

## Structure
```
boundary_conditions/   # MPI-ESM1-2-HR -> WRF-ready GRIB files (ungrib)
aerosols/              # AOD550 -> auxinput15 (CMIP6 GCM or MERRA-2)
geo_em/                # LUCAS LUC v1.1 -> yearly geo_em files
MPTABLE/               # Noah-MP table with corrected LAI and yearly CO2
soil_initialization/   # Soil spin-up with HRLDAS (offline Noah-MP)
```

All folders follow the same scheme: a `launch-*.sh` (choose the case and submit with `sbatch`) and a `run-*.sh` (does the work for one case). The values to change are marked with `## <<<`: folders and e-mail in the launch, input/output folders and settings in the run.

## 1. Boundary conditions
Converts the CMIP6 surface variables from NetCDF to GRIB1 and merges them with the MPI GRIB archives (`done_*`) into WRF-ready files (`Vtable.MPI-HR`).
- `launch1-nc2grib-exp.sh` / `run-nc2grib-exp_var.sh` — `huss`, `tas`, `uas`, `vas`, `mrsol` (and `hus`) → monthly GRIB1
- `launch2-merge_grib-exp.sh` / `run-merge_grib-exp_year.sh` — all fields → `MPI-HR_<experiment>_<YYYYMMDD_HH>_glob.grb` and `_EU.grb` (lon −55 to 70, lat 15 to 90)
- `check_merge_files.sh` — missing time steps and incomplete files

Details: [boundary_conditions/README.md](boundary_conditions/README.md)

## 2. Aerosols (auxinput15)
Daily AOD at 550 nm on the WRF grid, from MPI-ESM1-2-HR `od550aer` or MERRA-2. Based on [aerosols4wrf](https://github.com/yoselita/aerosols4wrf) (Josipa Milovac).
- `launch-aerosols4wrf-exp.sh` / `run-aerosols4wrf-exp.sh` → `AOD_<name>_<YYYYMM>_<domain>` (monthly), `AOD_<name>_<YYYY>_<domain>` (yearly)

Details: [aerosols/README.md](aerosols/README.md)

## 3. Land use (geo_em)
Yearly `geo_em` files with the LUCAS LUC v1.1 land use (`LU_INDEX`, `LANDUSEF`, `LANDMASK`) on the EUR-12 grid. Based on [landmate2wrf](https://github.com/yoselita/landmate2wrf) (Josipa Milovac).
- `launch-lucasluc2geo_em-exp.sh` / `run-lucasluc2geo_em-exp.sh` → `geo_em.<domain>_<experiment>_<YYYY>.nc`

Details: [geo_em/README.md](geo_em/README.md)

## 4. Noah-MP MPTABLE
Yearly `MPTABLE.TBL` with the CO2 of the experiment and the LAI corrected for Europe ([lai4wrf](https://github.com/yoselita/lai4wrf), Josipa Milovac).
- `launch-MPTABLE-exp.sh` / `run-MPTABLE-exp.sh` → `MPTABLE.TBL_<experiment>_<YYYY>`

Details: [MPTABLE/README.md](MPTABLE/README.md)

## 5. Soil initialization
Spin-up of the soil for a cold start: one year of WRF hourly forcing looped by HRLDAS, and the final soil and snow written into the `wrfinput` (ECMWF scripts).
- `HRLDAS/launch-soil-exp.sh` (`step = 1 | 2 | 3`) / `HRLDAS/run-soil*-exp.sh` → `wrfinput_d01_hrldas`

Details: [soil_initialization/README.md](soil_initialization/README.md)

## Download of input data
- **Boundary conditions:**
  - `done_c6`, `done_c6_133`, `done_etc`, `done_fx`, `done_land` (GRIB) → [WDC Climate](https://www.wdc-climate.de/ui/project?acronym=CMIP6_RCM_forcing_MPI-ESM1-2)
  - `huss`, `tas`, `uas`, `vas`, `mrsol` (CMIP6 NetCDF, table `6hrPlevPt`) → ESGF nodes (e.g. [DKRZ](https://esgf-data.dkrz.de/search/cmip6-dkrz/))
- **Aerosols:**
  - `od550aer` (CMIP6 NetCDF, table `AERmon`) → ESGF nodes
  - MERRA-2 → Jülich ([b2share](https://b2share.fz-juelich.de/records/?community=a140d3f3-0117-4665-9945-4c7fcb9afb51)) or NASA ([M2IMNXGAS](https://disc.gsfc.nasa.gov/datasets/M2IMNXGAS_5.12.4/summary))
- **Land use:** LUCAS LUC v1.1 (Europe, 0.1°) → WDC Climate: [historical](https://doi.org/10.26050/WDCC/LUC_hist_EU_v1.1), [future](https://doi.org/10.26050/WDCC/LUC_future_EU_v1.1)
- **CO2 (MPTABLE):** `CAMtr_volume_mixing_ratio.<SSP>` (from `WRF/run`, included in `MPTABLE/`)
- **EUR-12 geo_em:** [CORDEX WPS domains](https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/tree/main/static_data)

The search queries for ESGF are in the README of each folder.
