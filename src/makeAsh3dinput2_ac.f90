      program makeAsh3dinput2_ac

!      --This file is a component of the USGS program Ash3d for volcanic ash transport
!          and dispersion.

!      --Use of this program is described in:

!        Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., in press, Ash3d, a finite-
!           volume, conservative numerical model for ash transport and tephra deposition,
!           Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968

!      --Written in Fortran 90

!      --The program has been successsfully tested and run on the Linux Operating System using
!          Red Hat 8/9 and Ubuntu 22/24.

!       Although this program has been used by the USGS, no warranty, expressed or implied, is 
!         made by the USGS or the United States Government as to the accuracy and functioning 
!         of the program and related program material nor shall the fact of distribution constitute 
!         any such warranty, and no responsibility is assumed by the USGS in connection therewith.

!     program that reads the ASCII CloudLoad file from a preliminary run of 10x10 nodes
!     horizontally and generates an input file for a second run
!     whose model domain has been adjusted for the location of the CloudLoad

      ! This module requires Fortran 2003 or later
      use iso_fortran_env, only : &
         input_unit,output_unit,error_unit

      implicit none

      integer,parameter :: fid_ctrin_prelim  = 10
      integer,parameter :: fid_CloudLoadData = 11
      integer,parameter :: fid_ctrout_full   = 12

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
      integer      :: i,j,iday,imonth,iostatus,iwind,iWindFormat,iyear
      integer      :: ii,iii
      integer      :: k
      integer      :: nargs,nWindFiles
      integer,dimension(10) :: block_linestart
      integer      :: status
      !character(len=1) :: answer
      integer      :: nrows,remainder
      character(len=7) :: TimeNow_char
      character(len=23) :: CloudLoadFile
      character(len=80) :: linebuffer
      character         :: testkey
      character(len=5)  :: dum_str
      character(len=80) :: infile, outfile
      character(len=30) :: volcano_name
      character(len=133):: inputlines(400)
      logical           :: IsThere

      write(output_unit,*) ' '
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) 'starting makeAsh3dinput2_ac'
      write(output_unit,*) ' '

      ! set constants
      aspect_ratio     = 1.5_8                                    ! map aspect ratio (km/km)
      FineAshFraction  = 0.05_8                                   ! mass fraction fine ash
      resolution       = 100.0_8                                  ! model resolution in x and y
      CloudLoad_thresh = 0.03_8                                   ! threshold for setting model boundary
      nbuffer          = 2                                        ! number of cells buffer between ifirst and model boundary

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = command_argument_count()
      if (nargs.eq.2) then
        call get_command_argument(1, infile, status)
        call get_command_argument(2, outfile, status)
      else
        write(error_unit,*) 'ERROR: Two input arguments required'
        write(error_unit,*) 'an input file and an output file.'
        write(error_unit,*) 'You have specified ',nargs, ' input arguments.'
        write(error_unit,*) 'program stopped'
        stop 1
      end if
      write(output_unit,*) 'Command-line arguments parsed as:'
      write(output_unit,*) '  infile  = ', infile
      write(output_unit,*) '  outfile = ', outfile
      inquire( file=infile, exist=IsThere )
      if(.not.IsThere)then
        write(error_unit,*)"ERROR: Could not find file :",infile
        write(error_unit,*)"       Please copy file to cwd"
        stop 1
      endif
      open(unit=fid_ctrin_prelim,file=infile)         ! full control file for preliminary run

      iostatus=0
      i=1
      do while (iostatus.ge.0)
        read(fid_ctrin_prelim,'(a133)',IOSTAT=iostatus) inputlines(i)
        if(index(inputlines(i),' BLOCK 1 ').ne.0)block_linestart(1)=i+1
        if(index(inputlines(i),' BLOCK 2 ').ne.0)block_linestart(2)=i+1
        if(index(inputlines(i),' BLOCK 3 ').ne.0)block_linestart(3)=i+1
        if(index(inputlines(i),' BLOCK 4 ').ne.0)block_linestart(4)=i+1
        if(index(inputlines(i),' BLOCK 5 ').ne.0)block_linestart(5)=i+1
        if(index(inputlines(i),' BLOCK 6 ').ne.0)block_linestart(6)=i+1
        if(index(inputlines(i),' BLOCK 7 ').ne.0)block_linestart(7)=i+1
        if(index(inputlines(i),' BLOCK 8 ').ne.0)block_linestart(8)=i+1
        if(index(inputlines(i),' BLOCK 9 ').ne.0)block_linestart(9)=i+1
        if(index(inputlines(i),' BLOCK 10 ').ne.0)block_linestart(10)=i+1
        i=i+1
      end do
      ilines=i-2
      close(fid_ctrin_prelim)

      ! Reading BLOCK 1 of the preliminary control file
      read(inputlines(block_linestart(1)  ),'(a30)') volcano_name
      read(inputlines(block_linestart(1)+2),*) lonLL_old, latLL_old
      read(inputlines(block_linestart(1)+3),*) width_old, height_old
      read(inputlines(block_linestart(1)+4),*) v_lon, v_lat, v_elevation
      read(inputlines(block_linestart(1)+5),*) dx_old, dy_old
      read(inputlines(block_linestart(1)+6),*) dz
      ! Reading BLOCK 2 of the preliminary control file
      read(inputlines(block_linestart(2)  ),*) iyear, imonth,iday,StartTime, Duration, pHeight, e_volume
      ! Reading BLOCK 3 of the preliminary control file
      read(inputlines(block_linestart(3)  ),*) iwind, iWindFormat
      read(inputlines(block_linestart(3)+2),*) SimTime
      read(inputlines(block_linestart(3)+4),*) nWindFiles
      ! Reading BLOCK 4 of the preliminary control file
      read(inputlines(block_linestart(4)+16),*) nWriteTimes
      read(inputlines(block_linestart(4)+17),*) (WriteTimes(i), i=1,nWriteTimes)

      ! For double-checking that the control file is read correctly, if needed.
      !write(output_unit,*) 'volcano name=',volcano_name
      !write(output_unit,*) 'lonLL_old=',lonLL_old, ', latLL_old=',latLL_old
      !write(output_unit,*) 'width_old=',width_old, ', height_old=',height_old
      !write(output_unit,*) 'v_lon=',v_lon, ', v_lat=',v_lat, ', v_elevation=',v_elevation
      !write(output_unit,*) 'dx_old=',dx_old, ', dy_old=',dy_old, ', dz=',dz
      !write(output_unit,*) 'iyear=',iyear,', imonth=',imonth, ', iday=',iday, ', StartTime=',StartTime
      !write(output_unit,*) 'iwind=',iwind, ', iWindformat=',iWindFormat
      !write(output_unit,*) 'Simtime=',SimTime
      !write(output_unit,*) 'nWindFiles=',nWindFiles
      !write(output_unit,*) 'nWriteTimes=',nWriteTimes
      !write(output_unit,*) 'WriteTimes=',WriteTimes(1:nWriteTimes)

      !calculate i_volcano, j_volcano
      latUR_old     = latLL_old+height_old
      lonUR_old     = lonLL_old+width_old
      if (v_lon.lt.lonLL_old) v_lon=v_lon+360.0_8
      i_volcano_old = int((v_lon-lonLL_old)/dx_old)+1       !i node of volcano
      j_volcano_old = int((v_lat-latLL_old)/dy_old)+1       !j node of volcano

      if (i_volcano_old.gt.20) then
        write(error_unit,*) 'ERROR: The volcano is not within the mapped area'
        stop 1
      endif

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

      ! Now looping through all the expected CloudLoad files and evaluating
      do k=1,nWriteTimes
        TimeNow = WriteTimes(k)
        if (TimeNow.lt.10.0_8) then
          write(TimeNow_char,1) TimeNow
