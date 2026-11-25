# Boundary conditions

Prepares the WRF boundary and surface forcing from **CMIP6 MPI-ESM1-2-HR** (for `Vtable.MPI-HR`).
It combines the MPI GRIB archives (`done_*`) with CMIP6 6-hourly surface variables (NetCDF converted to GRIB1) and writes **WRF-ready GRIB1** files, global and EU subdomain, every 6 h.

## Files
- `launch1-nc2grib-exp.sh`, `run-nc2grib-exp_var.sh` — step 1: CMIP6 NetCDF → monthly GRIB1 (one job per variable)
- `launch2-merge_grib-exp.sh`, `run-merge_grib-exp_year.sh` — step 2: all fields → WRF-ready GRIBs (one job per year)
- `check_merge_files.sh` — checks the step 2 output: missing time steps and files too small (incomplete)

## Directory organization
```
boundary_conditions/                         # dir_scripts (launch): this folder
├── launch1-nc2grib-exp.sh, run-nc2grib-exp_var.sh
├── launch2-merge_grib-exp.sh, run-merge_grib-exp_year.sh
└── check_merge_files.sh

<dir_work step 1>/                           # where the jobs run (launch1): job logs
└── <experiment>/<variable>/                   # working folder, created by the run
    ├── links to the NetCDF chunks, myzaxis_*.dat
    └── merged_<variable>.nc, <prefix>_YYYYMM.nc   # intermediates (removed)

<dir_work step 2>/                           # where the jobs run (launch2): job logs
└── <experiment>/<year>/                       # working folder, created by the run
    ├── links to path_din/done_* and path_din/wget_*
    └── keep_*.grb, tmp*                     # intermediates (removed)

<path_dout step 1> = <path_din step 2>/      # ready_<experiment> (run, DIRECTORIES)
├── done_c6, done_c6_133, done_etc, done_land, done_fx   # MPI GRIBs (download)
└── wget_huss, wget_tas, wget_uas, wget_vas, wget_mrsol  # from step 1

<path_dout step 2>/                          # output folder (run, DIRECTORIES)
├── glob/MPI-HR_<experiment>_<YYYYMMDD_HH>_glob.grb
└── EU/MPI-HR_<experiment>_<YYYYMMDD_HH>_EU.grb
```

## How to run
All the values to change are marked with `## <<<`.
1. **launch1**, blocks `DIRECTORIES` and `E-MAIL`: `dir_scripts` (this folder), `dir_work`, `mail_user`. Block `ARGUMENTS`: `experiment`, list of `variables`.
2. **run-nc2grib**, block `DIRECTORIES`: input (NetCDF) and output (`ready_<experiment>`) folders.
3. `sbatch launch1-nc2grib-exp.sh`
4. **launch2**, same blocks; `ARGUMENTS`: `experiment`, `years_list`.
5. **run-merge**, block `DIRECTORIES`: input (`ready_<experiment>`) and output folders. Block `SETTINGS`: EU box.
6. `sbatch launch2-merge_grib-exp.sh`
7. `check_merge_files.sh` (block `USER CONFIGURATIONS`): `sbatch check_merge_files.sh`

To redo only one month (step 1, `yyyymm`) or one day / one hour (step 2, `date`, `hour`), set them in block `SPECIFIC MONTH` / `SPECIFIC DAY` of the launch.

## Input data
- **MPI GRIB archives (`done_*`)**
  - `done_c6` → 130 (T), 138 (vorticity), 155 (divergence)
  - `done_c6_133` → 133 (q), 134 (surface pressure)
  - `done_etc` → 102/103/139 (skin temperatures), 140 (soil wetness), 141 (snow depth), 153 (clw), 154 (cli), 193 (skin reservoir), 210 (ice fraction), 211 (ice depth), 214 (snow on ice)
  - `done_land` → 68 (soil temperature, 5 levels)
  - `done_fx` → 129 (orography), 172 (land/sea mask), 229 (field capacity), 232 (glacier fraction)
- **CMIP6 surface variables (NetCDF → GRIB1 in step 1)**
  - `huss` (2 m specific humidity), `tas` (2 m temperature), `uas`/`vas` (10 m wind), `mrsol` (soil moisture, 5 layers)
  - `hus` (6hrLev, specific humidity + `ps` on model levels) → `done_c6_133` of the historical (not in the MPI archives; GRIBs named as the MPI `done_c6_133`)

## Download data
- **MPI GRIB1** (`done_c6`, `done_c6_133`, `done_etc`, `done_fx`, `done_land`): [WDC Climate](https://www.wdc-climate.de/ui/project?acronym=CMIP6_RCM_forcing_MPI-ESM1-2).
- **CMIP6 NetCDF**: ESGF nodes ([ESGF Metagrid Nodes portal](https://esgf.github.io/nodes.html), e.g. [DKRZ](https://esgf-data.dkrz.de/search/cmip6-dkrz/)), with
  ```
  latest = true AND (table_id = 6hrPlevPt) AND (variable_id = <VAR>) AND (experiment_id = <EXP>) AND (source_id = MPI-ESM1-2-HR) AND (variant_label = r1i1p1f1)
  ```
  `<VAR>`: `huss | tas | uas | vas | mrsol` (for `hus`: `table_id = 6hrLev`). `<EXP>`: `historical | ssp126 | ssp245 | ssp370 | ssp585`.

## Outputs
- Step 1: `<var>_6hrPlevPt_MPI-ESM1-2-HR_<experiment>_r1i1p1f1_gn_<YYYYMM>.grb` (in `wget_<var>`)
- Step 2: `MPI-HR_<experiment>_<YYYYMMDD_HH>_glob.grb` and `MPI-HR_<experiment>_<YYYYMMDD_HH>_EU.grb` (EU box: `lon -55 to 70`, `lat 15 to 90`)

## Notes
- **Time**: `cdo mergetime` before `splityear/splitmon` fixes the "Jan 1st 00Z in December" issue. In step 2, `shifttime,240s` makes `00:00` use **23:56 of the previous day**; the first `00:00` of a series is skipped when there is no previous day.
- **Derived fields**: MSL (151) with `sealevelpressure` from 129, 134 and 130; skin temperature from 103/139 (water/land) and the ice mask (210 ≥ 0.75 → 102); winds with `dv2uv` and `sp2gp`; `mrsol` divided by the layer thickness and water density, negatives set to 0.
- **Centre**: `setattribute,Institut=MPIMET` sets the model centre in the final GRIBs.

## Requirements
cdo (with `sp2gp`, `dv2uv`, `sealevelpressure`), ecCodes (`grib_set`), coreutils, bc, SLURM.
