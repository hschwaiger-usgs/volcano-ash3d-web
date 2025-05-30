      program makeAsh3dinput2_dp

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

!     program that reads the ASCII deposit file from a preliminary run of 10x10 nodes
!     horizontally and generates an input file for a second run
!     whose model domain has been adjusted for the location of the deposit
!
!     This program takes two command-line arguments:
!       input file (full) written by makeAsh3dinput1_dp and used for the preliminary run
!       input file to be written by makeAsh3dinput2_dp and used for the full run

      ! This module requires Fortran 2003 or later
      use iso_fortran_env, only : &
         input_unit,output_unit,error_unit

      implicit none

      integer,parameter :: fid_ctrin_prelim  = 10
      integer,parameter :: fid_DepositData   = 11
      integer,parameter :: fid_ctrout_full   = 12

      integer           :: nargs
      integer           :: iostatus
      character(len=80) :: infile, outfile
      logical           :: IsThere

      character(len=25) :: DepositFile
      real(kind=8),dimension(:,:),allocatable :: Deposit
      real(kind=8)      :: Deposit_thresh
      real(kind=8)      :: row(10)
      real(kind=8)      :: aspect_ratio
      real(kind=8)      :: resolution
      integer           :: nbuffer
      real(kind=8)      :: dx_old, dy_old
      real(kind=8)      :: dz, Height_old, width_old
      real(kind=8)      :: lonLL_old, latLL_old
      real(kind=8)      :: latUR_old, lonUR_old
      real(kind=8)      :: dx_new, dy_new
      real(kind=8)      :: Height_new, width_new
      real(kind=8)      :: Height_new2, width_new2
      real(kind=8)      :: lonLL_new, latLL_new
      real(kind=8)      :: latUR_new, lonUR_new

      integer           :: ifirst, ilast, ilines, i_volcano_old, jfirst, jlast, j_volcano_old
      integer           :: e_iday,e_imonth,e_iyear
      real(kind=8)      :: e_Duration, e_Volume, height_km, lat_mean, e_Height
      real(kind=8)      :: e_Hour
      real(kind=8)      :: SimTime
      real(kind=8)      :: v_lon, v_lat, v_elevation, width_km, WriteInterval
      integer           :: iwind,iwindformat,igrid,idf
      integer           :: i,j,ii,iii
      integer           :: nWindFiles
      integer,dimension(10) :: block_linestart
      integer           :: nrows,remainder
      character(len=80) :: linebuffer
      character(len=25) :: volcano_name
      character         :: testkey
      character(len=5)  :: dum_str
      character(len=133):: inputlines(400)


      write(output_unit,*) ' '
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) 'starting makeAsh3dinput2_dp'
      write(output_unit,*) ' '

      ! Set constants
      aspect_ratio     = 1.3_8                                    ! map aspect ratio (km/km)
      resolution       = 75.0_8                                   ! model resolution in x and y
      Deposit_thresh   = 0.01_8                                   ! threshold for setting model boundary
      nbuffer          = 2                                        ! number of cells buffer between ifirst and model boundary

      ! Test read command-line arguments
      nargs = command_argument_count()
      if (nargs.eq.2) then
        call get_command_argument(1, infile, iostatus)
        call get_command_argument(2, outfile, iostatus)
        write(output_unit,*) 'input file=',infile,', output file=',outfile
      else
        write(error_unit,*) 'ERROR: This program requires two input arguments:'
        write(error_unit,*) 'an input file and an output file.'
        write(error_unit,*) 'You have specified ',nargs, ' input arguments.'
        write(error_unit,*) 'program stopped'
        stop 1
      endif
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
      enddo
      ilines=i-2
      close(fid_ctrin_prelim)

      ! Reading BLOCK 1 of the preliminary control file
      read(inputlines(block_linestart(1)  ),'(a25)') volcano_name
      read(inputlines(block_linestart(1)+2),*) lonLL_old, latLL_old
      read(inputlines(block_linestart(1)+3),*) width_old, height_old
      read(inputlines(block_linestart(1)+4),*) v_lon, v_lat, v_elevation
      read(inputlines(block_linestart(1)+5),*) dx_old, dy_old
      read(inputlines(block_linestart(1)+6),*) dz
      ! Reading BLOCK 2 of the preliminary control file
      read(inputlines(block_linestart(2)  ),*) e_iyear, e_imonth, e_iday, e_Hour, e_Duration, e_Height, e_Volume
      ! Reading BLOCK 3 of the preliminary control file
      read(inputlines(block_linestart(3)  ),*) iwind, iwindformat,igrid,idf
      read(inputlines(block_linestart(3)+2),*) SimTime
      read(inputlines(block_linestart(3)+4),*) nWindFiles
      ! Reading BLOCK 4 of the preliminary control file
      read(inputlines(block_linestart(4)+17),*) WriteInterval

      ! Calculate i_volcano, j_volcano
      latUR_old     = latLL_old+height_old
      lonUR_old     = lonLL_old+width_old
      if (v_lon.lt.lonLL_old) v_lon=v_lon+360.0_8
      i_volcano_old = int((v_lon-lonLL_old)/dx_old)+1       ! i node of volcano
      j_volcano_old = int((v_lat-latLL_old)/dy_old)+1       ! j node of volcano

      DepositFile = 'DepositFile_____final.dat'
      write(output_unit,*) 'opening ',DepositFile
      open(unit=fid_DepositData,file=DepositFile,status='old',err=1900)

      ! Initiate boundaries
      read(fid_DepositData,*)dum_str,ilast
      read(fid_DepositData,*)dum_str,jlast
      jfirst = 1
      ifirst = 1
      allocate(deposit(ilast,jlast))
      nrows     = ilast/10
      remainder = ilast - nrows*10

      do i=1,3
        read(fid_DepositData,*)         !skip header lines
      enddo
      read(fid_DepositData,'(a80)')linebuffer
      read(linebuffer,*)testkey
      do while(testkey.ne.'N')
        ! Haven't found 'NODATA_VALUE' yet
        read(fid_DepositData,'(a80)')linebuffer
        read(linebuffer,*)testkey
      enddo

      do j=jlast,1,-1
        do ii=1,nrows
          read(fid_DepositData,*) row(1:10)
          iii=(ii-1)*10
          Deposit(iii+1:iii+10,j) = row(1:10)
        enddo
        if (remainder.gt.0) then
          read(fid_DepositData,*)row(1:remainder)
          iii=nrows*10
          Deposit(iii+1:iii+remainder,j) = row(1:remainder)
        endif
        read(fid_DepositData,*)
      enddo
      close(fid_DepositData)
      ! Now all the data has been read into the array Deposit(i,j)

      do i=1,ilast                                !find ifirst
        ! For each i-slice, check if any value in Deposit(i,:) exceeds threshold
        do j=1,jlast
          if (Deposit(i,j).ge.Deposit_thresh) then
            ifirst = i
            go to 100
        endif
        enddo
      enddo
