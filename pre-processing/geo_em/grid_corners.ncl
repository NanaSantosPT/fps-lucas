;----------------------------------------------------------------------
; Converts WRF grid to a SCRIP convention file.
; 
; Command syntax:
;  ncl 'srcFile="LANDUSEF_WRF.nc"' grid_corners.ncl
; 
;----------------------------------------------------------------------


load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin
    ;---Input file
    srcFileName = "LANDUSEF_WRF.nc"
    
    ;---Output file
    srcGridName = "out_grid.nc"

    ;---Read lat and lon from the source file
    src_file = addfile(srcFileName,"r")
    lat_var  = src_file->XLAT_M(0,:,:)
    lon_var  = src_file->XLONG_M(0,:,:)
    
    ;---Set options
    Opt                = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = False
    Opt@Title          = "PISM Grid"
    Opt@Debug          = False
    
    ;---Writes the description of a curvilinear grid to a SCRIP file
    curvilinear_to_SCRIP(srcGridName,lat_var,lon_var,Opt)

    ;---Clean up
    delete(Opt)
end
                          
