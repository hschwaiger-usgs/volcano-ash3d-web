      program legend_placer_dp_mm

!     Program determines the coordinates of legends on maps generated by 
!     GFSVolc_to_gif_dp.sh and GFSVolc_to_gif_dp_mm.sh
!     This is essentially very similar to legend_placer_ac, but this program
!     also takes into consideration the location of the deposit

      implicit none

      real(kind=8) :: caveats_height, dlat, dlon
      real(kind=8) :: latmax, latmax_rad, latmin, latmin_rad
      real(kind=8) :: lat_now, lon_now
      real(kind=8) :: legend1x_position, legend1y_position
      real(kind=8) :: legend1x_LR, legend1x_UL
      real(kind=8) :: legend1y_LR, legend1y_UL
      real(kind=8) :: legend1x_LL_alt, legend1x_UL_alt
      real(kind=8) :: legend1y_LL_alt, legend1y_UL_alt
      real(kind=8) :: legend1_height, legend1_width
      real(kind=8) :: legend2x_position, legend2y_position
      real(kind=8) :: legend2x_UL, legend2x_UR
      real(kind=8) :: legend2y_UL, legend2y_UR
      real(kind=8) :: legend2x_LL_alt, legend2x_UL_alt, legend2x_UR_alt
      real(kind=8) :: legend2y_LL_alt, legend2y_UL_alt, legend2y_UR_alt
      real(kind=8) :: legend2x_LL_alt2, legend2x_UL_alt2
      real(kind=8) :: legend2y_LL_alt2, legend2y_UL_alt2
      real(kind=8) :: legend2_height, legend2_width
      real(kind=8) :: lonmax, lonmax_rad, lonmin, lonmin_rad
      real(kind=8) :: map_height, map_width
      real(kind=8) :: pi
      real(kind=8) :: xLL,xLR,xUL,    xleft_map,xright_map
      real(kind=8) :: yLL,yLR,yUL,yUR,ybottom_map,ytop_map
      real(kind=8) :: vclat, vclon
      real(kind=8) :: lat_to_pixels, pixels_to_lat
      integer  :: Iostatus =1
      integer  :: legend2x_pixels, legend2y_pixels
      logical  :: legend1_overlaps, legend1_alt_overlaps
      logical  :: legend2_overlaps, legend2_alt_overlaps, legend2_alt2_overlaps, wrap_lon
      logical  :: legend1_overlaps_volcano, legend1_alt_overlaps_volcano
      logical  :: legend2_overlaps_volcano, legend2_alt_overlaps_volcano
      logical  :: legend2_alt2_overlaps_volcano
      character(len=80) :: inputline
      character(len=1)  :: test_char

      !set constants
      pi             = 3.14159

      !set dimensions of map and legends.  All dimensions are in pixels unless specified
      map_width       = 20.*72./2.54       !width of map, pixels
      legend1_width   = 219.0              !width of legend containin ESP's
      legend1_height  = 96.0
      legend2_width   = 100.0              !width of legend_dep_mm.gif
      legend2_height  = 231.0
      xleft_map       = 31.0               !x offset of left side of map
      xright_map      = 631.0-598.0        !x offset of right side of map from right side of image
      ybottom_map     = 545.0-462.0        !y offset of base of map from base of image
      ytop_map        = 22.0               !y offset of top of map from top of image
      caveats_height  = 91.0

      !set overlap booleans
      legend1_overlaps      = .false.       !=.true. if legend1 covers contours
      legend1_alt_overlaps  = .false.       !=.true. if legend1 in alt. position covers contours
      legend2_overlaps      = .false.       !=.true. if legend2 covers contours
      legend2_alt_overlaps  = .false.       !=.true. if legend2 in alt. position covers contours
      legend2_alt2_overlaps = .false.       !=.true. if legend2 in alt. position covers contours
      legend1_overlaps_volcano      = .false.       !=.true. if legend1 covers contours
      legend1_alt_overlaps_volcano  = .false.       !=.true. if legend1 in alt. position covers contours
      legend2_overlaps_volcano      = .false.       !=.true. if legend2 covers contours
      legend2_alt_overlaps_volcano  = .false.       !=.true. if legend2 in alt. position covers contours
      legend2_alt2_overlaps_volcano = .false.       !=.true. if legend2 in alt. position covers contours
      wrap_lon              = .false.       !=.true. if longitude wraps across the antimeridian

      !open map_range.txt and read range of latitute, longitude
      open(unit=10,file='map_range.txt')
      read(10,*) lonmin, lonmax, latmin, latmax, vclon, vclat
      close(10)
      lonmin_rad = lonmin*pi/180.
      lonmax_rad = lonmax*pi/180.
      latmin_rad = latmin*pi/180.
      latmax_rad = latmax*pi/180.
      dlon       = lonmax-lonmin
      if (dlon.lt.0.) then
             dlon     = dlon+360.
             wrap_lon = .true.
      end if
      dlat       = latmax-latmin

      !adjust offsets depending on latitude (some labels are wider than others)
      if (latmin.lt.-10.0) then
           xleft_map=40.0
           xright_map = 41.0
      end if

      !calculate map scale, km per cm at the latitude of the volcano
      map_height = ((map_width*180.)/(pi*dlon)) * &
                     log(tan(pi/4.+latmax_rad/2.)/ &
                         tan(pi/4.+latmin_rad/2.))
      write(6,6) int(map_width), int(map_height), &
                 int(map_width+xleft_map+xright_map), int(map_height+ytop_map+ybottom_map)
