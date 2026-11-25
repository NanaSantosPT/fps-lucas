# MPTABLE (Noah-MP)

Creates one Noah-MP table per year (`MPTABLE.TBL_<experiment>_<YYYY>`) with the CO2 of that year, so that WRF–Noah-MP runs with the CO2 of the scenario. The run replaces the placeholder `_CHANGE-CO2_` of the base table (`MPTABLE_LAI.TBL`) with the yearly CO2 of `CAMtr_volume_mixing_ratio.<SSP>`.

## LAI for Europe
`MPTABLE_LAI.TBL` has the monthly LAI (`LAI_JAN` ... `LAI_DEC`) corrected for Europe, from the [lai4wrf](https://github.com/yoselita/lai4wrf) workflow of Josipa Milovac ([LAI_MPfit2veg.csv](https://github.com/yoselita/lai4wrf/blob/main/EUR11/tables/LAI_MPfit2veg.csv)).
Only the CO2 changes from year to year; the LAI is the same in all tables.

## Files
- `launch-MPTABLE-exp.sh` — choose the case and submit (`sbatch launch-MPTABLE-exp.sh`)
- `run-MPTABLE-exp.sh` — does the work
- `MPTABLE_LAI.TBL` — base table: LAI corrected for Europe, placeholder `_CHANGE-CO2_` in the CO2 line
- `MPTABLE_orig.TBL` — same table with the original LAI (reference, not used by the run)
- `CAMtr_volume_mixing_ratio.SSP*` — yearly CO2 (ppmv), from `WRF/run`

## Directory organization
```
MPTABLE/                                     # dir_scripts (launch): this folder
├── launch-MPTABLE-exp.sh
├── run-MPTABLE-exp.sh
├── MPTABLE_LAI.TBL, MPTABLE_orig.TBL
└── CAMtr_volume_mixing_ratio.SSP*

<dir_work>/                                  # where the jobs run (launch): job logs
└── <experiment>/                                   # working folder, created by the run
    └── MPTABLE_LAI.TBL, CAMtr_volume_mixing_ratio.<SSP>   # links to dir_scripts

<path_dout>/                                 # output folder (run, DIRECTORIES)
└── MPTABLE.TBL_<experiment>_<YYYY>
```

## How to run
All the values to change are in the `USER CONFIGURATIONS` section and marked with `## <<<`.
1. **launch**, blocks `DIRECTORIES` and `E-MAIL`: `dir_scripts` (this folder), `dir_work`, `mail_user`.
2. **run**, block `DIRECTORIES`: output folder.
3. **launch**, block `ARGUMENTS`: `experiment`, `year_beg`, `year_end`.
4. `sbatch launch-MPTABLE-exp.sh`

`historical` uses the SSP370 file (all CAMtr files have the same values until 2014).
Years missing in the CAMtr file are skipped with a warning.

## Outputs
`MPTABLE.TBL_<experiment>_<YYYY>`, with `CO2 = <ppmv>e-06`. In WRF, link the table of the year as `MPTABLE.TBL` in the run folder.

## Requirements
awk, sed, SLURM.
