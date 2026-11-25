# LUCAS Phase 1

Idealised (extreme) land use change experiments on a continental scale, driven by reanalysis data. Protocol and first results:
Davin E.L., Rechid D., Breil M., Cardoso R.M., et al. (2020) *Biogeophysical impacts of forestation in Europe: first results from the LUCAS (Land Use and Climate Across Scales) regional climate model intercomparison*. Earth Syst. Dynam., 11, 183–200. https://doi.org/10.5194/esd-11-183-2020

## Experiment setup (protocol)
Name                | Values                                                       | Description
--------------------|--------------------------------------------------------------|-------------
Domain              | EURO-CORDEX                                                  | Model domain
Resolution          | 0.44° (~50 km)                                               | Horizontal grid spacing
Forcing             | ERA-Interim, 6-hourly (lateral boundaries and SST)           | Boundary conditions
Simulation_period   | 1986–2015, preceded by spin-up (1979–1985 or a subset)       | Analysis period
Land_Use_Forcing    | Static, idealised maps (FOREST, GRASS)                       | Land use input

## Experiments (protocol)
Experiment | Land cover
-----------|-----------
EVAL       | Present-day land cover of each RCM (optional)
FOREST     | Maximally forested Europe: trees expanded to 100 % of the non-bare soil area (tree types and bare soil kept from the present-day map; crops and shrubs set to zero)
GRASS      | FOREST map with all trees converted to grassland (C3/C4 ratio and bare soil kept)

- Both maps start from a MODIS-based present-day map at 0.5° with 17 PFTs (Lawrence and Chase, 2007); the maps were produced by E.L. Davin and converted to the classes of each RCM.
- Urban areas, inland water and glaciers are kept as in the standard dataset of each RCM.
- The FOREST map is not a potential vegetation map: it covers reforestation and afforestation in an idealised way.

## Simulations IDL-FCUL
Name in the ensemble: **WRFa-NoahMP**.

Model          | Values
---------------|--------
RCM            | WRF v3.8.1
Land surface   | Noah-MP
Convection     | Grell–Freitas
Spin-up        | 1979–1985 (7 years), initialised from ERA-Interim
Experiments    | EVAL, FOREST, GRASS

The namelists of these simulations are not yet in this repository.
