      program makeAsh3dinput1_ac

!      --This file is a component of the USGS program Ash3d for volcanic ash transport
!          and dispersion.

!      --Use of this program is described in:

!        Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., in press, Ash3d, a finite-
!           volume, conservative numerical model for ash transport and tephra deposition,
!           Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968

!      --Written in Fortran 90

!      --The program has been successsfully tested and run on the Linux Operating System using
!          Red Hat and Ubuntu 10 and 11.

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

      implicit none
      real(kind=8)     :: aspect_ratio, dx, dy, dz, e_volume, FineAshFraction
      real(kind=8)     :: lonLL, latLL, lonUR, latUR 
      real(kind=8)     :: Duration, Height, HourNow, Hours1900Erupt, Hours1900Now
      real(kind=8)     :: Hours1900Wind
      real(kind=8)     :: hours_since_1900, min_duration, min_vol, pHeight
      real(kind=8)     :: SimTime, StartTime
      real(kind=8)     :: v_lon, v_lat, v_elevation, width
      real(kind=8)     :: windhour, WriteInterval, WriteTimes(20)
      integer          :: i,iargc,iday,imonth,imonthdays(12),iyear,iwind,iwindformat
      integer          :: nargs,nWindFiles
      integer          :: nWriteTimes,windyear,windmonth,windday
      !character(len=1) :: answer
      character(len=80) :: linebuffer, infile, outfile
      character(len=30) :: volcano_name
      character(len=80) :: Windfile !, inputline
      character(len=10) :: time2            !time argument used to get current date and time
      character(len=10) :: last_downloaded  !date and time of last downloaded wind file
      character(len=3)  :: runtype          !'now', 'rec', or 'old'
      character(len=5)  :: timezone
      character(len=8)  :: date
      integer           :: values(8),iyearnow,imonthnow,idaynow,ihournow,iminutesnow  !time values
      integer           :: timediff   !time difference (local-UTC, minutes)
      logical           :: VolumeInput                        !boolean set to true if volume is specified

      data imonthdays/31,29,31,30,31,30,31,31,30,31,30,31/

      write(6,*) 'starting makeAsh3dinput1_ac'

!     set constants
      aspect_ratio    = 1.5                                    !map aspect ratio (km/km)
      FineAshFraction = 0.05                                   !mass fraction fine ash
      VolumeInput     = .false.                                !=.true. if volume is specified

!     set default values
      iwind=4
      iwindformat=20
      nWindFiles=34
      runtype='now'
      min_vol = 0.0001                                         !minimum erupted volume (km3 DRE)
      min_duration = 0.1                                       !minimum eruption duration (hrs)

!     get current date & time
      timezone = "+0000"
      call date_and_time(date,time2,timezone,values)  !get current date & time
      iyearnow=values(1)
      imonthnow=values(2)
      idaynow=values(3)
      timediff=values(4)
      ihournow=values(5)
      HourNow = ihournow - float(timediff)/60.
      iminutesnow=values(6)
      Hours1900Now = hours_since_1900(iyearnow,imonthnow,idaynow,HourNow)
      write(6,1001) iyearnow,imonthnow,idaynow,ihournow,iminutesnow
1001  format('current date: ',i4,'.',i2.2,'.',i2,' ',i2,':',i2.2,' local time')

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = iargc()
      if (nargs.ne.3) then
           write(6,*) 'Error. Three input arguments required'
           write(6,*) 'an input file, an output file, and the date &'
           write(6,*) 'time of the last downloaded wind file.'
           write(6,*) 'You have specified ',nargs, ' input arguments.'
           write(6,*) 'program stopped'
           stop 1
      end if
      call getarg(1,infile)
      call getarg(2,outfile)
      call getarg(3,last_downloaded)
      read(last_downloaded,1041) windyear, windmonth, windday, windhour
1041  format(i4,i2,i2,f2.0)
      write(6,*) 'infile=', infile
      write(6,*) 'outfile=',outfile
      write(6,*) 'last downloaded wind file = ',last_downloaded
      open(unit=10,file=infile)         !simplified input file
      read(10,'(a30)') volcano_name
      read(10,*) v_lon, v_lat
      read(10,*) v_elevation
      read(10,'(a80)') linebuffer
          !see if we can read four variables
          read(linebuffer,*,err=100) pHeight, Duration, SimTime, e_volume
          VolumeInput = .true.          !if so, then VolumeInput=.true.
          write(6,*) 'VolumeInput=.true.'
          if ((e_volume.lt.1.e-05).or.(e_volume.gt.100.)) then
             write(6,*) 'Error: Specified eruptive volume must be between 0.00001 and 100 km3.'
             write(6,*) 'You entered ',e_volume, '.  Program stopped'
             stop 1
          end if
          go to 120
