      program makeAsh3dinput1_ac

!      --This file is a component of the USGS program Ash3d for volcanic ash transport
!          and dispersion.

!      --Use of this program is described in:

!        Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., in press, Ash3d, a finite-
!           volume, conservative numerical model for ash transport and tephra deposition,
!           Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968

!      --Written in Fortran 90

!      --The program has been successfully tested and run on the Linux Operating System using
!          Red Hat 8/9 and Ubuntu 22/24.

!       Although this program has been used by the USGS, no warranty, expressed or implied, is 
!         made by the USGS or the United States Government as to the accuracy and functioning 
!         of the program and related program material nor shall the fact of distribution constitute 
!         any such warranty, and no responsibility is assumed by the USGS in connection therewith.

!     program that reads from a simplified ASCII input file 
!     and creates a standard Ash3d input file with a very large 
!     model domain and very low resolution, appropriate for a preliminary
!     model run of an ash cloud deposit.  The results of this model run
!     are read by makeAsh3dinput2_ac, which adjusts the limits
!     of the model domain and creates a new Ash3d input file that can
!     be used for a standard run.
!
!     This program takes three command-line arguments:
!       input file (simplified) generated from web client
!       input file (full) to be written by makeAsh3dinput1_ac
!       The last forcast package downloaded in YYYYMMDDHH
!
!   makeAsh3dinput1_dp ash3d_input_dp.inp out.inp 2025040712
!
!     Where the simplified input file as the following format:
!
!   Popocatépetl                     # Volcano name
!   -98.622 19.023                   # Longitude, Latitude
!   5426.0                           # Elevation (m)
!   8.0 1.0 60.0  0.003              # Plume height (km), duration (hrs), sim. time (hrs), [optional volume (km3 DRE)]
!   2024 11 07 12.6666666666666666 0 # Start time (year, month, day, hour UTC) [Not Actual Eruption]
!   20                               # iwindformat; normally 20 (0.5 GFS), but can be 34 (0.25 ECMWF)
!
! NWP data are expected to be stored on the file system in the following structure.
!  GFS 0.5 degree
!     /data/WindFiles/gfs/gfs.2025041700/gfs.t00z.pgrb2.0p50.f000
!     /data/WindFiles/gfs/gfs.2025041700/2025041700.f000.nc
!  NCEP 2.5 degree reanalysis
!     /data/WindFiles/NCEP/2025/air.2025.nc
! Extra products that may be available:
!  ECMWF 0.25 degree
!     /data/WindFiles/ecmwf/ecmwf.2025041700/20250417000000-0h-oper-fc.grib2
!  NAM 196 (Hawaii 2.5 km)
!     /data/WindFiles/nam/196/20250417_00/nam.t00z.hawaiinest.hiresf00.tm00.grib2
!     /data/WindFiles/nam/196/20250417_00/nam.t00z.hawaiinest.hiresf00.tm00.grib2.nc
!  NAM 091 (Alaska 2.95 km)
!     /data/WindFiles/nam/091/20250417_00/nam.t00z.alaskanest.hiresf00.tm00.loc.grib2
!
      ! This module requires Fortran 2003 or later
      use iso_fortran_env, only : &
         input_unit,output_unit,error_unit

      implicit none

      integer,parameter :: GFS_Archive_Days   = 14
      integer,parameter :: ECMWF_Archive_Days = 3
      integer,parameter :: NAM_Archive_Days   = 7

      integer,parameter :: fid_ctrin_mini  = 10
      integer,parameter :: fid_ctrout_full = 11

      integer           :: nargs
      integer           :: iostatus
      character(len=80) :: infile, outfile
      logical           :: IsThere

      real(kind=8)      :: aspect_ratio
      real(kind=8)      :: dx, dy
      real(kind=8)      :: dz
      real(kind=8)      :: lonLL, latLL
      real(kind=8)      :: lonUR, latUR
      real(kind=8)      :: FineAshFraction
      integer           :: e_iday,e_imonth,e_iyear
      real(kind=8)      :: e_Hour
      real(kind=8)      :: e_Hours1900   = 0.0_8
      real(kind=8)      :: e_Volume, min_vol
      real(kind=8)      :: e_Duration, min_duration
      real(kind=8)      :: e_Height
      real(kind=8)      :: SimTime
      real(kind=8)      :: min_SimTime, max_SimTime
      integer           :: Erup
      integer           :: RunClass
      real(kind=8)      :: v_lon, v_lat, v_elevation
      real(kind=8)      :: Comp_Width,Comp_Height
      real(kind=8)      :: WriteInterval, WriteTimes(20)
      integer           :: i
      integer           :: imonthdays(12)
      integer           :: iwind,iwindformat,igrid,idf
      integer           :: nWindFiles
      character(len=80) :: Windfile
      integer           :: nWriteTimes
      character(len=80) :: linebuffer
      character(len=25) :: volcano_name

      ! Current date and time variables
      character(len=10) :: time2            !time argument used to get current date and time
      character(len=5)  :: timezone
      character(len=8)  :: date
      integer           :: values(8),Now_iyear,Now_imonth,Now_iday,Now_ihour,Now_iminutes  !time values
      real(kind=8)      :: Now_hour
      real(kind=8)      :: Now_Hours1900 = 0.0_8

      integer           :: timediff                       ! time difference (local-UTC, minutes)
      ! Variables for time of windfiles
      character(len=10) :: last_downloaded  !date and time of last downloaded wind file
      integer           :: NWP_iyear,NWP_imonth,NWP_iday,NWP_ihour
      real(kind=8)      :: NWP_hour
      real(kind=8)      :: NWP_Hours1900 = 0.0_8
      logical           :: VolumeInput                    ! boolean set to true if volume is specified

      real(kind=8)      :: HS_hours_since_baseyear
      integer           :: byear    = 1900
      logical           :: useLeaps = .true.
      integer           :: HS_YearOfEvent
      integer           :: HS_MonthOfEvent
      integer           :: HS_DayOfEvent
      real(kind=8)      :: HS_HourOfDay

      data imonthdays/31,29,31,30,31,30,31,31,30,31,30,31/

      write(output_unit,*) ' '
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) 'starting makeAsh3dinput1_ac'
      write(output_unit,*) ' '

      ! Set constants
      aspect_ratio     = 1.5_8                                    ! map aspect ratio (km/km)
      VolumeInput      = .false.                                  ! =.true. if volume is specified
      FineAshFraction  = 0.05_8                                   ! mass fraction fine ash

      ! Set default values
      iwind        = 4
      iwindformat  = 20
      igrid        = 4
      idf          = 2
      nWindFiles   = 67
      min_vol      = 0.001_8                                     ! minimum erupted volume (km3 DRE)
      min_duration = 0.1_8                                       ! minimum eruption duration (hrs)
      min_SimTime  = 3.0_8
      max_SimTime  = 120.0_8

      ! Get current date & time
      timezone = "+0000"
      call date_and_time(date,time2,timezone,values)  !get current date & time
      Now_iyear     = values(1)
      Now_imonth    = values(2)
      Now_iday      = values(3)
      timediff      = values(4)
      Now_ihour     = values(5)
      Now_hour      = Now_ihour - float(timediff)/60.0_8
      Now_iminutes  = values(6)
      Now_Hours1900 = HS_hours_since_baseyear(Now_iyear,Now_imonth,Now_iday,Now_hour,byear,useLeaps)
      write(output_unit,1001) Now_iyear,Now_imonth,Now_iday,Now_ihour,Now_iminutes
