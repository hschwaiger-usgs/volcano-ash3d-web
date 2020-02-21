      program makeAsh3dinput2_ac

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

!     program that reads the ASCII CloudLoad file from a preliminary run of 10x10 nodes
!     horizontally and generates an input file for a second run
!     whose model domain has been adjusted for the location of the CloudLoad

      implicit none
      real(kind=8), dimension(:,:,:), allocatable           :: CloudLoad
      real(kind=8) :: row(10)
      real(kind=8) :: dx_old, dy_old, dz, Height_old, lonLL_old, latLL_old
      real(kind=8) :: latUR_old, lonUR_old, width_old
      real(kind=8) :: dx_new, dy_new, Height_new, Height_new2
      real(kind=8) :: lonLL_new, latLL_new, width_new, width_new2
      real(kind=8) :: aspect_ratio, latUR_new, lonUR_new, resolution
      real(kind=8) :: CloudLoad_thresh
      integer      :: ifirst, ilast, ilines, i_volcano_old, jfirst, jlast, j_volcano_old
      integer      :: nWriteTimes
      integer      :: nbuffer
      real(kind=8) :: Duration, e_volume, FineAshFraction, height_km, lat_mean, pHeight
      real(kind=8) :: SimTime, StartTime
      real(kind=8) :: TimeNow, v_lon, v_lat, v_elevation, width_km, WriteTimes(24)
      integer      :: i,j,iargc,iday,imonth,iostatus,iwind,iWindFormat,iyear
      integer      :: ii,iii
      integer      :: k,nargs,nWindFiles
      !character(len=1) :: answer
      integer      :: nrows,remainder
      character(len=7) :: TimeNow_char
      character(len=23) :: CloudLoadFile
      character(len=80) :: linebuffer
      character         :: testkey
      character(len=5)  :: dum_str
      character(len=80) :: infile, outfile
      character(len=30) :: volcano_name
      character(len=133):: inputlines(310)

      write(6,*) 'starting makeAsh3dinput2'

      !set constants
      resolution = 100.     !model resolution in x and y
      aspect_ratio = 1.5   !map aspect ratio
      FineAshFraction = 0.05  !mass fraction of fine ash that goes into the cloud
      CloudLoad_thresh = 0.03    !threshold for setting model boundary
      nbuffer          = 2       !number of cells buffer between ifirst and model boundary

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = iargc()
      if (nargs.eq.2) then
           call getarg(1,infile)
           call getarg(2,outfile)
           write(6,*) 'input file=',infile,', output file=',outfile
         else
           write(6,*) 'error: this program requires two input arguments:'
           write(6,*) 'an input file and an output file.'
           write(6,*) 'You have specified ',nargs, ' input arguments.'
           write(6,*) 'program stopped'
           stop 1
      end if
      open(unit=10,file=infile)         !simplified input file

      iostatus=0
      i=1
      do while (iostatus.ge.0)
         read(10,'(a133)',IOSTAT=iostatus) inputlines(i)
         i=i+1
      end do
      ilines=i-2

      read(inputlines(37),'(a25)') volcano_name
      read(inputlines(39),*) lonLL_old, latLL_old
      read(inputlines(40),*) width_old, height_old
      read(inputlines(41),*) v_lon, v_lat, v_elevation
      read(inputlines(42),*) dx_old, dy_old
      read(inputlines(43),*) dz
      read(inputlines(55),*) iyear, imonth,iday,StartTime, Duration, pHeight, e_volume
      read(inputlines(93),*) iwind, iWindFormat
      read(inputlines(95),*) SimTime
      read(inputlines(97),*) nWindFiles
      read(inputlines(127),*) nWriteTimes
      read(inputlines(128),*) (WriteTimes(i), i=1,nWriteTimes)

      !write(6,*) 'volcano name=',volcano_name
      !write(6,*) 'lonLL_old=',lonLL_old, ', latLL_old=',latLL_old
      !write(6,*) 'width_old=',width_old, ', height_old=',height_old
      !write(6,*) 'v_lon=',v_lon, ', v_lat=',v_lat, ', v_elevation=',v_elevation
      !write(6,*) 'dx_old=',dx_old, ', dy_old=',dy_old, ', dz=',dz
      !write(6,*) 'iyear=',iyear,', imonth=',imonth, ', iday=',iday, ', StartTime=',StartTime
      !write(6,*) 'iwind=',iwind, ', iWindformat=',iWindFormat
      !write(6,*) 'Simtime=',SimTime
      !write(6,*) 'nWindFiles=',nWindFiles
      !write(6,*) 'nWriteTimes=',nWriteTimes
      !write(6,*) 'WriteTimes=',WriteTimes

      !calculate i_volcano, j_volcano
      latUR_old     = latLL_old+height_old
      lonUR_old     = lonLL_old+width_old
      if (v_lon.lt.lonLL_old) v_lon=v_lon+360.
      i_volcano_old = int((v_lon-lonLL_old)/dx_old)+1       !i node of volcano
      j_volcano_old = int((v_lat-latLL_old)/dy_old)+1       !j node of volcano

      if (i_volcano_old.gt.20) then
          write(6,*) 'Error: The volcano is not within the mapped area'
          stop 1
      end if



      !do i=1,3
      !    read(11,*)         !skip header lines
      !end do
      !read(11,'(a80)')linebuffer
      !read(linebuffer,*)testkey
      !do while(testkey.ne.'N')
      !   ! haven't found 'NODATA_VALUE' yet
      !  read(11,'(a80)')linebuffer
      !  read(linebuffer,*)testkey
      !enddo