100       read(linebuffer,*) pHeight, Duration, SimTime !if not, then VolumeInput remains .false.
120   read(10,*) iyear, imonth, iday, StartTime

      if ((StartTime.lt.0.).or.((iyear.ne.0).and.(StartTime.gt.24.))) then
         write(6,*) 'Error: Start hour must be between zero and 24.  You entered ',StartTime
         stop 1
      end if

      if (iyear.ne.0) then

         !trap errors in start time
         if ((iyear.lt.1948).or.(iyear.gt.iyearnow)) then
               write(6,*) 'Error:  Eruption start year must be zero or a year between'
               write(6,*) '1948 and the present.  You entered:',iyear
               write(6,*) 'Program stopped'
               stop 1
         end if
         if ((imonth.lt.0).or.(imonth.gt.12)) then
               write(6,*) 'Error:  Eruption start month must be between 0 and 12.'
               write(6,*) 'You entered:',imonth
               write(6,*) 'Program stopped'
               stop 1
         end if
         if ((iday.lt.0).or.(iday.gt.imonthdays(imonth))) then
               write(6,*) 'Error: Eruption start day must be less than the number of days'
               write(6,*) 'in that month.  The month you entered is:',imonth
               write(6,*) 'the day in that month you entered is:',iday
               write(6,*) 'Program stopped'
         end if
         if (SimTime.lt.3.0) then
               write(6,2413) SimTime
2413           format('Error: you gave a simulation time of ',f6.2,' hours.',/, &
                      'Simulation time must be =>3 hrs.  Program stopped')
               stop 1
         end if
 
         !calculate eruption time before present
         Hours1900Erupt = hours_since_1900(iyear,imonth,iday,StartTime)
         Hours1900Wind  = hours_since_1900(windyear,windmonth,windday,windhour)
         if ((Hours1900Erupt+SimTime).gt.(Hours1900Wind+99.)) then             !if the time is in the future
              write(6,*) 'Error.  You entered an eruption start time'
              write(6,*) 'that extends beyond the last currently available'
              write(6,*) 'wind file.  the last currently available wind file'
              write(6,*) 'extends to 99 hours beyond ',last_downloaded
              write(6,*) 'Please adjust your start time or'
              write(6,*) 'simulation time.'
              stop 1
           else if (Hours1900Erupt.gt.Hours1900Wind) then      !if the start time is within the last wind file
              runtype = 'now'
              write(6,*) 'Using latest wind files'
              write(WindFile,1040)
1040          format('Wind_nc/gfs/latest/latest.f')
              WindFile = trim(WindFile)
           else if ((Hours1900Now-Hours1900Erupt).lt.(24*14)) then !if it's in the last two weeks
              runtype='rec'
              write(6,*) 'Using archived gfs wind files'
              if (StartTime.lt.12.0) then                          !before 1200 UTC
                  write(WindFile,1002) iyear, imonth, iday, iyear, imonth, iday
1002              format('Wind_nc/gfs/gfs.',i4,i2.2,i2.2,'00','/',i4,i2.2,i2.2,'00.f')
                else                                               !after 1200 UTC
                  write(WindFile,1003) iyear, imonth, iday, iyear, imonth, iday
1003              format('Wind_nc/gfs/gfs.',i4,i2.2,i2.2,'12','/',i4,i2.2,i2.2,'12.f')
              end if
           else if (iyear.ge.1948) then                            !If we're using NCEP reanalysis
              runtype='old'
              write(6,*) 'Using NCEP reanalysis wind files'
              iwind=5
              iWindFormat=25
              nWindFiles=1
              write(WindFile,1004)
