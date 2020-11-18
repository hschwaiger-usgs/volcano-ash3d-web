      program citywriter

!     program the reads from a list of cities and figures out which ones to include
!     on a map.

      implicit none
      integer            :: iostatus = 1
      integer            :: i, nargs, ncities, nmax, nread
      integer            :: status
      integer            :: resolution                              !# of cells in x and y
      !integer            :: CityRank
      character(len=26)  :: CityName
      character(len=26)  :: CityName_out(20)
      character(len=133) :: inputline
      character(len=9)   :: lonLL_char, lonUR_char, latLL_char, latUR_char
      !character(len=1)   :: answer
      real(kind=8)       :: CityLat, CityLat_out(20), CityLon, CityLon_out(20)
      real(kind=8)       :: latLL, latUR, lonLL, lonUR, dlat, dlon, cell_width, cell_height
      real(kind=8)       :: minspace_x, minspace_y
      logical            :: IsOkay                 !true if city is not near any others
      logical            :: IsThere

      write(6,*) 'starting citywriter'

      CityName_out = ''           !set default values
      CityLon_out  = 0.0_8
      CityLat_out  = 0.0_8
      nmax         = 20           !maximum number of cities plotted
      resolution   = 100          !number of cells in width & height

      !read input arguments
      !nargs=iargc()
      nargs = command_argument_count()

      if (nargs.eq.4) then
        call get_command_argument(1, lonLL_char, status)
        call get_command_argument(2, lonUR_char, status)
        call get_command_argument(3, latLL_char, status)
        call get_command_argument(4, latUR_char, status)
        !call getarg(1,lonLL_char)
        !call getarg(2,lonUR_char)
        !call getarg(3,latLL_char)
        !call getarg(4,latUR_char)
        read(lonLL_char,*) lonLL
        read(lonUR_char,*) lonUR
        read(latLL_char,*) latLL
        read(latUR_char,*) latUR

        !error check on latitude
        if (latUR.lt.latLL) then
          write(6,*) 'error: upper right latitude < lower left latitude'
          write(6,*) 'map boundaries should be entered as lonLL, lonUR, latLL, latUR'
          write(6,*) 'program stopped'
          stop 1
        endif

        ! make sure everything between -180 and 180 degrees.
        if (lonLL.gt.180.0_8) lonLL=lonLL-360.0_8
        if (lonUR.gt.180.0_8) lonUR=lonUR-360.0_8
        ! if the model domain wraps across the prime meridian add 360 to longitude
        if (lonLL.gt.lonUR)lonUR = lonUR + 360.0_8

        dlat = latUR - latLL
        dlon = lonUR - lonLL
        cell_width = dlon/resolution
        cell_height = dlat/resolution
        minspace_x  = 3.0_8*cell_width
        minspace_y  = 3.0_8*cell_height

!        write(6,1) lonLL, lonUR, latLL, latUR
!1       format('lonLL=',f9.4,', lonUR=',f9.4,', latLL=',f8.4,', latUR=',f8.4)
      else
        write(6,*) 'error: this program requires four input arguments:'
        write(6,*) 'the lower left and upper right longitude,'
        write(6,*) 'and the lower left and upper right latitude.'
        write(6,*) 'You have specified ',nargs, ' input arguments.'
        write(6,*) 'program stopped'

        call get_command_argument(1, lonLL_char, status)
        !call getarg(1,lonLL_char)
        write(6,*) 'argument 1=',lonLL_char
        stop 1
      endif

      nread   = 0
      ncities = 0

!      write(6,*) 'reading from world_cities.txt'
      inquire( file='world_cities.txt', exist=IsThere )
      if(.not.IsThere)then
        write(6,*)"ERROR: Could not find file world_cities.txt."
        write(6,*)"       Please copy file to cwd"
        stop 1
      endif
      open(unit=12,file='world_cities.txt')

      read(12,*)                                     !skip the first line
      do while ((ncities.lt.nmax).and.(iostatus.ge.0))
        read(12,'(a133)',IOSTAT=iostatus) inputline
        read(inputline,2) CityLon, CityLat, CityName
2       format(f16.4,f15.4,a26)
        if ((CityLon.gt.lonLL).and.(CityLon.lt.lonUR).and. &
            (CityLat.gt.latLL).and.(CityLat.lt.latUR)) then
          ! Make sure this city is not near any others
          IsOkay=.true.
!          write(6,4) 
!4         format('                      City       lon       lat')
!          write(6,5) CityName, CityLon, CityLat
!5         format(a26,2f10.4)
          call space_checker(CityLon_out,CityLat_out,CityName_out,ncities, & 
                             CityLon,CityLat, &
                             minspace_x,minspace_y,IsOkay)
          if (IsOkay) then
            ncities = ncities+1
            CityName_out(ncities) = CityName
            CityLon_out(ncities)  = CityLon
            CityLat_out(ncities)  = CityLat
          endif
          ! if the model domain crosses over the prime meridian
        elseif ((CityLon+360.0_8.gt.lonLL).and.(CityLon+360.0_8.lt.lonUR).and. &
                (CityLat.gt.latLL).and.(CityLat.lt.latUR)) then
          ! Make sure this city is not near any others
          IsOkay=.true.
          call space_checker(CityLon_out,CityLat_out,CityName_out,ncities, & 
                             CityLon,CityLat, &
                             minspace_x,minspace_y,IsOkay)
          if (IsOkay) then
            ncities = ncities+1
            CityName_out(ncities) = CityName
            CityLon_out(ncities)  = CityLon
            CityLat_out(ncities)  = CityLat
          endif
        endif
        nread=nread+1
      enddo

!      write(6,*) 'writing to cities.xy'
      if (ncities.gt.0) then
        open(unit=13,file='cities.xy')
        do i=1,ncities
          write(13,3) CityLon_out(i),CityLat_out(i),CityName_out(i)
3         format(2f10.4,'  10  0  9  BL    ',a26)
        enddo
        close(13)
      endif

      write(6,*) 'wrote ',ncities,' to cities.xy'

      close(12)
      close(13)

      write(6,*)"citywriter ended normally."
      stop 0

      end program citywriter
         
!***************************************************************************************

      subroutine space_checker(CityLon_out,CityLat_out,CityName_out,ncities, & 
                                  CityLon,CityLat, &
                                  minspace_x,minspace_y,IsOkay)
      implicit none

      integer            :: icity, ncities
      real(kind=8)       :: CityLat, CityLat_out(20), CityLon, CityLon_out(20)
      character(len=26)  :: CityName_out(20)
      !character(len=1)   :: answer
      real(kind=8)       :: minspace_x, minspace_y
      logical            :: IsOkay                 !true if city is not near any others

!      write(6,*) 'compare with:'
      do icity=1,ncities
!        write(6,6) CityName_out(icity), CityLon_out(icity), CityLat_out(icity)
!6       format(a26,2f10.4)
        if ((abs(CityLon_out(icity)-CityLon).lt.minspace_x).and. &
            (abs(CityLat_out(icity)-CityLat).lt.minspace_y)) then
!          write(6,*) 'too close'
          IsOkay=.false.
          exit
        endif
      enddo

      !write(6,*) 'continue?'
      !read(5,'(a1)') answer
      !if (answer.eq.'n') stop

      return

      end subroutine
