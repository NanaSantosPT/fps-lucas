# FPS on the Land Use Change Across Scales (FPS-LUCAS) - WRF

This repository collects the configuration and the pre-processing scripts used to run the WRF simulations of the CORDEX Flagship Pilot Study LUCAS, following the LUCAS protocol.

Questions, suggestions and corrections:
 * Luana C. Santos (lssantos@ciencias.ulisboa.pt)
 * Rita M. Cardoso (rmcardoso@ciencias.ulisboa.pt)
 * Jorge Navarro Montesinos (jorge.navarro@ciemat.es)

[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## LUCAS experiment strategy
 * **Phase 1:** idealised land use change experiments on a continental scale driven by reanalysis data
 * **Phase 2:** realistic land use change experiments on a continental scale driven by CMIP6 GCM data
 * **Phase 3:** high-resolution experiments in pilot regions

## Contents
```
PHASE-1/            # Phase 1 setup (EUR-44, ERA-Interim)
PHASE-2/            # Phase 2 setup (EUR-12, MPI-ESM1-2-HR): namelists, output fields, WPS tables
pre-processing/     # Scripts to prepare the WRF input data
├── boundary_conditions/   # MPI-ESM1-2-HR -> GRIB files for ungrib
├── aerosols/              # AOD550 -> auxinput15 (CMIP6 GCM or MERRA-2)
├── geo_em/                # LUCAS LUC -> yearly geo_em files
├── MPTABLE/               # Noah-MP table with corrected LAI and yearly CO2
└── soil_initialization/   # Soil spin-up (WRF / HRLDAS)
util/               # Helper scripts (tavgsfc.py)
```

## How to use the pre-processing scripts
Each folder in `pre-processing/` has a `launch-*.sh` (SLURM job: choose experiment, years, domain) and a `run-*.sh` (does the work for one case). Before running:
1. Set the paths at the top of the `launch-*.sh` and `run-*.sh` scripts (lines marked with `## <<<`).
2. Download the input data listed in the README of each folder.

## Download only one folder
To get only one folder (e.g. the aerosols) without the rest of the repository (git 2.25 or later):
```bash
git clone --filter=blob:none --sparse https://github.com/NanaSantosPT/fps-lucas.git
cd fps-lucas
git sparse-checkout init --cone
git sparse-checkout set pre-processing/aerosols
```
Only the files at the top level and the chosen folder are downloaded; `git pull` keeps working.
To add another folder later: `git sparse-checkout add pre-processing/MPTABLE`.

## WRF version
Phase 2 uses WRF v4.5.1.4 from the CORDEX-WRF-community:
```bash
git clone --recurse-submodules -b v4.5.1.4 https://github.com/CORDEX-WRF-community/WRF.git
```
