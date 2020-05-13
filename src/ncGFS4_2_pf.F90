!##############################################################################
!##############################################################################
!
!  This program converts a GFS forecast package as downloaded (one file
!  per time step) and writes out a file in the format that puff expects.
!  The default output filenae is Puff__GFS_______pf.nc
!
!##############################################################################
!##############################################################################

      program ncGFS4_2_pf

      use MetReader

      implicit none

      integer            :: nargs
      integer            :: status
      character (len=100):: arg

      character(len=100) :: infile
      character(len=70), allocatable :: statefiles(:)
      integer :: nfiles,grdnum
      character(len=80)  :: linebuffer
      integer :: i
      integer :: out_ncid
      logical :: IsThere

!     TEST READ COMMAND LINE ARGUMENTS
      !nargs = iargc()
      nargs = command_argument_count()
      if (nargs.lt.1) then
        write(6,*)"Enter input control file in the following format:"
        write(6,*)"Grid_Num (4 for 0.5-deg GFS)"
        write(6,*)"num_files"
        write(6,*)"list of  files"
        write(6,*)" "
        write(6,*)" Name : "
        read(5,*)infile
      else
        call get_command_argument(1, arg, status)
        infile = TRIM(arg)
      endif
      inquire( file=infile, exist=IsThere )
      if(.not.IsThere)then
        write(6,*)"ERROR: Could not find file ",infile
        write(6,*)"       Please copy file to cwd"
        stop 1
      endif
      open(unit=10,file=infile,status='old')
      read(10,*)grdnum
      read(10,*)nfiles
      write(*,*)"Grid format = ",grdnum
      write(*,*)"Number of files = ",nfiles

      allocate(statefiles(nfiles))

      write(*,*)"State files:"
      do i =1,nfiles
        read(10,'(a80)')linebuffer
        statefiles(i) = trim(adjustl(linebuffer))
        write(*,*)i,"    :",statefiles(i)
      enddo
      write(*,*)"-------------------------------------------------"

      call Write_Puff_NC_Header(grdnum,nfiles,statefiles,out_ncid)

      write(*,*)"Program ended normally."

      end program ncGFS4_2_pf

!##############################################################################
!
!     Subroutines
!
!##############################################################################

