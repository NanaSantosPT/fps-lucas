# MPTABLE

This workflow generates yearly **Noah-MP `MPTABLE.TBL`** files with CO₂ concentrations consistent with CMIP6 scenarios.  
It replaces the placeholder `_CHANGE-CO2_` in a base template (`MPTABLE_LAI.TBL`) with yearly CO₂ values from
`CAMtr_volume_mixing_ratio.<scenario>`.

---

## Purpose
Ensure WRF–Noah-MP runs with **scenario-consistent CO₂ forcing** by creating per-year `MPTABLE.TBL` files.  
The base template used here (**`MPTABLE_LAI.TBL`**) also includes a **LAI section corrected for Europe**, following the configuration from Josipa Milovac’s workflow.

---

## Directory organization (suggestion)
```
/MPTABLE/
├── create_yearly_MPTABLE.sh                # ← 🔧 Main Bash script
├── helpers/                                # ← 📂 Support files (not tracked by git)
│   ├── MPTABLE_LAI.TBL                        # Base template (with LAI section corrected for Europe)
│   └── CAMtr_volume_mixing_ratio.<scenario>   # File with yearly CO₂ values
└── <scenario>/                             # ← 📂 Working directory auto-created by the script
    ├── CAMtr_file                            -> symlink to helpers/CAMtr_volume_mixing_ratio.<scenario>
    ├── MPTABLE_orig                          -> symlink to helpers/MPTABLE_LAI.TBL
    ├── MPTABLE.TBL_<scenario>_<YYYY>          # Created files (before being moved)
```

---

## Paths & configuration (inside the script)
- `scenario=$1` — pass one of: `ssp126 | ssp245 | ssp370 | ssp585`.
- `start_year`, `end_year` — range of years to process.
- **Directories**
  - `path_s` — folder containing support files (`MPTABLE_LAI.TBL`, `CAMtr_volume_mixing_ratio.<scenario>`).
  - `path_o` — **final destination** for outputs. The script moves all yearly MPTABLE files here.

---

## Inputs
1. **Template file**
   - `MPTABLE_LAI.TBL` → base MPTABLE with **European LAI corrections** already applied and the `_CHANGE-CO2_` placeholder present.  
     LAI corrections follow Josipa Milovac’s mappings used in `lai4wrf` (see *LAI for Europe* below).

2. **CO₂ time series**
   - `CAMtr_volume_mixing_ratio.<scenario>` → ASCII-like file with yearly CO₂ values (ppmv).

---

## Outputs
- `MPTABLE.TBL_<scenario>_<YYYY>` → per-year MPTABLE files with substituted CO₂.

> Final files are **moved to `${path_o}`**. The working folder keeps only temporary links and copies.

---

## Usage
```bash
cd MPTABLE
./create_yearly_MPTABLE.sh <scenario>
# scenario: ssp126 | ssp245 | ssp370 | ssp585
```
Before running, edit the variables at the top of the script (`start_year`, `end_year`, `path_s`, `path_o`).

---

## Notes & conventions
- **CO₂ substitution**: the `_CHANGE-CO2_` placeholder in the template is replaced using `sed` on a per-year basis.
- **Missing years**: if a year is not present in the CO₂ file, that year is skipped with a warning.
- **Template scope**: the template already contains the **LAI section calibrated for Europe**; you normally **do not** alter LAI during generation—only CO₂ is substituted.

### LAI for Europe (reference)
The European LAI corrections in the template are based on Josipa Milovac’s `lai4wrf` configuration, specifically
the mapping file:  
`LAI_MPfit2veg.csv` → https://github.com/yoselita/lai4wrf/blob/main/EUR11/tables/LAI_MPfit2veg.csv

---

## Download data
- **CO₂ time series**: `CAMtr_volume_mixing_ratio.<scenario>` is distributed with CESM/WRF-Chem utilities; provides prescribed GHG concentrations.  
  For this repository, place a copy under `helpers/`.

---

## Requirements
- **coreutils** (`awk`, `sed`, etc.)
