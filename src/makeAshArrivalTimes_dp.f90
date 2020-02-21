       program MakeAshArrivalTimes_dp

!      program that takes the file AshArrivalTimes.txt for airborne runs and
!      removes the deposit information, writing out a new file,
!      AshArrivalTimes_ac.txt

       implicit none

       character(len=164)  :: inputline
       character(len=90)   :: inputline_short
       character(len=122) :: inputline_new
       character(len=122) :: inputlines(3000)
       character(len=6)  :: hoursminutes
       real              :: arrival_time(3000), duration(3000)
       integer           :: i, n_airports
       character(len=1)  :: morethan(3000)
       !character(len=1)  :: answer

       n_airports = 0

       write(6,*) 'running MakeAshArrivalTimes_dp'

       open(unit=10,file='AshArrivalTimes.txt',status='old',err=2000)
       open(unit=11,file='AshArrivalTimes_dp.txt')

       do i=1,11                                !read header lines
           read(10,1) inputline_short 
           write(11,1) inputline_short
       end do
       do i=12,18
           read(10,2) inputline
           write(11,3) inputline(1:57), inputline(100:164)
       end do

       i = 1
       read(10,2) inputline
       !write(6,*) 'inputline=',inputline
       do while (inputline.ne.'')
           read(inputline,5) arrival_time(i), morethan(i), duration(i)
           !write(6,*) 'airport=',inputline(1:33)
           !write(6,*) 'i=',i, ', arrival_time(i)=',arrival_time(i),', duration(i)=',duration(i)
           !write(6,*) 'hoursminutes(arrival_time(i))=',hoursminutes(arrival_time(i))
           !write(6,*) 'hoursminutes(duration(i))=',hoursminutes(duration(i))
           !write(6,*) 'continue (y/n)?'
           !read(5,'(a1)') answer
           !if (answer.eq.'n') stop 1
           if (abs(arrival_time(i)+9999.000).gt.1.e-05) then  !skip line if arrival time=-9999
               write(inputline_new,4) inputline(1:57), inputline(100:122), &
                                      hoursminutes(arrival_time(i)), morethan(i), &
                                      hoursminutes(duration(i)), &
                                      inputline(140:164)
               inputlines(i) = inputline_new
               i = i+1
           end if
           read(10,2) inputline
       end do
       n_airports=i-1

       if (n_airports.eq.0) then
           write(11,6)
         else if (n_airports.eq.1) then
           write(11,7) inputlines(1)
         else
           call sorter(n_airports,inputlines,arrival_time)
           do i=1,n_airports
               write(11,7)  inputlines(i)
           end do
       end if

       write(11,8)
       close(10)
       close(11)

       write(*,*)"makeAshArrivalTimes_dp ended normally."
       !return
       stop 0

!----------------------------------------------------------------------------------------

1      format(a90)
2      format(a164)
3      format(a57,a64)
!3      format(a57,a65)
4      format(a57,a22,3x,a6,2x,a1,a6,a24)
5      format(121x,f9.2,3x,a1,f5.2)
6      format(6x,'No airports affected by ash',87x,'|')
7      format(a122)
8      format('-----------------------------------------------------------------------------', &
              '-------------------------------------------|',//, &
              'NOTES ON ITEMS IN THIS TABLE:',/, &
              'LOCATION: If the location is an airport, the first three letters are the ICAO airport code',/, &
              'DEPOSIT DATA:  The deposit arrival time is given in hours since eruption start and in the date and time UTC.',/,&
              '  "Deposit arrival time" is the time of arrival of the deposit at a thickness exceeding 0.01 mm (0.0004 ',/,&
              '  inches).  Deposit duration is the time period (hrs) over which the deposit was falling at a rate exceeding',/,&
              '  0.01 mm/hr.  A ">" character before this number indicates that the deposit was still falling at the end of',/,&
              '  the simulation.  The thickness of the deposit is given in millimeters (left column) and as ranked according',/,&
              '  to the following system devised by the U.S. National Weather Service and U.S. Geological Survey:',/,&
              '        NWS/USGS Rank    Thickness',/,&
              '                           up to',/,&
              '                        mm      in.',/,&
              '        trace           0.8     1/32"',/,&
              '        minor           6.3     1/4"',/,&
              '        substantial    25.4     1"',/,&
              '        heavy          100      4"',/,&
              '        severe        >100     >4"',//,&
              'NOTE: This table is the estimate at time of issuance: changing conditions at the volcano may require updating',/,&
              '  the forecast.')

2000   write(6,*) 'error: AshArrivalTimes.txt cant be found.  Stopping'
       stop 1

       end program MakeAshArrivalTimes_dp

!*******************************************************************************

      subroutine sorter(n_airports,inputlines,arrival_time)

!     subroutine that sorts inputlines according to arrival time


       character(len=122) :: inputlines(3000), inputline
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

!*****************************************************************************

       function hoursminutes(hours)

       !function that returns a five-character string with format "hh:mm", given 
       !a real(kind=ip) number in decimal hours

       implicit none
       real              :: hours, minutes
       integer           :: int_minutes, int_hours
       character(len=6)  :: hoursminutes
       !character(len=1)  :: answer

       if (hours.eq.-9999.0) then
             hoursminutes = '---:--'
         else
            int_hours = int(hours)
            minutes = (hours-int(hours))*60.0
            int_minutes = int(minutes)
            write(hoursminutes,1) int_hours, int_minutes
1           format(i3.3,':',i2.2)
       end if

       return
       end function hoursminutes

