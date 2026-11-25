# Aerosols (auxinput15)

Creates daily AOD at 550 nm on the WRF grid (`AOD5502D`), read by WRF as `auxinput15`.
Based on [aerosols4wrf](https://github.com/yoselita/aerosols4wrf) (Josipa Milovac), adapted for long simulations.

`data`                          | Source                                   | Period
--------------------------------|------------------------------------------|-------------
`historical`, `ssp245`, `ssp370`, ... | CMIP6 MPI-ESM1-2-HR `od550aer` (AERmon) | 1850–2014, 2015–2100
`MERRA`                         | MERRA-2 (Jülich or NASA)                 | 1980 onwards

## Files
- `launch-aerosols4wrf-exp.sh` — choose the case and submit (`sbatch launch-aerosols4wrf-exp.sh`)
- `run-aerosols4wrf-exp.sh` — does the work
- `grid_corners.ncl`, `set_attributes.ncl` — grid corners and WRF attributes (from the `geo_em` file)

The `geo_em` file is read from `path_geo` (run, block `DIRECTORIES`) and chosen by `target`: `LUCAS` → `geo_em.<domain>.EUR-12-v4.1.nc`, other names → `geo_em.<domain>.<target>.nc`.
The EUR-12 `geo_em` of LUCAS is available at [CORDEX WPS domains](https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/tree/main/static_data).

## Directory organization
```
aerosols/                                    # dir_scripts (launch): this folder
├── launch-aerosols4wrf-exp.sh
├── run-aerosols4wrf-exp.sh
└── grid_corners.ncl, set_attributes.ncl

<path_geo>/                                  # geo_em files (run, DIRECTORIES)
└── geo_em.<domain>.<target>.nc

<dir_work>/                                  # where the jobs run (launch): job logs
└── <data>_<target>_<domain>_<year_beg>-<year_end>/   # working folder, created by the run
    ├── geo_em.<domain>.nc, *.ncl            # links to path_geo and dir_scripts
    ├── file_grid.nc, weights.nc             # WRF grid and remap weights (computed once)
    └── temp_*.nc                            # intermediate files

<path_dout_gcm> | <path_dout_merra>/         # output folders (run, DIRECTORIES)
└── AOD_<name>_...
```

## How to run
All the values to change are in the `USER CONFIGURATIONS` section and marked with `## <<<`.
1. **launch**, blocks `DIRECTORIES` and `E-MAIL`: `dir_scripts` (this folder), `dir_work`, `mail_user`.
2. **run**, block `DIRECTORIES`: `geo_em` folder (`path_geo`), input and output folders.
3. **launch**, block `ARGUMENTS`: `data`, `target`, `domain`, `year_beg`, `year_end`.
   Optional, block `SPECIFIC PERIOD`: `date_beg`/`date_end` (YYYY-MM-DD) instead of full years.
4. `sbatch launch-aerosols4wrf-exp.sh`

## Input data
**MPI-ESM1-2-HR** — `od550aer`, table `AERmon`, from the [ESGF nodes](https://esgf.github.io/nodes.html), with the query
(`<EXP>` = `historical`, `ssp245`, `ssp370`, ...):
```
latest = true AND (table_id = AERmon) AND (variable_id = od550aer) AND (experiment_id = <EXP>) AND (source_id = MPI-ESM1-2-HR) AND (variant_label = r1i1p1f1)
```

**MERRA-2** — for each month the run uses the Jülich file if it exists, otherwise the NASA one:

Source | File | Variable
-------|------|---------
Jülich ([b2share](https://b2share.fz-juelich.de/records/?community=a140d3f3-0117-4665-9945-4c7fcb9afb51)), 1980–2020 | `MERRA2_OPPMONTH_wb10.<YYYYMM>.nc.gz` | `AOD` (533 nm)
NASA ([M2IMNXGAS](https://disc.gsfc.nasa.gov/datasets/M2IMNXGAS_5.12.4/summary)) | `MERRA2_400.instM_2d_gas_Nx.<YYYYMM>.nc` (or `401`) | `AODANA` (550 nm)

Jülich files must be downloaded by hand. NASA months are downloaded by the run if missing
(`do_download="True"`), which needs a free NASA Earthdata account:
1. Create it at <https://urs.earthdata.nasa.gov/users/new>.
2. In *Applications → Authorized Apps*, approve **NASA GESDISC DATA ARCHIVE**.
3. Save the login in `~/.netrc`:
   ```bash
   echo "machine urs.earthdata.nasa.gov login <USER> password <PASSWORD>" >> ~/.netrc
   chmod 600 ~/.netrc
   ```

## Outputs
NetCDF files without `.nc` (as WRF expects), one value per day at 00 UTC (the monthly value repeated every day). Each monthly file ends on the 1st day of the next month.

- Monthly: `AOD_<name>_<YYYYMM>_<domain>`
- Yearly: `AOD_<name>_<YYYY>_<domain>`
- Specific period: `AOD_<name>_<YYYYMMDD>_<YYYYMMDD>_<domain>`

with `<name>` = experiment (MPI-ESM1-2-HR) or `target` (MERRA). In WRF: `auxinput15_interval = 1440`, `io_form_auxinput15 = 2`, `aer_aod550_opt = 2`.

## Requirements
cdo, nco, ncl, wget, SLURM.