1004          format('Wind_nc/NCEP')
           else if (iyear.lt.1948) then                            !if before 1948 (error)
              write(6,*) 'Error.  You entered a year earlier than 1948.'
              write(6,*) 'Wind files do not exist for this earlier time period.'
              stop 1
           else
              write(6,*) 'Unknown error in identifying appropriate wind files.'
              stop 1
         end if
        else                     !If this is a normal forecast run
         write(6,*) 'Using current windfiles'
         write(Windfile,1005)
1005     format('Wind_nc/gfs/latest/latest.f')
      end if

      !make sure plume height is greater than volcano elevation
      if (pHeight.lt.(v_elevation/1000.)) then
           write (6,*) 'error: plume height is lower than volcano summit elevation'
           write(6,*) 'program stopped'
           stop 1
      end if

      !make sure minimum eruption duration exceeds 0.05 hrs
      if (Duration.lt.min_duration) then
           write(6,*) 'error: eruption duration=',Duration
           write(6,*) 'eruption duration must exceed ',min_duration
           write(6,*) 'Program stopped'
           stop 1
      end if

      !calculate eruptive volume, model domain, resolution
      if (VolumeInput.eqv..false.) then             !erupted volume (km3)
         e_volume=((pHeight-v_elevation/1000.)/2.)** (1./0.241)*3600.*Duration/1.0e09
         if (e_volume.lt.min_vol) e_volume = min_vol
      end if
      write(6,*) 'e_volume=',e_volume
      e_volume= FineAshFraction * e_volume         !adjust for mass in the cloud
      height  = 50.*SimTime*3600./(109.*1000.)     !estimate of # of deg. latitude a cloud can travel
      height  = max(1.50,height)
      width   = aspect_ratio*height/cos(3.14*v_lat/180.)
      latLL   = v_lat-height/2.
      lonLL   = v_lon-width/2.
      latUR   = latLL+height
      lonUR   = lonLL+width
      dx      = width/20.1
      dy      = height/20.1
      dz      = pHeight/20.
      if (((pHeight-(v_elevation/1000.))/dz).lt.5.0) then       !Added to ensure enough nodes for low plumes
            dz = (pHeight-(v_elevation/1000.))/5.0
      end if
      !write(6,*) 'plume height=',pHeight,', vent elevation=',v_elevation
      !write(6,*) 'dz=',dz
      !stop

      if (SimTime.le.8.) then                    !calculate time interval between write times
         WriteInterval = 0.5
       else if (SimTime.le.16.) then
         WriteInterval = 1.0
       else if (SimTime.le.48.) then
         WriteInterval = 3.0
       else
         WriteInterval = 6.0
      end if
                                                 !calculate write times and nWriteTimes
      WriteTimes(1) = (WriteInterval+aint(StartTime/WriteInterval)*WriteInterval)-StartTime
      i=1
      do while (WriteTimes(i).lt.SimTime)
         WriteTimes(i+1) = WriteTimes(i)+WriteInterval
         i=i+1
      enddo
      nWriteTimes=i-1

      if ((latLL-dy).le.-89.5) then                !Make sure the south model boundary doesn't cross the S. pole
          latLL  = -89.5+dy
          height = latUR-latLL
          dy     = height/20.1
      end if
      if ((latUR+dy).ge.89.5) then                 !Same for the north model boundary
          latUR  = 89.5-dy
          height = latUR - latLL
          dy     = height/20.1
      end if
      if (lonLL.lt.-180.)     lonLL=lonLL+360.
      if (width.gt.360.)      width=355.

      write(6,*) 'Duration=', Duration, ', pHeight=', pHeight
      write(6,*) 'Simulation time (hrs)=', SimTime
      write(6,*) 'e_volume=',e_volume
      write(6,*) 'height=',height, ', width=',width
      write(6,*) 'v_lon=',v_lon, ', v_lat=',v_lat
      write(6,*) 'lonLL=', lonLL, ', latLL=', latLL
      write(6,*) 'width=', width, 'height=', height
      write(6,*) 'dx=', dx, ', dy=', dy
      write(6,*) 'WriteInterval=',WriteInterval
      write(6,*)
      write(6,*) 'writing ', outfile

      open(unit=11,file=outfile)
      write(11,1)  volcano_name, lonLL, latLL, width, height, v_lon, v_lat, v_elevation, &
                   dx, dy, dz, &
                   iyear, imonth, iday, StartTime, Duration, pHeight, e_volume, &
                   iwind, iWindformat, &
                   SimTime, &
                   nWindfiles, &
                   nWriteTimes, &
                   (WriteTimes(i), i=1,nWriteTimes)
      write(11,6)
      if (runtype.eq.'now') then
          do i=1,nWindfiles
            write(11,2) WindFile, 3*(i-1)
          end do
        else if (runtype.eq.'rec') then
          do i=1,nWindfiles
            write(11,3) WindFile, 3*(i-1)
          end do
        else
          write(11,4) Windfile
      end if
      write(11,5)
      close(11)
      write(6,*) 'all done'
      