!##############################################################################
!##############################################################################

      subroutine Write_Puff_NC_Header(grdnum,nfiles,statefiles,out_ncid)

      use MetReader
      use netcdf

       implicit none

       integer             , intent(in)    :: grdnum
       integer             , intent(in)    :: nfiles
       character(len=70)   , intent(in)    :: statefiles(nfiles)
       integer             , intent(inout) :: out_ncid

       character(len=21) :: outfile_name
       integer :: nSTAT
           ! dimensions
       integer :: ot_dim_id      ! Time
       integer :: ox_dim_id      ! X (lon)
       integer :: oy_dim_id      ! Y (lat)
       integer :: op_dim_id      ! level
       integer :: onav_dim_id
       integer :: otl_dim_id
           ! variables
       integer :: ovt_var_id               ! Time
       integer :: ort_var_id               ! Time
       integer :: odt_var_id               ! Time
       integer :: oft_var_id               ! Time

       integer :: ox_var_id               ! X-distance (lon)
       integer :: oy_var_id               ! Y-distance (lat)
       integer :: op_var_id               ! Pressure
       integer :: ovx_var_id              ! u_wind
       integer :: ovy_var_id              ! v_wind
       !integer :: ovz_var_id              ! Pressure_vertical_velocity
       !integer :: oGh_var_id              ! Geopotential_height
       !integer :: oTp_var_id              ! Temperature
       integer :: oni_var_id
       integer :: onj_var_id
       integer :: ola1_var_id
       integer :: olo1_var_id
       integer :: ola2_var_id
       integer :: olo2_var_id
       integer :: odi_var_id
       integer :: odj_var_id

       integer :: it_var_id

       integer :: npmax
       integer :: nymax
       integer :: nxmax
       real(kind=4),dimension(:),allocatable :: p_sp
       real(kind=4),dimension(:),allocatable :: y_sp
       real(kind=4),dimension(:),allocatable :: x_sp
       !real(kind=4),dimension(:),allocatable :: dum1d_sp

       real(kind=4) :: dx, dy
       real(kind=4) :: x_start,y_start

       integer :: i,ivar
       real(kind=8) :: offset,FC_Package_StartHour,ref_time
       integer :: tstart_year,tstart_month,tstart_day,tstart_hour,tstart_min,tstart_sec
       integer :: FC_year
       real(kind=8) :: HS_hours_since_baseyear,start_hour
       character(len=20) :: start_date_str
       character(len=31) :: GRIB_str
       character(len=2) :: hour_str,day_str,month_str
       character(len=4) :: year_str
       integer :: xtype, length, attnum
       integer :: iw,iwf,igrid,iwfiles
       integer :: incid

       integer :: ilat
       integer :: iprojflag
       real(kind=8) :: lambda0,phi0,phi1,phi2,k0,radius_earth
       logical :: IsPeriodic, IsLatLon
       integer            :: HS_YearOfEvent
       real(kind=8)        :: Simtime_in_hours
       real(kind=4), dimension(:)      ,allocatable :: dum1d_out
       real(kind=4), dimension(:,:,:)  ,allocatable :: dum3d_out_tmp

       ! First, get the start time of the list of files
       nSTAT = nf90_open(statefiles(1),NF90_NOwrite,incid)
       write(*,*)nSTAT
       nSTAT = nf90_inq_varid(incid,"time",it_var_id)
       write(*,*)nSTAT
       nSTAT = nf90_Inquire_Attribute(incid, it_var_id,&
                     "units",xtype, length, attnum)
       write(*,*)nSTAT
       nSTAT = nf90_get_att(incid, it_var_id,"units",GRIB_str)
       write(*,*)nSTAT
       nSTAT = nf90_close(incid)
       write(*,*)nSTAT

       hour_str  = GRIB_str(23:24)
       day_str   = GRIB_str(20:21)
       month_str = GRIB_str(17:18)
       year_str  = GRIB_str(12:15)
       write(*,*)GRIB_str
       read(GRIB_str,111)tstart_year,tstart_month,tstart_day, &
                             tstart_hour,tstart_min,tstart_sec
       start_hour = real(tstart_hour,kind=8) + real(tstart_min,kind=8)/60.0_8 + &
                     real(tstart_sec,kind=8)/3600.0_8
 111   format(11x,i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2,1x)
       write(*,*)start_hour

       offset = HS_hours_since_baseyear(1992,1,1,0.0,1900,.true.)
       FC_Package_StartHour = &
           HS_hours_since_baseyear(tstart_year,tstart_month,tstart_day,&
                                   start_hour,1900,.true.)
       ref_time = FC_Package_StartHour - offset
       FC_year = HS_YearOfEvent(FC_Package_StartHour,1900,.true.)

       write(*,*)GRIB_str
       write(*,*)year_str
       write(*,*)month_str
       write(*,*)day_str
       write(*,*)hour_str
       write(*,*)FC_Package_StartHour
       write(start_date_str,122)year_str,month_str,day_str,hour_str
 122   format(a4,'-',a2,'-',a2,' ',a2,':00:00Z')
       write(*,*)start_date_str

       if(grdnum.eq.4)then
         npmax = 34
         nymax = 361
         nxmax = 720
       endif

       outfile_name="Puff__GFS_______pf.nc"
       ! Create and open netcdf file
       write(*,*)"Creating ",outfile_name
       nSTAT = nf90_create(trim(adjustl(outfile_name)),nf90_clobber, out_ncid)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: create file_OUT: ', &
                             nf90_strerror(nSTAT)

       ! Define dimesions
         ! t,z,lon,lat
         ! We will define a 'time' dimension though it will be of length 1
       nSTAT = nf90_def_dim(out_ncid,"record",nf90_unlimited,ot_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def t',nf90_strerror(nSTAT)
       nSTAT = nf90_def_dim(out_ncid,"level",npmax,op_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def z',nf90_strerror(nSTAT)
       nSTAT = nf90_def_dim(out_ncid,"lat",nymax,oy_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def y',nf90_strerror(nSTAT)
       nSTAT = nf90_def_dim(out_ncid,"lon",nxmax,ox_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def x',nf90_strerror(nSTAT)

       nSTAT = nf90_def_dim(out_ncid,"nav",1,onav_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def nav',nf90_strerror(nSTAT)
       nSTAT = nf90_def_dim(out_ncid,"time_len",21,otl_dim_id)
       if(nSTAT.ne.0) &
           write(9,*)'ERROR: def timelen',nf90_strerror(nSTAT)

       ! Define coordinate variables
         ! X,Y,Z,time
       nSTAT = nf90_def_var(out_ncid,"valtime",nf90_double,(/ot_dim_id/),ovt_var_id)
       nSTAT = nf90_put_att(out_ncid,ovt_var_id,"units","hours since 1992-1-1")
       nSTAT = nf90_put_att(out_ncid,ovt_var_id,"long_name","valid time")

       nSTAT = nf90_def_var(out_ncid,"reftime",nf90_double,(/ot_dim_id/),ort_var_id)
       nSTAT = nf90_put_att(out_ncid,ort_var_id,"units","hours since 1992-1-1")
       nSTAT = nf90_put_att(out_ncid,ort_var_id,"long_name","reference time")

       nSTAT = nf90_def_var(out_ncid,"datetime",nf90_char,(/ot_dim_id,otl_dim_id/),odt_var_id)
       nSTAT = nf90_put_att(out_ncid,odt_var_id,"long_name","reference date and time")

       nSTAT = nf90_def_var(out_ncid,"forecasttime",nf90_char,(/ot_dim_id,otl_dim_id/),oft_var_id)
       nSTAT = nf90_put_att(out_ncid,oft_var_id,"long_name","forecast date and time")

       nSTAT = nf90_def_var(out_ncid,"level",nf90_float,(/op_dim_id/),op_var_id)
       nSTAT = nf90_put_att(out_ncid,op_var_id,"long_name","isobaric level")
       nSTAT = nf90_put_att(out_ncid,op_var_id,"units","hectopascals")

       nSTAT = nf90_def_var(out_ncid,"lat",nf90_float,(/oy_dim_id/),oy_var_id)
       nSTAT = nf90_put_att(out_ncid,oy_var_id,"long_name","latitude")
       nSTAT = nf90_put_att(out_ncid,oy_var_id,"units","degrees_north")

       nSTAT = nf90_def_var(out_ncid,"lon",nf90_float,(/ox_dim_id/),ox_var_id)
       nSTAT = nf90_put_att(out_ncid,ox_var_id,"long_name","longitude")
       nSTAT = nf90_put_att(out_ncid,ox_var_id,"units","degrees_east")

       nSTAT = nf90_def_var(out_ncid,"Ni",nf90_int,(/onav_dim_id/),oni_var_id)
       nSTAT = nf90_put_att(out_ncid,oni_var_id,"long_name",&
                 "number of points along a latitude circle")

       nSTAT = nf90_def_var(out_ncid,"Nj",nf90_int,(/onav_dim_id/),onj_var_id)
       nSTAT = nf90_put_att(out_ncid,onj_var_id,"long_name",&
                 "number of points along a longitude circle")

       nSTAT = nf90_def_var(out_ncid,"La1",nf90_float,(/onav_dim_id/),ola1_var_id)
       nSTAT = nf90_put_att(out_ncid,ola1_var_id,"long_name",&
                 "latitude of first grid point")
       nSTAT = nf90_put_att(out_ncid,ola1_var_id,"units","degrees_north")

       nSTAT = nf90_def_var(out_ncid,"Lo1",nf90_float,(/onav_dim_id/),olo1_var_id)
       nSTAT = nf90_put_att(out_ncid,olo1_var_id,"long_name",&
                 "longitude of first grid point")
       nSTAT = nf90_put_att(out_ncid,olo1_var_id,"units","degrees_east")

       nSTAT = nf90_def_var(out_ncid,"La2",nf90_float,(/onav_dim_id/),ola2_var_id)
       nSTAT = nf90_put_att(out_ncid,ola2_var_id,"long_name",&
                 "latitude of last grid point")
       nSTAT = nf90_put_att(out_ncid,ola2_var_id,"units","degrees_north")

       nSTAT = nf90_def_var(out_ncid,"Lo2",nf90_float,(/onav_dim_id/),olo2_var_id)
       nSTAT = nf90_put_att(out_ncid,olo2_var_id,"long_name",&
                 "longitude of last grid point")
       nSTAT = nf90_put_att(out_ncid,olo2_var_id,"units","degrees_east")

       nSTAT = nf90_def_var(out_ncid,"Di",nf90_float,(/onav_dim_id/),odi_var_id)
       nSTAT = nf90_put_att(out_ncid,odi_var_id,"long_name",&
                 "Longitudinal direction increment")
       nSTAT = nf90_put_att(out_ncid,odi_var_id,"units","degrees")

       nSTAT = nf90_def_var(out_ncid,"Dj",nf90_float,(/onav_dim_id/), odj_var_id)
       nSTAT = nf90_put_att(out_ncid,odj_var_id,"long_name",&
                 "Latitudinal direction increment")
       nSTAT = nf90_put_att(out_ncid,odj_var_id,"units","degrees")

       if(nSTAT.ne.0)write(9,*)'ERROR: def_var: ',nf90_strerror(nSTAT)
          ! Now define the time-dependent variables
          ! u_wind
       nSTAT = nf90_def_var(out_ncid,"u",nf90_float,   &
           (/ox_dim_id,oy_dim_id,op_dim_id,ot_dim_id/), &
             ovx_var_id)
       nSTAT = nf90_put_att(out_ncid,ovx_var_id,"long_name","u-component of wind at isobaric levels")
       nSTAT = nf90_put_att(out_ncid,ovx_var_id,"units","m/s")
       nSTAT = nf90_put_att(out_ncid,ovx_var_id,"missing_value","-9999.f")
       nSTAT = nf90_put_att(out_ncid,ovx_var_id,"navigation","nav")
          ! v_wind
       nSTAT = nf90_def_var(out_ncid,"v",nf90_float,   &
           (/ox_dim_id,oy_dim_id,op_dim_id,ot_dim_id/), &
             ovy_var_id)
       nSTAT = nf90_put_att(out_ncid,ovy_var_id,"long_name","v-component of wind at isobaric levels")
       nSTAT = nf90_put_att(out_ncid,ovy_var_id,"units","m/s")
       nSTAT = nf90_put_att(out_ncid,ovy_var_id,"missing_value","-9999.f")
       nSTAT = nf90_put_att(out_ncid,ovy_var_id,"navigation","nav")
          ! Temperature
       !nSTAT = nf90_def_var(out_ncid,"temperature",nf90_float,   &
       !    (/ox_dim_id,oy_dim_id,op_dim_id,ot_dim_id/), &
       !      oTp_var_id)
       !nSTAT = nf90_put_att(out_ncid,oTp_var_id,"long_name","temperature")
       !nSTAT = nf90_put_att(out_ncid,oTp_var_id,"units","degrees C")
       !nSTAT = nf90_put_att(out_ncid,oTp_var_id,"missing_value","-9999.f")
          ! Geopotential Height
       !nSTAT = nf90_def_var(out_ncid,"gpm",nf90_float,   &
       !    (/ox_dim_id,oy_dim_id,op_dim_id,ot_dim_id/), &
       !      oGh_var_id)
       !nSTAT = nf90_put_att(out_ncid,oGh_var_id,"long_name","Geopotential Height")
       !nSTAT = nf90_put_att(out_ncid,oGh_var_id,"units","m")
       !nSTAT = nf90_put_att(out_ncid,oGh_var_id,"missing_value","-9999.f")

       ! Leaving define mode.
       nSTAT = nf90_enddef(out_ncid)
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ! Fill non-time-dependent variables with initial values
        ! Note: datetime, forecasttime, reftime, and valtime will be filled once
        !       the first GFS file is read.
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ! Fill non-time-dependent variables with initial values
        ! datetime
        nSTAT=nf90_put_var(out_ncid,odt_var_id,start_date_str,(/1,1/))
        ! forecasttime
        nSTAT=nf90_put_var(out_ncid,oft_var_id,start_date_str,(/1,1/))
        !reftime 
        nSTAT=nf90_put_var(out_ncid,ort_var_id,ref_time,(/1/))
        !valtime
        nSTAT=nf90_put_var(out_ncid,ovt_var_id,ref_time+0.0_8,(/1/))

       allocate(p_sp(npmax))
       p_sp = (/1000.0_4, 975.0_4, 950.0_4, 925.0_4, 900.0_4, &
                 850.0_4, 800.0_4, 750.0_4, 700.0_4, 650.0_4, &
                 600.0_4, 550.0_4, 500.0_4, 450.0_4, 400.0_4, &
                 350.0_4, 300.0_4, 250.0_4, 200.0_4, 150.0_4, &
                 100.0_4,  70.0_4,  50.0_4,  40.0_4,  30.0_4, &
                  20.0_4,  15.0_4,  10.0_4,   7.0_4,   5.0_4, &
                   3.0_4,   2.0_4,   1.0_4,   0.4_4/)
       dx      =  0.5_4
       dy      =  0.5_4
       x_start =  0.0_4
       y_start =-90.0_4
       allocate(x_sp(nxmax))
       allocate(y_sp(nymax))
       do i = 1,nxmax
         x_sp(i) = x_start + (i-1)*dx
       enddo
       do i = 1,nymax
         y_sp(i) = y_start + (i-1)*dy
       enddo

       nSTAT=nf90_put_var(out_ncid,op_var_id,p_sp,(/1/))
       if(nSTAT.ne.0) write(9,*)'ERROR: put_var p: ',nf90_strerror(nSTAT)

          ! Lat
          !  Note : we need to reverse the order so that the outfile
          !         starts at the north
        allocate(dum1d_out(nymax))
        do ilat = 1,nymax
          dum1d_out(ilat) = real(y_sp(nymax+1-ilat),kind=4)
        enddo
        nSTAT=nf90_put_var(out_ncid,oy_var_id,dum1d_out,(/1/))
        if(nSTAT.ne.0) &
          write(9,*)'ERROR: put_var y: ',nf90_strerror(nSTAT)
        deallocate(dum1d_out)
          ! Lon
        allocate(dum1d_out(nxmax))
        dum1d_out(:) = real(x_sp(1:nxmax),kind=4)
        nSTAT=nf90_put_var(out_ncid,ox_var_id,dum1d_out,(/1/))
        if(nSTAT.ne.0) &
          write(9,*)'ERROR: put_var x: ',nf90_strerror(nSTAT)
        deallocate(dum1d_out)

       nSTAT=nf90_put_var(out_ncid,ola1_var_id,-90.0_4,(/1/))
       nSTAT=nf90_put_var(out_ncid,olo1_var_id,0.0_4,(/1/))
       nSTAT=nf90_put_var(out_ncid,ola2_var_id,90.0_4,(/1/))
       nSTAT=nf90_put_var(out_ncid,olo2_var_id,359.5_4,(/1/))
       nSTAT=nf90_put_var(out_ncid,oni_var_id,720,(/1/))
       nSTAT=nf90_put_var(out_ncid,onj_var_id,361,(/1/))
       nSTAT=nf90_put_var(out_ncid,odi_var_id,0.5_4,(/1/))
       nSTAT=nf90_put_var(out_ncid,odj_var_id,0.5_4,(/1/))

      ! Initialize MetReader library
       iw      = 4
       iwf     = 20
       igrid   = 0
       iwfiles = nfiles

       Simtime_in_hours = 3*(nfiles-1)
       call MR_Allocate_FullMetFileList(iw,iwf,igrid,2,iwfiles)

       do i=1,nfiles
         write(MR_windfiles(i),*)trim(ADJUSTL(statefiles(i)))
       enddo
         ! Check for existance and compatibility with simulation time requirements
       call MR_Read_Met_DimVars(FC_year)

       IsLatLon = .true.
       iprojflag = 1
       lambda0      = -105.0_8
       phi0         = 90.0_8
       phi1         = 90.0_8
       phi2         = 90.0_8
       k0           = 0.933_8
       radius_earth = 6371.229_8
       IsPeriodic = .true.

       call MR_Set_CompProjection(IsLatLon,iprojflag,lambda0,phi0,phi1,phi2,k0,radius_earth)

       call MR_Initialize_Met_Grids(nxmax,nymax,npmax, &
                               x_sp(1:nxmax)         , &
                               y_sp(1:nymax)         , &
                               p_sp(1:npmax)         , &
                               IsPeriodic)
       call MR_Set_Met_Times(FC_Package_StartHour, Simtime_in_hours)

       ! Now we need to open each file in the list and copy vx,vy,temp,gpm to outfile
       allocate(dum3d_out_tmp(nxmax,nymax,npmax))
       do i=1,nfiles
           ! Time
         ! datetime
         nSTAT=nf90_put_var(out_ncid,odt_var_id,start_date_str,(/i,1/))
         !reftime 
         nSTAT=nf90_put_var(out_ncid,ort_var_id,ref_time,(/i/))
         ! forecasttime
         nSTAT=nf90_put_var(out_ncid,oft_var_id,start_date_str,(/i,1/))
         !valtime
         nSTAT=nf90_put_var(out_ncid,ovt_var_id,ref_time+(i-1)*3,(/i/))


         ! Note: MetReader loads MR_dum3d_metP with lat from S to N and z from
         !       bottom to top.  Puff wants the files to be N to S and bottom to
         !       top
         ivar = 2 ! Vx
         call MR_Read_3d_MetP_Variable(ivar,i)
         do ilat = 1,nymax
           dum3d_out_tmp(:,ilat,:) = MR_dum3d_metP(:,nymax+1-ilat,:)
         enddo
         nSTAT=nf90_put_var(out_ncid,ovx_var_id,dum3d_out_tmp,(/1,1,1,i/))

         ivar = 3 ! Vy
         call MR_Read_3d_MetP_Variable(ivar,i)
         do ilat = 1,nymax
           dum3d_out_tmp(:,ilat,:) = MR_dum3d_metP(:,nymax+1-ilat,:)
         enddo
         nSTAT=nf90_put_var(out_ncid,ovy_var_id,dum3d_out_tmp,(/1,1,1,i/))

       enddo
       deallocate(dum3d_out_tmp)

       nSTAT = nf90_close(out_ncid)

      end subroutine Write_Puff_NC_Header


