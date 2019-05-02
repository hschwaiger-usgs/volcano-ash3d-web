      program convert_to_decimal

!     program that converts a number in scientific notation to one in decimal 
!     notation to avoid syntax errors when the shell script does arithmetic
!     using the utility bc

      implicit none
      integer           :: iargc, nargs
      character(len=80) :: linebuffer
      real              :: numnow

      nargs = iargc()
      if (nargs.eq.1) then
         call getarg(1,linebuffer)
         read(linebuffer,*,err=2000) numnow
       else
         go to 2000
      end if
      write(6,1) numnow
1     format(f14.8)
      stop 0

2000  write(6,*) 'error running convert_to_decimal'
      stop 1

      end program convert_to_decimal