1         format('_00',f4.2)
        elseif (TimeNow.lt.100.0_8) then
          write(TimeNow_char,2) TimeNow
2         format('_0',f5.2)
        else
          write(TimeNow_char,22) TimeNow
22        format('_',f6.2)
        endif
        CloudLoadFile = 'CloudLoad' // TimeNow_char // 'hrs.dat'
        write(output_unit,*) 'opening ', CloudLoadFile
        open(unit=fid_CloudLoadData,file=CloudLoadFile,status='old',err=1900)

        read(fid_CloudLoadData,*)dum_str,ilast
        read(fid_CloudLoadData,*)dum_str,jlast
        jfirst = 1
        ifirst = 1
        if(k.eq.1)allocate(CloudLoad(ilast,jlast,nWriteTimes))
        nrows     = ilast/10
        remainder = ilast - nrows*10

        do i=1,3
          read(fid_CloudLoadData,*)         !skip header lines
        enddo
        read(fid_CloudLoadData,'(a80)')linebuffer
        read(linebuffer,*)testkey
        do while(testkey.ne.'N')
          ! haven't found 'NODATA_VALUE' yet
          read(fid_CloudLoadData,'(a80)')linebuffer
          read(linebuffer,*)testkey
        enddo

        do j=jlast,1,-1
          do ii=1,nrows
            read(fid_CloudLoadData,*) row(1:10)
            iii=(ii-1)*10
            CloudLoad(iii+1:iii+10,j,k) = row(1:10)
          enddo
          if (remainder.gt.0) then
            read(fid_CloudLoadData,*)row(1:remainder)
            iii=nrows*10
            CloudLoad(iii+1:iii+remainder,j,k) = row(1:remainder)
          endif
          !read(fid_CloudLoadData,3) (CloudLoad(i,j,k), i=1,10)
          !read(fid_CloudLoadData,3) (CloudLoad(i,j,k), i=11,20)
