###############################################################################
#  Makefile for Ash3d_webtools
#
#    User-specified flags are in this top block
#
###############################################################################

#      This file is a component of the volcanic ash transport and dispersion model Ash3d,
#      written at the U.S. Geological Survey by Hans F. Schwaiger (hschwaiger@usgs.gov),
#      Larry G. Mastin (lgmastin@usgs.gov), and Roger P. Denlinger (roger@usgs.gov).

#      The model and its source code are products of the U.S. Federal Government and therefore
#      bear no copyright.  They may be copied, redistributed and freely incorporated 
#      into derivative products.  However as a matter of scientific courtesy we ask that
#      you credit the authors and cite published documentation of this model (below) when
#      publishing or distributing derivative products.

#      Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., 2012, Ash3d, a finite-
#         volume, conservative numerical model for ash transport and tephra deposition,
#         Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968. 

#      We make no guarantees, expressed or implied, as to the usefulness of the software
#      and its documentation for any purpose.  We assume no responsibility to provide
#      technical support to users of this software.

#      Sequence of commands:
#      "make"  compiles the Ash3d executable
#      "make all" builds the executables and copies to bin
#      "make install" copies the contents of branches/core_code/bin to the install location
#                        e.g. /opt/USGS/Ash3d
#
#  SYSTEM specifies which compiler to use
#    Current available options are:
#      gfortran , ifort
#    This variable cannot be left blank
SYSTEM = gfortran
#
#  RUN specifies which collection of compilation flags that should be run
#    Current available options are:
#      DEBUG : includes debugging info and issues warnings
#      PROF  : includes profiling flags with some optimization
#      OPT   : includes optimizations flags for fastest runtime
#      OMPOPT: includes optimizations flags for fastest runtime and OpenMP directives
#              To run, enter: env OMP_NUM_THREADS=4 Ash3d input_file.inp
#    This variable cannot be left blank
RUN = DEBUG

# This is the location of the USGS libraries and include files
USGSROOT=/opt/USGS

INSTALLDIR=/opt/USGS/Ash3d

#  VERB specifies the verbosity level for debugging purposes
#    Current available options are:
#      VERB=0 : no output to stdout (logfile is still generated)
#      VERB=1 : standard level of logging to stdout
#      VERB=2 : normal output to screen (VERB=1) with additional write statements
#      VERB=3 : 
#       -     : same as VERB=1
VERB = 1

# MEMORY
# If you need pointer arrays instead of allocatable arrays, set this to 'T'
USEPOINTERS = F

###############################################################################

###############################################################################
#####  END OF USER SPECIFIED FLAGS  ###########################################
###############################################################################



###############################################################################
###############################################################################


VERBFPPFLAG = -DVERBOSE_L1
ifeq ($(VERB), 0)
    VERBFPPFLAG = -DVERBOSE_L0
endif
ifeq ($(VERB), 1)
    VERBFPPFLAG = -DVERBOSE_L1
endif
ifeq ($(VERB), 2)
    VERBFPPFLAG = -DVERBOSE_L2
endif
ifeq ($(VERB), 3)
    VERBFPPFLAG = -DVERBOSE_L3
endif

ifeq ($(USEPOINTERS), T)
 memFPPFLAG = -DUSEPOINTERS
endif

# location of MetReader, HoursSince and projection
USGSLIBDIR = -L$(USGSROOT)/lib
USGSLIB = -lhourssince -lprojection
USGSINC = -I$(USGSROOT)/include

###############################################################################
##########  GNU Fortran Compiler  #############################################
ifeq ($(SYSTEM), gfortran)

    FCHOME=/usr
    FC=/usr/bin/gfortran

    COMPINC = -I$(FCHOME)/include -I$(FCHOME)/lib64/gfortran/modules
    COMPLIBS = -L$(FCHOME)/lib -L$(FCHOME)/lib64

    LIBS = $(COMPLIBS) $(USGSLIBDIR) $(USGSINC) $(COMPINC) -llapack -lblas $(USGSLIB) $(DATALIBS)

# Debugging flags
ifeq ($(RUN), DEBUG)
    FFLAGS =  -O0 -g3 -Wall -fbounds-check -pedantic -fbacktrace -fimplicit-none -Wunderflow -Wuninitialized -ffpe-trap=invalid,zero,overflow -fdefault-real-8
    ASH3DEXEC=Ash3d_debug