!      do j=jlast,1,-1
!        do ii=1,nrows
!          read(11,*) row(1:10)
!          iii=(ii-1)*10
!          deposit(iii+1:iii+10,j) = row(1:10)
!2         format(10f10.3)
!        enddo
!        if (remainder.gt.0) then
!          read(11,*)row(1:remainder)
!          iii=nrows*10
!          deposit(iii+1:iii+remainder,j) = row(1:remainder)
!        endif
!        read(11,*)
!      end do

      do k=1,nWriteTimes
         TimeNow = WriteTimes(k)
         if (TimeNow.lt.10.0) then
            write(TimeNow_char,1) TimeNow
1           format('_00',f4.2)
          else if (TimeNow.lt.100.0) then
            write(TimeNow_char,2) TimeNow
2           format('_0',f5.2)
          else
            write(TimeNow_char,22) TimeNow
22          format('_',f6.2)
         end if
         CloudLoadFile = 'CloudLoad' // TimeNow_char // 'hrs.dat'
         write(6,*) 'opening ', CloudLoadFile
         open(unit=11,file=CloudLoadFile,status='old',err=1900)

         read(11,*)dum_str,ilast
         read(11,*)dum_str,jlast
         jfirst = 1
         ifirst = 1
         if(k.eq.1)allocate(CloudLoad(ilast,jlast,nWriteTimes))
         nrows     = ilast/10
         remainder = ilast - nrows*10

          do i=1,3
              read(11,*)         !skip header lines
          end do
          read(11,'(a80)')linebuffer
          read(linebuffer,*)testkey
          do while(testkey.ne.'N')
             ! haven't found 'NODATA_VALUE' yet
            read(11,'(a80)')linebuffer
            read(linebuffer,*)testkey
          enddo


         do j=jlast,1,-1
          do ii=1,nrows
            read(11,*) row(1:10)
            iii=(ii-1)*10
            CloudLoad(iii+1:iii+10,j,k) = row(1:10)
          enddo
          if (remainder.gt.0) then
            read(11,*)row(1:remainder)
            iii=nrows*10
            CloudLoad(iii+1:iii+remainder,j,k) = row(1:remainder)
          endif
             !read(11,3) (CloudLoad(i,j,k), i=1,10)
             !read(11,3) (CloudLoad(i,j,k), i=11,20)