!3        format(10f10.3)
          read(fid_CloudLoadData,*)
        end do
        close(fid_CloudLoadData)
      end do
      ! Now all the data has been read into the array CloudLoad(i,j,k)

      do i=1,ilast                                !find ifirst
        ! For each i-slice, check if any value in CloudLoad(i,:,:) exceeds threshold
        do j=1,jlast
          do k=1,nWriteTimes
            if (CloudLoad(i,j,k).ge.0.01_8) then
                ifirst = i
              go to 100
            end if
          end do
        end do
      end do
100   continue
      do i=ilast,1,-1                             !find ilast
        ! For each i-slice, check if any value in CloudLoad(i,:,:) exceeds threshold
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
        ! For each j-slice, check if any value in CloudLoad(:,j,:) exceeds threshold
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
        ! For each j-slice, check if any value in CloudLoad(:,j,:) exceeds threshold
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

      write(output_unit,*) 'volcano name : ', volcano_name
      write(output_unit,*) 'Start time (year, month, day, hour):',iyear, imonth, iday, real(StartTime,kind=4)
      write(output_unit,*) 'i_volcano_old=', i_volcano_old, ',   j_volcano_old=', j_volcano_old
      write(output_unit,*) 'CloudLoad_thresh = ',real(CloudLoad_thresh,kind=4)
      write(output_unit,*) 'ifirst=',ifirst, ', ilast=', ilast
      write(output_unit,*) 'jfirst=',jfirst, ', jlast=', jlast
      write(output_unit,*) 'lonLL:  old = ',real(lonLL_old,kind=4),   ', new = ',real(lonLL_new,kind=4)
      write(output_unit,*) 'latLL:  old = ',real(latLL_old,kind=4),   ', new = ',real(latLL_new,kind=4)
      write(output_unit,*) 'width:  old = ',real(width_old,kind=4),   ', new = ',real(width_new,kind=4)
      write(output_unit,*) 'height: old = ',real(height_old,kind=4),  ', new = ',real(height_new,kind=4)
      write(output_unit,*)

      !Adjust model boundaries to maintain the specified aspect ratio
      lat_mean = latLL_new + height_new/2.0_8
      height_km=height_new*109.0_8
      width_km =width_new*109.0_8*cos(3.14_8*lat_mean/180.0_8)
      if (width_km.gt.(aspect_ratio*height_km)) then
         write(output_unit,*) 'adjusting height to maintain aspect ratio'
         height_new2 = width_km/(aspect_ratio*109.0_8)
         latLL_new  = latLL_new - (height_new2-height_new)/2.0_8
         height_new = height_new2
         latUR_new  = latLL_new+height_new
         dy_new = height_new/resolution
         if ((latUR_new+dy_new).gt.89.5_8) then  !make sure top of model boundary doesn't cross the N pole
             write(output_unit,*) 'adjusting N model boundary so that it doesnt cross the north pole'
             latUR_new = 89.5_8-dy_new
             height_new = latUR_new-latLL_new
         end if
         if ((latLL_new-dy_new).lt.-89.5_8) then
             write(output_unit,*) 'adjusting S model boundary so that it doesnt cross the south pole'
             latLL_new = -89.5_8+dy_new
             height_new = latUR_new-latLL_new
         end if
         write(output_unit,*) 'height_new=', height_new
       else
         write(output_unit,*) 'adjusting width to maintain aspect ratio'
         width_new2 = aspect_ratio*height_km/(109.0_8*cos(3.14_8*lat_mean/180.0_8))
         lonLL_new  = lonLL_new - (width_new2-width_new)/2.0_8
         width_new  = width_new2
         write(output_unit,*) 'width_new=', width_new
      end if

      write(output_unit,*) 'width:      old = ',real(width_old,kind=4),      ', new = ', real(width_new,kind=4)
      write(output_unit,*) 'height:     old = ',real(height_old,kind=4),     ', new = ', real(height_new,kind=4)
      dx_new = width_new/resolution
      dy_new = height_new/resolution
      write(output_unit,*) 'dx:         old = ',real(dx_old,kind=4),         ', new = ', real(dx_new,kind=4)
      write(output_unit,*) 'dy:         old = ',real(dy_old,kind=4),         ', new = ', real(dy_new,kind=4)

      !read boundaries

      write(output_unit,*) 'Eruption ESP for ash cloud:'
      write(output_unit,*) ' Duration = ',real(Duration,kind=4), &
                             ', pHeight= ',real(pHeight,kind=4),&
                             ', e_volume = ',real(e_volume,kind=4)
      write(output_unit,*)
      write(output_unit,*) 'writing full control file for full Ash3d run: ', outfile

      open(unit=fid_ctrout_full,file=outfile)
      write(fid_ctrout_full,2010) ! write block 1 header, then content  (Grid specification)
      write(fid_ctrout_full,2011) volcano_name, &
                                  lonLL_new, latLL_new, &
                                  width_new, height_new, &
                                  v_lon, v_lat, v_elevation, &
                                  dx_new, dy_new, &
                                  dz
      write(fid_ctrout_full,2020) ! write block 2 header, then content  (Eruption specification)
      write(fid_ctrout_full,2021) iyear, imonth, iday, StartTime, Duration, pHeight, e_volume
      write(fid_ctrout_full,2030) ! write block 3 header, then content  (Wind options)
      write(fid_ctrout_full,2031) iwind, iWindformat, &
                                  SimTime, &
                                  nWindfiles
      write(fid_ctrout_full,2040) ! write block 4 header, then content  (Output products)
      write(fid_ctrout_full,2041) nWriteTimes,&
                                  (WriteTimes(i), i=1,nWriteTimes)

      ! Now just copy blocks 5 -> end from the preliminary file
      write(fid_ctrout_full,2050) ! write block 5 header
      do i=block_linestart(5)-1,ilines
        write(fid_ctrout_full,4) inputlines(i)