100   continue
      do i=ilast,1,-1                             !find ilast
        ! For each i-slice, check if any value in Deposit(i,:) exceeds threshold
        do j=1,jlast
          if (Deposit(i,j).ge.Deposit_thresh) then
            ilast = i
            go to 200
          endif
        enddo
      enddo
200   continue
      do j=1,jlast                                !find jfirst
        ! For each j-slice, check if any value in Deposit(:,j) exceeds threshold
        do i=1,ilast
          if (Deposit(i,j).ge.Deposit_thresh) then
            jfirst = j
            go to 300
          endif
        enddo
      enddo
300   continue
      do j=jlast,1,-1                             !find jlast
        ! For each j-slice, check if any value in Deposit(:,j) exceeds threshold
        do i=1,ilast
          if (Deposit(i,j).ge.Deposit_thresh) then
            jlast = j
            go to 400
          endif
        enddo
      enddo
400 continue

      ! Make sure the volcano is not right at the boundary
      if (ifirst.ge.i_volcano_old) ifirst = i_volcano_old-1
      if (ilast .le.i_volcano_old) ilast  = i_volcano_old+1
      if (jfirst.ge.j_volcano_old) jfirst = j_volcano_old-1
      if (jlast .le.j_volcano_old) jlast  = j_volcano_old+1

      ! Calculate new model boundaries
      lonLL_new  = lonLL_old + float(ifirst-nbuffer)*dx_old
      latLL_new  = latLL_old + float(jfirst-nbuffer)*dy_old
      width_new  = float(ilast-ifirst+nbuffer*2)*dx_old
      height_new = float(jlast-jfirst+nbuffer*2)*dy_old
      latUR_new  = latLL_new + height_new
      lonUR_new  = lonLL_new + width_new

      ! Adjust model boundaries to maintain the specified aspect ratio
      dy_new = 0.0_8   !  Initialize dy_new to 0.0
      lat_mean = latLL_new + height_new/2.0_8
      height_km=height_new*109.0_8
      width_km =width_new*109.0_8*cos(3.14_8*lat_mean/180.0_8)
      if (width_km.gt.(aspect_ratio*height_km)) then
         write(output_unit,*) 'adjusting height to maintain aspect ratio'
         height_new2 = width_km/(aspect_ratio*109.0_8)
         latLL_new  = latLL_new - (height_new2-height_new)/2.0_8
         height_new = height_new2
         latUR_new  = latLL_new+height_new
         if ((latUR_new+dy_new).gt.89.5_8) then  ! Make sure top of model boundary doesn't cross the N pole
             write(output_unit,*) 'adjusting N model boundary so that it doesnt cross the north pole'
             latUR_new = 89.5_8 - dy_new
             height_new = latUR_new-latLL_new
         endif
         if ((latLL_new-dy_new).lt.-89.5_8) then
             write(output_unit,*) 'adjusting S model boundary so that it doesnt cross the south pole'
             latLL_new = -89.5_8 + dy_new
             height_new = latUR_new-latLL_new
         endif
         write(output_unit,*) 'height_new=', height_new
       else
         write(output_unit,*) 'adjusting width to maintain aspect ratio'
         width_new2 = aspect_ratio*height_km/(109.0_8*cos(3.14_8*lat_mean/180.0_8))
         lonLL_new  = lonLL_new - (width_new2-width_new)/2.0_8
         width_new  = width_new2
         write(output_unit,*) 'width_new=', width_new
      endif

      write(output_unit,*) 'Volcano name : ', volcano_name
      write(output_unit,*) 'Start time (year, month, day, hour):',e_iyear, e_imonth, e_iday, real(e_Hour,kind=4)
      write(output_unit,*) ' i_volcano_old=', i_volcano_old, ',   j_volcano_old=', j_volcano_old
      write(output_unit,*) ' Deposit_thresh = ',real(Deposit_thresh,kind=4)
      write(output_unit,*) ' ifirst=',ifirst, ', ilast=', ilast
      write(output_unit,*) ' jfirst=',jfirst, ', jlast=', jlast
      write(output_unit,*)
      write(output_unit,*) 'Model parameters:'
      write(output_unit,*) ' lonLL:  old = ',real(lonLL_old,kind=4),   ', new = ',real(lonLL_new,kind=4)
      write(output_unit,*) ' latLL:  old = ',real(latLL_old,kind=4),   ', new = ',real(latLL_new,kind=4)
      write(output_unit,*) ' width:  old = ',real(width_old,kind=4),   ', new = ',real(width_new,kind=4)
      write(output_unit,*) ' height: old = ',real(height_old,kind=4),  ', new = ',real(height_new,kind=4)
      dx_new = width_new/resolution
      dy_new = height_new/resolution
      write(output_unit,*) ' dx:     old = ',real(dx_old,kind=4),      ', new = ', real(dx_new,kind=4)
      write(output_unit,*) ' dy:     old = ',real(dy_old,kind=4),      ', new = ', real(dy_new,kind=4)
      write(output_unit,*)

      write(output_unit,*) 'Eruption ESP for deposit run:'
      write(output_unit,*) ' e_Duration = ',real(e_Duration,kind=4), &
                           ', e_Height  = ',real(e_Height,kind=4),&
                           ', e_Volume  = ',real(e_Volume,kind=4)
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
      write(fid_ctrout_full,2021) e_iyear, e_imonth, e_iday, e_Hour, e_Duration, e_Height, e_Volume
      write(fid_ctrout_full,2030) ! write block 3 header, then content  (Wind options)
      write(fid_ctrout_full,2031) iwind, iWindformat, igrid, idf, &
                                  SimTime, &
                                  nWindfiles
      write(fid_ctrout_full,2040) ! write block 4 header, then content  (Output products)
      write(fid_ctrout_full,2042) WriteInterval

      ! Now just copy blocks 5 -> end from the preliminary file
      write(fid_ctrout_full,2050) ! write block 5 header
      do i=block_linestart(5)-1,ilines
        write(fid_ctrout_full,4) inputlines(i)
