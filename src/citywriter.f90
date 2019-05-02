      program citywriter

!     program the reads from a list of cities and figures out which ones to include
!     on a map.

      implicit none
      integer            :: iostatus = 1
      integer            :: i, iargc, nargs, ncities, nmax
      !integer            :: CityRank
      character(len=26)  :: CityName, CityName_out(20)
      character(len=133) :: inputline
      character(len=9)   :: lonLL_char, lonUR_char, latLL_char, latUR_char
      !character(len=1)   :: answer
      real(kind=8)       :: CityLat, CityLat_out(20), CityLon, CityLon_out(20), latLL, latUR, lonLL, lonUR

      !write(6,*) 'starting citywriter'

      CityName_out = ''           !set default values
      CityLon_out  = 0.0_8
      CityLat_out  = 0.0_8
      nmax         = 20           !maximum number of cities plotted

      !read input arguments
      nargs=iargc()
      if (nargs.eq.4) then
           call getarg(1,lonLL_char)
           call getarg(2,lonUR_char)
           call getarg(3,latLL_char)
           call getarg(4,latUR_char)
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
            end if

           !make sure everything between -180 and 180 degrees.
           if (lonLL.gt.180.) lonLL=lonLL-360.
           if (lonUR.gt.180.) lonUR=lonUR-360.
           !if the model domain wraps across the prime meridian add 360 to longitude
           if (lonLL.gt.lonUR)        lonUR = lonUR + 360.0

!           write(6,1) lonLL, lonUR, latLL, latUR
!1          format('lonLL=',f9.4,', lonUR=',f9.4,', latLL=',f8.4,', latUR=',f8.4)
         else
           write(6,*) 'error: this program requires four input arguments:'
           write(6,*) 'the lower left and upper right longitude,'
           write(6,*) 'and the lower left and upper right latitude.'
           write(6,*) 'You have specified ',nargs, ' input arguments.'
           write(6,*) 'program stopped'

           call getarg(1,lonLL_char)
           write(6,*) 'argument 1=',lonLL_char
           stop 1
      end if

      ncities = 0

!      write(6,*) 'reading from world_cities.txt'
      open(unit=12,file='world_cities.txt')
      !open(unit=12,file='cities5000.txt')
      read(12,*)                                     !skip the first line
      do while ((ncities.lt.nmax).and.(iostatus.ge.0))
         read(12,'(a133)',IOSTAT=iostatus) inputline
         !read(inputline,*)  CityLon, CityLat
         !read(inputline,2)  CityName
!2         format(32x,a20)
          read(inputline,2) CityLon, CityLat, CityName
          !write(6,*) 'CityLon=',CityLon,', CityLat=',CityLat,', CityName=',CityName
          !write(6,*) 'continue?'
          !read(5,'(a1)') answer
          !if (answer.eq.'n') stop 1
2        format(f16.4,f15.4,a26)
         if ((CityLon.gt.lonLL).and.(CityLon.lt.lonUR).and. &
             (CityLat.gt.latLL).and.(CityLat.lt.latUR)) then
               ncities = ncities+1
               CityName_out(ncities) = CityName
               CityLon_out(ncities)  = CityLon
               CityLat_out(ncities)  = CityLat
            !if the model domain crosses over the prime meridian
            else if ((CityLon+360..gt.lonLL).and.(CityLon+360..lt.lonUR).and. &
                     (CityLat.gt.latLL).and.(CityLat.lt.latUR)) then
               ncities = ncities+1
               CityName_out(ncities) = CityName
               CityLon_out(ncities)  = CityLon
               CityLat_out(ncities)  = CityLat
         end if
      end do

!      write(6,*) 'writing to cities.xy'
      if (ncities.gt.0) then
          open(unit=13,file='cities.xy')
          do i=1,ncities
               write(13,3) CityLon_out(i),CityLat_out(i),CityName_out(i)
!              write(6,3) CityLon_out(i),CityLat_out(i),CityName_out(i)
3              format(2f10.4,'  10  0  9  BL    ',a26)
          end do
          close(13)
      end if

!      write(6,*) 'ncities=',ncities

      close(12)
      close(13)

      end program citywriter
         