4       format(a100)
      end do

      close(fid_ctrout_full)

      write(output_unit,*) 'Successfully finished makeAsh3dinput2_ac'
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) ' '

      stop 0

1900  write(error_unit,*) 'ERROR: CloudLoad_xxx.xhrs.dat files do not exist.'
      write(error_unit,*) '       Preliminary run did not write CloudLoad files as expected.'
      write(error_unit,*) 'Program stopped'
      stop 1
      
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
      a30,'                 # Volcano name (character*30) (52.894N 170.054W)  ',/, &
      '1 1 -135.0 90.0 0.933 6371.229  # Proj flags and params  ',/, &
      2f13.3,                   '      # x, y of LL corner of grid (km, or deg. if latlongflag=1)  ',/, &
      2f13.3,                   '      # grid width and height (km, or deg. if latlonflag=1)  ',/, &
      3f10.3,                      '   # vent location         (km, or deg. if latlonflag=1)  ',/, &
      2f13.3,                   '      # DX, DY of grid cells  (km, or deg.)  ',/, &
      f8.3,   '                        # DZ of grid cells      (always km)  ',/, &
      '000.      4.                    # diffusion coefficient (m2/s), Suzuki constant  ',/, &
      '1                               # neruptions, number of eruptions or pulses')
2020  format( &
      '******************************************************************************* ',/, &
      '#ERUPTION LINES (number = neruptions) ',/, &
      '#In the following line, each line represents one eruptive pulse.   ',/, &
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
       i2,3x,i2,'       #iwind, iwindFormat  ',/, &
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
      'no      # Write out ESRI ASCII files of ash-cloud height?                        ',/, &
      'no      # Write out        KML files of ash-cloud height?                        ',/, &
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

      end program makeAsh3dinput2_ac
