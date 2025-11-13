# Aerosols

This section is based on the repository made by Josipa Milovac (milovacj@unican.es) for a GCM run (**MPI-ESM1-2-HR**).
 * 🔗 https://github.com/yoselita/aerosols4wrf

---
## Purpose
Create monthly (or yearly‑merged) **AOD550** files on the WRF grid that WRF can read as `auxinput15`.

---
## Directory organization (suggestion)
> The script creates a **scenario working folder** and moves final outputs to a configurable path.
```
/aerosols/
├── create_aerosol4wrf_input.sh          # ← 🔧 Main Bash script
├── helpers/                             # ← 📂 Support files (not tracked by git)
│   ├── grid_corners.ncl                   # NCL script to define corners of the WRF grid
│   ├── set_attributes.ncl                 # NCL script to add attributes and CF compliance to the aerosol file
│   ├── geo_em.<domain>.EUR-12-v4.1.nc     # WPS geo file (target grid)
│   └── wrfinput_<domain>_201501           # WRF input for global attributes
└── <scenario>/                          # ← 📂 working directory auto‑created by the script
    ├── od550aer_AERmon_MPI-ESM1-2-HR_<scenario>_<YYYYMM>.nc -> symlinks to ${path_i}
    ├── out_grid.nc, weights.nc            # built once per domain
    ├── temp_*.nc                          # intermediates
    └── AOD_<scenario>_<YYYYMM>_<domain>   # created here then MOVED to ${path_o}
```

---
## Paths & configuration (inside the script)
- `domain="d01"` — WRF domain name used in filenames.
- `scenario=$1` — pass one of: `historical | ssp126 | ssp245 | ssp370 | ssp585`.
- `start_year/month`, `end_year/month` — processing window.
- `merge_yearly="False|True"` — optionally merge monthly outputs per year.
- `do_prepare="True|False"` — run the CDO split steps on first use.
- **Directories**
  - `path_s` — folder containing `helpers/` (NCL scripts, template files).
  - `path_i` — location of raw AERmon `od550aer` NetCDFs (by scenario).
  - `path_o` — **final destination** for outputs (per scenario). The script moves files here at the end of each year.

---
## Inputs
1) **CMIP6 AERmon od550aer** (monthly, by scenario)  
   `od550aer_AERmon_MPI-ESM1-2-HR_<scenario>_r1i1p1f1_gn_<YYYYMM>.nc`

2) **Support files** (not tracked in Git):
- `helpers/geo_em.<domain>.EUR-12-v4.1.nc` → target grid descriptor for remapping
- `helpers/wrfinput_<domain>_201501` → source of WRF global attributes/metadata
- `helpers/grid_corners.ncl` → builds `out_grid.nc` (grid corners) used by CDO for remap weights
- `helpers/set_attributes.ncl` → cleans/standardizes NetCDF attributes and inserts WRF `Times`

---
## Outputs
- **Monthly:** `AOD_<scenario>_<YYYYMM>_<domain>` → NetCDF file **without `.nc` extension** (as expected by WRF)
- **Yearly (optional):** `AOD_<scenario>_<YYYY>_<domain>` → if `merge_yearly=True`

> Final files are **moved to `${path_o}`**. The scenario working folder keeps links and intermediates only.

---
## Usage
```bash
cd aerosols
./create_aerosol4wrf_input.sh <scenario>
# scenario: historical | ssp126 | ssp245 | ssp370 | ssp585
```
Before running, edit the variables at the top of the script (`domain`, `path_s`, `path_i`, `path_o`, dates, flags).

---
## Notes & conventions
- **Time axes:** After NCL adds `Times (char)`, the script creates numeric `time`/`XTIME` so CDO can operate cleanly while WRF still reads `Times`.
- **Remapping:** `grid_corners.ncl` defines corners; `cdo genbil` builds `weights.nc` (reused across runs for a given domain).
- **Naming:** Outputs follow `AOD_<scenario>_<YYYYMM>_<domain>` (or yearly). WRF typically expects the no‑extension convention.
- **Consistency:** Ensure `geo_em` and `wrfinput` refer to the **same domain**.

---
## Download data
- Aerosol optical depth (AOD, variable **od550aer**) → from the [ESGF Metagrid Nodes portal](https://esgf.github.io/nodes.html), using the following:
  
  ```
  Query String: latest = true AND (table_id = AERmon) AND (variable_id = od550aer) AND (experiment_id = *EXP*) AND (source_id = MPI-ESM1-2-HR) AND (variant_label = r1i1p1f1)
  ```
  Replace `<EXP>` with one of: `historical | ssp126 | ssp245 | ssp370 | ssp585`.
- `geo_em.d01.EUR-12-v4.1.nc` → from [CORDEX WPS domains](https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/tree/main/static_data)
- `wrfinput_d01_201501` file is available at [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.16890707.svg)](https://doi.org/10.5281/zenodo.16890707)

---
## Requirements
- **CDO**, **NCO** (`ncks`, `ncap2`, `ncatted`, `ncrcat`), **NCL**, **coreutils**.