!3            format(10f10.3)
             read(11,*)
         end do
      end do

      do i=1,ilast                                !find ifirst
        do j=1,jlast
          do k=1,nWriteTimes
             if (CloudLoad(i,j,k).ge.0.01) then
                ifirst = i
                go to 100
             end if
          end do
        end do
      end do
100   continue
      do i=ilast,1,-1                             !find ilast
        do j=1,jlast
           do k=1,nWriteTimes
              if (CloudLoad(i,j,k).ge.CloudLoad_thresh) then
                 ilast = i
                 go to 200
              end if
           end do
        end do
      end do
200   continue
      do j=1,jlast                                !find jfirst
        do i=1,ilast
           do k=1,nWriteTimes
              if (CloudLoad(i,j,k).ge.CloudLoad_thresh) then
                 jfirst = j
                 go to 300
              end if
           end do
        end do
      end do
300   continue
      do j=jlast,1,-1                             !find jlast
        do i=1,ilast
           do k=1,nWriteTimes
              if (CloudLoad(i,j,k).ge.CloudLoad_thresh) then
                 jlast = j
                 go to 400
              end if
           end do
        end do
      end do
400 continue

     !make sure the volcano is not right at the boundary
      if (ifirst.ge.i_volcano_old) ifirst = i_volcano_old-1
      if (ilast .le.i_volcano_old) ilast  = i_volcano_old+1
      if (jfirst.ge.j_volcano_old) jfirst = j_volcano_old-1
      if (jlast .le.j_volcano_old) jlast  = j_volcano_old+1

      !calculate new model boundaries
      lonLL_new  = lonLL_old + float(ifirst-nbuffer)*dx_old
      latLL_new  = latLL_old + float(jfirst-nbuffer)*dy_old
      width_new  = float(ilast-ifirst+nbuffer)*dx_old
      height_new = float(jlast-jfirst+nbuffer)*dy_old
      latUR_new  = latLL_new + height_new
      lonUR_new  = lonLL_new + width_new

      write(6,*) 'volcano name :', volcano_name
      write(6,*) 'Start time (year, month, day, hour):',iyear, imonth, iday, StartTime
      write(6,*) 'i_volcano_old=', i_volcano_old, ', j_volcano_old=', j_volcano_old
      write(6,*) 'CloudLoad_thresh = ',CloudLoad_thresh
      write(6,*) 'ifirst=',ifirst, ', ilast=', ilast
      write(6,*) 'jfirst=',jfirst, ', jlast=', jlast
      write(6,*) 'lonLL:  old=',lonLL_old,   ', new=',lonLL_new
      write(6,*) 'latLL:  old=',latLL_old,   ', new=',latLL_new
      write(6,*) 'width:  old=',width_old,   ', new=', width_new
      write(6,*) 'height: old=',height_old,  ', new=', height_new
      write(6,*)

      !Adjust model boundaries to maintain the specified aspect ratio
      lat_mean = latLL_new + height_new/2.
      height_km=height_new*109
      width_km =width_new*109.*cos(3.14*lat_mean/180.)
      if (width_km.gt.(aspect_ratio*height_km)) then
         write(6,*) 'adjusting height to maintain aspect ratio'
         height_new2 = width_km/(aspect_ratio*109.)
         latLL_new  = latLL_new - (height_new2-height_new)/2.
         height_new = height_new2
         latUR_new  = latLL_new+height_new
         dy_new = height_new/resolution
         if ((latUR_new+dy_new).gt.89.5) then  !make sure top of model boundary doesn't cross the N pole
             write(6,*) 'adjusting N model boundary so that it doesnt cross the north pole'
             latUR_new = 89.5-dy_new
             height_new = latUR_new-latLL_new
         end if
         if ((latLL_new-dy_new).lt.-89.5) then
             write(6,*) 'adjusting S model boundary so that it doesnt cross the south pole'
             latLL_new = -89.5+dy_new
             height_new = latUR_new-latLL_new
         end if
         write(6,*) 'height_new=', height_new
       else
         write(6,*) 'adjusting width to maintain aspect ratio'
         width_new2 = aspect_ratio*height_km/(109.*cos(3.14*lat_mean/180.))
         lonLL_new  = lonLL_new - (width_new2-width_new)/2.
         width_new  = width_new2
         write(6,*) 'width_new=', width_new
      end if

      write(6,*) 'width:      old=',width_old,      ', new=', width_new
      write(6,*) 'height:     old=',height_old,     ', new=', height_new
      dx_new = width_new/resolution
      dy_new = height_new/resolution
      write(6,*) 'dx:         old=',dx_old,         ', new=', dx_new
      write(6,*) 'dy:         old=',dy_old,         ', new=', dy_new

      !read boundaries
      write(6,*) 'Duration=', Duration, ', pHeight=', pHeight
      write(6,*) 'e_volume=',e_volume
      write(6,*)
      write(6,*) 'writing ', outfile


      open(unit=12,file=outfile)
      write(12,5)  volcano_name, lonLL_new, latLL_new, width_new, height_new, &
                   v_lon, v_lat, &
                   dx_new, dy_new, dz, &
                   iyear, imonth, iday, StartTime, Duration, pHeight, e_volume, &
                   iwind, iWindFormat, &
                   SimTime, &
                   nWindFiles, &
                   nWriteTimes, &
                   (WriteTimes(i), i=1,nWriteTimes)
      do i=129,ilines
         write(12,4) inputlines(i)
