# Run WPS


## 1. geogrid
The `geo_em*` files contain static geographical data (e.g., topography, land use, soil types) interpolated to the WRF model domain.  
Since we have yearly `geo_em*` changing the land cover it is not necessary to run `geogrid.exe`.  
📄 Steps to generate these `geo_em*` files are described in the [pre-run_issues](../../pre-run_issues) section.


## 2. ungrib
### 2.1. Grib files
The `*.grb` files contain the MPI-HR model-level output, including atmospheric and surface variables needed to initialize WRF.  
These files are processed by `ungrib.exe` using the appropriate `Vtable` to extract and convert the data into an intermediate format.  
📄 Steps to generate these `*.grb` files are described in the [pre-run_issues](../../pre-run_issues) section.

### 2.2. Vtable
The `Vtable.MPI-HR.ml` is a lookup table used by `ungrib.exe` to interpret GRIB data correctly, mapping variables, levels, and units to a format WRF can use.
This Vtable is intended for use with MPI-HR model-level output.
```bash
ln -sf Vtable.MPI-HR.ml ./Vtable
```


## 3. metgrid
To run `metgrid.exe` it will be necessary to have:

### 3.1. ecmwf_coeffs
The `MPI-HR_coeffs` file provides the A and B coefficients used to convert MPI-HR hybrid model levels to pressure levels on the `calc_ecmwf_p.exe` step.
```bash
ln -sf MPI-HR_coeffs ecmwf_coeffs
```

### 3.2. METGRID.TBL
The `METGRID.TBL.ARW.MPI` file defines how variables are horizontally interpolated during the `metgrid.exe` step.  
This version is adapted for use with MPI-HR model-level data and includes proper handling of **soil layers** for **soil temperature (ST)** and **soil moisture (SM)** to ensure accurate initialization of land surface conditions in WRF.

### 3.3. tavgsfc.py
From https://github.com/CORDEX-WRF-community/euro-cordex-cmip6/blob/main/util/tavgsfc.py  
This script computes the TAVGSFC variable (average near-surface air temperature) for WRF lake temperature initialization.  
It processes met_em files produced by metgrid.exe and applies a running mean (default: 15 days) of near-surface temperature, used to set more realistic lake skin temperatures instead of using SSTs or avg_tsfc.exe.

Usage:
```bash
python tavgsfc.py 'met_em.d01.*'
python tavgsfc.py -O 'met_em.d01.*'  # to overwrite existing TAVGSFC
```

Note:
- It progressively fills the average for the first 15 days (spin-up).
- When processing in chunks, include the 15 days prior and avoid using -O.
