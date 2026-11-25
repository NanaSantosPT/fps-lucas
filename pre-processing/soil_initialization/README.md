# Soil initialization

Spin-up of the soil for a cold start with **HRLDAS** (offline Noah-MP): one year of WRF hourly forcing is looped 20 times by HRLDAS, and the soil and snow at the end are written into the `wrfinput` of the simulation.

Used once, for the start of `lucas-ssp370` in 2015 (ran with success); in the end that simulation started from a restart of another group. Kept documented for future use. The scripts are written for the ECMWF HPC (SLURM account, `qos`, modules).

## Steps
0. **WRF, one year** with `WRF/namelist_soil.input.in` and `WRF/myoutfields_soil.txt` (your WRF chain): writes hourly `wrfhrly_d01_<date>` files with the forcing.
1. `run-soil1_ldasin-exp.sh` — `wrfhrly` → LDASIN forcing files (precipitation of each hour, LDASIN variable names)
2. `run-soil2_hrldas-exp.sh` — HRLDAS loops the year (`spinup_loops`, default 20), starting from the `wrfinput` of the simulation
3. `run-soil3_wrfinput-exp.sh` — soil (`TSLB`, `SMOIS`, `SH2O`) and snow (`SNOW`, `SNOWH`) of the last LDASOUT → `wrfinput_d01_hrldas`

Steps 1–3 are submitted with `launch-soil-exp.sh` (`step = 1 | 2 | 3`), one at a time, checking each before the next.

## Files
- `WRF/namelist_soil.input.in` — the PHASE-2 `namelist.input.in` with the hourly output `wrfhrly` (`auxhist14`) on
- `WRF/myoutfields_soil.txt` — the PHASE-2 `myoutfields.txt` with the variables of the `wrfhrly` files (stream 14)
- `HRLDAS/launch-soil-exp.sh`, `HRLDAS/run-soil*-exp.sh` — steps 1–3
- `HRLDAS/namelist.hrldas.in` — HRLDAS namelist; folders, start date, `KDAY` and loops are set by step 2. Noah-MP options as in the WRF namelist (`&noah_mp` of PHASE-2, e.g. `DYNAMIC_VEG_OPTION = 3`)
- `HRLDAS/NoahmpTable_LAI.TBL` — Noah-MP table with the LAI corrected for Europe ([lai4wrf](https://github.com/yoselita/lai4wrf), Josipa Milovac), as the WRF `MPTABLE_LAI.TBL` (default)
- `HRLDAS/NoahmpTable_orig.TBL` — same table with the original LAI

## NoahmpTable
Both tables have:
1. `CBIOM` changed from 0.02 to 0.002 (USGS and MODIS blocks, as in the WRF `MPTABLE`)
```
CBIOM = 0.002, 0.002, 0.002, ...
```
2. The placeholder `_CHANGE-CO2_` in the CO2 line, replaced by step 2 with the CO2 of the year looped (constant during the spin-up), from `../MPTABLE/CAMtr_volume_mixing_ratio.<SSP>` (`historical` uses SSP370):
```
&noahmp_global_parameters
 CO2                 = _CHANGE-CO2_e-06   ! CO2 partial pressure
```

## Directory organization
```
soil_initialization/
├── WRF/                                     # step 0: namelist and output fields for WRF
└── HRLDAS/                                  # dir_scripts (launch): steps 1-3

<dir_work>/                                  # where the jobs run (launch): job logs
└── <experiment>_<year>/                     # working folder, created by the runs
    ├── namelist.hrldas, NoahmpTable.TBL     # step 2
    ├── wrf_infiles/                         # LDASIN files (step 1) and copy of wrfinput_d01 (step 2)
    ├── wrf_outfiles/                        # LDASOUT files (step 2)
    └── wrfinput_d01_hrldas                  # step 3: use it as the wrfinput_d01 of the simulation
```

## How to run
All the values to change are marked with `## <<<`.
1. Run REAL as usual (its `wrfinput_d01` is the one initialised in steps 2-3) and WRF for one year with `WRF/namelist_soil.input.in` and `WRF/myoutfields_soil.txt`.
2. **launch**, blocks `DIRECTORIES` and `E-MAIL`: `dir_scripts` (`HRLDAS/`), `dir_work`, `mail_user`. Block `ARGUMENTS`: `experiment`, `year`.
3. **run-soil1**, block `DIRECTORIES`: folder of the `wrfhrly` files. Then `step=1` and `sbatch launch-soil-exp.sh`.
4. **run-soil2**, block `DIRECTORIES`: HRLDAS folder, `wrfinput` of the simulation and CAMtr folder (`../../MPTABLE`). Block `SETTINGS`: table, start date, loops. Then `step=2`.
5. `step=3`. Use `<experiment>_<year>/wrfinput_d01_hrldas` as the `wrfinput_d01` of the simulation.

## Requirements
HRLDAS compiled ([hrldas](https://github.com/NCAR/hrldas); environment in `~/.bash_compile_hrldas`), cdo, nco, SLURM.