endif
ifeq ($(RUN), DEBUGOMP)
    FFLAGS =  -g3 -pg -Wall -fbounds-check -pedantic -fimplicit-none -Wunderflow -Wuninitialized -Wmaybe-uninitialized -ffpe-trap=invalid,zero,overflow -fdefault-real-8 -fopenmp -lgomp
    ASH3DEXEC=Ash3d_debugOMP
endif
# Profiling flags
ifeq ($(RUN), PROF)
    FFLAGS = -g -pg -w -fno-math-errno -funsafe-math-optimizations -fno-trapping-math -fno-signaling-nans -fcx-limited-range -fno-rounding-math -fdefault-real-8
    ASH3DEXEC=Ash3d_prof
endif
# Production run flags
ifeq ($(RUN), OPT)
    FFLAGS = -O3 -w -fno-math-errno -funsafe-math-optimizations -fno-trapping-math -fno-signaling-nans -fcx-limited-range -fno-rounding-math -fdefault-real-8
    ASH3DEXEC=Ash3d
endif
ifeq ($(RUN), OMPOPT)
    FFLAGS = -O3 -w -ffast-math -fdefault-real-8 -fopenmp -lgomp
    ASH3DEXEC=Ash3d_omp
endif

      # Preprocessing flags
    FPPFLAGS =  -x f95-cpp-input $(VERBFPPFLAG)
      # Extra flags
    #EXFLAGS = -xf95
    EXFLAGS =
endif
###############################################################################
##########  Intel Fortran Compiler  #############################################
ifeq ($(SYSTEM), ifort)
    FCHOME = $(HOME)/intel
    FC = $(FCHOME)/bin/ifort
    COMPLIBS = -L$(FCHOME)/lib
    COMPINC = -I$(FCHOME)/include
    LIBS = $(COMPLIBS) $(DATALIBS) $(PROJLIBS) $(COMPINC) -llapack -lblas -lirc -limf
# Debugging flags
ifeq ($(RUN), DEBUG)
    FFLAGS = -g2 -pg -warn all -check all -real-size 64 -check uninit -traceback
    ASH3DEXEC=Ash3d_debug
endif
ifeq ($(RUN), DEBUGOMP)
    FFLAGS = -g2 -pg -warn all -check all -real-size 64 -check uninit -openmp
    ASH3DEXEC=Ash3d_debugOMP
endif
# Profiling flags
ifeq ($(RUN), PROF)
    FFLAGS = -g2 -pg
    ASH3DEXEC=Ash3d_prof
endif
# Production run flags
ifeq ($(RUN), OPT)
    FFLAGS = -O3 -ftz -w -ipo
    ASH3DEXEC=Ash3d
endif
ifeq ($(RUN), OMPOPT)
    FFLAGS = -O3 -ftz -w -ipo -openmp
    ASH3DEXEC=Ash3d_omp
endif

      # Preprocessing flags
    FPPFLAGS =  -fpp -Qoption,fpp $(VERBFPPFLAG) 
      # Extra flags
    EXFLAGS =
endif
###############################################################################

UTIL_SRC=makeAsh3dinput1_ac.f90     \
         makeAsh3dinput1_dp.f90     \
         makeAsh3dinput2_ac.f90     \
         makeAsh3dinput2_dp.f90     \
         makeAshArrivalTimes_ac.f90 \
         makeAshArrivalTimes_dp.f90 \
         legend_placer_ac.f90       \
         legend_placer_dp.f90       \
         legend_placer_dp_mm.f90    \
         legend_placer_ac_traj.f90  \
         convert_to_decimal.f90     \
         citywriter.f90
UTIL_OBJS=makeAsh3dinput1_ac       \
          makeAsh3dinput1_dp       \
          makeAsh3dinput2_ac       \
          makeAsh3dinput2_dp       \
          makeAshArrivalTimes_ac   \
          makeAshArrivalTimes_dp   \
          legend_placer_ac         \
          legend_placer_dp         \
          legend_placer_dp_mm      \
          legend_placer_ac_traj    \
          convert_to_decimal       \
          citywriter