1001  format(' current date: ',i4,'.',i2.2,'.',i2,' ',i2,':',i2.2,&
             ' local time')

      ! Test read command-line arguments
      nargs = command_argument_count()
      if (nargs.ne.3) then
        write(error_unit,*) 'ERROR: Three input arguments required:'
        write(error_unit,*) '         input filename'
        write(error_unit,*) '         output file'
        write(error_unit,*) '         date & time of the last downloaded wind data FC package.'
        write(error_unit,*) '            date & time in format YYYYMMDDHH'
        write(error_unit,*) 'You have specified ',nargs, ' input arguments.'
        write(error_unit,*) 'program stopped'
        stop 1
      endif
      call get_command_argument(1, infile,          iostatus)
      call get_command_argument(2, outfile,         iostatus)
      call get_command_argument(3, last_downloaded, iostatus)

      ! Read and parse command-line argument specifying last downloaded forecast package
      read(last_downloaded,1041) NWP_iyear, NWP_imonth, NWP_iday, NWP_ihour
1041  format(i4,i2,i2,i2)
      NWP_hour = real(NWP_ihour,kind=8)
      NWP_Hours1900 = HS_hours_since_baseyear(NWP_iyear,NWP_imonth,NWP_iday,NWP_hour,byear,useLeaps)

      write(output_unit,*) 'Command-line arguments parsed as:'

      write(output_unit,*) '  infile  = ', infile
      write(output_unit,*) '  outfile = ', outfile
      write(output_unit,*) '  last downloaded wind file = ',last_downloaded
      inquire( file=infile, exist=IsThere )
      if(.not.IsThere)then
        write(error_unit,*)"ERROR: Could not find file :",infile
        write(error_unit,*)"       Please copy file to cwd"
        stop 1
      endif

      open(unit=fid_ctrin_mini,file=infile)         !simplified input file generated by the web client
      ! This file should have the following format:
      !  Line 1 : Volcano name
      !  Line 2 : Longitude, Latitude
      !  Line 3 : Elevation (m)
      !  Line 4 : Plume height (km), duration (hrs), sim. time (hrs), optional volume (km3)
      !  Line 5 : YYYY MM DD HH.HH Erup  : Start time (hours relative to start of current windfile)
      !  Line 6 : iwindformat
        ! line 1
      read(fid_ctrin_mini,'(a25)',iostat=iostatus) volcano_name  ! This is normally 30, but is 25 in ash3d_input_ac.inp
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano name'
        stop 1
      endif
        ! line 2
      read(fid_ctrin_mini,*      ,iostat=iostatus) v_lon, v_lat
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano lon and lat'
        stop 1
      endif
        ! line 3
      read(fid_ctrin_mini,*      ,iostat=iostatus) v_elevation
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano elevation'
        stop 1
      endif
        ! line 4
      read(fid_ctrin_mini,'(a80)',iostat=iostatus) linebuffer
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano line with ESPs'
        stop 1
      endif
      read(linebuffer,*,iostat=iostatus) e_Height, e_Duration, SimTime
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano e_Height, e_Duration, SimTime'
        stop 1
      endif
      ! Error-checking values for line 4
      ! Make sure plume height is greater than volcano elevation
      if (e_Height.lt.(v_elevation/1000.0_8)) then
        write(error_unit,*) 'ERROR: plume height is lower than volcano summit elevation'
        write(error_unit,*) 'program stopped'
        stop 1
      endif
      ! Make sure minimum eruption duration exceeds 0.05 hrs
      if (e_Duration.lt.min_duration) then
        write(error_unit,*) 'ERROR: eruption duration = ',e_Duration
        write(error_unit,*) 'eruption duration must exceed ',min_duration
        write(error_unit,*) 'Program stopped'
        stop 1
      endif
      ! Make sure the simulation time is long enought
      if (SimTime.lt.min_SimTime) then
        write(error_unit,*) 'ERROR: you gave a simulation time of ',real(SimTime,kind=4),&
                            ' hours.'
        write(error_unit,*) 'Simulation time must be =>',real(min_SimTime,kind=4)
        stop 1
      endif
      ! Successfully read 3 values, try for 4
      read(linebuffer,*,iostat=iostatus) e_Height, e_Duration, SimTime, e_Volume
      if(iostatus.eq.0)then
        ! If 4 values were read, then a user-provided e_Volume was given
        ! If so, then VolumeInput=.true, and we need to do some error checking
        VolumeInput = .true.
        write(output_unit,*) 'VolumeInput = .true.'
        write(output_unit,*) 'Erupted volume specified as input:', &
                              real(e_Volume,kind=4), ' km3 DRE'
        if ((e_Volume.lt.1.e-5_8).or.(e_Volume.gt.1.0e2_8)) then
          write(error_unit,*) 'ERROR: Specified eruptive volume must be between 0.00001 and 100 km3.'
          write(error_unit,*) 'You entered ',e_Volume, '.  Program stopped'
          stop 1
        endif
      endif

        ! line 5
      read(fid_ctrin_mini,'(a80)',iostat=iostatus)linebuffer
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read volcano line with start time'
        stop 1
      endif
      read(linebuffer,*,iostat=iostatus) e_iyear, e_imonth, e_iday, e_Hour
      if(iostatus.ne.0)then
        write(error_unit,*) 'ERROR: Could not read eruption start times.'
        write(error_unit,*) '   e_iyear  = ',e_iyear
        write(error_unit,*) '   e_imonth = ',e_imonth
        write(error_unit,*) '   e_iday   = ',e_iday
        write(error_unit,*) '   e_Hour   = ',e_Hour
        stop 1
      elseif(e_iyear.eq.0)then
        if(e_iday.lt.0.or.e_iday.gt.5)then
          ! Don't let forecast go more than 5 days out
          write(error_unit,*) 'ERROR: forecast offset start day must be 0=<t<=5'
          write(error_unit,*) '   e_iday   = ',e_iday
          stop 1
        endif
        if(e_Hour.lt.0.0_8.or.e_Hour.gt.120.0_8)then
          write(error_unit,*) 'ERROR: forecast offset start hour must be 0=<t<=120'
          write(error_unit,*) '   e_Hour   = ',e_Hour
          stop 1
        endif
      else
        ! imput date is a real time; check validity
        if ((e_iyear.lt.1948).or.(e_iyear.gt.Now_iyear)) then
          write(error_unit,*) 'ERROR:  Eruption start year must be zero or a year between'
          write(error_unit,*) '1948 and the present.  You entered:',e_iyear
          write(error_unit,*) 'Program stopped'
          stop 1
        else
          e_Hours1900 = HS_hours_since_baseyear(e_iyear,e_imonth,e_iday,e_hour,byear,useLeaps)
        endif
        if ((e_imonth.lt.0).or.(e_imonth.gt.12)) then
          write(error_unit,*) 'ERROR:  Eruption start month must be between 0 and 12.'
          write(error_unit,*) 'You entered:',e_imonth
          write(error_unit,*) 'Program stopped'
          stop 1
        endif
        if ((e_iday.lt.0).or.(e_iday.gt.imonthdays(e_imonth))) then
          write(error_unit,*) 'ERROR: Eruption start day must be less than the number of days'
          write(error_unit,*) 'in that month.  The month you entered is:',e_imonth
          write(error_unit,*) 'The number of days in this month is:',imonthdays(e_imonth)
          write(error_unit,*) 'the day in that month you entered is:',e_iday
          write(error_unit,*) 'Program stopped'
          stop 1
        endif
      endif

      ! Successfully read 4 values, try for 5
      read(linebuffer,*,iostat=iostatus) e_iyear, e_imonth, e_iday, e_Hour, Erup
      if(iostatus.ne.0)then
        write(output_unit,*) 'WARNING: Could not read volcano actual eruption flag.'
        write(output_unit,*) '         Setting to 0.'
        Erup = 0
      endif
      if(Erup.ne.1)then
        ! If Erup is anything other than 1, the turn it off
        Erup = 0
      endif

        ! line 6
      read(fid_ctrin_mini,*,iostat=iostatus)iWindFormat
      if(iostatus.ne.0)then
        write(output_unit,*) 'WARNING: Could not read wind file type'
        iWindFormat = 20
      endif
      if(iWindFormat.ne.20.and.iWindFormat.ne.34)then
        write(output_unit,*) 'WARNING: provided iwindformat not recognized: ',iWindFormat
        write(output_unit,*) '         Resetting to 20'
        iWindFormat = 20
      endif
        ! Done with mini-input file
      close(fid_ctrin_mini)

      write(*,*)"--------------------------"
      write(*,*)"System time now      : ",Now_iyear,Now_imonth,Now_iday,&
                                          real(Now_hour,kind=4),real(Now_Hours1900,kind=4)
      write(*,*)"Eruption start time  : ",e_iyear,e_imonth,e_iday,real(e_Hour,kind=4)
      write(*,*)"Most recent wind data: ",NWP_iyear,NWP_imonth,NWP_iday,NWP_ihour
      write(*,*)"--------------------------"

      ! Now sort out the windfiles to use
      if(e_iyear.eq.0.or.e_Hours1900.gt.NWP_Hours1900)then
        ! This is a forecast case using the most recent FC package, either where the e_Hour provided is
        ! the offset from the most recent FC package, or the start time is after the latest FC
        if(Erup.eq.0)then
          RunClass = 2  ! Hypothetical
        else
          RunClass = 3  ! Forecast (actual eruption)
        endif

        if(e_iyear.eq.0)then
          ! Reset eruption start time based on day/hour offset from last available FC package
          e_Hours1900 = NWP_Hours1900 + e_iday*24.0_8 + e_Hour
          e_iyear  = HS_YearOfEvent(e_Hours1900,byear,useLeaps)
          e_imonth = HS_MonthOfEvent(e_Hours1900,byear,useLeaps)
          e_iday   = HS_DayOfEvent(e_Hours1900,byear,useLeaps)
          e_Hour   = HS_HourOfDay(e_Hours1900,byear,useLeaps)
        endif
        ! This actual eruption start time will be written to the control file, but the template
        ! windfile name needs to be the last package downloaded
        write(output_unit,*) 'Using current windfiles'
        if(iwindformat.eq.20)then
          write(WindFile,1002) NWP_iyear, NWP_imonth, NWP_iday, NWP_ihour, &
                               NWP_iyear, NWP_imonth, NWP_iday, NWP_ihour