6     format('    Estimated map and figure dimensions (pixels)',/, &
             '             width   height',/, &
             '    map      ',i4,i8,/, &
             '    figure   ',i4,i8)

!***************************************************************************************************************
      !FIND POSITIONS FOR LEGENDS

      !Positiions for legends
      !---------------------------------------------------------!
      ! legend1                        legend1_alt, legend2_alt !
      !                                                         !
      !                                                         !
      !                                                         !
      ! legend2                                    legend2_alt2 !
      !                                                         !
      !                                                         !
      !                                                         !
      !                                                         !
      !                                              USGS_vid   !
      !---------------------------------------------------------!

      !calculate upper left, lower right corners of ESP legend
      !NOTE: THESE COORDINATES ARE IN LATITUDE/LONGITUDE
      legend1x_UL = lonmin+0.02*dlon                                            !find UL in lat, lon
      legend1y_UL = latmin+0.98*dlat
      xUL         = xleft_map+dlon*(0.02+legend1_width/map_width)                 !convert to x, y
      yUL         = lat_to_pixels(ytop_map,map_height,latmin,latmax,legend1y_UL)
      xLR         = xUL + legend1_width                                         !find LR in x, y
      yLR         = yUL + legend1_height
      legend1x_LR = legend1x_UL+dlon*(legend1_width/map_width)
      legend1y_LR = pixels_to_lat(ytop_map,map_height,latmin,latmax,yLR)

      !calculate upper right, lower left corners of ESP legend (alternate placement)
      xLL             = xleft_map+0.98*map_width-legend1_width
      legend1x_LL_alt = lonmin+dlon*((xLL-xleft_map)/map_width)
      legend1y_LL_alt = legend1y_LR
      legend1x_UL_alt = legend1x_LL_alt
      legend1y_UL_alt = legend1y_UL

      !calculate corners of contour legend
      yUR         = ytop_map+0.98*map_height - legend2_height
      legend2x_UR = lonmin+dlon*(0.02+legend2_width/map_width)
      legend2y_UR = pixels_to_lat(ytop_map,map_height,latmin,latmax,yUR)
      legend2x_UL = legend1x_UL
      legend2y_UL = legend2y_UR

      !calculate corners of contour legend, alternate position
      legend2x_UR_alt = lonmin+0.98*dlon                                       !find UR in lat, lon
      legend2y_UR_alt = legend1y_UL
      legend2x_LL_alt = lonmax-dlon*(0.02+legend2_width/map_width)              !find LL in lon
      yLL             = ytop_map+0.02*map_height+legend2_height
      legend2y_LL_alt = pixels_to_lat(ytop_map,map_height,latmin,latmax,yLL)         !convert yLL to LL in lat
      legend2x_UL_alt = legend2x_LL_alt
      legend2y_UL_alt = legend2y_UR_alt

      !Corners of the contour legends, alternate position #2
      legend2x_UL_alt2 = legend2x_LL_alt                                        !find UL in lat, lon
      legend2y_UL_alt2 = legend1y_LL_alt-0.02*dlat
      legend2x_LL_alt2 = legend2x_LL_alt                                        !find LL in lon
      yLL = lat_to_pixels(ytop_map,map_height,latmin,latmax,legend2y_UL_alt2) &      !find LL in y
             + legend2_height
      legend2y_LL_alt2 = pixels_to_lat(ytop_map,map_height,latmin,latmax,yLL)        !convert to lat