1     format( &
      '# Input file generated by web application. ',/, &
      '# Webapp site: vsc-ash.wr.usgs.gov',/, &
      '# Webapp gen date time: 2012/03/05 09:56:29',/, &
      '# ',/, &
      '#The following is an input file to the model Ash3d, v.1.0 ',/, &
      '#Created by L.G. Mastin and R. P. Denlinger, U.S. Geological Survey, 2009. ',/, &
      '# ',/, &
      '#GENERAL SOURCE PARAMETERS. DO NOT DELETE ANY LINES ',/, &
      '#  The first line of this block identifies the projection used and the form of ',/, &
      '#  the input coordinates and is of the following format: ',/, &
      '#    latlonflag projflag (variable list of projection parameters) ',/, &
      '#  projflag should describe the projection used for both the windfile(s) and ',/, &
      '#  the input coordinates.  Currently, these need to be the same projection. ',/, &
      '#  For a particular projflag, additional values are read defining the projection. ',/, &
      '#    latlonflag = 0 if the input coordinates are already projected ',/, &
      '#               = 1 if the input coordinates are in lat/lon ',/, &
      '#    projflag   = 1 -- polar stereographic projection ',/, &
      '#           lambda0 -- longitude of projection point ',/, &
      '#           phi0    -- latitude of projection point ',/, &
      '#           k0      -- scale factor at projection point ',/, &
      '#           radius  -- earth radius for spherical earth ',/, &
      '#               = 2 -- Alberts Equal Area ',/, &
      '#           lambda0 --  ',/, &
      '#           phi0    --  ',/, &
      '#           phi1    --  ',/, &
      '#           phi2    --  ',/, &
      '#               = 3 -- UTM ',/, &
      '#           zone    -- zone number ',/, &
      '#           north   -- flag indication norther (1) or southern (0) hemisphere ',/, &
      '#               = 4 -- Lambert conformal conic ',/, &
      '#           lambda0 -- longitude of origin ',/, &
      '#              phi0 -- latitude of origin ',/, &
      '#              phi1 -- latitude of secant1 ',/, &
      '#              phi2 -- latitude of secant2 ',/, &
      '#            radius -- earth radius for a spherical earth ',/, &
      '******************* BLOCK 1 ***************************************************  ',/, &
      a30,'  #Volcano name (character*30) (52.894N 170.054W)  ',/, &
      '1 1 -135.0 90.0 0.933 6371.229  #Proj flags and params  ',/, &
      2f13.3,                   '      #x, y of LL corner of grid (km, or deg. if latlongflag=1)  ',/, &
      2f13.3,                   '      #grid width and height (km, or deg. if latlonflag=1)  ',/, &
      3f10.3,                      '   #vent location         (km, or deg. if latlonflag=1)  ',/, &
      2f13.3,                   '      #DX, DY of grid cells  (km, or deg.)  ',/, &
      f8.3,   '                        #DZ of grid cells      (always km)  ',/, &
      '000.      4.                    #diffusion coefficient (m2/s), Suzuki constant  ',/, &
      '1                               #neruptions, number of eruptions or pulses  ',/, &
      '******************************************************************************* ',/, &
      '#ERUPTION LINES (number = neruptions) ',/, &
      '#In the following line, each line represents one eruptive pulse.   ',/, &
      '#Parameters are (1) start time (yyyy mm dd h.hh (UT)); (2) duration (hrs);  ',/, &
      '#               (3) plume height (km);                 (4) eruped volume (km3) ',/, &
      '#If the year is 0, then the model run in forecast mode where mm dd h.hh are ',/, &
      '#interpreted as the time after the start of the windfile.  In this case, duration, plume ',/, &
      '#height and erupted volume are replaced with ESP if the values are negative. ',/, &
      '******************* BLOCK 2 *************************************************** ',/, &
      i4,3x,i2,3x,i2,3x,f10.2,2f10.1,e12.4,/, &
      '******************************************************************************* ',/, &
      '#WIND OPTIONS ',/, &
      '#Ash3d will read from either a single 1-D wind sounding, or gridded, time- ',/, &
      '#dependent 3-D wind data, depending on the value of the parameter iwind. ',/, &
      '#For iwind = 1, read from a 1-D wind sounding ',/, &
      '#            2, read from 3D gridded ASCII files generated by the Java script ',/, &
      '#               ReadNAM216forAsh3d or analogous. ',/, &
      '#            3, read directly from a single NetCDF file. ',/, &
      '#            4, read directly from multiple NetCDF files. ',/, &
      '#The parameter iwindFormat specifies the format of the wind files, as follows: ',/, &
      '# iwindFormat =  1: ASCII files (this is redundant with iwind=2 ',/, &
      '#                2: NAM_216pw 45km files (provided by Peter Webley) ',/, &
      '#                3: NARR_221 32km (see http://dss.ucar.edu/pub/narr) ',/, &
      '#                4:   unassigned ',/, &
      '#                5: NAM_216 files from idd.unidata.ucar.edu ',/, &
      '#                6: AWIPS_105 90km from idd.unidata.ucar.edu ',/, &
      '#                7: CONUS_212 40km from idd.unidata.ucar.edu ',/, &
      '#                8: NAM_218 12km ',/, &
      '#                9:   unassigned ',/, &
      '#               10: NAM_242 11km http://motherlode.ucar.edu/ ',/, &
      '#               20: NCEP GFS 0.5 degree files (http://www.nco.ncep.noaa.gov/pmb/products/gfs/) ',/, &
      '#               21: ECMWF 0.25deg for Hekla intermodel comparison ',/, &
      '#               22: NCEP GFS 2.5 degree files ',/, &
      '#               23: NCEP DOE Reanalysis 2.5 degree files (http://dss.ucar.edu/pub/reanalysis2) ',/, &
      '#Many plumes extend  higher than the maximum height of mesoscale models. ',/, &
      '#Ash3d handles this as determined by the parameter iHeightHandler, as follows: ',/, &
      '#for iHeightHandler = 1, stop the program if the plume height exceeds mesoscale height ',/, &
      '#                     2, wind velocity at levels above the highest node  ',/, &
      '#                        equal that of the highest node.  Temperatures in the ',/, &
      '#                        upper nodes dont change between 11 and 20 km; above ',/, &
      '#                        20 km they increase by 2 C/km, as in the Standard ',/, &
      '#                        atmosphere.  A warning is written to the log file. ',/, &
      '#Checking divergence:  Some wind modeled wind fields are not very good at  ',/, &
      '#                      conserving mass, meaning that the divergence of velocity ',/, &
      '#                      in each cell is not close to zero.  The model can check ',/, &
      '#                      the divergence of the wind field if desired. ',/, &
      '******************* BLOCK 3 *************************************************** ',/, &
       i2,3x,i2,'       #iwind, iwindFormat  ',/, &
      '2                   #iHeightHandler  ',/, &
      f7.1,  '             #Simulation time in hours  ',/, &
      'no                  #stop computation when 99% of erupted mass has deposited?  ',/, &
       i2,'              #nWindFiles, number of gridded wind files (used if iwind>1)  ',/, &
      '******************************************************************************* ',/, &
      '#OUTPUT OPTIONS: ',/, &
      '#The list below allows users to specify the output options ',/, &
      '#All but the final deposit file can be written out at specified ',/, &
      '#times using the following parameters: ',/, &
      '#nWriteTimes   = if >0,  number of times output are to be written. The following ',/, &
      '# line contains nWriteTimes numbers specifying the times of output ',/, &
      '#                if =-1, it specifies that the following line gives a constant time ',/, &
      '# interval in hours between write times. ',/, &
      '#WriteTimes    = Hours between output (if nWritetimes=-1), or ',/, &
      '#                Times (hours since start of first eruption) for each output  ',/, &
      '#     (if nWriteTimes >1) ',/, &
      '******************* BLOCK 4 *************************************************** ',/, &
      'no      #Write out ESRI ASCII file of final deposit thickness?                    ',/, &
      'no      #Write out        KML file of final deposit thickness?                   ',/, &
      'no      #Write out ESRI ASCII deposit files at specified times?                  ',/, &
      'no      #Write out        KML deposit files at specified times?                  ',/, &
      'no      #Write out ESRI ASCII files of ash-cloud concentration?                  ',/, &
      'no      #Write out        KML files of ash-cloud concentration ?                 ',/, &
      'no      #Write out ESRI ASCII files of ash-cloud height?                        ',/, &
      'no      #Write out        KML files of ash-cloud height?                        ',/, &
      'yes     #Write out      ASCII files of ash-cloud load (T/km2) at specified times?  ',/, &
      'yes     #Write out        KML files of ash-cloud load (T/km2) at specified times?  ',/, &
      'no      #Write ASCII file of deposit arrival times?  ',/, &
      'no      #Write KML file of deposit arrival times?  ',/, &
      'no      #write ASCII file of cloud arrival times?  ',/, &
      'no      #Write KML file of cloud arrival times?  ',/, &
      'yes     #Write out 3-D ash concentration at specified times?                       ',/, &
      'netcdf  #format of ash concentration files   ("ascii", "binary", or "netcdf")  ',/, &
      i2,'      #nWriteTimes  ',/, &
      18f6.2)