1002      format('Wind_nc/gfs/gfs.',i4,i2.2,i2.2,i2.2,'/',i4,i2.2,i2.2,i2.2,'.f')
          ! Error-check the start/end time
        elseif(iwindformat.eq.34)then
          nWindFiles   = 34
          igrid        = 193
          idf          = 3
          ! Only write for the FC00 package since that's all we are downloading now
          write(WindFile,1003) NWP_iyear, NWP_imonth, NWP_iday,  &
                               NWP_iyear, NWP_imonth, NWP_iday
1003      format('Wind_nc/ecmwf/ecmwf.',i4,i2.2,i2.2,'00/',i4,i2.2,i2.2,'000000-')
        endif

        ! Do a bit of error-checking to make sure the simulation is within the package
        if(iwindformat.eq.20)then
          if(e_Hours1900.gt.NWP_Hours1900+120.0_8)then
            ! Don't let forecast go more than 5 days out
            write(error_unit,*) 'ERROR: forecast start time too far in the future.'
            stop 1
          elseif(e_Hours1900+SimTime.gt.NWP_Hours1900+198.0_8)then
            write(error_unit,*) 'ERROR: forecast end time too far in the future.'
            stop 1
          endif
        elseif(iwindformat.eq.34)then
          if(e_Hours1900.gt.NWP_Hours1900+24.0_8)then
            ! Don't let forecast go more than 1 day out
            write(error_unit,*) 'ERROR: forecast start time too far in the future.'
            stop 1
          elseif(e_Hours1900+SimTime.gt.NWP_Hours1900+99.0_8)then
            write(error_unit,*) 'ERROR: forecast end time too far in the future.'
            stop 1
          endif
        endif

      else
        ! A specific date/time is given and start time is earlier that last downloaded.
        ! Runclass is by default Analysis, but could be Forecast if Erup=1
        RunClass = 1  ! Analysis
        if(Erup.eq.1)then
          ! This could be if we are tracking a cloud over a few days and using old forecast data
          RunClass = 3  ! Forecast (actual eruption)
        endif

        ! Check to see if it is in the scope of GFS/ECMWF/NCEP
        if (iwindformat.eq.20.and.&
            ((Now_Hours1900-e_Hours1900).lt.(24.0_8*GFS_Archive_Days))) then
          ! if GFS files are requested and the start time is within the archive
          write(output_unit,*) 'Using archived gfs wind files'
          if (e_Hour.lt.12.0) then                        ! before 1200 UTC
            write(WindFile,1004) e_iyear, e_imonth, e_iday, e_iyear, e_imonth, e_iday
