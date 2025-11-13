# Land Use (geo_em)

This workflow generates yearly **WRF geo_em files** with **LUCAS_LUC v1.1** land-use scenarios.  
It remaps LUCAS inputs to the EUR-12 grid and injects them into WRF `geo_em` templates via a Fortran recategorization tool.

---

## Purpose
Produce yearly `geo_em.<domain>_<scenario>_<YYYY>.nc` files for use in WRF, consistent with the EURO-CORDEX EUR-12 domain and scenario-specific land use.

---

## Directory organization (suggestion)
> The script creates a **scenario working folder** and moves final yearly geo_em files to a configurable output path.

```
/geo_em/
├── lucasluc2geo_em.sh                      # ← 🔧 Main Bash script
├── helpers/                                # ← 📂 Support files (not tracked by git)
│   ├── geo_em.<domain>.EUR-12-v4.1.nc        # Template WPS geo_em file (base grid)
│   ├── grid_corners.ncl                      # NCL script to build out_grid.nc (grid corners)
│   ├── water_ice.nc                          # Auxiliary mask (water/ice handling)
│   └── WRF_LUCAS_PFTs_v3_water_ice_landmask  # Fortran binary for recategorization
└── <scenario>/                             # ← 📂 Working dir auto-created by script
    ├── LUCAS_LUC_v1.1_<scenario>_Europe_0.1deg_<block>.nc  -> symlinks to ${path_i}
    ├── LUCAS_LUC_v1.1_<scenario>_EUR-12_<YYYY>.nc           # remapped yearly file
    ├── luc_input.nc                                         # symlink for Fortran tool
    └── geo_em.<domain>_<scenario>_<YYYY>.nc                -> moved to ${path_o}
```

---

## Paths & configuration (inside the script)
- `scenario=$1` — one of: `historical | ssp126 | ssp245 | ssp370 | ssp585`
- `domain="d01"` — WRF domain (naming convention)
- `method="con"` — CDO remap method (`con` for conservative, `bil` for bilinear, ...)
- **Directories**
  - `path_s` — folder with helpers (geo_em template, NCL, water/ice mask, Fortran binary)
  - `path_i` — location of raw LUCAS_LUC files (multi-year blocks by scenario)
  - `path_o` — final destination for yearly geo_em outputs

---

## Inputs
1. **LUCAS_LUC v1.1** (multi-year blocks, 0.1° resolution)  
   `LUCAS_LUC_v1.1_<scenario>_Europe_0.1deg_<block>.nc`

2. **Support files** (not tracked in Git):
- `helpers/geo_em.<domain>.EUR-12-v4.1.nc` → template WPS geo_em file (EUR-12 grid)
- `helpers/grid_corners.ncl` → builds `out_grid.nc` from `LANDUSEF_WRF.nc`
- `helpers/water_ice.nc` → auxiliary mask for water/ice fields
- `helpers/WRF_LUCAS_PFTs_v3_water_ice_landmask` → Fortran binary that recategorizes LU_INDEX/LANDUSEF/LANDMASK

---

## Outputs
- `geo_em.<domain>_<scenario>_<YYYY>.nc` (yearly WRF geo_em files with LUCAS land use)

> Final files are **moved to `${path_o}`**. Intermediates (e.g. luc_input.nc, remapped LUCAS files) are cleaned up if desired.

---

## Usage
```bash
cd geo_em
./lucasluc2geo_em.sh <scenario>
# scenario: historical | ssp126 | ssp245 | ssp370 | ssp585
```

The script will automatically split LUCAS multi-year blocks, remap yearly files, recategorize them via Fortran, and create per-year `geo_em` files.

---

## Notes & conventions
- **Remapping**: CDO is used to remap LUCAS from 0.1° to EUR-12 using `out_grid.nc` (built once from WPS template).
- **Recategorization**: Fortran binary injects LU_INDEX, LANDUSEF, and LANDMASK into the copied geo_em template.
- **Year blocks**: The script splits multi-year LUCAS files into yearly files before remapping.
- **Water/ice handling**: interpolated from `water_ice.nc`.

---

## Download data
- **LUCAS_LUC v1.1** (Europe, 0.1°) → WDC Climate (e.g. [WDCC](https://doi.org/10.26050/WDCC/LUC_future_EU_v1.1))  
- `geo_em.d01.EUR-12-v4.1.nc` → from [CORDEX WPS domains](https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/tree/main/static_data)
- `water_ice.nc` file is available at [landmate2wrf](https://github.com/yoselita/landmate2wrf)

---

## Requirements
- **CDO**, **NCO**, **NCL**, **coreutils**, **Fortran compiler** (for the recategorization binary)
