!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Code developed by Rita Margarida Cardoso, contact: rmcardoso@ciencias.ulisboa.pt
! Minor changes added by Josipa Milovac, contact: milovacj@unican.es
! Adaptations made by Luana C Santos, contact: lssantos@ciencias.ulisboa.pt
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module datvar
!
integer, parameter :: npft=16,nluse=21
integer :: nt,nlon,nlat,nt2,nlon2,nlat2
integer :: ncid,varid,status
integer :: latid,lonid,timeid,levid,timedim,latdim,londim,levdim
integer, dimension(npft) :: PFT
!
real :: dummy
real, dimension(:), allocatable :: time
real, dimension(:,:), allocatable :: lon,lat,landsea,LU_diff,LU_1950,LU_2015, var2d
real, dimension(:,:,:), allocatable :: var,water,ice,water_ice_per,PFTf,PFT_per,PFT_landmask
real, dimension(:,:,:,:), allocatable :: PFTi,PFTw,PFTw_f
!
character*6 avar
character*10 vaid1,vaid2,vaid3,varid1,varid2,varid3
character*400 landfile,lfile,outfile,fnameout
!
data PFT/2,4,2,4,1,3,6,6,10,10,19,11,12,14,13,16/
end module datvar
!
program landuse
use datvar
use netcdf
!
!lfile='LANDMATE_PFT_v1.1_Europe_0.11deg_2015.nc'
!lfile='LANDMATE_PFT_v1.1_Europe_0.11deg_2015_nn.nc'
lfile='luc_input.nc'
landfile=lfile(1:len_trim(lfile))
!
status=nf90_open(landfile,nf90_nowrite,ncid)
!call ncerror(status,'opening file')

status=nf90_inq_dimid(ncid,'time',timeid)
!call ncerror(status,'getting time id')

status=nf90_inq_dimid(ncid,'y',latid)
!call ncerror(status,'getting lat id')

status=nf90_inq_dimid(ncid,'x',lonid)
!call ncerror(status,'getting lon id')

status=nf90_inquire_dimension(ncid=ncid,dimid=timeid,len=timedim)
!call ncerror(status,'getting time dimension')
nt=timedim

status=nf90_inquire_dimension(ncid=ncid,dimid=latid,len=latdim)
!call ncerror(status,'getting lat dimension')
nlat=latdim

