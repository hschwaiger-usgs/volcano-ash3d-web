      program convert_to_decimal

!     program that converts a number in scientific notation to one in decimal 
!     notation to avoid syntax errors when the shell script does arithmetic
!     using the utility bc

      implicit none

      integer           :: nargs
      character(len=80) :: linebuffer
      integer           :: status
      real              :: numnow

      !nargs = iargc()
      nargs = command_argument_count()
      if (nargs.eq.1) then
        call get_command_argument(1, linebuffer, status)
        !call getarg(1,linebuffer)
        read(linebuffer,*,err=2000) numnow
      else
        goto 2000
      endif
      write(6,1) numnow
1     format(f14.8)

      return

2000  write(6,*) 'error running convert_to_decimal'
      stop 1

      end program convert_to_decimal