4        format(a100)
      end do
      close(10)
      close(12)
      write(6,*) 'all done'
      stop 0

1900  write(6,*) 'error: CloudLoad_xxx.xhrs.dat files do not exist.'
      write(6,*) 'Program stopped'
      stop 1
      
5     format( &
      '# Input file generated by web application. ',/, &
      '# Webapp site: vsc-ash.wr.usgs.gov',/, &
      '# Webapp gen date time: 2012/03/05 09:56:29',/, &
      '# ',/, &
      '#The following is an input file to the model Ash3d, v.1.0 ',/, &
      '#Created by L.G. Mastin, R.P. Denlinger, and H.F. Schwaiger U.S. Geological Survey, 2009. ',/, &
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
      2f13.3,                   '      #vent location         (km, or deg. if latlonflag=1)  ',/, &
      2f13.5,                   '      #DX, DY of grid cells  (km, or deg.)  ',/, &
      f8.3,'                        #DZ of grid cells      (always km)  ',/, &
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
      3i6,3f10.2,e12.4,/, &
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
      2i3,  '              #iwind, iwindFormat  ',/, &
      '2                   #iHeightHandler  ',/, &
      f7.1,  '             #Simulation time in hours  ',/, &
      'no                  #stop computation when 99% of erupted mass has deposited?  ',/, &
      i2,'                  #nWindFiles, number of gridded wind files (used if iwind>1)  ',/, &
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
      'yes     #Write out        KML files of ash-cloud concentration ?                 ',/, &
      'no      #Write out ESRI ASCII files of ash-cloud height?                        ',/, &
      'yes     #Write out        KML files of ash-cloud height?                        ',/, &
      'no      #Write out      ASCII files of ash-cloud load (T/km2) at specified times?  ',/, &
      'yes     #Write out        KML files of ash-cloud load (T/km2) at specified times?  ',/, &
      'no      #Write ASCII file of deposit arrival times?  ',/, &
      'no      #Write KML file of deposit arrival times?  ',/, &
      'no      #write ASCII file of cloud arrival times?  ',/, &
      'yes     #Write KML file of cloud arrival times?  ',/, &
      'yes     #Write out 3-D ash concentration at specified times?                       ',/, &
      'netcdf  #format of ash concentration files   ("ascii", "binary", or "netcdf")  ',/, &
      i2,'      #nWriteTimes  ',/, &
      24f7.2)


      end program makeAsh3dinput2_ac
