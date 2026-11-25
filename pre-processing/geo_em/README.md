# Land use (geo_em)

Creates one WRF `geo_em` file per year (`geo_em.<domain>_<experiment>_<YYYY>.nc`) with the **LUCAS_LUC v1.1** land use of a scenario.
The LUCAS_LUC files are remapped to the EUR-12 grid and a Fortran program writes `LU_INDEX`, `LANDUSEF` and `LANDMASK`, which replace those of the EUR-12 `geo_em`.
Based on [landmate2wrf](https://github.com/yoselita/landmate2wrf) (Josipa Milovac), adapted for yearly LUCAS_LUC land use.

## Files
- `launch-lucasluc2geo_em-exp.sh` — choose the case and submit (`sbatch launch-lucasluc2geo_em-exp.sh`)
- `run-lucasluc2geo_em-exp.sh` — does the work
- `WRF_LUCAS_PFTs_v3_water_ice_landmask.f90`, `Makefile` — Fortran program (LUCAS PFTs + water/ice + land mask)
- `grid_corners.ncl` — WRF grid corners (`out_grid.nc`) for the CDO remap
- `water_ice.nc` — water and ice fractions (ESA CCI), from landmate2wrf

The EUR-12 `geo_em` (`geo_em.<domain>.EUR-12-v4.1.nc`) is read from `path_geo` (run, block `DIRECTORIES`). It is available at [CORDEX WPS domains](https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/tree/main/static_data).

## Directory organization
```
geo_em/                                      # dir_scripts (launch): this folder
├── launch-lucasluc2geo_em-exp.sh
├── run-lucasluc2geo_em-exp.sh
├── WRF_LUCAS_PFTs_v3_water_ice_landmask     # built with make
└── grid_corners.ncl, water_ice.nc

<path_geo>/                                  # geo_em files (run, DIRECTORIES)
└── geo_em.<domain>.EUR-12-v4.1.nc

<dir_work>/                                  # where the jobs run (launch): job logs
└── <experiment>/                                   # working folder, created by the run
    ├── links to path_geo, dir_scripts and the LUCAS_LUC files
    ├── LANDUSEF_WRF.nc, out_grid.nc         # WRF grid
    ├── ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc # water/ice on the WRF grid
    └── LUCAS_LUC_v1.1_<experiment>_*_<YYYY>.nc, luc_input.nc   # yearly files (removed after use)

<path_dout>/                                 # output folder (run, DIRECTORIES)
└── geo_em.<domain>_<experiment>_<YYYY>.nc
```

## How to run
1. Build the Fortran program in this folder: `make` (set `NF_CONFIG` in the `Makefile` to the `nf-config` of your netCDF-Fortran).
2. **launch**, blocks `DIRECTORIES` and `E-MAIL`: `dir_scripts` (this folder), `dir_work`, `mail_user`.
3. **run**, block `DIRECTORIES`: `geo_em` folder (`path_geo`), input and output folders. Block `SETTINGS`: `domain`, remap `method`.
4. **launch**, block `ARGUMENTS`: `experiment`.
5. `sbatch launch-lucasluc2geo_em-exp.sh`

All the values to change are marked with `## <<<`. Years: `historical` 1950–2014, scenarios 2016–2100 (blocks of years of the LUCAS_LUC v1.1 files, in `FIXED VALUES` of the run).

## Input data
**LUCAS_LUC v1.1** (Europe, 0.1°), `LUCAS_LUC_v1.1_<experiment>_Europe_0.1deg_<YYYY>_<YYYY>.nc`, from [WDC Climate](https://doi.org/10.26050/WDCC/LUC_future_EU_v1.1).

## Outputs
`geo_em.<domain>_<experiment>_<YYYY>.nc`: the EUR-12 `geo_em` with `LU_INDEX`, `LANDUSEF` and `LANDMASK` of that year.

## Requirements
cdo, nco, ncl, Fortran compiler with netCDF-Fortran, SLURM.