all: $(UTIL_OBJS)
	mkdir -p ../bin
	mv makeAsh3dinput1_ac      ../bin/
	mv makeAsh3dinput1_dp      ../bin/
	mv makeAsh3dinput2_ac      ../bin/
	mv makeAsh3dinput2_dp      ../bin/
	mv makeAshArrivalTimes_ac  ../bin/
	mv makeAshArrivalTimes_dp  ../bin/
	mv legend_placer_ac        ../bin/
	mv legend_placer_dp        ../bin/
	mv legend_placer_dp_mm     ../bin/
	mv legend_placer_ac_traj   ../bin/
	mv convert_to_decimal      ../bin/
	mv citywriter              ../bin/

#ncGFS4_2_pf: ncGFS4_2_pf.F90
#	$(FC) $(FFLAGS) $(EXFLAGS) ncGFS4_2_pf.F90 -o ncGFS4_2_pf $(LIBS)
citywriter: citywriter.f90
	$(FC) $(FFLAGS) $(EXFLAGS) citywriter.f90 -o citywriter $(LIBS)
convert_to_decimal: convert_to_decimal.f90
	$(FC) $(FFLAGS) $(EXFLAGS) convert_to_decimal.f90 -o convert_to_decimal $(LIBS)
legend_placer_ac: legend_placer_ac.f90
	$(FC) $(FFLAGS) $(EXFLAGS) legend_placer_ac.f90 -o legend_placer_ac $(LIBS)
legend_placer_ac_traj: legend_placer_ac_traj.f90
	$(FC) $(FFLAGS) $(EXFLAGS) legend_placer_ac_traj.f90 -o legend_placer_ac_traj $(LIBS)
legend_placer_dp: legend_placer_dp.f90
	$(FC) $(FFLAGS) $(EXFLAGS) legend_placer_dp.f90 -o legend_placer_dp $(LIBS)
legend_placer_dp_mm: legend_placer_dp_mm.f90
	$(FC) $(FFLAGS) $(EXFLAGS) legend_placer_dp_mm.f90 -o legend_placer_dp_mm $(LIBS)
makeAsh3dinput1_ac: makeAsh3dinput1_ac.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAsh3dinput1_ac.f90 -o makeAsh3dinput1_ac $(LIBS)
makeAsh3dinput1_dp: makeAsh3dinput1_dp.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAsh3dinput1_dp.f90 -o makeAsh3dinput1_dp $(LIBS)
makeAsh3dinput2_ac: makeAsh3dinput2_ac.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAsh3dinput2_ac.f90 -o makeAsh3dinput2_ac $(LIBS)
makeAsh3dinput2_dp: makeAsh3dinput2_dp.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAsh3dinput2_dp.f90 -o makeAsh3dinput2_dp $(LIBS)
makeAshArrivalTimes_ac: makeAshArrivalTimes_ac.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAshArrivalTimes_ac.f90 -o makeAshArrivalTimes_ac $(LIBS)
makeAshArrivalTimes_dp: makeAshArrivalTimes_dp.f90
	$(FC) $(FFLAGS) $(EXFLAGS) makeAshArrivalTimes_dp.f90 -o makeAshArrivalTimes_dp $(LIBS)
#makegfsncml: makegfsncml.f90
#	$(FC) $(FFLAGS) $(EXFLAGS) makegfsncml.f90 -o makegfsncml $(LIBS)

clean:
	rm -rf ../bin/legend* ../bin/makeAsh*

install:
	install -d $(INSTALLDIR)/bin/scripts/              $(INSTALLDIR)/share/post_proc
	install -m 755 ../bin/*                            $(INSTALLDIR)/bin
	install -m 755 ../scripts/*.sh                     $(INSTALLDIR)/bin/scripts/
	install -m 755 ../scripts/xyz2shp.py               $(INSTALLDIR)/bin/scripts/
	install -m 644 ../share/GlobalAirports_ewert.txt   $(INSTALLDIR)/share/
	install -m 644 ../share/readme.pdf                 $(INSTALLDIR)/share/
	install -m 644 ../share/post_proc/*cpt             $(INSTALLDIR)/share/post_proc/
	install -m 644 ../share/post_proc/*png             $(INSTALLDIR)/share/post_proc/
	install -m 644 ../share/post_proc/*xy              $(INSTALLDIR)/share/post_proc/
	install -m 644 ../share/post_proc/world_cities.txt $(INSTALLDIR)/share/post_proc/