4       format(a100)
      enddo
      ! Here we add the topography block
      write(fid_ctrout_full,2200) ! write block 10+ header, then content (Topography)
      write(fid_ctrout_full,2201)

      close(fid_ctrout_full)

      write(output_unit,*) ' '
      write(output_unit,*) 'Successfully finished makeAsh3dinput2_dp'
      write(output_unit,*) '---------------------------------------------------'
      write(output_unit,*) ' '

      stop 0

1900  write(error_unit,*) 'ERROR: DepositFile_____final.dat files do not exist.'
      write(error_unit,*) '       Preliminary run did not write Deposit file as expected.'
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
      'yes                 #stop computation when 99% of erupted mass has deposited?  ',/, &
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
2042  format( &
      '******************* BLOCK 4 *************************************************** ',/, &
      'yes     # Write out ESRI ASCII file of final deposit thickness?                    ',/, &
      'yes     # Write out        KML file of final deposit thickness?                   ',/, &
      'yes     # Write out ESRI ASCII deposit files at specified times?                  ',/, &
      'yes     # Write out        KML deposit files at specified times?                  ',/, &
      'no      # Write out ESRI ASCII files of ash-cloud concentration?                  ',/, &
      'no      # Write out        KML files of ash-cloud concentration ?                 ',/, &
      'no      # Write out ESRI ASCII files of ash-cloud height?                        ',/, &
      'no      # Write out        KML files of ash-cloud height?                        ',/, &
      'no      # Write out ESRI ASCII files of ash-cloud load (T/km2) at specified times?  ',/, &
      'no      # Write out        KML files of ash-cloud load (T/km2) at specified times?  ',/, &
      'yes     # Write out ESRI ASCII file of deposit arrival times?  ',/, &
      'yes     # Write out        KML file of deposit arrival times?  ',/, &
      'no      # Write out ESRI ASCII file of cloud arrival times?  ',/, &
      'no      # Write out        KML file of cloud arrival times?  ',/, &
      'yes     # Write out 3-D ash concentration at specified times? / [output code: 1=2d+concen,2=2d only]',/, &
      'netcdf  #format of ash concentration files   ("ascii", "binary", or "netcdf")  ',/, &
      '-1      #nWriteTimes  ',/, &
      f6.2)
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
!2051  format( &
!      '******************* BLOCK 5 ***************************************************')
!2052  format(a27,i3.3,'.nc')                          ! for forecast winds       Wind_nc/gfs/latest/latest.f**.nc
2052  format(a39,i3.3,'.nc')                          ! for archived gfs winds     Wind_nc/gfs/gfs.YYYYMMDDHH/YYYYMMDDHH.f**.nc
2053  format(a46,i1.1,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
2054  format(a46,i2.2,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
2055  format(a46,i3.3,'h-oper-fc.grib2')              ! for archived ecmwf winds   Wind_nc/ecmwf/ecmwf.YYYYMMDDHH/YYYYMMDDHH0000-*h-oper-fc.grib2
!2054  format(a12)                                      !for NCEP reanalyis winds Wind_nc/NCEP
!2060  format( &
!      '*******************************************************************************',/, &
!      '# AIRPORT LOCATION FILE ',/, &
!      '# The following lines allow the user to specify whether times of ash arrival ',/, &
!      '# at airports & other locations will be written out, and which file  ',/, &
!      '# to read for a list of airport locations. ',/, &
!      '# PLEASE NOTE:  Each line in the airport location file should contain the ',/, &
!      '#               airport latitude, longitude, projected x and y coordinates,  ',/, &
!      '#               and airport name.  If you are using a projected grid,  ',/, &
!      '#               THE X AND Y MUST BE IN THE SAME PROJECTION as the computational grid.',/, &
!      '#               Alternatively, coordinates can be projected via libprojection  ',/, &
!      '#               by typing "yes" to the last parameter ')
!2061  format( &
!      '******************* BLOCK 6 *************************************************** ',/, &
!      'yes                           # Write out ash arrival times at airports to ASCII FILE? ',/, &
!      'no                            # Write out grain-size distribution to ASCII airport file?  ',/, &
!      'yes                           # Write out ash arrival times to kml file?  ',/, &
!      '                              # Name of file containing aiport locations  ',/, &
!      'no                            # Defer to Lon/Lat coordinates? ("no" defers to projected)  ')
!2070  format( &
!      '******************************************************************************* ',/, &
!      '# GRAIN SIZE GROUPS',/, &
!      '# The first line must contain the number of settling velocity groups, but',/, &
!      '# can optionally also include a flag for the fall velocity model to be used.',/, &
!      '#    FV_ID = 1, Wilson and Huang',/, &
!      '#          = 2, Wilson and Huang + Cunningham slip',/, &
!      '#          = 3, Wilson and Huang + Mod by Pfeiffer Et al.',/, &
!      '#          = 4, Ganser (assuming prolate ellipsoids)',/, &
!      '#          = 5, Ganser + Cunningham slip',/, &
!      '#          = 6, Stokes flow for spherical particles + slip',/, &
!      '# If no fall model is specified, FV_ID = 1, by default',/, &
!      '# The grain size bins can be enters with 2, 3, or 4 parameters.',/, &
!      '# If TWO are given, they are read as:   FallVel (in m/s), mass fraction',/, &
!      '# If THREE are given, they are read as: diameter (mm), mass fraction, density (kg/m3)',/, &
!      '# If FOUR are given, they are read as:  diameter (mm), mass fraction, density (kg/m3), Shape F',/, &
!      '# The shape factor is given as in Wilson and Huang: F=(b+c)/(2*a), but converted',/, &
!      '# to sphericity (assuming b=c) for the Ganser model.',/, &
!      '# If a shape factor is not given, a default value of F=0.4 is used.',/, &
!      '# If FIVE are given, they are read as:  diameter (mm), mass fraction, density (kg/m3), Shape F, G',/, &
!      '#  where G is an additional Ganser shape factor equal to c/b',/, &
!      '#  ',/, &
!      '# If the last grain size bin has a negative diameter, then the remaining mass fraction',/, &
!      '# will be distributed over the previous bins via a log-normal distribution in phi.',/, &
!      '# The last bin would be interpreted as:',/, &
!      '# diam (neg value) , phi_mean, phi_stddev ')
!2071  format( &
!      '******************* BLOCK 7 *************************************************** ',/, &
!      '12                           #Number of settling velocity groups',/, &
!      '2        0.06118 800     0.44',/, &
!      '1        0.07098 1040    0.44',/, &
!      '0.5      0.22701 1280    0.44',/, &
!      '0.25     0.21868 1520    0.44',/, &
!      '0.1768   0.05362 1640    0.44',/, &
!      '0.125    0.04039 1760    0.44',/, &
!      '0.088    0.02814 1880    0.44',/, &
!      '0.2176   0.018   600     1.0',/, &
!      '0.2031   0.072   600     1.0',/, &
!      '0.1895   0.12    600     1.0',/, &
!      '0.1768   0.072   600     1.0',/, &
!      '0.1649   0.018   600     1.0')
!2080  format( &
!      '******************************************************************************* ',/, &
!      '# Options for writing vertical profiles ',/, &
!      '# The first line below gives the number of locations (nlocs) where vertical ',/, &
!      '# profiles are to be written.  That is followed by nlocs lines, each of which ',/, &
!      '# contain the location, in the same coordinates as the computational grid.',/, &
!      '# Optionally, a site name can be provided in after the location. ',/, &
!      '******************* BLOCK 8 *************************************************** ')
!2081  format( &
!      '0                             #number of locations for vertical profiles (nlocs)  ')
!2090  format( &
!      '******************************************************************************* ',/, &
!      '# netCDF output options ',/, &
!      '# This last block is optional.',/, &
!      '# The output file name can be give, but will default to 3d_tephra_fall.nc if absent',/, &
!      '# The title and comment lines are passed through to the netcdf header of the',/, &
!      '# output file. ')
!2091  format( &
!      '******************* BLOCK 9 *************************************************** ',/, &
!      '3d_tephra_fall.nc             # Name of output file  ',/, &
!      'Ash3d_web_run_dp              # Title of simulation  ',/, &
!      'no comment                    # Comment  ')
!2100  format( &
!      '***********************',/, &
!      '# Reset parameters',/, &
!      '***********************')
!2101  format( &
!      'OPTMOD=RESETPARAMS',/, &
!      'cdf_run_class        = ',i3)
2200  format( &
      '*******************************************************************************',/, &
      '# Topography',/, &
      '# Line 1 indicates whether or not to use topography followed by the integer flag',/, &
      '#        describing how topography will modify the vertical grid.',/, &
      '#          0 = no vertical modification; z-grid remains 0-> top throughout the domain',/, &
      '#          1 = shifted; s = z-z_surf; computational grid is uniformly shifted upward',/, &
      '#              everywhere by topography',/, &
      '#          2 = sigma-altitude; s=z_top(z-z_surf)/(z_top-z_surf); topography has decaying',/, &
      '#              influence with height',/, &
      '# Line 2 indicates the topography data format followed by the smoothing radius in km',/, &
      '# Topofile format must be one of',/, &
      '#   1 : Gridded lon/lat (netcdf): ETOPO, GEBCO',/, &
      '#   2 : Gridded Binary: NOAA GLOBE, GTOPO30',/, &
      '#   3 : ESRI ASCII',/, &
      '#  Line 3 is the file name of the topography data. ',/, &
      '#')
2201  format( &
      '******************* BLOCK 10+ *************************************************',/, &
      'OPTMOD=TOPO',/, &
      'no  0                           # use topography?; z-mod (0=none,1=shift,2=sigma)',/, &
      '1 20.0                          # Topofile format, smoothing radius',/, &
      'GEBCO_2023.nc                   # topofile name',/, &
      '*******************************************************************************')

      end program makeAsh3dinput2_dp