6     format( &
      '******************************************************************************* ',/, &
      '#WIND INPUT FILES ',/, &
      '#The following block of data contains names of wind files. ',/, &
      '#If we are reading from a 1-D wind sounding (i.e. iwind=1) then there should ',/, &
      '#be only one wind file.   ',/, &
      '# If we are reading gridded data there should be iWinNum wind files, each having ',/, &
      '# the format volcano_name_yyyymmddhh_FHhh.win ',/, &
      '******************* BLOCK 5 ***************************************************')
2     format(a27,i2.2,'.nc')                          !for forecast winds       Wind_nc/gfs/latest/latest.f**.nc
3     format(a39,i2.2,'.nc')                          !for archived gfs winds   Wind_nc/gfs/gfs.2012052300/2012052300.f**.nc
4     format(a12)                                      !for NCEP reanalyis winds Wind_nc/NCEP
5     format( &
      '*******************************************************************************',/, & 
      '#AIRPORT LOCATION FILE ',/, &
      '#The following lines allow the user to specify whether times of ash arrival ',/, &
      '#at airports & other locations will be written out, and which file  ',/, &
      '#to read for a list of airport locations. ',/, &
      '#PLEASE NOTE:  Each line in the airport location file should contain the ',/, &
      '#              airport latitude, longitude, projected x and y coordinates,  ',/, &
      '#              and airport name.  if you are using a projected grid,  ',/, &
      '#              THE X AND Y MUST BE IN THE SAME PROJECTION as the wind files.',/, & 
      '#              Alternatively, if proj4 is compiled, you can have Proj4  ',/, &
      '#              find the projected coordinates by typing "yes" to the last parameter ',/, &
      '******************* BLOCK 6 *************************************************** ',/, &
      'yes                           #Write out ash arrival times at airports to ASCII FILE? ',/, & 
      'no                            #Write out grain-size distribution to ASCII airport file?  ',/, &
      'yes                           #Write out ash arrival times to kml file?  ',/, &
      '                              #Name of file containing aiport locations  ',/, &
      'no                            #Have Proj4 calculate projected coordinates?  ',/, &
      '******************************************************************************* ',/, &
      '#GRAIN SIZE GROUPS ',/, &
      '#The first line of this block contains an integer (nsize) that gives the  ',/, &
      '#     number of size bins or settling velocity groups. ',/, &
      '#This should be followed by nsize lines.  If those lines contain: ',/, &
      '#    2  numbers, Ash3d interprets them to be the mass fraction of particles in ',/, &
      '#                that bin, and the settling velocity.  It then calculates fall ',/, &
      '#                assuming a constant settling velocity regardless of elevation. ',/, &
      '#    3 numbers, Ash3d interprets them to be: ',/, &
      '#                --size (mm) in that bin ',/, &
      '#                --mass fraction in that bin ',/, &
      '#                --density of particles (kg/m3) in that bin. ',/, &
      '#               Ash3d calculates the settling velocity of each grain size as a  ',/, &
      '#               function of elevation using the formula of Wilson and Huang ',/, &
      '#               (1979, EPSL, 44:311-324), assuming the particles have a shape ',/, &
      '#               factor of f=0.44, which is the average of particles measured ',/, &
      '#               by Wilson and Huang.  This calculation also includes a slip ',/, &
      '#               factor for small particles. ',/, &
      '#     4 numbers, Ash3d interprets the first three as before.  The fourth number ',/, &
      '#               is assumed to be the slip factor. ',/, &
      '******************* BLOCK 7 *************************************************** ',/, &
      '1                            #Number of settling velocity groups',/, &
      '0.0100 1.00 2000.',/, &
      '******************************************************************************* ',/, &
      '#Options for writing vertical profiles ',/, &
      '#The first line below gives the number of locations (nlocs) where vertical ',/, &
      '# profiles are to be written.  That is followed by nlocs lines, each of which ',/, &
      '#contain the location, in the same coordinate system specified above for the ',/, &
      '#volcano. ',/, &
      '******************* BLOCK 8 *************************************************** ',/, &
      '0                             #number of locations for vertical profiles (nlocs)  ',/, &
      '******************************************************************************* ',/, &
      '#netCDF output options ',/, &
      '******************* BLOCK 9 *************************************************** ',/, &
      '3d_tephra_fall.nc             # Name of output file  ',/, &
      'St. Helens forecast           # Title of simulation  ',/, &
      'no comment                    # Comment  ',/, &
      'no                            # use topography?  ',/, &
      '1 40                          # Topofile format, smoothing  length  ',/, &
      'GEBCO_08.nc                   # topofile name              ')

      end program makeAsh3dinput1_ac

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      function hours_since_1900(iyear,imonth,iday,hours)

