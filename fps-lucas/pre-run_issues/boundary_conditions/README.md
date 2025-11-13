# Boundary Conditions

This workflow prepares **boundary and surface forcing fields** for WRF using **CMIP6 MPI-ESM1-2-HR** data and is compatible with `Vtable.MPI-HR`.  
It combines MPI GRIB archives (`done_*`) with CMIP6 6-hourly surface variables (converted from NetCDF) and writes **WRF-ready GRIB1** streams.

---

## Purpose
Produce complete **global** and **EU subdomain** GRIB sequences at 6-hourly steps for a given scenario and year.

---

## Directory organization (suggestion)
> These scripts create a **scenario working folder** and move the final results to configurable paths.

```
/boundary_conditions/
├── 01-nc2grib-ssp_var.sh          # ← 🔧 Step 1: NetCDF → monthly GRIB1 (surface vars)
├── 02-merge_grib-ssp_year.sh      # ← 🔧 Step 2: Merge all fields → WRF-ready GRIBs (glob/EU)
└── <scenario>/
    ├── <variable>/                # ← 📂 Working dir (step 1)
    │   ├── merged_<variable>.nc, <prefix>_YYYYMM.nc   # intermediates
    │   └── <prefix>_YYYYMM.grb → moved to ${path_o}/wget_<variable>
    └── <year>/                    # ← 📂 Working dir (step 2)
        ├── symlinks to ${path_i}/done_* and ${path_i}/wget_*/*.grb
        ├── keep_*.grb, tmp*                           # intermediates
        └── MPI-HR_<scenario>_<YYYYMMDD_HH>_{glob,EU}.grb → moved to ${path_o}/{glob,EU}
```

---

## Paths & configuration (inside the scripts)

- **Step 1 (`01-nc2grib-ssp_var.sh`)**
  - `scenario=$1`, `variable=$2` (one of `huss | tas | uas | vas | mrsol`)
  - `path_i` → raw NetCDF chunks by variable (5-year blocks)
  - `path_o` → final monthly GRIBs destination (per variable)
  - Working dir: `${wrkdir}/${scenario}/${variable}`

- **Step 2 (`02-merge_grib-ssp_year.sh`)**
  - `scenario=$1`, `year=$2`
  - `path_i` → base folder containing processed groups (`done_c6`, `done_c6_133`, `done_etc`, `done_land`, `done_fx`) and `wget_*` (from Step 1)
  - `path_o` → destinations for `glob/` and `EU/`
  - Working dir: `${wrkdir}/${scenario}/${year}`

---

## Input data sources

- **MPI atmospheric GRIB archives (`done_*`)**
  - `done_c6` → 130 (T), 138 (vorticity), 155 (divergence)
  - `done_c6_133` → 133 (q), 134 (surface pressure)
  - `done_etc` → 102/103/139 (skin temps), 140 (soil wetness), 141 (snow depth), 153 (clw), 154 (cli), 193 (skin reservoir), 210 (ice fraction), 211 (ice depth), 214 (snow on ice)
  - `done_land` → 68 (soil temperature, 5 levels)
  - `done_fx` → 129 (orography), 172 (land/sea mask), 229 (field capacity), 232 (glacier fraction)

- **Surface variables (NetCDF → GRIB via Step 1)**
  - `huss` (2 m specific humidity), `tas` (2 m air temperature), `uas`/`vas` (10 m winds), `mrsol` (soil moisture, 5 layers)

---

## Outputs

- **Step 1 (per variable & month)**
  - `<var>_6hrPlevPt_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMM>.grb`

- **Step 2 (per timestamp)**
  - `MPI-HR_<scenario>_<YYYYMMDD_HH>_glob.grb`
  - `MPI-HR_<scenario>_<YYYYMMDD_HH>_EU.grb`  
    ▸ EU box (default): `lon1=-55; lon2=70; lat1=15; lat2=90`

---

## Usage

### 1) Convert NetCDF → monthly GRIBs (surface vars)
```bash
cd boundary_conditions
./01-nc2grib-ssp_var.sh <scenario> <variable>
# variables: huss | tas | uas | vas | mrsol
```

### 2) Merge all fields into full forcing for one year
```bash
./02-merge_grib-ssp_year.sh <scenario> <year>
```

---

## Notes & conventions

- **Time handling**: `cdo mergetime` before `splityear/splitmon` fixes the “Jan 1st 00Z in December” issue.  
  In Step 2, `shifttime,240s` ensures `00:00` uses **23:56 of the previous day** where needed.
- **Derived fields**:
  - **MSL (151)** via `sealevelpressure` from 129 (orog), 134 (sp), 130 (T)
  - **Skin temperature** combining 103/139 (land/water) with ice mask (210/102)
  - **Winds**: `dv2uv` and `sp2gp` applied to spectral fields
  - **mrsol**: rescaled by layer thickness & water density, negatives clipped to 0
- **EU subdomain**: defined at the end of Step 2 (`sellonlatbox`).
- **Centre/attributes**: `setattribute,Institut=MPIMET` sets the model centre in final GRIBs.

---

## Download data

The MPI data used here comes from **two different sources**:

- **GRIB1 format**:  
  *Core atmospheric, soil and fixed fields* can be downloaded from WDC Climate (e.g. [WDCC](https://www.wdc-climate.de/ui/project?acronym=CMIP6_RCM_forcing_MPI-ESM1-2))  
  Provided in pre-organized folders:  
  `done_c6`, `done_c6_133`, `done_etc`, `done_fx`, `done_land`  

- **CMIP6 NetCDF**:  
  *Surface variables* can be downloaded from ESGF nodes ([ESGF Metagrid Nodes portal](https://esgf.github.io/nodes.html), e.g. [DKRZ](https://esgf-data.dkrz.de/search/cmip6-dkrz/))  
  ```
  Query String: latest = true AND (table_id = 6hrPlevPt) AND (variable_id = *VAR*) AND (experiment_id = *EXP*) AND (source_id = MPI-ESM1-2-HR) AND (variant_label = r1i1p1f1)
  ```
  Replace `<VAR>` with one of: `huss | tas | uas | vas | mrsol`.  
  Replace `<EXP>` with one of: `historical | ssp126 | ssp245 | ssp370 | ssp585`.  

---
## Requirements
- **CDO** (incl. `sp2gp`, `dv2uv`, `sealevelpressure`), **coreutils**  
- **ecCodes** (`grib_set`)  
- Step 1 uses NetCDF I/O in CDO; Step 2 benefits from `-L` (lazy) for performance
