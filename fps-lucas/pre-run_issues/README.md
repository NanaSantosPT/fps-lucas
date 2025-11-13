# Pre-run issues

This repository collects preprocessing workflows to prepare **CMIP6 MPI-ESM1-2-HR** data for use in WRF.  
It provides tools to generate **boundary conditions**, **aerosol forcing (auxinput15)**, **geo_em files (land use)**, and **Noah-MP MPTABLEs** for different scenarios.

---
## Repository structure
```
/aerosols/              # Scripts to preprocess AOD550 data into auxinput15 for WRF
/boundary_conditions/   # Scripts to preprocess boundary/surface forcing fields into GRIBs for WRF
/geo_em/                # Scripts to generate geo_em files with LUCAS_LUC land use
/MPTABLE/               # Scripts to build yearly Noah-MP MPTABLEs with CO₂ forcing
```

---
## 1. Boundary Conditions

This workflow prepares the **lateral and surface forcing fields** required by WRF (using the `Vtable.MPI-HR`).  
It converts CMIP6 NetCDF chunks into GRIB1 files, merges them with MPI-provided atmospheric archives (`done_*` files),  
and outputs complete **WRF-ready boundary condition files**.

- **Scripts:**  
  - `01-nc2grib-ssp_var.sh` → Converts surface variables (`huss`, `tas`, `uas`, `vas`, `mrsol`) from NetCDF to monthly GRIBs.  
  - `02-merge_grib-ssp_year.sh` → Merges all atmospheric + surface fields into final forcing files.  

- **Outputs:**  
  - `MPI-HR_<scenario>_<YYYYMMDD_HH>_glob.grb` (global)  
  - `MPI-HR_<scenario>_<YYYYMMDD_HH>_EU.grb` (Europe subset: lon1=-55.0; lon2=70.0; lat1=15.0; lat2=90.0)

📖 Detailed documentation: [boundary_conditions/README.md](boundary_conditions/README.md)

---
## 2. Aerosols (auxinput15)

This workflow prepares **aerosol optical depth (AOD)** forcing for WRF (`auxinput15`).  
It is based on the workflow developed by Josipa Milovac for MPI-ESM1-2-HR, adapted to the EURO-CORDEX domain.

- **Script:**  
  - `create_aerosol4wrf_input.sh` → Processes `od550aer` CMIP6 data into monthly WRF auxinput15 files.  

- **Outputs:**  
  - `AOD_<scenario>_<YYYYMM>_<domain>` (monthly auxinput15-compliant NetCDFs)
  - `AOD_<scenario>_<YYYY>_<domain>` (yearly auxinput15-compliant NetCDFs)

📖 Detailed documentation: [aerosols/README.md](aerosols/README.md)

---
## 3. Land Use (geo_em)

This workflow generates yearly `geo_em.*.nc` files with **LUCAS_LUC** land-use scenarios.  
It remaps LUCAS inputs to the EUR-12 grid and injects them into WRF geo_em templates via a Fortran recategorization tool.

- **Script:**  
  - `lucasluc2geo_em.sh` → Splits multi-year LUCAS_LUC, remaps to EUR-12, and outputs yearly geo_em files.  

- **Outputs:**  
  - `geo_em.<domain>_<scenario>_<YYYY>.nc`

📖 Detailed documentation: [geo_em/README.md](geo_em/README.md)

---
## 4. Noah-MP MPTABLEs

This workflow generates yearly **MPTABLE.TBL** files with CO₂ values replaced from `CAMtr_volume_mixing_ratio.<scenario>`.  
It ensures Noah-MP runs with scenario-consistent CO₂.

- **Script:**  
  - `create_yearly_MPTABLE.sh` → Replaces `_CHANGE-CO2_` placeholder in `MPTABLE_LAI.TBL` with yearly CO₂.  

- **Outputs:**  
  - `MPTABLE.TBL_<scenario>_<YYYY>`

📖 Detailed documentation: [MPTABLE/README.md](MPTABLE/README.md)

---
## Download of input data

- **Boundary conditions:**  
  - `done_c6`, `done_c6_133`, `done_etc`, `done_fx`, `done_land` archives (GRIBs format `spectral`) → WDC Climate (e.g. [WDCC](https://www.wdc-climate.de/ui/project?acronym=CMIP6_RCM_forcing_MPI-ESM1-2))
  - `huss`, `tas`, `uas`, `vas`, `mrsol` (CMIP6 NetCDF, table: `6hrPlevPt`) → ESGF nodes (e.g. [DKRZ](https://esgf-data.dkrz.de/search/cmip6-dkrz/))  

- **Aerosols:**  
  - `od550aer` (CMIP6 NetCDF, table: `AERmon`) → ESGF nodes (e.g. [DKRZ](https://esgf-data.dkrz.de/search/cmip6-dkrz/))  

- **Land use:**  
  - `LUCAS_LUC v1.1` (Europe, 0.1°) → WDC Climate (e.g. [WDCC](https://doi.org/10.26050/WDCC/LUC_future_EU_v1.1))  

- **CO₂ (MPTABLE):**  
  - `CAMtr_volume_mixing_ratio.<scenario>` (distributed with CESM/WRF-Chem utilities; provides prescribed GHG concentrations)