1004        format('Wind_nc/gfs/gfs.',i4,i2.2,i2.2,'00','/',i4,i2.2,i2.2,'00.f')
          else                                               ! after 1200 UTC
            write(WindFile,1005) e_iyear, e_imonth, e_iday, e_iyear, e_imonth, e_iday
1005        format('Wind_nc/gfs/gfs.',i4,i2.2,i2.2,'12','/',i4,i2.2,i2.2,'12.f')
          endif
        elseif (iwindformat.eq.34.and.&
            ((Now_Hours1900-e_Hours1900).lt.(24.0_8*ECMWF_Archive_Days))) then
          ! if ECMWF files are requested and the start time is within the archive
          write(output_unit,*) 'Using archived ecmwf wind files'

          write(WindFile,1003) e_iyear, e_imonth, e_iday,  &
                               e_iyear, e_imonth, e_iday
        elseif (e_iyear.ge.1948) then                            ! If we're using NCEP reanalysis
          if(Erup.eq.1)then
            ! We should not have an actual eruption with NCEP data
            write(output_unit,*) 'Looks like the Actual Eruption flag is set, but with a start time > 14 days ago.'
            write(output_unit,*) 'Switching runclass to Analysis.'
            RunClass = 1  ! Analysis
          endif
          write(output_unit,*) 'Using NCEP reanalysis wind files'
          iwind       = 5
          iWindFormat = 25
          igrid       = 2
          idf         = 2
          nWindFiles=1
          write(WindFile,1006)
1006      format('Wind_nc/NCEP')
        elseif (e_iyear.lt.1948) then                            ! if before 1948 (error)
          write(error_unit,*) 'ERROR.  You entered a year earlier than 1948.'
          write(error_unit,*) 'Wind files do not exist for this earlier time period.'
          stop 1
        else
          write(error_unit,*) 'Unknown error in identifying appropriate wind files.'
          stop 1
        endif
      endif

      ! Calculate eruptive volume, model domain, resolution
      if (VolumeInput.eqv..false.) then             ! erupted volume (km3)
        ! Calculate total erupted volume from the Mastin relation
        e_Volume=((e_Height-v_elevation/1000.0_8)/2.0_8)** (1.0_8/0.241_8)*3600.0_8*e_Duration/1.0e09_8
        if (e_Volume.lt.min_vol) e_Volume = min_vol
        write(output_unit,*) 'Erupted volume calculated as:',e_Volume
      endif
      e_Volume= FineAshFraction * e_Volume                    ! adjust for mass in the cloud
      Comp_Height  = 50.0_8*SimTime*3600.0_8/(109.0_8*1000.0_8)    ! estimate of # of deg. latitude a cloud can travel
      Comp_Height  = max(Comp_Height,1.5_8)
      Comp_Width   = aspect_ratio*Comp_Height/cos(3.14_8*v_lat/180.0_8)
      latLL   = v_lat - Comp_Height/2.0_8
      lonLL   = v_lon - Comp_Width/2.0_8
      latUR   = latLL + Comp_Height
      lonUR   = lonLL + Comp_Width
      dx      = Comp_Width/20.1_8
      dy      = Comp_Height/20.1_8
      dz      = e_Height/20.0_8
      if (((e_Height-(v_elevation/1000.0_8))/dz).lt.5.0_8) then       ! Added to ensure enough nodes for low plumes
        dz = (e_Height-(v_elevation/1000.0_8))/5.0_8
      endif

      if (SimTime.le.8.0_8) then                    ! Calculate time interval between write times
        WriteInterval = 0.5_8
      elseif (SimTime.le.12.0_8) then
        WriteInterval = 1.0_8
      elseif (SimTime.le.36.0_8) then
        WriteInterval = 2.0_8
      elseif (SimTime.le.72.0_8) then
        WriteInterval = 4.0_8
      else
        WriteInterval = 8.0_8
      endif
                                                 ! Calculate write times and nWriteTimes
      WriteTimes(1) = (WriteInterval+aint(e_Hour/WriteInterval)*WriteInterval)-e_Hour
      i=1
      do while (WriteTimes(i).lt.SimTime)
        WriteTimes(i+1) = WriteTimes(i)+WriteInterval
        i=i+1
      enddo
      nWriteTimes=i-1

      if ((latLL-dy).le.-89.5_8) then                ! Make sure the south model boundary doesn't cross the S. pole
        latLL       = -89.5_8 + dy
        Comp_Height = latUR - latLL
        dy          = Comp_Height/20.1_8
      endif
      if ((latUR+dy).ge.89.5_8) then                 ! Same for the north model boundary
        latUR       = 89.5_8-dy
        Comp_Height = latUR - latLL
        dy          = Comp_Height/20.1_8
      endif
      if (lonLL.lt.-180.0_8)     lonLL=lonLL+360.0_8
      if (Comp_Width.gt.360.0_8)then
        ! Just make the domain periodic
        Comp_Width = 360.0_8
        lonLL = 0.0_8
      endif

      write(output_unit,*) 'Eruption ESP for ash cloud:'
      write(output_unit,*) ' e_Duration = ',real(e_Duration,kind=4), &
                           ', e_Height= ',real(e_Height,kind=4),&
                           ', e_Volume = ',real(e_Volume,kind=4)
      write(output_unit,*) 'Model parameters:'
      write(output_unit,*) ' height   = ',real(Comp_Height,kind=4),', width  = ',real(Comp_Width,kind=4)
      write(output_unit,*) ' v_lon    = ',real(v_lon,kind=4),     ', v_lat  = ',real(v_lat,kind=4)
      write(output_unit,*) ' lonLL    = ',real(lonLL,kind=4),     ', latLL  = ',real(latLL,kind=4)
      write(output_unit,*) ' width    = ',real(Comp_Width,kind=4), ', height = ',real(Comp_Height,kind=4)
      write(output_unit,*) ' dx       = ',real(dx,kind=4),        ', dy     = ',real(dy,kind=4)
      write(output_unit,*) ' Simulation time (hrs) = ', real(SimTime,kind=4)
      write(output_unit,*) ' WriteInterval         = ',real(WriteInterval,kind=4)
      write(output_unit,*)
      write(output_unit,*) 'writing full control file for preliminary run: ', outfile

      open(unit=fid_ctrout_full,file=outfile,status='replace',action='write',err=2500)

      write(fid_ctrout_full,2010) ! write block 1 header, then content  (Grid specification)
      write(fid_ctrout_full,2011) volcano_name, &
                                  lonLL, latLL, &
                                  Comp_Width,Comp_Height, &
                                  v_lon, v_lat, v_elevation, &
                                  dx, dy, &
                                  dz
      write(fid_ctrout_full,2020) ! write block 2 header, then content  (Eruption specification)
      write(fid_ctrout_full,2021) e_iyear, e_imonth, e_iday, e_Hour, e_Duration, e_Height, e_Volume
      write(fid_ctrout_full,2030) ! write block 3 header, then content  (Wind options)
      write(fid_ctrout_full,2031) iwind, iWindformat, igrid, idf, &
                                  SimTime, &
                                  nWindfiles
      write(fid_ctrout_full,2040) ! write block 4 header, then content  (Output products)
      write(fid_ctrout_full,2041) nWriteTimes,&
                                  (WriteTimes(i), i=1,nWriteTimes)

      write(fid_ctrout_full,2050) ! write block 5 header, then content  (Windfile names)
      write(fid_ctrout_full,2051)
      if (iwindformat.eq.20)then
        do i=1,nWindfiles
          write(fid_ctrout_full,2052) WindFile, 3*(i-1)  ! Wind_nc/gfs/gfs.YYYYMMDDFF/YYYYMMDDFF.f[hhh].nc
        enddo
      elseif(iwindformat.eq.34)then
        do i=1,nWindfiles
          if(i.le.4 )then
            write(fid_ctrout_full,2053) WindFile, 3*(i-1)  ! Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
          elseif(i.le.34)then
            write(fid_ctrout_full,2054) WindFile, 3*(i-1)  ! Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
          else
            write(fid_ctrout_full,2055) WindFile, 3*(i-1)  ! Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
          endif
        enddo
      elseif(iwindformat.eq.25)then
        write(fid_ctrout_full,2056) Windfile             ! Wind_nc/NCEP
      endif

      write(fid_ctrout_full,2060) ! write block 6 header, then content  (Airport I/O options)
      write(fid_ctrout_full,2061)
      write(fid_ctrout_full,2070) ! write block 7 header, then content  (GSD specification)
      write(fid_ctrout_full,2071)
      write(fid_ctrout_full,2080) ! write block 8 header, then content  (Vertical Profiles)
      write(fid_ctrout_full,2081)
      write(fid_ctrout_full,2090) ! write block 9 header, then content  (NetCDF info)
      write(fid_ctrout_full,2091)
      write(fid_ctrout_full,2100) ! write block 10+ header, then content (Reset Params)
      write(fid_ctrout_full,2101)RunClass
      !write(fid_ctrout_full,2200) ! write block 10+ header, then content (Topography)
      !write(fid_ctrout_full,2201)

      close(fid_ctrout_full)

      write(output_unit,*) ' '
      write(output_unit,*) 'Successfully finished makeAsh3dinput1_ac'
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) ' '

      stop 0

      ! Output control file format statements