!     function that calculates the number of hours since 1900 of a year, month, day, and hour (UT)      
      ! Check against calculator on
      ! http://www.7is7.com/otto/datediff.html

      implicit none
      integer                :: iyear,imonth
      integer                :: iday, ileaphours
      real(kind=8)           :: hours
      real(kind=8)           :: hours_since_1900
                                   !cumulative hours in each month
      integer, dimension(12) :: monthours = (/0,744,1416,2160,2880,3624,4344,5088,5832,6552,7296,8016/)

      logical :: IsLeapYear

      ! First check input values
      if (iyear.lt.1900) then
        write(*,*)"ERROR:  year must not be less than 1900."
        stop 1
      endif
      if (imonth.lt.1.or.imonth.gt.12) then
        write(*,*)"ERROR:  month must be between 1 and 12."
        stop 1
      endif
      if (iday.lt.1) then
        write(*,*)"ERROR:  day must be greater than 0."
        stop 1
      endif
      if ((imonth.eq.1.or.&
           imonth.eq.3.or.&
           imonth.eq.5.or.&
           imonth.eq.7.or.&
           imonth.eq.8.or.&
           imonth.eq.10.or.&
           imonth.eq.12).and.iday.gt.31)then
        write(*,*)"ERROR:  day must be <= 31 for this month."
        stop 1
      endif
      if ((imonth.eq.4.or.&
           imonth.eq.6.or.&
           imonth.eq.9.or.&
           imonth.eq.11).and.iday.gt.30)then
        write(*,*)"ERROR:  day must be <= 30 for this month."
        stop 1
      endif
      if ((imonth.eq.2).and.iday.gt.29)then
        write(*,*)"ERROR:  day must be <= 29 for this month."
        stop 1
      endif

      if  ((mod(iyear,4).eq.0)     .and.                          &
           (mod(iyear,100).ne.0).or.(mod(iyear,400).eq.0))then
        IsLeapYear = .true.
      else
        IsLeapYear = .false.
      endif

      ileaphours = 24 * int((iyear-1900)/4)
      ! If this is a leap year, but still in Jan or Feb, removed the
      ! extra 24 hours credited above
      if (IsLeapYear.and.imonth.lt.3) ileaphours = ileaphours - 24

      hours_since_1900 = (iyear-1900)*8760.0    + & ! number of hours per normal year 
                         monthours(imonth)      + & ! hours in year at beginning of month
                         ileaphours             + & ! total leap hours since 1900
                         24.0*(iday-1)          + & ! hours in day
                         hours                      ! hour of the day

      end function hours_since_1900

