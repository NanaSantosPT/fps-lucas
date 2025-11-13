# FPS on the Land Use Change Across Scale (FPS-LUCAS)

This repository is created for the coordination of the WRF simulations within the CORDEX FPS LUCAS framework following the protocol.

Questions, suggestions, and corrections:
 * Luana C. Santos (lssantos@ciencias.ulisboa.pt)
 * Rita M. Cardoso (rmcardoso@ciencias.ulisboa.pt)
 * Jorge Navarro Montesinos
(jorge.navarro@ciemat.es)

## Overall LUCAS experiment strategy:
 * Phase 1: Extreme land use change experiments on a continental scale driven by reanalysis data
 * Phase 2: Realistic land use change experiments on a continental scale driven by GCM CMIP6 simulation data
 * Phase 3: High resolution experiments in pilot regions driven by high-resolution reanalysis data / RCM simulation data

[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# LUCAS Phase 2
These experiments use WRF v4.5.1.4
```bash
git clone --recurse-submodules -b v4.5.1.4 https://github.com/CORDEX-WRF-community/WRF.git
```
## WRF Experiment Setup Summary
Name                | Values                                                                 | Description
--------------------|------------------------------------------------------------------------|-------------
Domain              | EURO-CORDEX                                                            | WRF model domain
Resolution          | 0.11°                                                                  | Horizontal grid spacing
Forcing             | CMIP6 GCM: MPI-ESM1.2-HR (member 1; optional member 2)                 | Boundary conditions from GCM
Simulation_period   | Historical: 1950–2014<br>Future: 2015–2100                             | Time span of transient simulations
Scenario            | SSP1-2.6                                                               | Low-emission CMIP6 scenario
Land_Use_Forcing    | Dynamic: LUCAS LUC V1.1 (annual, 1950–2100, from LUH2)<br>Static: LUCAS LUC V1.1 for year 2015 | Type of land use input
LUC_Update_Freq     | Annual                                                                 | Frequency of land cover updates