2010  format( &
      '# Input file generated by web application. ',/, &
      '# Webapp site: vsc-ash.wr.usgs.gov',/, &
      '# Webapp gen date time: ',/, &
      '# ',/, &
      '# The following is an input file to the model Ash3d, v1.0 https://code.usgs.gov/vsc/ash3d/volcano-ash3d',/, &
      '# Created by L.G. Mastin, R.P. Denlinger, and H.F. Schwaiger U.S. Geological Survey, 2009. ',/, &
      '# ',/, &
      '# GENERAL SOURCE PARAMETERS. DO NOT DELETE ANY NON-COMMENT LINES ',/, &
      '#  The first line of this block identifies the volcano by name.',/, &
      '#  If the volcano name begins with either 0 or 1, then the volcano',/, &
      '#  is assumed to be in the Smithsonian database and default values for',/, &
      '#  Plume Height, Duration, Mass Flux Rate, Volume, and mass fraction of',/, &
      '#  fines are loaded.  These can be over-written by entering non-negative',/, &
      '#  values in the appropriate locations in this input file.',/, &
      '# ',/, &
      '#  The second line of this block identifies the projection used and the form of',/, &
      '#  the input coordinates and is of the following format:',/, &
      '#    latlonflag, projflag,  followed by a variable list of projection parameters',/, &
      '#  projflag describes the projection used for the Ash3d run. Windfiles can have a',/, &
      '#  different projection.',/, &
      '#  For a particular projflag, additional values are read defining the projection.',/, &
      '#    latlonflag = 0 if computational grid is projected',/, &
      '#               = 1 if computational grid is lat/lon (all subsequent projection parameters ignored.)',/, &
      '#    projflag   = 1 -- polar stereographic projection',/, &
      '#           lambda0 -- longitude of projection point',/, &
      '#           phi0    -- latitude of projection point',/, &
      '#           k0      -- scale factor at projection point',/, &
      '#           radius  -- earth radius for spherical earth',/, &
      '#     e.g. for NAM 104,198, 216: 0 1 -105.0 90.0 0.933 6371.229',/, &
      '#               = 2 -- Albers Equal Area ( not yet implemented)',/, &
      '#               = 3 -- UTM ( not yet implemented)',/, &
      '#               = 4 -- Lambert conformal conic',/, &
      '#           lambda0 -- longitude of origin',/, &
      '#              phi0 -- latitude of origin',/, &
      '#              phi1 -- latitude of secant1',/, &
      '#              phi2 -- latitude of secant2',/, &
      '#            radius -- earth radius for a spherical earth',/, &
      '#     e.g. for NAM 212: 0 4 265.0 25.0 25.0 25.0 6371.22',/, &
      '#               = 5 -- Mercator',/, &
      '#           lambda0 -- longitude of origin',/, &
      '#              phi0 -- latitude of origin',/, &
      '#            radius -- earth radius for a spherical earth',/, &
      '#     e.g. for NAM 196: 0 5 198.475 20.0 6371.229',/, &
      '# ',/, &
      '# On line 3, the vent coordinates can optionally include a third value for elevation in km.',/, &
      '# If the vent elevation is not given, 0 is used if topography is turned off.',/, &
      '# ',/, &
      '# Line 4 is the width and height of the computational grid in km (if projected) or degrees.',/, &
      '# Line 5 is the vent x,y (or lon, lat) coordinates.',/, &
      '# Line 6, DX and DY resolution in km or degrees (for projected or lon/lat grid, respectively)',/, &
      '# Line 7, DZ can be given as a real number, indicating the vertical spacing in km.',/, &
      '# Alternatively, it can be given as dz_plin (piece-wise linear), dz_clog (constant-',/, &
      '# logarithmic), or dz_cust (custom specification)',/, &
      '# If dz_plin, then a second line is read containing:',/, &
      '#   number of line segments (N) followed by the steps and step-size of each segment',/, &
      '#   e.g. 4 6 0.25 5 0.5 5 1.0 10 2.0',/, &
      '#         This corresponds to 4 line segments with 6 cells of 0.25, then 5 cells of 0.5,',/, &
      '#         5 cells of 1.0, and finally 10 cells of 2.0',/, &
      '# If dz_clog, then a second line is read containing: ',/, &
      '#   maximum z and number of steps of constant dlogz',/, &
      '#   e.g. 30.0 30',/, &
      '#         This corresponds to 30 steps from 0-30km with constant log-spacing',/, &
      '# If dz_cust, then a second line is read containing:',/, &
      '#   the number of dz values to read (ndz), followed by dz(1:ndz)',/, &
      '#   e.g. 20 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 1.5 1.5 1.5 1.5 1.5 1.5 1.5 1.5 1.5 5.5',/, &
      '#         This corresponds to 10 steps of 0.5, 9 steps of 1.5, followed by 1 step of 5.5',/, &
      '#',/, &
      '#',/, &
      '# Line 8 is the the diffusivity (m2/s) followed by the eruption specifier.  The',/, &
      '# eruption specifier can be a real number, in which case it is assumed to be the',/, &
      '# positive constant specifying the Suzuki distribution.  Alternatively, it can be',/, &
      '#  umbrella     : Suzuki (const. = 12) with radial spreading of the plume',/, &
      '#  umbrella_air : Suzuki (const. = 12) with radial spreading of the plume scaled to 5% of vol.',/, &
      '#  point        : all mass inserted in cell containing PlmH',/, &
      '#  linear       : mass uniformly distributed from z-vent to PlmH',/, &
      '# Line 9 : number of pulses to be read in BLOCK 2 ')
