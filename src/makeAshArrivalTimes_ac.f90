       program MakeAshArrivalTimes_ac

!      program that takes the file AshArrivalTimes.txt for airborne runs and
!      removes the deposit information, writing out a new file,
!      AshArrivalTimes_ac.txt

       implicit none

       integer           :: iargc, nargs
       integer           :: status
       character(len=100):: arg
       integer           :: nerupt

       character(len=99) :: inputline
       character(len=99) :: inputlines(3000)
       character(len=5)  :: hoursminutes
       character(len=1)  :: morethan(3000)
       real              :: arrival_time(3000), duration(3000)
       integer           :: i, n_airports

       write(6,*) 'running MakeAshArrivalTimes_ac'

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = iargc()
      if (nargs.eq.0) then
        nerupt=1
      elseif (nargs.eq.1) then
        call get_command_argument(1, arg, status)
        read(arg,*)nerupt
      endif

       open(unit=10,file='AshArrivalTimes.txt',status='old',err=2000)
       open(unit=11,file='AshArrivalTimes_ac.txt')

       do i=1,17+nerupt                                !read header lines
           read(10,1) inputline
           write(11,1) inputline
       end do

       i = 1
       read(10,1) inputline
       do while (inputline(1:5).ne.'-----')
           if (inputline(80:87).eq.'       ') go to 14
           read(inputline,2) arrival_time(i), morethan(i), duration(i)
2          format(79x,f7.2,3x,a1,f5.2)
           if (abs(arrival_time(i)+9999).gt.1.e-05) then
              write(inputlines(i),13) inputline(1:79), hoursminutes(arrival_time(i)), &
                                      morethan(i),  hoursminutes(duration(i))
13            format(a79,2x,a5,3x,a1,a5,'   |')
              i = i+1
           end if
14         read(10,1) inputline
       end do

       n_airports=i-1

       if (n_airports.eq.0) then
          write(11,*) 'No airports affected by ash'
        else if (n_airports.eq.1) then
          write(11,1) inputlines(1)
1         format(a99)
        else
          call sorter(n_airports,inputlines,arrival_time)
          do i=1,n_airports
              write(11,1)  inputlines(i)
          end do
       end if

       write(11,4)
       close(10)
       close(11)

       write(*,*)"makeAshArrivalTimes_ac ended normally."
       !return
       stop 0

!----------------------------------------------------------------------------------------

4      format('---------------------------------------------------------------------------------------------------',//, &
              'NOTES ON ITEMS IN THIS TABLE:',/, &
              'LOCATION: If the location is an airport, the first three letters are the ICAO airport code',/, &
              'CLOUD DATA: Cloud arrival time is given in hours after the eruption start and the date and',/, &
              '  time in UTC,in the format yyyy-mm-ddThh:mm:ssZ).  Duration is the number of hours during'  ,/, &
              '  which the cloud is overhead (or, if there is a break in the cloud, the time from the clouds ',/, &
              '  first arrival until it last passes).  A character ">" in front of the duration indicates '   ,/, &
              '  that the cloud was still overhead at the end of the simulation. The vertically integrated '  ,/, &
              '  cloud mass must exceed a threshold value of 0.2 tonnes per square kilometer to be considered',/, &
              '  in these calculations.',/, &
              'ERUPTED VOLUME:  For airborne ash simulations, the erupted volume given in the source parameters',/, &
              '  is not the total volume, but the erupted volume that makes it into the distal cloud, which is',/, &
              '  set at 5% of the total volume.',//, &
              'NOTE: This table is the estimate at time of issuance: changing conditions at the volcano may',/, &
              '  require updating the forecast.')
       stop 1

2000   write(6,*) 'error: AshArrivalTimes.txt cant be found.  Stopping'
       stop 1

       end program MakeAshArrivalTimes_ac

!*******************************************************************************

      subroutine sorter(n_airports,inputlines,arrival_time)

!     subroutine that sorts inputlines according to arrival time


       character(len=99) :: inputlines(3000), inputline
       real              :: arrival_time(3000), a
       integer           :: i,j, n_airports

       !Insertion and shell routine as described in Numerical Recipes for F77,
       !Second Edition, page 320-322.
       do j=2,n_airports
            a         = arrival_time(j)
            inputline = inputlines(j)
            do i=j-1,1,-1
               if (arrival_time(i).le.a) go to 10
               arrival_time(i+1) = arrival_time(i)
               inputlines(i+1)   = inputlines(i)
            end do
            i = 0
10         arrival_time(i+1) = a
           inputlines(i+1)   = inputline
       end do
       return

       end subroutine sorter

!******************************************************************************
       function hoursminutes(hours)

       !function that returns a five-character string with format "hh:mm", given 
       !a real(kind=ip) number in decimal hours

       implicit none
       real              :: hours, minutes
       integer           :: int_minutes, int_hours
       character(len=5)  :: hoursminutes
       !character(len=1)  :: answer

       if (hours.eq.-9999.0) then
             hoursminutes = '--:--'
         else
            int_hours = int(hours)
            minutes = (hours-int(hours))*60.0
            int_minutes = int(minutes)
            write(hoursminutes,1) int_hours, int_minutes
1           format(i2.2,':',i2.2)
       end if

       return
       end function hoursminutes