!**************************************************************************************************************

      !READ FILES WITH CONTOUR LINES

      !Open first file
      !there are at least three possible names for this file, so we have
      !to try all of them
      write(6,*) 'trying to open contourfile_0.1_0_i.xyz'
      open(unit=12,file='contourfile_0.1_0_i.xyz',status='old',err=200)  !file name if it's a closed contour
      write(6,*) '   opening contourfile_0.1_0_i.xyz'
      go to 240
200   write(6,*) 'Couldnt find   contourfile_0.1_0_i.xyz'
      write(6,*) 'trying to open contourfile_0.1_0.xyz'
      open(unit=12,file='contourfile_0.1_0.xyz',status='old',err=250)    !file name if it's not
      write(6,*) '   opening contourfile_0.1_0.xyz'
!      write(6,1)                                 !write table header
!1     format('       lon       lat        L1    L1_alt        L2    L2_alt   L2_alt2')
240   do while (Iostatus.ge.0)
         !Read in latitude & longitude
         read(12,'(a80)',IOSTAT=Iostatus) inputline
         read(inputline,'(a1)') test_char
         IF(test_char.eq.'>')THEN
           read(12,'(a80)',IOSTAT=Iostatus) inputline
         ENDIF
         read(inputline,*) lon_now, lat_now
         !Adjust longitude if the region crosses the antimeridian
         !if ((wrap_lon.eqv..true.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         if ((lonmax.gt.180.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         !See whether any of the legend positions overlap these points
         if  ((lon_now<legend1x_LR)     .and.(lat_now>legend1y_LR))      legend1_overlaps     =.true.
         if  ((lon_now>legend1x_LL_alt) .and.(lat_now>legend1y_LL_alt))  legend1_alt_overlaps =.true.
         if  ((lon_now<legend2x_UR)     .and.(lat_now<legend2y_UR))      legend2_overlaps     =.true.
         if  ((lon_now>legend2x_LL_alt) .and.(lat_now>legend2y_LL_alt))  legend2_alt_overlaps =.true.
         if (((lon_now>legend2x_UL_alt2).and.(lat_now<legend2y_UL_alt2)).and. &
             ((lon_now>legend2x_LL_alt2).and.(lat_now>legend2y_LL_alt2)))legend2_alt2_overlaps=.true.

         !write out results
         !write(6,2) lon_now, lat_now, legend1_overlaps, legend1_alt_overlaps, legend2_overlaps, &
         !                                               legend2_alt_overlaps, legend2_alt2_overlaps
!2        format(2f10.3,5L10)
      end do
      close(12)

      !See if there are other files of isolated contours
      Iostatus = 1
      write(6,*) '   Looking for contourfile_0.1_1_i.xyz'
      open(unit=13,file='contourfile_0.1_1_i.xyz',status='old',err=350)
      write(6,*) '   found contourfile_0.1_1_i.xyz'
      do while (Iostatus.ge.0)
         !Read in latitude & longitude
         read(13,'(a80)',IOSTAT=Iostatus) inputline
         read(inputline,'(a1)') test_char
         IF(test_char.eq.'>')THEN
           read(13,'(a80)',IOSTAT=Iostatus) inputline
         ENDIF
         read(inputline,*) lon_now, lat_now
         !Adjust for regions that cross the antimeridian
         !if ((wrap_lon.eqv..true.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         if ((lonmax.gt.180.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         !See whether any of the legend positions overlap these points
         if  ((lon_now<legend1x_LR)     .and.(lat_now>legend1y_LR))      legend1_overlaps     =.true.
         if  ((lon_now>legend1x_LL_alt) .and.(lat_now>legend1y_LL_alt))  legend1_alt_overlaps =.true.
         if  ((lon_now<legend2x_UR)     .and.(lat_now<legend2y_UR))      legend2_overlaps     =.true.
         if  ((lon_now>legend2x_LL_alt) .and.(lat_now>legend2y_LL_alt))  legend2_alt_overlaps =.true.
         if (((lon_now>legend2x_UL_alt2).and.(lat_now<legend2y_UL_alt2)).and. &
             ((lon_now>legend2x_LL_alt2).and.(lat_now>legend2y_LL_alt2)))legend2_alt2_overlaps=.true.
         !write out results
         !write(6,2) lon_now, lat_now, legend1_overlaps, legend1_alt_overlaps, legend2_overlaps, &
         !                                               legend2_alt_overlaps, legend2_alt2_overlaps
      end do
      close(13)

      Iostatus = 1
      write(6,*) '   Looking for contourfile_0.1_2_i.xyz'
      open(unit=14,file='contourfile_0.1_2_i.xyz',status='old',err=350)
      write(6,*) '   found contourfile_0.1_2_i.xyz'
      do while (Iostatus.ge.0)
         !Read in latitude & longitude
         read(14,'(a80)',IOSTAT=Iostatus) inputline
         read(inputline,'(a1)') test_char
         IF(test_char.eq.'>')THEN
           read(14,'(a80)',IOSTAT=Iostatus) inputline
         ENDIF
         read(inputline,*) lon_now, lat_now
         !Adjust for regions that cross the antimeridian
         !if ((wrap_lon.eqv..true.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         if ((lonmax.gt.180.).and.(lon_now.lt.0.)) lon_now=lon_now+360.
         !See whether any of the legend positions overlap these points
         if  ((lon_now<legend1x_LR)     .and.(lat_now>legend1y_LR))      legend1_overlaps     =.true.
         if  ((lon_now>legend1x_LL_alt) .and.(lat_now>legend1y_LL_alt))  legend1_alt_overlaps =.true.
         if  ((lon_now<legend2x_UR)     .and.(lat_now<legend2y_UR))      legend2_overlaps     =.true.
         if  ((lon_now>legend2x_LL_alt) .and.(lat_now>legend2y_LL_alt))  legend2_alt_overlaps =.true.
         if (((lon_now>legend2x_UL_alt2).and.(lat_now<legend2y_UL_alt2)).and. &
             ((lon_now>legend2x_LL_alt2).and.(lat_now>legend2y_LL_alt2)))legend2_alt2_overlaps=.true.
         !write out results
         !write(6,2) lon_now, lat_now, legend1_overlaps, legend1_alt_overlaps, legend2_overlaps, &
         !                                               legend2_alt_overlaps, legend2_alt2_overlaps
      end do
      close(14)

350   continue

!*******************************************************************************************************

      !See if the volcano overlaps any of these legend locations
      if  ((vclon<legend1x_LR)     .and.(vclat>legend1y_LR))      legend1_overlaps_volcano     =.true.
      if  ((vclon>legend1x_LL_alt) .and.(vclat>legend1y_LL_alt))  legend1_alt_overlaps_volcano =.true.
      if  ((vclon<legend2x_UR)     .and.(vclat<legend2y_UR))      legend2_overlaps_volcano     =.true.
      if  ((vclon>legend2x_LL_alt) .and.(vclat>legend2y_LL_alt))  legend2_alt_overlaps_volcano =.true.
      if (((vclon>legend2x_UL_alt2).and.(vclat<legend2y_UL_alt2)).and. &
          ((vclon>legend2x_LL_alt2).and.(vclat>legend2y_LL_alt2)))legend2_alt2_overlaps_volcano=.true.

      write(6,*) 'vclon=',vclon,', vclat=',vclat
      write(6,*) 'legend1x_LR=',legend1x_LR,', legend1y_LR=',legend1y_LR
      write(6,*) 'legend2x_LL_alt=',legend2x_LL_alt,', legend2y_LL_alt=',legend2y_LL_alt
      write(6,*) 'legend1_overlaps_volcano=',legend1_overlaps_volcano
      write(6,*) 'legend1_alt_overlaps_volcano=',legend1_alt_overlaps_volcano
      write(6,*) 'legend2_overlaps_volcano=',legend2_overlaps_volcano
      write(6,*) 'legend2_alt_overlaps_volcano=',legend2_alt_overlaps_volcano
      write(6,*) 'legend2_alt2_overlaps_volcano=',legend2_alt2_overlaps_volcano

      !ADJUST LOCATION OF LEGENDS DEPENDING ON OVERLAPS

      !set default positions
      legend1x_position = legend1x_UL
      legend1y_position = legend1y_UL
      legend2x_position = legend2x_UL
      legend2y_position = legend2y_UL

      !if (legend1_overlaps) then
      !   if (legend2_overlaps) then
      !      legend1x_position = legend1x_UL_alt
      !      legend1y_position = legend1y_UL_alt           
      !      legend2x_position = legend2x_UL_alt2
      !      legend2y_position = legend2y_UL_alt2
      !    else
      !      legend1x_position = legend1x_UL_alt           
      !      legend1y_position = legend1y_UL_alt           
      !   end if
      ! else
      !   if (legend2_overlaps) then
      !      legend2x_position = legend2x_UL_alt
      !      legend2y_position = legend2y_UL_alt
      !   end if
      !end if

      if (legend1_overlaps) then
         if (legend2_overlaps) then
            if (legend1_alt_overlaps_volcano.eqv..false.) then    !Move legend1 only if it doesn't cover volcano
               legend1x_position = legend1x_UL_alt
               legend1y_position = legend1y_UL_alt
            end if
            if (legend2_alt2_overlaps_volcano.eqv..false.) then    !Move legend2 only if it doesn't cover volcano
               legend2x_position = legend2x_UL_alt2
               legend2y_position = legend2y_UL_alt2
            end if
          else
            if (legend1_alt_overlaps_volcano.eqv..false.) then    !Move legend1 only if it doesn't cover volcano
               legend1x_position = legend1x_UL_alt
               legend1y_position = legend1y_UL_alt
            end if
         end if
       else
         if (legend2_overlaps) then
            if (legend2_alt_overlaps_volcano.eqv..false.) then    !Move legend2 only if it doesn't cover volcano
               legend2x_position = legend2x_UL_alt
               legend2y_position = legend2y_UL_alt
            end if
         end if
      end if

      !convert legend2 position from lat/lon to pixels
      legend2x_pixels = floor(xleft_map+map_width*(legend2x_position-lonmin)/dlon)
      legend2y_pixels = floor(lat_to_pixels(ytop_map,map_height,latmin,latmax,legend2y_position))

      write(6,3) legend1x_position, legend1y_position, legend2x_position, legend2y_position, &
                                                       legend2x_pixels,   legend2y_pixels
3     format('    Caption placement:   lon       lat     x     y',/, &
             '    ESP legend    ',2f10.3,/, &
             '    Contour legend',2f10.3,2i6,/, &
             '    writing to legend_positions_dp.txt')

      open(unit=25,file='legend_positions_dp_mm.txt')
      write(25,4) legend1x_position, legend1y_position, legend2x_pixels, legend2y_pixels
4     format('legend1x_UL=',f8.3,  '   legend1y_UL=',f7.3,/, &
             'legend2x_UL=',i3,    '   legend2y_UL=',i3)
      close(25)

      write(*,*)"legend_placer_dp_mm ended normally."
      !return
      stop 0

      !error trap if there is no contour_0.1_0_i.xyz file
250   write(6,*) 'error opening contourfile_0.1_0_i.xyz'
      goto 350

      end program legend_placer_dp_mm
  

!******************************************************************************

      function lat_to_pixels(ytop,map_height,latmin,latmax,latnow)

      !function that calculates the y coordinate on the page in pixels from the top of the page
      !ytop: the # of pixels from the top of the map from the top of the page
      !map_height: the height of the map area on the page in cm
      !latmin:     the latitude at the base of the map
      !latmax:     The latitude at the top of the map
      !latnow      The latitude whose y position you want to convert

      implicit none
      real(kind=8) :: ytop, map_height, latmin, latmax, latnow
      real(kind=8) :: lat_to_pixels, latmax_rad, latmin_rad, latnow_rad
      real(kind=8) :: pi, y

      pi = 3.14159

      latmin_rad = latmin*pi/180.
      latmax_rad = latmax*pi/180.
      latnow_rad = latnow*pi/180.

      y =  ytop + map_height * (1.0 - log(tan(pi/4.+latnow_rad/2.)/tan(pi/4.+latmin_rad/2.)) / &
                                log(tan(pi/4.+latmax_rad/2.)/tan(pi/4.+latmin_rad/2.)))

      lat_to_pixels = y

      return

      end function

!******************************************************************************

      function pixels_to_lat(ytop,map_height,latmin,latmax,ynow)

      !function that calculates the latitude given the y coordinate, where:
      !ytop:       The y offset between the top of the map and the top of the image
      !map_height: the height of the map area on the page in cm
      !latmin:     the latitude at the left edge of the map
      !latmax:     The latitude at the right edge of the map
      !ynow:       The y coordinate in cm from the bottom of the page

      implicit none
      real(kind=8) :: ytop, map_height, latmin, latmax, ycoord, ynow
      real(kind=8) :: latmin_rad, latmax_rad, latnow_rad, pixels_to_lat
      real(kind=8) :: term1, term2, term3
      real(kind=8) :: pi

      pi = 3.14159

      latmin_rad = latmin*pi/180.
      latmax_rad = latmax*pi/180.
      ycoord     = (ytop+map_height) - ynow         !convert to y value above base of map

      term1    = tan(pi/4.+latmin_rad/2.)
      term2    = tan(pi/4.+latmax_rad/2.)
      term3    = exp((ycoord/map_height)*log(term2/term1))

      latnow_rad = 2.*(atan(term1*term3) - pi/4.)

      pixels_to_lat = 180.*latnow_rad/pi

      return

      end function