2011  format( &
      '******************* BLOCK 1 ***************************************************  ',/, &
      a25,'       # Volcano name (character*30) (52.894N 170.054W)  ',/, &
      '1 1 -135.0 90.0 0.933 6371.229  # Proj flags and params  ',/, &
      2f13.3,                   '      # x, y of LL corner of grid (km, or deg. if latlongflag=1)  ',/, &
      2f13.3,                   '      # grid width and height (km, or deg. if latlonflag=1)  ',/, &
      3f10.3,                     '   # vent location         (km, or deg. if latlonflag=1)  ',/, &
      2f13.3,                   '      # DX, DY of grid cells  (km, or deg.)  ',/, &
      f8.3,   '                        # DZ of grid cells      (always km)  ',/, &
      '000.      4.                    # diffusion coefficient (m2/s), Suzuki constant  ',/, &
      '1                               # neruptions, number of eruptions or pulses')
2020  format( &
      '******************************************************************************* ',/, &
      '# ERUPTION LINES (number = neruptions) ',/, &
      '# In the following line, each line represents one eruptive pulse.   ',/, &
      '# Parameters are (1-4) start time (yyyy mm dd h.hh (UT)); (5) duration (hrs);',/, &
      '#                  (6) plume height;                      (7) erupted volume (km3 DRE)',/, &
      '# If neruptions=1 and the year is 0, then the model run in forecast mode where mm dd h.hh are',/, &
      '# interpreted as the time after the start of the windfile.  In this case, duration, plume',/, &
      '# height and erupted volume are replaced with ESP if the values are negative.',/, &
      '# This applies to source types: suzuki, point, line, umbrella and umbrella_air.',/, &
      '# For profile sources, an additional two values are read: dz and nz',/, &
      '# 2010 04 14   0.00   1.0     18.0  0.16 1.0 18',/, &
      '# 0.01 0.02 0.03 0.03 0.04 0.04 0.05 0.06 0.06 0.070 0.08 0.08 0.09 0.09 0.09 0.08 0.06 0.02')
2021  format( &
      '******************* BLOCK 2 *************************************************** ',/, &
      i4,3x,i2,3x,i2,3x,f10.2,2f10.1,e12.4)
2030  format( &
      '******************************************************************************* ',/, &
      '# WIND OPTIONS ',/, &
      '# Ash3d will read from either a single 1-D wind sounding, or gridded, time- ',/, &
      '# dependent 3-D wind data, depending on the value of the parameter iwind. ',/, &
      '# For iwind = 1, read from a 1-D wind sounding ',/, &
      '#             2, read from 3D gridded ASCII files',/, &
      '#             3/4, read directly from a single or multiple NetCDF files.',/, &
      '#             5, read directly from multiple multi-timestep NetCDF files.',/, &
      '# The parameter iwindformat specifies the format of the wind files, as follows:',/, &
      '#  iwindformat =  0: User-defined via template',/, &
      '#                 1: User-specified ASCII files',/, &
      '#                 2: Global radiosonde data',/, &
      '#                 3: NARR 221 Reanalysis (32 km)',/, &
      '#                 4: NAM Regional North America 221 Forecast (32 km)',/, &
      '#                 5: NAM 216 Regional Alaska Forecast (45 km)',/, &
      '#                 6: NAM 104 Northern Hemisphere Forecast (90 km)',/, &
      '#                 7: NAM 212 40km Cont. US Forecast (40 km)',/, &
      '#                 8: NAM 218 12km Cont. US Forecast (12 km)',/, &
      '#                 9: NAM 227 Cont. US Forecast (5.08 km)',/, &
      '#                10: NAM 242 11km Regional Alaska Forecast (11.25 km)',/, &
      '#                11: NAM 196 Regional Hawaii Forecast (2.5 km)',/, &
      '#                12: NAM 198 Regional Alaska Forecast (5.953 km)',/, &
      '#                13: NAM 91 Regional Alaska Forecast (2.976 km)',/, &
      '#                14: NAM Regional Cont. US Forecast (3.0 km)',/, &
      '#                20: GFS 0.5 degree files Forecast',/, &
      '#                21: GFS 1.0 degree files Forecast',/, &
      '#                22: GFS 0.25 degree files Forecast',/, &
      '#                23: NCEP DOE Reanalysis 2.5 degree',/, &
      '#                24: NASA MERRA-2 Reanalysis',/, &
      '#                25: NCEP1 2.5 global Reanalysis (1948-pres)',/, &
      '#                      Note: use nWindFiles=1 for iwindformat=25',/, &
      '#                26: JRA-55 Reanalysis',/, &
      '#                27: NOAA-CIRES II 2-deg global Reanalysis (1870-2010)',/, &
      '#                28: ECMWF ERA-Interim Reanalysis',/, &
      '#                29: ECMWA ERA-5 Reanalysis',/, &
      '#                30: ECMWA ERA-20C Reanalysis',/, &
      '#                32: Air Force Weather Agency',/, &
      '#                33: CCSM 3.0 Community Atmospheric Model',/, &
      '#                34: ECMWF 0.25-degree forecast',/, &
      '#                40: NASA GEOS-5 Cp',/, &
      '#                41: NASA GEOS-5 Np',/, &
      '#                50: Weather Research and Forecast (WRF) output',/, &
      '# ',/, &
      '# igrid (optional, defaults to that associated with iwindformat) is the NCEP grid ID,',/, &
      '# if a NWP product is used, or the number of stations of sonde data, if iwind = 1.',/, &
      '# idata (optional, defaults to 2) is a flag for data type (1=ASCII, 2=netcdf, 3=grib).',/, &
      '# ',/, &
      '# Many plumes extend higher than the maximum height of mesoscale models.',/, &
      '# Ash3d handles this as determined by the parameter iHeightHandler, as follows:',/, &
      '# for iHeightHandler = 1, stop the program if the plume height exceeds mesoscale height',/, &
      '#                      2, wind velocity at levels above the highest node',/, &
      '#                         equal that of the highest node.  Temperatures in the',/, &
      '#                         upper nodes do not change between 11 and 20 km; above',/, &
      '#                         20 km they increase by 2 C/km, as in the Standard',/, &
      '#                         atmosphere.  A warning is written to the log file.',/, &
      '# Simulation time in hours is the maximal length of the simulation.',/, &
      '# Ash3d can end the simulation early if desired, once 99% of the ash has deposited.',/, &
      '# The last line of this block is the number of windfiles listed in block 5 below.  If',/, &
      '# iwind=5 and one of the NWP products is used that require a special file structure,',/, &
      '# then nWindFiles should be set to 1 and only the root folder of the windfiles listed.')
