GRIB | Level| Level| Level| metgrid  |  metgrid | metgrid                                  |
Code | Code |   1  |   2  | Name     |  Units   | Description                              |
-----+------+------+------+----------+----------+------------------------------------------+
 130 | 109  |   *  |      | TT       | K        | Temperature                              | !---------MPI - temperature [K]
 131 | 109  |   *  |      | UU       | m s-1    | U                                        | 
 132 | 109  |   *  |      | VV       | m s-1    | V                                        | 
 133 | 109  |   *  |      | SPECHUMD | kg kg-1  | Specific Humidity                        | !---------MPI - specific humidity [kg/kg]
 134 |  1   |   0  |      | PSFC     | Pa       | Surface Pressure                         | !---------MPI - surface pressure [Pa]
 151 |  1   |   0  |      | PMSL     | Pa       | Sea-level Pressure                       | 
 165 |  1   |   0  |      | UU       | m s-1    | U                                        | At 10 m !-MPI - 10m u-velocity [m/s]
 166 |  1   |   0  |      | VV       | m s-1    | V                                        | At 10 m !-MPI - 10m v-velocity [m/s]
 167 |  1   |   0  |      | TT       | K        | Temperature                              | At 2 m !--MPI - 2m temperature [K]
  54 |  1   |   0  |      | SPECHUMD | kg kg-1  | Specific Humidity at 2 m                 | At 2 m !--MPI - 2m specific humidity [kg kg-1]
 129 |  1   |   0  |      | SOILGEO  | m2 s-2   |                                          | !---------MPI - surface geopotential (orography) [m2/s-2]
 172 |  1   |   0  |      | LANDSEA  | 0/1 Flag | Land/Sea flag                            | !---------MPI - land sea mask (1=land, 0=sea/lakes)
 103 |  1   |   0  |      | SST      | K        | Sea-Surface Temperature                  | !---------MPI - 103 - surface temperature of water [K]
 001 |  1   |   0  |      | SKINTEMP | K        | Surface temperature where land/land-ice  | !---------MPI - 001/002 - SKINTEMP without/with ice [K]
 141 |  1   |   0  |      | SNOW_EC  | m        |                                          | !---------MPI - snow depth [m]
 210 |  1   |   0  |      | SEAICE   | fraction | Sea-Ice-Fraction                         | !---------MPI - ice cover (fraction of 1-SLM)
  68 | 111  |   3  |      | ST000003 | K        | T of 0-3 cm ground layer                 | !---------MPI - soil temperature [K]
  68 | 111  |  19  |      | ST003019 | K        | T of 3-19 cm ground layer                |
  68 | 111  |  78  |      | ST019078 | K        | T of 19-78 cm ground layer               |
  68 | 111  | 268  |      | ST078268 | K        | T of 78-268 cm ground layer              |
  68 | 111  | 698  |      | ST268698 | K        | T of 268-698 cm ground layer             |
  84 | 111  |   3  |      | SM000003 | fraction | Soil moisture of 0-3 cm ground layer     | !---------MPI - soil wetness[fraction]
  84 | 111  |  19  |      | SM003019 | fraction | Soil moisture of 3-19 cm ground layer    |
  84 | 111  |  78  |      | SM019078 | fraction | Soil moisture of 19-78 cm ground layer   |
  84 | 111  | 268  |      | SM078268 | fraction | Soil moisture of 78-268 cm ground layer  |
  84 | 111  | 698  |      | SM268698 | fractoin | Soil moisture of 268-698 cm ground layer |
-----+------+------+------+----------+----------+------------------------------------------+
#
#  For use with MPI-HR model-level output.
#
#  Grib codes from Table 128 (MPI):
#   54 102 103 139 140 210
#
#  Grib codes from Table 180 (MPI-LAND):
#   68 84
#
#  Grib codes from Table 128 (ECMWF & MPI):
#   129 130 131 132 133 134 141 151 165 166 167 172 
#   http://www.ecmwf.int/services/archive/d/parameters/order=grib_parameter/table=128/
#
# WE HAVE BUT WRF DOESN'T USE
# 138 | 109  |   *  |      |          | s-1      |                                          | !MPI - vorticity [1/s]
# 153 | 109  |   *  |      |          | kg kg-1  | Mass fraction cloud liquid water in air  | !MPI - cloud water [kg/kg]
# 154 | 109  |   *  |      |          | kg kg-1  | Mass fraction cloud ice in air           | !MPI - cloud ice [kg/kg]
# 155 | 109  |   *  |      |          | s-1      |                                          | !MPI - divergence [1/s]
# 102 |  1   |   0  |      |          | K        | Sea ice surface temperature              | !MPI - surface temperature of ice [K]
# 139 |  1   |   0  |      |          | K        | Surface temperature where land/land-ice  | !MPI - surface temperature of land [K]
# 140 |  1   |   0  |      |          | m        |                                          | !MPI - soil wetness [m]
# 193 |  1   |   0  |      |          | m        |                                          | !MPI - skin reservoir content [m]
# 211 |  1   |   0  |      |          | m        | Sea ice thickness                        | !MPI - ice depth [m]
# 214 |  1   |   0  |      |          | m        | Surface snow thickness where sea ice     | !MPI - water equivalent of snow on ice [m]
# 229 |  1   |   0  |      |          |          |                                          | !MPI - field capacity of soil [m]
# 232 |  1   |   0  |      |          |          |                                          | !MPI - fraction of land covered by glaciers
#
# WE DON'T USE
#   9 |  1   |   0  |      |          | 0/1 Flag | Glacier mask                             | !MPI - 
#  11 |  1   |   0  |      |          | m        | Soil moisture content at field capacity  | !MPI - 
#  33 |  1   |   0  |      | SNOW_DEN | kg m-3   |                                          | 
# 144 |  1   |   0  |      | SST      | K        | Sea surface temperature (fixed)          | !MPI - 
# 152 |  1   |   0  |      |          | ln(Pa)   | Log (ln) of sea-level pressure           | 
# 168 |  1   |   0  |      | DEWPT    | K        |                                          | At 2 m
#     |  1   |   0  |      | RH       | %        | Relative Humidity at 2 m                 | At 2 m
# 169 |  1   |   0  |      | SKINTEMP | K        | Surface temperature + sea surface temp.  | !MPI - surface temperature [K]