status=nf90_inquire_dimension(ncid=ncid,dimid=lonid,len=londim)
!call ncerror(status,'getting lon dimension')
nlon=londim
!
write(*,*)nlon,nlat,nt
!
allocate(time(nt))
allocate(lon(nlon,nlat))
allocate(lat(nlon,nlat))
!
status=nf90_inq_varid(ncid,'time',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,time,(/1/),(/nt/),(/1/))
!call ncerror(status,'reading '//'time')
!
status=nf90_inq_varid(ncid,'lon',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,lon,(/1,1/),(/nlon,nlat/),(/1,1/))
!call ncerror(status,'reading '//'lon')
!
status=nf90_inq_varid(ncid,'lat',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,lat,(/1,1/),(/nlon,nlat/),(/1,1/))
!call ncerror(status,'reading '//'lat')
!
allocate(PFTi(nlon,nlat,npft,nt))
!
status=nf90_inq_varid(ncid,'landCoverFrac',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,PFTi,(/1,1,1,1/),(/nlon,nlat,npft,nt/),(/1,1,1,1/))
!call ncerror(status,'reading '//'PFTi')
!
allocate(landsea(nlon,nlat))
!
landsea=0.
do iy=1,nlat
  do ix=1,nlon
    do it=1,nt
      sum=0.
      do ip=1,npft
        if(PFTi(ix,iy,ip,it)> 0.)then
          landsea(ix,iy)=1.
        endif
        sum=sum+PFTi(ix,iy,ip,it)
      enddo
      do ip=1,npft
        PFTi(ix,iy,ip,it)=PFTi(ix,iy,ip,it)/sum  ! for interpolations other than nearest neighbor
      enddo
    enddo
  enddo
enddo
!
lfile='LANDUSEF_WRF.nc'
landfile=lfile(1:len_trim(lfile))
!
status=nf90_open(landfile,nf90_nowrite,ncid)
!call ncerror(status,'opening file')

status=nf90_inq_dimid(ncid,'Times',timeid)
!call ncerror(status,'getting time id')

status=nf90_inq_dimid(ncid,'south_north',latid)
!call ncerror(status,'getting lat id')

status=nf90_inq_dimid(ncid,'west_east',lonid)
!call ncerror(status,'getting lon id')

status=nf90_inquire_dimension(ncid=ncid,dimid=timeid,len=timedim)
!call ncerror(status,'getting time dimension')
nt2=timedim

status=nf90_inquire_dimension(ncid=ncid,dimid=latid,len=latdim)
!call ncerror(status,'getting lat dimension')
nlat2=latdim

status=nf90_inquire_dimension(ncid=ncid,dimid=lonid,len=londim)
!call ncerror(status,'getting lon dimension')
nlon2=londim
!
if(nlon /= nlon2 .or. nlat /= nlat2)then
  write(*,*)nlon,nlon2,nlat,nlat2
  write(*,*)'diferent dimensions. program stoped'
  stop
endif
!
allocate(PFTw(nlon2,nlat2,nluse,nt2))
!
status=nf90_inq_varid(ncid,'LANDUSEF',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,PFTw,(/1,1,1,1/),(/nlon2,nlat2,nluse,nt2/),(/1,1,1,1/))
!call ncerror(status,'reading '//'PFTw')
!
!  Get ESA CCI water and ice
!
!lfile='ESACCI-LC-L4-LCCS_water_ice_1992-2015.nc'
lfile='ESACCI-LC-L4-LCCS_EUR-12_water_ice.nc'
landfile=lfile(1:len_trim(lfile))
!
status=nf90_open(landfile,nf90_nowrite,ncid)
!call ncerror(status,'opening file')

!status=nf90_inq_dimid(ncid,'time',timeid)
!call ncerror(status,'getting time id')

status=nf90_inq_dimid(ncid,'y',latid)
!call ncerror(status,'getting lat id')

status=nf90_inq_dimid(ncid,'x',lonid)
!call ncerror(status,'getting lon id')

!status=nf90_inquire_dimension(ncid=ncid,dimid=timeid,len=timedim)
!call ncerror(status,'getting time dimension')
!nt3=timedim
!nt3=1

status=nf90_inquire_dimension(ncid=ncid,dimid=latid,len=latdim)
!call ncerror(status,'getting lat dimension')
nlat3=latdim

status=nf90_inquire_dimension(ncid=ncid,dimid=lonid,len=londim)
!call ncerror(status,'getting lon dimension')
nlon3=londim
!
if(nlon3 /= nlon2 .or. nlat3 /= nlat2)then
  write(*,*)nlon3,nlon2,nlat3,nlat2
  write(*,*)'diferent dimensions. program stoped'
  stop
endif
!
allocate(var2d(nlon3,nlat3))
allocate(water(nlon3,nlat3,nt))
allocate(ice(nlon3,nlat3,nt))
!
!status=nf90_inq_varid(ncid,'class_area_210',varid)
status=nf90_inq_varid(ncid,'Water',varid)

!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,var2d,(/1,1/),(/nlon3,nlat3/),(/1,1/))
!call ncerror(status,'reading '//'water')
!
!    Water percentage
!
water=0.
do iy=1,nlat
  do ix=1,nlon
    if(var2d(ix,iy)>0. .and. var2d(ix,iy) <= 1.)then
        water(ix,iy,1)=var2d(ix,iy)
!      do it=1,nt-nt3
!        water(ix,iy,it)=var(ix,iy,1)
!      enddo
    endif
!    do it=1,nt3
!      if(var(ix,iy,it)>0.)water(ix,iy,it+nt-nt3)=var(ix,iy,it)
!    enddo
  enddo
enddo
!
status=nf90_inq_varid(ncid,'Snow_Ice',varid)
!call ncerror(status,'getting var id')
!
status=nf90_get_var(ncid,varid,var2d,(/1,1/),(/nlon3,nlat3/),(/1,1/))
!call ncerror(status,'reading '//'ice')
!
!    Ice percentage
!
ice=0.
do iy=1,nlat
  do ix=1,nlon
    if(var2d(ix,iy)>0. .and. var2d(ix,iy) <= 1.)then
      ice(ix,iy,1)=var2d(ix,iy)
!      do it=1,nt-nt3
!        ice(ix,iy,it)=var(ix,iy,1)
!      enddo
    endif
!    do it=1,nt3
!      if(var(ix,iy,it)>0.)ice(ix,iy,it+nt-nt3)=var(ix,iy,it)
!    enddo
  enddo
enddo
deallocate(var2d)
!
!     Water and ice percentage
allocate(water_ice_per(nlon3,nlat3,nt))
!
water_ice_per=water+ice

allocate(PFTw_f(nlon2,nlat2,nluse,nt))
!
PFTw_f=0.
!do it=1,nt
!  PFTw_f(:,:,:,it)=PFTw(:,:,:,1)
!enddo
!

!Fix wetlands
do it=1,nt
  do iy=1,nlat
    do ix=1,nlon  
      if (PFTw(ix,iy,11,1)>0.)then  
        PFTw_f(ix,iy,11,it)=PFTw(ix,iy,11,1)     ! unchanged from WRF    
      endif
    enddo
  enddo
enddo

do it=1,nt
  do iy=1,nlat
    do ix=1,nlon!
      if(landsea(ix,iy)>0.)then
!       Forests
        PFTw_f(ix,iy,1,it)=PFTi(ix,iy,5,it)*(1.-water_ice_per(ix,iy,it))
        PFTw_f(ix,iy,2,it)=PFTi(ix,iy,3,it)*(1.-water_ice_per(ix,iy,it))
        PFTw_f(ix,iy,3,it)=PFTi(ix,iy,6,it)*(1.-water_ice_per(ix,iy,it))
        PFTw_f(ix,iy,4,it)=PFTi(ix,iy,4,it)*(1.-water_ice_per(ix,iy,it))
!       No mixed forests
        PFTw_f(ix,iy,5,it)=0.d0
!       Shrubs
        PFTw_f(ix,iy,6,it)=(PFTi(ix,iy,7,it)+PFTi(ix,iy,8,it))*(1.-water_ice_per(ix,iy,it))
        PFTw_f(ix,iy,7,it)=0.d0
        PFTw_f(ix,iy,8,it)=0.d0
!       No savannas, to be replaced by irrigated crops
        PFTw_f(ix,iy,9,it)=PFTi(ix,iy,14,it)*(1.-water_ice_per(ix,iy,it))
!       Adding grasses into grassland
        PFTw_f(ix,iy,10,it)=(PFTi(ix,iy,9,it)+PFTi(ix,iy,10,it))*(1.-water_ice_per(ix,iy,it))
!       Swamps
        PFTw_f(ix,iy,11,it)=PFTi(ix,iy,12,it)*(1.-water_ice_per(ix,iy,it))
!       Crops
        PFTw_f(ix,iy,12,it)=PFTi(ix,iy,13,it)*(1.-water_ice_per(ix,iy,it))
!       Urban
        PFTw_f(ix,iy,13,it)=PFTi(ix,iy,15,it)*(1.-water_ice_per(ix,iy,it))
!       No cropland/natural vegetation mosaic
        PFTw_f(ix,iy,14,it)=0.d0
!       Snow and Ice from ESA CCI
        PFTw_f(ix,iy,15,it)=ice(ix,iy,it)
!       Bare
        PFTw_f(ix,iy,16,it)=PFTi(ix,iy,16,it)*(1.-water_ice_per(ix,iy,it))
!       Tundra
        PFTw_f(ix,iy,18,it)=0.d0
        PFTw_f(ix,iy,19,it)=PFTi(ix,iy,11,it)*(1.-water_ice_per(ix,iy,it))
        PFTw_f(ix,iy,20,it)=0.d0
      endif
!     Land-sea
      PFTw_f(ix,iy,17,it)=PFTw(ix,iy,17,1)     ! unchanged from WRF
!     Lakes and rivers from ESA CCI
      if(PFTw(ix,iy,17,1) == 0)PFTw_f(ix,iy,21,it)=water(ix,iy,it)
    enddo
  enddo
enddo
!

allocate(var(nlon2,nlat2,nluse))
var=0.
!
! Tundra
!
do iy=1,nlat2
  do ix=1,nlon2
    var(ix,iy,18)=PFTw(ix,iy,18,1)/(PFTw(ix,iy,18,1)+PFTw(ix,iy,19,1)+PFTw(ix,iy,20,1))
    var(ix,iy,19)=PFTw(ix,iy,19,1)/(PFTw(ix,iy,18,1)+PFTw(ix,iy,19,1)+PFTw(ix,iy,20,1))
    var(ix,iy,20)=PFTw(ix,iy,20,1)/(PFTw(ix,iy,18,1)+PFTw(ix,iy,19,1)+PFTw(ix,iy,20,1))
  enddo
enddo
!
! Shrubland
!
do iy=1,nlat2
  do ix=1,nlon2
    if(PFTw(ix,iy,6,1) >0.)then
      var(ix,iy,6)=PFTw(ix,iy,6,1)/(PFTw(ix,iy,6,1)+PFTw(ix,iy,7,1)+PFTw(ix,iy,8,1))
    endif
    if(PFTw(ix,iy,7,1) >0.)then
      var(ix,iy,7)=PFTw(ix,iy,7,1)/(PFTw(ix,iy,6,1)+PFTw(ix,iy,7,1)+PFTw(ix,iy,8,1))
    endif
    if(PFTw(ix,iy,8,1) >0.)then
      var(ix,iy,8)=PFTw(ix,iy,8,1)/(PFTw(ix,iy,6,1)+PFTw(ix,iy,7,1)+PFTw(ix,iy,8,1))
    endif
  enddo
enddo
!
do it=1,nt
  do iy=1,nlat2
    do ix=1,nlon2
! Tundra
      if(var(ix,iy,18)>0.)then
        PFTw_f(ix,iy,18,it)=PFTw_f(ix,iy,19,it)*var(ix,iy,18)
      endif
      if(var(ix,iy,19)>0.)then
        PFTw_f(ix,iy,19,it)=PFTw_f(ix,iy,19,it)*var(ix,iy,19)
      endif
      if(var(ix,iy,20)>0.)then
        PFTw_f(ix,iy,20,it)=PFTw_f(ix,iy,19,it)*var(ix,iy,20)
      endif
! Shrub
      if(var(ix,iy,6)>0.)then
        PFTw_f(ix,iy,6,it)=PFTw_f(ix,iy,6,it)*var(ix,iy,6)
      endif
      if(var(ix,iy,7)>0.)then
        PFTw_f(ix,iy,7,it)=PFTw_f(ix,iy,6,it)*var(ix,iy,7)
      endif
      if(var(ix,iy,8)>0.)then
        PFTw_f(ix,iy,8,it)=PFTw_f(ix,iy,6,it)*var(ix,iy,8)
      endif
    enddo
  enddo
enddo
!

!Fix water pixels along the coast
do it=1,nt
  do iy=1,nlat
    do ix=1,nlon
     if(PFTw_f(ix,iy,21,it)>0.)then           
       if ( PFTw(ix-1,iy,17,1)>0   .or. PFTw(ix+1,iy,17,1)>0   .or. PFTw(ix,iy-1,17,1)>0   .or. PFTw(ix,iy+1,17,1)>0     .or. &
            PFTw(ix-1,iy+1,17,1)>0 .or. PFTw(ix-1,iy-1,17,1)>0 .or. PFTw(ix+1,iy-1,17,1)>0 .or. PFTw(ix+1,iy+1,17,1)>0 ) then
         PFTw_f(ix,iy,17,it)=water(ix,iy,it)
         PFTw_f(ix,iy,21,it)=0
      endif
     endif
   enddo
 enddo
enddo
!

allocate(PFTf(nlon2,nlat2,nt))
allocate(PFT_per(nlon2,nlat2,nt))
allocate(PFT_landmask(nlon2,nlat2,nt))
PFTf=0.
PFT_per=0.
!
do it=1,nt
  do iy=1,nlat2
    do ix=1,nlon2
      dummy=0.
      do ip=1,nluse
!        if(ip /= 17)then
          dummy=max(PFTw_f(ix,iy,ip,it),dummy)
          if(PFTw_f(ix,iy,ip,it).eq.dummy)then
            PFTf(ix,iy,it)=ip
            PFT_per(ix,iy,it)=PFTw_f(ix,iy,ip,it)
            if(PFTf(ix,iy,it).eq.17.or.PFTf(ix,iy,it).eq.21)then
              PFT_landmask(ix,iy,it)=0
            else
              PFT_landmask(ix,iy,it)=1
            end if
!          endif
        endif
      enddo
    enddo
  enddo
enddo
!
nlon=nlon2
nlat=nlat2
!
outfile='WRF_LUCAS_LUC_LU_INDEX_v2.nc'
fnameout=outfile(1:len_trim(outfile))
vaid1='LU_INDEX'
varid1=vaid1(1:len_trim(vaid1))
vaid2='PFT_per'
varid2=vaid2(1:len_trim(vaid2))
call write_netcdf_3D(PFTf,PFT_per,nt,time)
!
outfile='WRF_LUCAS_LUC_LANDUSEF_v2.nc'
fnameout=outfile(1:len_trim(outfile))
vaid1='LANDUSEF'
varid1=vaid1(1:len_trim(vaid1))
call write_netcdf_4D(PFTw_f,nt,time)
!
outfile='WRF_LUCAS_LUC_LANDMASK_v2.nc'
fnameout=outfile(1:len_trim(outfile))
vaid1='LANDMASK'
varid1=vaid1(1:len_trim(vaid1))
vaid2='PFT_per'
varid2=vaid2(1:len_trim(vaid2))
call write_netcdf_3D(PFT_landmask,PFT_per,nt,time)
!
!allocate(LU_diff(nlon,nlat))
!allocate(LU_1950(nlon,nlat))
!allocate(LU_2015(nlon,nlat))
!!
!LU_diff(:,:)=PFTf(:,:,nt)-PFTf(:,:,1)
!LU_1950(:,:)=PFTf(:,:,1)
!LU_2015(:,:)=PFTf(:,:,nt)
!!
!outfile='WRF_LUCAS_LUC_v1.0_ESACCI_LUH2_historical_0.11deg_1950-2015_LUINDEX_diff.nc'
!fnameout=outfile(1:len_trim(outfile))
!vaid1='LU_diff'
!varid1=vaid1(1:len_trim(vaid1))
!vaid2='LU_1950'
!varid2=vaid2(1:len_trim(vaid2))
!vaid3='LU_2015'
!varid3=vaid3(1:len_trim(vaid3))
!call write_netcdf_2D(LU_diff,LU_1950,LU_2015)
!
end
!
!
!
subroutine ncerror(status,info)
use netcdf
integer :: status
character(len=*),optional :: info

if( status /= 0 ) then
  print *, trim(nf90_strerror(status))
  if( present(info) ) print*,trim(info)
  stop 99
endif

end subroutine ncerror
!
!
!
subroutine write_netcdf_2D(uvar1,uvar2,uvar3)
use netcdf
use datvar
!
!integer :: status
!integer :: ncid
integer :: LatDimID,LonDimID,rlonDimID,rlatDimID
integer :: LonVarID,LatVarID,rlatVarId,rlonVarID,uVarID1,uVarID2,uVarID3
real, dimension(nlon,nlat) :: uvar1,uvar2,uvar3
real, parameter :: FillValue=-1.e+20

status = nf90_create(fnameout, nf90_clobber, ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "rlat", nlat, LatDimID)
status = nf90_def_dim(ncid, "rlon", nlon, LonDimID)

status = nf90_def_var(ncid, "lat", nf90_double, &
                            (/ LonDimId, LatDimID /), LatVarId)
status = nf90_def_var(ncid, "lon", nf90_double, &
                            (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, varid1, nf90_float, &
                            (/ LonDimId, LatDimID /), uVarId1)
status = nf90_def_var(ncid, varid2, nf90_float, &
                            (/ LonDimId, LatDimID /), uVarId2)
status = nf90_def_var(ncid, varid3, nf90_float, &
                            (/ LonDimId, LatDimID /), uVarId3)
call handle_err(status)

status = nf90_put_att(ncid, uVarID1, "coordinates","lon lat")
status = nf90_put_att(ncid, uVarID1, "_FillValue",FillValue)
status = nf90_put_att(ncid, uVarID1, "missing_value",FillValue)

status = nf90_put_att(ncid, uVarID2, "coordinates","lon lat")
status = nf90_put_att(ncid, uVarID2, "_FillValue",FillValue)
status = nf90_put_att(ncid, uVarID2, "missing_value",FillValue)

status = nf90_put_att(ncid, uVarID3, "coordinates","lon lat")
status = nf90_put_att(ncid, uVarID3, "_FillValue",FillValue)
status = nf90_put_att(ncid, uVarID3, "missing_value",FillValue)

status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
call handle_err(status)

status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
call handle_err(status)

status = nf90_enddef(ncid)

status = nf90_put_var(ncid, LatVarId, lat )
call handle_err(status)
status = nf90_put_var(ncid, LonVarId, lon )
call handle_err(status)
status = nf90_put_var(ncid, uVarId1, uvar1 )
call handle_err(status)
status = nf90_put_var(ncid, uVarId2, uvar2 )
call handle_err(status)
status = nf90_put_var(ncid, uVarId3, uvar3 )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)
!
return
end
!
!
!
subroutine write_netcdf_3D(uvar,uvar2,mtime,utime)
use netcdf
use datvar
!
!integer :: status
!integer :: ncid
integer :: LatDimID,LonDimID,rlonDimID,rlatDimID,HDimID,BDimID,HeDimID
integer :: LonVarID,LatVarID,TBVarID,TVarID,rlatVarId,rlonVarID,uVarID,uvar2VarID,uvar3VarID,HVarID,rpVarID
real, dimension(mtime) :: utime
real, dimension(nlon,nlat,mtime) :: uvar,uvar2
real, parameter :: FillValue=-1.e+20

status = nf90_create(fnameout, nf90_clobber, ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "Time", nf90_unlimited, HDimID)
status = nf90_def_dim(ncid, "west_east", nlon, LonDimID)
status = nf90_def_dim(ncid, "south_north", nlat, LatDimID)

status = nf90_def_var(ncid, "Times", nf90_double, &
                            (/ HDimID /), TVarId)
!status = nf90_def_var(ncid, "XLAT", nf90_double, &
!                            (/ LonDimId, LatDimID /), LatVarId)
!status = nf90_def_var(ncid, "lon", nf90_double, &
!                            (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, varid1, nf90_float, &
                            (/ LonDimId, LatDimID, HDimID /), uVarId)
!status = nf90_def_var(ncid, varid2, nf90_float, &
!                            (/ LonDimId, LatDimID, HDimID /), uvar2VarId)
call handle_err(status)

status = nf90_put_att(ncid, TVarID, "standard_name","time")
status = nf90_put_att(ncid, TVarID, "units","days since 1950-1-1 12:00:00")
status = nf90_put_att(ncid, TVarID, "calendar","standard")
!status = nf90_put_att(ncid, TVarID, "units","day as %Y%m%d.%f")
!status = nf90_put_att(ncid, TVarID, "calender","proleptic_gregorian")
status = nf90_put_att(ncid, TVarID, "axis","T")

status = nf90_put_att(ncid, uVarID, "_FillValue",FillValue)
status = nf90_put_att(ncid, uVarID, "FieldType",104)
status = nf90_put_att(ncid, uVarID, "MemoryOrder","XY")
status = nf90_put_att(ncid, uVarID, "units","category")
status = nf90_put_att(ncid, uVarID, "description","Dominant category")
status = nf90_put_att(ncid, uVarID, "stagger","M")
status = nf90_put_att(ncid, uVarID, "sr_x",1)
status = nf90_put_att(ncid, uVarID, "sr_y",1)

!status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
!status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
!status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
!call handle_err(status)

!status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
!status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
!status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
!call handle_err(status)

!status = nf90_put_att(ncid, uvar2VarID, "coordinates","lon lat time")
!status = nf90_put_att(ncid, uvar2VarID, "_FillValue",FillValue)
!status = nf90_put_att(ncid, uvar2VarID, "missing_value",FillValue)

status = nf90_enddef(ncid)

status = nf90_put_var(ncid, TVarId, utime )
call handle_err(status)

!status = nf90_put_var(ncid, LatVarId, lat )
!call handle_err(status)
!status = nf90_put_var(ncid, LonVarId, lon )
!call handle_err(status)
!status = nf90_put_var(ncid, uvar2VarId, uvar2 )
!call handle_err(status)
status = nf90_put_var(ncid, uVarId, uvar )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)
!
return
end
!
!
!
subroutine write_netcdf_4D(uvar,mtime,utime)
use netcdf
use datvar
!
!integer :: status
!integer :: ncid
integer :: LatDimID,LonDimID,LanDimID,rlatDimID,HDimID,BDimID,HeDimID
integer :: LonVarID,LatVarID,TBVarID,TVarID,rlatVarId,rlonVarID,uVarID,uvar2VarID,uvar3VarID,HVarID,rpVarID
real, dimension(mtime) :: utime
real, dimension(nlon,nlat,nluse,mtime) :: uvar
!real, parameter :: FillValue=-1.e+20
character*19 autime

status = nf90_create(fnameout, nf90_clobber, ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "Time", nf90_unlimited, HDimID)
status = nf90_def_dim(ncid, "west_east", nlon, LonDimID)
status = nf90_def_dim(ncid, "south_north", nlat, LatDimID)
status = nf90_def_dim(ncid, "land_cat", nluse, LanDimID)

!status = nf90_def_var(ncid, "Times", nf90_double, &
!                            (/ HDimID /), TVarId)
!status = nf90_def_var(ncid, "lat", nf90_double, &
!                            (/ LonDimId, LatDimID /), LatVarId)
!status = nf90_def_var(ncid, "lon", nf90_double, &
!                            (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, varid1, nf90_float, &
                            (/ LonDimId, LatDimID, LanDimID, HDimID /), uVarId)
call handle_err(status)

!status = nf90_put_att(ncid, TVarID, "standard_name","time")
!status = nf90_put_att(ncid, TVarID, "units","day as %Y%m%d.%f")
!status = nf90_put_att(ncid, TVarID, "calender","proleptic_gregorian")
!status = nf90_put_att(ncid, TVarID, "axis","T")

status = nf90_put_att(ncid, uVarID, "_FillValue",FillValue)
status = nf90_put_att(ncid, uVarID, "FieldType",104)
status = nf90_put_att(ncid, uVarID, "MemoryOrder","XYZ")
status = nf90_put_att(ncid, uVarID, "units","category")
status = nf90_put_att(ncid, uVarID, "description","LUCAS_LUC_v1.1_Europe_0.11deg")
status = nf90_put_att(ncid, uVarID, "stagger","M")
status = nf90_put_att(ncid, uVarID, "sr_x",1)
status = nf90_put_att(ncid, uVarID, "sr_y",1)

!status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
!status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
!status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
!call handle_err(status)

!status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
!status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
!status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
!call handle_err(status)

status = nf90_enddef(ncid)

!autime=trim("0000-00-00_00:00:00")
!
!status = nf90_put_var(ncid, TVarId, autime )
!call handle_err(status)
!status = nf90_put_var(ncid, LatVarId, lat )
!call handle_err(status)
!status = nf90_put_var(ncid, LonVarId, lon )
!call handle_err(status)
status = nf90_put_var(ncid, uVarId, uvar )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)
!
return
end
!
!
!
subroutine handle_err(status)

use netcdf

integer, intent ( in) :: status

if(status /= nf90_noerr) then
  print*, trim(nf90_strerror(status))
  stop "Stopped"
end if
end subroutine handle_err