2031  format( &
      '******************* BLOCK 3 *************************************************** ',/, &
       i2,3x,i2,3x,i3,3x,i1,'       #iwind, iwindFormat  ',/, &
      '2                   #iHeightHandler  ',/, &
      f7.1,  '             #Simulation time in hours  ',/, &
      'no                  #stop computation when 99% of erupted mass has deposited?  ',/, &
       i2,'              #nWindFiles, number of gridded wind files (used if iwind>1)  ')
2040  format( &
      '******************************************************************************* ',/, &
      '# OUTPUT OPTIONS:',/, &
      '# The list below allows users to specify the output options',/, &
      '# All but the final deposit file can be written out at specified',/, &
      '# times using the following parameters:',/, &
      '# Line 15 asks for 3d output (yes/no) followed by an optional output format code;',/, &
      '#   1 = (default) output all the normal 2d products to the output file as well as the 3d concentrations',/, &
      '#   2 = only output the 2d products',/, &
      '# nWriteTimes   = if >0,  number of times output are to be written. The following',/, &
      '#                  line contains nWriteTimes numbers specifying the times of output',/, &
      '#                 if =-1, it specifies that the following line gives a constant time',/, &
      '#                  interval in hours between write times.',/, &
      '# WriteTimes    = Hours between output (if nWritetimes=-1), or',/, &
      '#                 Times (hours since start of first eruption) for each output',/, &
      '#                (if nWriteTimes >1) ')
2041  format( &
      '******************* BLOCK 4 *************************************************** ',/, &
      'no      # Write out ESRI ASCII file of final deposit thickness?                    ',/, &
      'no      # Write out        KML file of final deposit thickness?                   ',/, &
      'no      # Write out ESRI ASCII deposit files at specified times?                  ',/, &
      'no      # Write out        KML deposit files at specified times?                  ',/, &
      'no      # Write out ESRI ASCII files of ash-cloud concentration?                  ',/, &
      'no      # Write out        KML files of ash-cloud concentration ?                 ',/, &
      'yes     # Write out ESRI ASCII files of ash-cloud height?                        ',/, &
      'yes     # Write out        KML files of ash-cloud height?                        ',/, &
      'yes     # Write out ESRI ASCII files of ash-cloud load (T/km2) at specified times?  ',/, &
      'yes     # Write out        KML files of ash-cloud load (T/km2) at specified times?  ',/, &
      'no      # Write out ESRI ASCII file of deposit arrival times?  ',/, &
      'no      # Write out        KML file of deposit arrival times?  ',/, &
      'no      # Write out ESRI ASCII file of cloud arrival times?  ',/, &
      'yes     # Write out        KML file of cloud arrival times?  ',/, &
      'yes     # Write out 3-D ash concentration at specified times? / [output code: 1=2d+concen,2=2d only]',/, &
      'netcdf  #format of ash concentration files   ("ascii", "binary", or "netcdf")  ',/, &
      i2,'      #n WriteTimes  ',/, &
      24f7.2)
2050  format( &
      '******************************************************************************* ',/, &
      '# WIND INPUT FILES ',/, &
      '# The following block of data contains names of wind files. There should be one line for',/, &
      '# each of nWindFiles (from Block 3 Line 5) windfiles. Files should be given in',/, &
      '# chronological order, should have names with only letters and numbers (no spaces)',/, &
      '# and should not exceed 130 characters in length.',/, &
      '# For iwind=5 (files with hard-coded paths), just provide the directory with the',/, &
      '# windfiles or the root of the dataset (if files are sorted by year).',/, &
      '# For example, iwind=5, iwindformat=25 for NCEP reanalysis, data might look like:',/, &
      '# /data/WindFiles/NCEP',/, &
      '# |-- 2016',/, &
      '# |   |-- air.2016.nc',/, &
      '# |   |-- hgt.2016.nc',/, &
      '# |   |-- omega.2016.nc',/, &
      '# |   |-- uwnd.2016.nc',/, &
      '# |   `-- vwnd.2016.nc',/, &
      '# |-- 2017',/, &
      '#     |-- air.2017.nc',/, &
      '# In this case, Block 5 will just contain one line: /data/WindFiles/NCEP or just NCEP',/, &
      '# if you have a soft link in the run directory.',/, &
      '# For a network of radiosonde data, please see the MetReader documentation for',/, &
      '# the input specification https://code.usgs.gov/vsc/ash3d/volcano-ash3d-metreader.')
2051  format( &
      '******************* BLOCK 5 ***************************************************')
!2052  format(a27,i3.3,'.nc')                          ! for forecast winds       Wind_nc/gfs/latest/latest.f**.nc
2052  format(a39,i3.3,'.nc')                          ! for archived gfs winds     Wind_nc/gfs/gfs.YYYYMMDDHH/YYYYMMDDHH.f**.nc
2053  format(a46,i1.1,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
2054  format(a46,i2.2,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
2055  format(a46,i3.3,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2

2056  format(a12)                                     ! for NCEP reanalyis winds Wind_nc/NCEP
2060  format( &
      '*******************************************************************************',/, & 
      '# AIRPORT LOCATION FILE ',/, &
      '# The following lines allow the user to specify whether times of ash arrival ',/, &
      '# at airports & other locations will be written out, and which file  ',/, &
      '# to read for a list of airport locations. ',/, &
      '# PLEASE NOTE:  Each line in the airport location file should contain the ',/, &
      '#               airport latitude, longitude, projected x and y coordinates,  ',/, &
      '#               and airport name.  If you are using a projected grid,  ',/, &
      '#               THE X AND Y MUST BE IN THE SAME PROJECTION as the computational grid.',/, & 
      '#               Alternatively, coordinates can be projected via libprojection  ',/, &
      '#               by typing "yes" to the last parameter ')
2061  format( &
      '******************* BLOCK 6 *************************************************** ',/, &
      'yes                           # Write out ash arrival times at airports to ASCII FILE? ',/, & 
      'no                            # Write out grain-size distribution to ASCII airport file?  ',/, &
      'yes                           # Write out ash arrival times to kml file?  ',/, &
      '                              # Name of file containing aiport locations  ',/, &
      'no                            # Defer to Lon/Lat coordinates? ("no" defers to projected)  ')
2070  format( &
      '******************************************************************************* ',/, &
      '# GRAIN SIZE GROUPS',/, &
      '# The first line must contain the number of settling velocity groups, but',/, &
      '# can optionally also include a flag for the fall velocity model to be used.',/, &
      '#    FV_ID = 1, Wilson and Huang',/, &
      '#          = 2, Wilson and Huang + Cunningham slip',/, &
      '#          = 3, Wilson and Huang + Mod by Pfeiffer Et al.',/, &
      '#          = 4, Ganser (assuming prolate ellipsoids)',/, &
      '#          = 5, Ganser + Cunningham slip',/, &
      '#          = 6, Stokes flow for spherical particles + slip',/, &
      '# If no fall model is specified, FV_ID = 1, by default',/, &
      '# The grain size bins can be enters with 2, 3, or 4 parameters.',/, &
      '# If TWO are given, they are read as:   FallVel (in m/s), mass fraction',/, &
      '# If THREE are given, they are read as: diameter (mm), mass fraction, density (kg/m3)',/, &
      '# If FOUR are given, they are read as:  diameter (mm), mass fraction, density (kg/m3), Shape F',/, &
      '# The shape factor is given as in Wilson and Huang: F=(b+c)/(2*a), but converted',/, &
      '# to sphericity (assuming b=c) for the Ganser model.',/, &
      '# If a shape factor is not given, a default value of F=0.4 is used.',/, &
      '# If FIVE are given, they are read as:  diameter (mm), mass fraction, density (kg/m3), Shape F, G',/, &
      '#  where G is an additional Ganser shape factor equal to c/b',/, &
      '#  ',/, &
      '# If the last grain size bin has a negative diameter, then the remaining mass fraction',/, &
      '# will be distributed over the previous bins via a log-normal distribution in phi.',/, &
      '# The last bin would be interpreted as:',/, &
      '# diam (neg value) , phi_mean, phi_stddev ')
2071  format( &
      '******************* BLOCK 7 *************************************************** ',/, &
      '1                            #Number of settling velocity groups',/, &
      '0.0100 1.00 2000.')
2080  format( &
      '******************************************************************************* ',/, &
      '# Options for writing vertical profiles ',/, &
      '# The first line below gives the number of locations (nlocs) where vertical ',/, &
      '# profiles are to be written.  That is followed by nlocs lines, each of which ',/, &
      '# contain the location, in the same coordinates as the computational grid.',/, &
      '# Optionally, a site name can be provided in after the location. ',/, &
      '******************* BLOCK 8 *************************************************** ')
2081  format( &
      '0                             #number of locations for vertical profiles (nlocs)  ')
2090  format( &
      '******************************************************************************* ',/, &
      '# netCDF output options ',/, &
      '# This last block is optional.',/, &
      '# The output file name can be give, but will default to 3d_tephra_fall.nc if absent',/, &
      '# The title and comment lines are passed through to the netcdf header of the',/, &
      '# output file. ')
2091  format( &
      '******************* BLOCK 9 *************************************************** ',/, &
      '3d_tephra_fall.nc             # Name of output file  ',/, &
      'Ash3d_web_run_ac              # Title of simulation  ',/, &
      'no comment                    # Comment  ')
2100  format( &
      '******************************************************************************* ',/, &
      '# Reset parameters',/, &
      '******************************************************************************* ')
2101  format( &
      'OPTMOD=RESETPARAMS',/, &
      'cdf_run_class        = ',i3)
!2200  format( &
!      '*******************************************************************************',/, &
!      '# Topography',/, &
!      '# Line 1 indicates whether or not to use topography followed by the integer flag',/, &
!      '#        describing how topography will modify the vertical grid.',/, &
!      '#          0 = no vertical modification; z-grid remains 0-> top throughout the domain',/, &
!      '#          1 = shifted; s = z-z_surf; computational grid is uniformly shifted upward',/, &
!      '#              everywhere by topography',/, &
!      '#          2 = sigma-altitude; s=z_top(z-z_surf)/(z_top-z_surf); topography has decaying',/, &
!      '#              influence with height',/, &
!      '# Line 2 indicates the topography data format followed by the smoothing radius in km',/, &
!      '# Topofile format must be one of',/, &
!      '#   1 : Gridded lon/lat (netcdf): ETOPO, GEBCO',/, &
!      '#   2 : Gridded Binary: NOAA GLOBE, GTOPO30',/, &
!      '#   3 : ESRI ASCII',/, &
!      '#  Line 3 is the file name of the topography data. ',/, &
!      '#')
!2201  format( &
!      '******************* BLOCK 10+ *************************************************',/, &
!      'OPTMOD=TOPO',/, &
!      'no  0                           # use topography?; z-mod (0=none,1=shift,2=sigma)',/, &
!      '1 20.0                          # Topofile format, smoothing radius',/, &
!      'GEBCO_2023.nc                   # topofile name',/, &
!      '*******************************************************************************')

!     Error traps
2500  write(error_unit,*) 'Error opening full control file for writing. Program stopped'
      stop 1

      end program makeAsh3dinput1_ac

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
