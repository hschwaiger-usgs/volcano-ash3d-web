#!/bin/bash

#      This file is a component of the volcanic ash transport and dispersion model Ash3d,
#      written at the U.S. Geological Survey by Hans F. Schwaiger (hschwaiger@usgs.gov),
#      Larry G. Mastin (lgmastin@usgs.gov), and Roger P. Denlinger (roger@usgs.gov).
#
#      The model and its source code are products of the U.S. Federal Government and therefore
#      bear no copyright.  They may be copied, redistributed and freely incorporated 
#      into derivative products.  However as a matter of scientific courtesy we ask that
#      you credit the authors and cite published documentation of this model (below) when
#      publishing or distributing derivative products.
#
#      Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., 2012, Ash3d, a finite-
#         volume, conservative numerical model for ash transport and tephra deposition,
#         Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968. 
#
#      We make no guarantees, expressed or implied, as to the usefulness of the software
#      and its documentation for any purpose.  We assume no responsibility to provide
#      technical support to users of this software.
#
#      This script runs an Ash3d simulation for a simplified deposit ash case launched
#      from the web interface at vsc-ash.wr.usgs.gov. It expects that the web client
#      has created a run directory containing the minimal control file ash3d_input_dp.inp.
#      Also expected are about 2 weeks of GFS forecast data (downloaded via cron job autorun_gfs.sh)
#      the NCEP Reanalysis data from 1948-present.
#
#      Usage: runAsh3d_ac.sh INPUT_PATH, ZIP_NAME, DASHBOARD_IND (T or F), RUN_ID, JAVA_THREAD_ID
#       e.g. /var/www/html/ash3d-api/htdocs/ash3druns/runAsh3d_dp.sh          \
#               /var/www/html/ash3d-api/htdocs/ash3druns/ash3d_run_334738/    \
#               ash3d_test_dep_20201015-19:25:29                              \
#               F                                                             \
#               334738                                                        \
#               ash3dclient-thread-370
#
# Files needed:
#   last_downloaded.txt         : created by convert_gfs.sh; needed by makeAsh3dinput1_[ac,dp]
#   ash3d_input_[ac,dp].inp     : minimal input file created by the Ash3d web client
#   GlobalAirports_ewert.txt    : Needed for Ash3d
#   pp_ashfalltime_shp.ctr      : Needed to generate shapefiles
#   GEBCO_2023.nc               : topo file
# Programs needed:
#   date,find,hostname          : unix tools
#   zip                         : needed for preparing data download bundle
#   unix2dos                    : program to strip some control characters from ASCII files
#   full_2_simp.sh              : for advanced runs, convert full input file to mini
#   runTraj.sh                  : for trajectory run
#   GFSVolc_to_gif_ac_traj.sh   : makes GMT maps of the trajectory results
#   GFSVolc_to_gif_dp.sh        : produces a static map of deposit thickness in inches
#   GFSVolc_to_gif_dp_mm.sh     : produces a static map of deposit thickness in mm
#   MetTraj_F                   : trajectory executable
#   Ash3d,Ash3d_res             : main character
#   makeAsh3dinput1_[ac,dp]     : needed for converting mini-input to complete coarse input
#   makeAsh3dinput2_[ac,dp]     : needed for converting coarse input to full input file
#   makeAshArrivalTimes_[ac,dp] : reformats some ASCII output for display on web pages
#
SLAB="[runAsh3d_dp.sh]: "            # Script label prepended on all echo to stdout
#

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
# Customizable settings
RUNTYPE="DEP"          # ADV,DEP,ACL
CLEANFILES="T"         # set to T to remove temporary files
USECONTAINERASH="F"    # set to T to use Ash3d container
USECONTAINERTRAJ="F"   # set to T to use Trajectory container
CONTAINEREXE="podman"  # container flavor
CONTAINERRUNDIR="/run/user/1004/libpod/tmp"

# Check if environment variables are set; if not, set them to the default
if [ -z ${USGSROOT} ];then
 # Standard Linux location
 USGSROOT="/opt/USGS"
fi
if [ -z ${ASH3DHOME} ];then
 # Standard Linux location
 ASH3DHOME="/opt/USGS/Ash3d"
fi
if [ -z ${WINDROOT} ];then
 # Standard Linux location
 WINDROOT="/data/WindFiles"
 # Mac
 #WINDROOT="/opt/data/WindFiles"
fi
if [ -z ${TOPOROOT} ];then
 # Standard Linux location
 TOPOROOT="/data/Topo"
 # Mac
 #TOPOROOT="/opt/data/Topo"
fi
# Set dependent path variables
ASH3DBINDIR="${ASH3DHOME}/bin"
ASH3DSCRIPTDIR="${ASH3DHOME}/bin/scripts"
ASH3DSHARE="$ASH3DHOME/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

# Check input parameters needed for run
NARGS=$#
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} running runAsh3d_dp.sh with $NARGS parameters:"
echo "${SLAB}   run directory           = $1"
echo "${SLAB}   zip file name           = $2"
echo "${SLAB}   Dashboard case (T or F) = $3"
echo "${SLAB}   Run ID                  = $4"
echo "${SLAB}   Java thread ID          = $5"
echo `date`
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} RUNTYPE = ${RUNTYPE}"
t0=`date -u`                                     # record start time
rc=0                                             # error message accumulator

HOST=`hostname | cut -c1-9`
echo "${SLAB} HOST=$HOST"
if [ "$USECONTAINERASH" == "T" ]; then
  echo "${SLAB} Post processing scripts for Ash3d results will be run with containers via ${CONTAINEREXE}"
fi
if [ "$USECONTAINERTRAJ" == "T" ]; then
  echo "${SLAB} Post processing scripts for traj results will be run with containers via ${CONTAINEREXE}"
fi

#Determine last downloaded windfile
LAST_DOWNLOADED=`cat ${WINDROOT}/gfs/last_downloaded.txt`
echo "${SLAB} last downloaded windfile =${LAST_DOWNLOADED}"

INFILE_PRELIM="ash3d_input_prelim.inp"                     # input file used for preliminary Ash3d run
INFILE_MAIN="ash3d_input.inp"                              # input file used for main Ash3d run

echo "${SLAB} Checking input arguments"
if [ -z $1 ] ; then
  echo "${SLAB}   Error: you must specify an input directory containing the file ash3d_input_dp.inp"
  echo "${SLAB}   Usage: runAsh3d_dp.sh rundir zipname dash_flag run_ID java_thread_ID"
  exit 1
else
  RUNDIR=$1
  echo "${SLAB}   run directory is $1"
fi

if [ -z $2 ] ; then
  echo "${SLAB}   Error: you must specify a zip file name"
  exit 1
else
  ZIPNAME=$2
fi

if [ -z $3 ] ; then
  echo "${SLAB}   Dashboard flag not set.  Setting to 'F'"
  DASHBOARD_RUN='F'
else
  DASHBOARD_RUN=$3
fi

if [ -z $4 ] ; then
  echo "${SLAB}   Run ID not set"
  RUNID="000000"
else
  RUNID=$4
fi

if [ -z $5 ] ; then
  echo "${SLAB}   Java thread ID not set"
  JAVAID='000'
else
  JAVAID=$5
fi

###############################################################################
# PRELIMINARY SYSTEM CHECK
###############################################################################
rc=0                                                       # error message accumulator
# Test for the existance of required files.
GFS_LAST="${WINDROOT}/gfs/last_downloaded.txt"             # Needed to link to the correct forecast package
AIRPORT="${ASH3DSHARE}/GlobalAirports_ewert.txt"
TOPOFILE=${TOPOROOT}/GEBCO/GEBCO_2023.nc
if [ -f "${TOPOFILE}" ]; then
  echo "${SLAB}   Found file required file: ${TOPOFILE}"
else
  echo "${SLAB}   ERROR: no ${TOPOFILE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
if [ -f "${AIRPORT}" ]; then
  echo "${SLAB}   Found file required file: ${AIRPORT}"
else
  echo "${SLAB}   ERROR: no ${AIRPORT} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
if [ -f "${ASH3DSCRIPTDIR}/pp_ashfalltime_shp.ctr" ]; then
  echo "${SLAB}   Found file required file: ${ASH3DSCRIPTDIR}/pp_ashfalltime_shp.ctr"
else
  echo "${SLAB}   ERROR: no ${ASH3DSCRIPTDIR}/pp_ashfalltime_shp.ctr file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# Test for the existance/executability of required programs and files.
command -v "${ASH3DSCRIPTDIR}/full_2_simp.sh"             > /dev/null 2>&1 ||  { echo >&2 "full_2_simp.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/runTraj.sh"                 > /dev/null 2>&1 ||  { echo >&2 "runTraj.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh"  > /dev/null 2>&1 ||  { echo >&2 "GFSVolc_to_gif_ac_traj.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh"       > /dev/null 2>&1 ||  { echo >&2 "GFSVolc_to_gif_dp.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp_mm.sh"    > /dev/null 2>&1 ||  { echo >&2 "GFSVolc_to_gif_dp_mm.sh not found. Exiting"; exit 1;}
command -v "${USGSROOT}/bin/MetTraj_F"                    > /dev/null 2>&1 ||  { echo >&2 "MetTraj_F not found. Exiting"; exit 1;}
command -v date     > /dev/null 2>&1 ||  { echo >&2 "date not found. Exiting"; exit 1;}
command -v find     > /dev/null 2>&1 ||  { echo >&2 "find not found. Exiting"; exit 1;}
command -v hostname > /dev/null 2>&1 ||  { echo >&2 "hostname not found. Exiting"; exit 1;}
command -v zip      > /dev/null 2>&1 ||  { echo >&2 "zip not found. Exiting"; exit 1;}
command -v unix2dos > /dev/null 2>&1 ||  { echo >&2 "unix2dos not found. Exiting"; exit 1;}

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
# Customizable settings
RUNTYPE="DEP"          # ADV,DEP,ACL
CLEANFILES="T"         # set to T to remove temporary files
USECONTAINERASH="F"    # set to T to use Ash3d container
USECONTAINERTRAJ="F"   # set to T to use Trajectory container
CONTAINEREXE="podman"  # container flavor
CONTAINERRUNDIR="/run/user/1004/libpod/tmp"

# Check input parameters needed for run
NARGS=$#
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} running runAsh3d_dp.sh with $NARGS parameters:"
echo "${SLAB}   run directory           = $1"
echo "${SLAB}   zip file name           = $2"
echo "${SLAB}   Dashboard case (T or F) = $3"
echo "${SLAB}   Run ID                  = $4"
echo "${SLAB}   Java thread ID          = $5"
echo `date`
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} RUNTYPE = ${RUNTYPE}"
t0=`date -u`                                     # record start time
rc=0                                             # error message accumulator

HOST=`hostname | cut -c1-9`
echo "${SLAB} HOST=$HOST"
if [ "$USECONTAINERASH" == "T" ]; then
  echo "${SLAB} Post processing scripts for Ash3d results will be run with containers via ${CONTAINEREXE}"
fi
if [ "$USECONTAINERTRAJ" == "T" ]; then
  echo "${SLAB} Post processing scripts for traj results will be run with containers via ${CONTAINEREXE}"
fi

#Determine last downloaded windfile
LAST_DOWNLOADED=`cat ${WINDROOT}/gfs/last_downloaded.txt`
echo "${SLAB} last downloaded windfile =${LAST_DOWNLOADED}"

INFILE_PRELIM="ash3d_input_prelim.inp"                     # input file used for preliminary Ash3d run
INFILE_MAIN="ash3d_input.inp"                              # input file used for main Ash3d run

echo "${SLAB} Checking input arguments"
if [ -z $1 ] ; then
  echo "${SLAB}   Error: you must specify an input directory containing the file ash3d_input_dp.inp"
  echo "${SLAB}   Usage: runAsh3d_dp.sh rundir zipname dash_flag run_ID java_thread_ID"
  exit 1
else
  RUNDIR=$1
  echo "${SLAB}   run directory is $1"
fi

if [ -z $2 ] ; then
  echo "${SLAB}   Error: you must specify a zip file name"
  exit 1
else
  ZIPNAME=$2
fi

if [ -z $3 ] ; then
  echo "${SLAB}   Dashboard flag not set.  Setting to 'F'"
  DASHBOARD_RUN='F'
else
  DASHBOARD_RUN=$3
fi

if [ -z $4 ] ; then
  echo "${SLAB}   Run ID not set"
  RUNID="000000"
else
  RUNID=$4
fi

if [ -z $5 ] ; then
  echo "${SLAB}   Java thread ID not set"
  JAVAID='000'
else
  JAVAID=$5
fi





#Assign default filenames and directory names and variables to be plotted
# default variable netcdfnames
nVARS=8
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
if [ "$RUNTYPE" == "ADV"  ] ; then
  if test -r ${ASH3DBINDIR}/Ash3d_res ; then
    echo "${SLAB} Using Ash3d_res for advanced run"
    ASH3DEXEC="${ASH3DBINDIR}/Ash3d_res"
  else
    ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
  fi
  MAKEINPUT1="${ASH3DBINDIR}/makeAsh3dinput1_ac"
  MAKEINPUT2="${ASH3DBINDIR}/makeAsh3dinput2_ac"
  #MAKEASHARRIVAL="${ASH3DBINDIR}/makeAshArrivalTimes_dp"
  INFILE_SIMPLE="ash3d_input_simp.inp"
    # For advanced runs, plot all variables
  plotvars=(1 1 1 1 1 1 1 1)
elif [ "$RUNTYPE" == "DEP"  ] ; then
  ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
  MAKEINPUT1="${ASH3DBINDIR}/makeAsh3dinput1_dp"
  MAKEINPUT2="${ASH3DBINDIR}/makeAsh3dinput2_dp"
  #MAKEASHARRIVAL="${ASH3DBINDIR}/makeAshArrivalTimes_dp"
  INFILE_SIMPLE="ash3d_input_dp.inp"
    # For deposit runs, plot final deposit (inches and mm)
  plotvars=(0 0 0 0 0 1 1 0)
elif [ "$RUNTYPE" == "ACL"  ] ; then
  ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
  MAKEINPUT1="${ASH3DBINDIR}/makeAsh3dinput1_ac"
  MAKEINPUT2="${ASH3DBINDIR}/makeAsh3dinput2_ac"
  #MAKEASHARRIVAL="${ASH3DBINDIR}/makeAshArrivalTimes_ac"
  INFILE_SIMPLE="ash3d_input_ac.inp"
    # For cloud runs, plot cloud_height and cloud_load
  if [[ $DASHBOARD_RUN == T* ]] ; then
    plotvars=(0 0 1 1 0 0 0 0)
  else
    plotvars=(0 0 0 1 0 0 0 0)
  fi
fi

# Test for the existance/executability of required programs and files.
command -v ${ASH3DEXEC}  > /dev/null 2>&1 ||  { echo >&2 "Ash3d executable not found. Exiting"; exit 1;}
command -v ${MAKEINPUT1} > /dev/null 2>&1 ||  { echo >&2 "makeAsh3dinput1_[ac,dp] executable not found. Exiting"; exit 1;}
command -v ${MAKEINPUT2} > /dev/null 2>&1 ||  { echo >&2 "makeAsh3dinput2_[ac,dp] executable not found. Exiting"; exit 1;}
command -v ${MAKEASHARRIVAL} > /dev/null 2>&1 ||  { echo >&2 "makeAshArrivalTimes_[ac,dp] executable not found. Exiting"; exit 1;}

echo "${SLAB} changing directories to ${RUNDIR}"
if test -r ${RUNDIR} ; then
  cd $RUNDIR
  FULLRUNDIR=`pwd`
else
  echo "${SLAB} Error: Directory ${RUNDIR} does not exist."
  exit $rc
fi
if [[ $? -ne 0 ]]; then
  rc=$((rc + 1))
fi
echo "${SLAB} Checking for ${INFILE_SIMPLE} in ${RUNDIR}"
if [ -f "${INFILE_SIMPLE}" ]; then
  echo "${SLAB}   Found file required file: ${INFILE_SIMPLE}"
else
  echo "${SLAB}   ERROR: no ${INFILE_SIMPLE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

if [ "$RUNTYPE" == "ADV"  ] ; then
  # lobby to have the file written from the webpage be called ash3d_input_adv.inp
  cp ${INFILE_MAIN} ash3d_input_adv.inp
  echo "${SLAB} Running full_2_simp.sh"
  command -v ${ASH3DSCRIPTDIR}/full_2_simp.sh  > /dev/null 2>&1 ||  { echo >&2 "full_2_simp.sh script not found. Exiting"; exit 1;}
  ${ASH3DSCRIPTDIR}/full_2_simp.sh ash3d_input_adv.inp
fi
if [ "$CLEANFILES" == "T" ]; then
  echo "${SLAB} Removing old input & output files"
  rm -f *.gif *.kmz *.zip ${INFILE_PRELIM} ${INFILE_MAIN} *.txt cities.xy *.dat *.pdf 3d_tephra_fall.nc
  rm -f *.lst Wind_nc *.xyz *.png depTS_*.gnu dp.* ash3d_runlog.txt
  rc=$((rc + $?))
  if [[ "$rc" -gt 0 ]] ; then
    echo "${SLAB} Error removing old files: rc=$rc"
    exit $rc
  fi
fi

echo "${SLAB} Linking airports file."
ln -sf ${AIRPORT} .
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB}   Error copying files: rc=$rc"
  exit $rc
fi

echo "${SLAB} Creating soft links to wind files"
ln -sf  ${WINDROOT} Wind_nc
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB}   Error linking ${WINDROOT}: rc=$rc"
  exit $rc
fi

echo "${SLAB} Creating soft links to topo file (Not needed for cloudd runs)"
rm -f GEBCO_2023.nc
ln -s ${TOPOROOT}/GEBCO/GEBCO_2023.nc .
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error linking GEBCO_2023.nc: rc=$rc"
  exit $rc
fi

###############################################################################
# INITIAL COARSE ASH3D RUN
###############################################################################
echo "${SLAB} _______________________________________________________________________________"
echo "${SLAB} >>>>>>>>>>>>>>>>>          Setting up preliminary run           <<<<<<<<<<<<<<<"
echo "${SLAB} _______________________________________________________________________________"
# First, generate the full input file based on the mini-web-version, if needed
echo "${SLAB} Running ${MAKEINPUT1} ${INFILE_SIMPLE} ${INFILE_PRELIM} ${LAST_DOWNLOADED}"
# This creates the coarse control file: ash3d_input_prelim.inp
${MAKEINPUT1} ${INFILE_SIMPLE} ${INFILE_PRELIM} ${LAST_DOWNLOADED} 2>outerr_makeinput1.log
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB}   Error running ${MAKEINPUT1}: rc=$rc"
  exit $rc
fi
# Verify that we have the expected output control file
if test -r ${INFILE_PRELIM} ; then
  echo "${SLAB}   Verified that ${INFILE_PRELIM} was created."
else
  echo "${SLAB}   Error: ${INFILE_PRELIM} not created"
  exit $rc
fi

echo "${SLAB} *******************************************************************************"
echo "${SLAB} *******************************************************************************"
echo "${SLAB} **********                  Preliminary Ash3d run                    **********"
echo "${SLAB} *******************************************************************************"
echo "${SLAB} *******************************************************************************"
# The default log file writen by Ash3d is Ash3d.lst, but we will capture all stdout to
# an alternative log file.  This initial 10x10 run will produce output files that will
# be processed to determine the geometry of the subsequent full run.
# For deposit runs, ${INFILE_PRELIM} and DepositFile_____final.dat are needed.
# For cloud runs, ${INFILE_PRELIM} and CloudLoad_*hrs.dat are needed.
echo "${SLAB}    Running :: ASH33DCFL=0.5 ${ASH3DEXEC} ${INFILE_PRELIM} | tee ashlog_prelim.txt"
ASH33DCFL=0.5 ${ASH3DEXEC} ${INFILE_PRELIM} 2>outerr_Ash3dprelim.log | tee ashlog_prelim.txt
rc=$((rc + ${PIPESTATUS[0]}))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB}   Error running Preliminary Ash3d run: rc=$rc"
  exit $rc
fi
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} ----------             Completed  Preliminary Ash3d run              ----------"
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} -------------------------------------------------------------------------------"

if [ "$CLEANFILES" == "T" ]; then
  # Clean up files from the preliminary Ash3d run
  # Note, we need to leave the ASCII output file DepositFile_____final.dat since it is used for
  # determining the grid range via ${MAKEINPUT2}
  echo "${SLAB} Removing kml files"
  rm -f *.kml *kmz ash_arrivaltimes_airports.txt
  rm -f depTS*.dat depTS*.gnu depTS*.png
  rm -f progress.txt Ash3d.lst
fi

###############################################################################
# PREPARING FOR FULL ASH3D RUN
###############################################################################
echo "${SLAB} _______________________________________________________________________________"
echo "${SLAB} >>>>>>>>>>>>>>>>>              Setting up main run              <<<<<<<<<<<<<<<"
echo "${SLAB} _______________________________________________________________________________"
echo "${SLAB} making ${INFILE_MAIN}"
if [ "$RUNTYPE" == "DEP" ] || [ "$RUNTYPE" == "ACL" ]  ; then
  ${MAKEINPUT2} ${INFILE_PRELIM} ${INFILE_MAIN} 2>outerr_makeinput2.log
else
  cp ash3d_input_adv.inp ${INFILE_MAIN}
fi

rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error running ${MAKEINPUT2}: rc=$rc"
  exit $rc
fi
if test -r ${INFILE_MAIN} ; then
  echo "${SLAB} ${INFILE_MAIN} created okay"
else
  echo "${SLAB} Error: ${INFILE_MAIN} not created"
  exit $rc
fi

if [ "$CLEANFILES" == "T" ]; then
  echo "${SLAB} Removing remnant .dat files from the preliminary Ash3d run"
  rm -f ${INFILE_PRELIM}
  rm -f CloudLoad*.dat
  rm -f DepositFile_____final.dat
fi

###############################################################################
# INITIAL TRAJECTORY RUN
###############################################################################
# Run the trajectory model with the parameters in the simple input file
echo "${SLAB} -------------------------------------------------------------------------------"
if test -r ${USGSROOT}/bin/MetTraj_F; then
  echo "${SLAB} Calling runTraj.sh"
  # This script reads the simplified input file, runs MetTraj_F. This will produce the
  # trajectory files ftraj*.dat and map_range_traj.txt
  ${ASH3DSCRIPTDIR}/runTraj.sh
  rc=$((rc + $?))
  if [[ "$rc" -gt 0 ]] ; then
    echo "${SLAB} Error running runTraj.sh: rc=$rc"
    echo "${SLAB} Skipping post-processing, but continuing with Ash3d simulations."
    #exit $rc
    rc=0
  else
    # Now post-processing ftraj*.dat
    # The map information is pulled from 3d_tephra_fall.nc from the preliminary run
    echo "${SLAB}   Running installed script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 0
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running GFSVolc_to_gif_ac_traj.sh: rc=$rc"
      echo "${SLAB} No trajectory output produced; continuing with run script"
      #exit $rc
      rc=0
    fi
  fi
else
  echo "${SLAB} ${USGSROOT}/bin/MetTraj_F does not exist.  Skipping trajectory runs."
fi
echo "${SLAB} -------------------------------------------------------------------------------"

###############################################################################
# FULL ASH3D RUN
###############################################################################
if [ "$CLEANFILES" == "T" ]; then
  rm -f 3d_tephra_fall.nc
fi
echo "${SLAB} *******************************************************************************"
echo "${SLAB} *******************************************************************************"
echo "${SLAB} **********                   Main Ash3d run                          **********"
echo "${SLAB} *******************************************************************************"
echo "${SLAB} *******************************************************************************"
# Again, the default log file written by Ash3d is Ash3d.lst, but we will capture all stdout to
# an alternative log file.  
echo "${SLAB}    Running :: ${ASH3DEXEC} ${INFILE_MAIN} | tee ash3d_runlog.txt"
${ASH3DEXEC} ${INFILE_MAIN} 2>outerr_Ash3dmain.log | tee ash3d_runlog.txt
rc=$((rc + ${PIPESTATUS[0]}))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error running main Ash3d run: rc=$rc"
  exit $rc
fi
# This will produce the following output files written directly by Ash3d:
#  3d_tephra_fall.nc
#  Ash3d.lst
#  ash3d_runlog.txt
#  ash_arrivaltimes_airports.txt
#  ash_arrivaltimes_airports.kml
#  ash_arrivaltimes_airports.kmz
#   CloudHeight.kml
#   CloudLoad.kml
#   cloud_arrivaltimes_hours.kml
#   CloudHeight_*.dat
#   CloudLoad_*.dat
#
#   DepositFile_____final.dat
#   DepositFile_*.dat
#   DepositArrivalTime.dat
#   ashfall_arrivaltimes_hours.kml
#   deposit_thickness_mm.kml
#   deposit_thickness_inches.kml
#   depTS_000*.gnu
#   depTS_000*.dat
#   depTS_000*.png
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} ----------                Completed  Main Ash3d run                  ----------"
echo "${SLAB} -------------------------------------------------------------------------------"
echo "${SLAB} -------------------------------------------------------------------------------"
# Check if there are any deposit time-series files; if so, zip up ash_arrivaltimes_airports.kmz
#if test -r depTS_0001.gnu; then
#  echo "${SLAB} using gnuplot to plot deposit thickness vs. time"
#  for i in `ls -1 depTS_*.gnu`
#  do
#    gnuplot ${i}
#  done
#  zip -r ash_arrivaltimes_airports.kmz ash_arrivaltimes_airports.kml depTS*.png
#else
#  mv ash_arrivaltimes_airports.kml cloud_arrivaltimes_airports.kml
#  zip -r cloud_arrivaltimes_airports.kmz cloud_arrivaltimes_airports.kml
#fi
mv ash_arrivaltimes_airports.kmz cloud_arrivaltimes_airports.kmz
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error zipping output: rc=$rc"
  exit $rc
fi
rm -f ash_arrivaltimes_airports.kml cloud_arrivaltimes_airports.kml

#
# Zip all kml files, make kmz files
#
echo "${SLAB} zipping up kml files"
for file in *.kml
do
  IFS='.'
  array=( $file )
  zip -r "${array[0]}".kmz "$file"
  if [[ $? -ne 0 ]]; then
    echo "${SLAB} Error zipping file $file"
    rc=$((rc + 1))
    exit $rc
  fi
  rm "$file"
  if [[ $? -ne 0 ]]; then
    echo "${SLAB} Error removing extra file $file after zip"
    rc=$((rc + 1))
    exit $rc
  fi
done

echo "${SLAB} unix2dos ash_arrivaltimes_airports.txt"
if [ "$RUNTYPE" == "ADV"  ] ; then
  unix2dos ash_arrivaltimes_airports.txt
  rc=$((rc+$?))
elif [ "$RUNTYPE" == "DEP"  ] ; then
  echo "${SLAB} First stripping ash_arrivaltimes_airports.txt of cloud data"
  ## Reads file ash_arrivaltimes_airports.txt
  #${ASH3DBINDIR}/makeAshArrivalTimes_dp 2>outerr_makearrival.log
  ## Wrote out file ash_arrivaltimes_airports_dp.txt
  #rc=$((rc+$?))
  #if [[ "$rc" -gt 0 ]] ; then
  #  echo "${SLAB} Error running makeAshArrivalTimes_dp: rc=$rc"
  #  exit $rc
  #fi
  # copy output of makeAshArrivalTimes_dp back to ash_arrivaltimes_airports.txt
  mv ash_arrivaltimes_airports_dp.txt ash_arrivaltimes_airports.txt
  unix2dos ash_arrivaltimes_airports.txt
  rc=$((rc+$?))
  cp ash_arrivaltimes_airports.txt ashfall_arrivaltimes_airports.txt
  ln -s ash_arrivaltimes_airports.txt AshArrivalTimes.txt
  cp DepositArrivalTime.dat ashfall_arrivaltimes_hours.dat
elif [ "$RUNTYPE" == "ACL"  ] ; then
  echo "${SLAB} First stripping ash_arrivaltimes_airports.txt of deposit data"
  # Reads file ash_arrivaltimes_airports.txt
  ${ASH3DBINDIR}/makeAshArrivalTimes_ac 2>outerr_makearrival.log
  # Wrote out file ash_arrivaltimes_airports_ac.txt
  rc=$((rc+$?))
  if [[ "$rc" -gt 0 ]] ; then
    echo "${SLAB} Error running makeAshArrivalTimes_ac: rc=$rc"
    exit $rc
  fi
  # copy output of makeAshArrivalTimes_ac back to cloud_arrivaltimes_airports.txt
  mv ash_arrivaltimes_airports_ac.txt cloud_arrivaltimes_airports.txt
  rm -f ash_arrivaltimes_airports.txt
  unix2dos cloud_arrivaltimes_airports.txt
  rc=$((rc+$?))
  # Web page want this output with a consistant name so link it here
  ln -s cloud_arrivaltimes_airports.txt AshArrivalTimes.txt
fi
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error producing AshArrivalTimes.txt: rc=$rc"
  exit $rc
fi

# Get time of completed Ash3d calculations
t1=`date -u`

echo "${SLAB} *******************************************************************************"
echo "${SLAB} POST-PROCESSING"
echo "${SLAB} *******************************************************************************"
echo "${SLAB} Creating gif images from the standard Ash3d output file."
if [ "$RUNTYPE" == "ADV" ] || [ "$RUNTYPE" == "ACL" ]  ; then
  echo "${SLAB} Creating gif images of ash cloud"
  # Generate gifs for the transient variables
  #  0 = depothick
  #  1 = ashcon_max
  #  2 = cloud_height
  #  3 = cloud_load
    
  elif [ "$RUNTYPE" == "ADV" ] || [ "$RUNTYPE" == "DEP" ]  ; then
  echo "${SLAB} Creating gif images of deposit"
  if [ "$USECONTAINERASH" == "T" ]; then
    echo "${SLAB} First process for deposit results (in inches)"
    echo "${SLAB} Calling podman ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh"
    echo "${SLAB}  ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh ${CONTAINERRUNDIR}"
    ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                    ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh ${CONTAINERRUNDIR}
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_dp.sh: rc=$rc"
      exit $rc
    fi
    echo "${SLAB} Now process for deposit results in mm"
    echo "${SLAB} Calling podman ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp_mm.sh"
    ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                    ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp_mm.sh ${CONTAINERRUNDIR}
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_dp_mm.sh: rc=$rc"
      exit $rc
    fi
  else
    echo "${SLAB} First process for deposit results (in inches)"
    echo "${SLAB} Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh

    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running GFSVolc_to_gif_dp.sh: rc=$rc"
      exit $rc
    fi
    echo "${SLAB} Now process for deposit results in mm"
    echo "${SLAB} Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp_mm.sh"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp_mm.sh
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running GFSVolc_to_gif_dp_mm.sh: rc=$rc"
      exit $rc
    fi
    # Create a shapefile of the arrival time
    #${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 7 5
    cp ${ASH3DSCRIPTDIR}/pp_ashfalltime_shp.ctr .
    ${ASH3DBINDIR}/Ash3d_PostProc pp_ashfalltime_shp.ctr 2>outerr_pp.log
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "Error running Ash3d_PostProc to generate ashfalltime_shp: rc=$rc"
      #exit $rc
      rc=0
    fi
  fi
fi

if test -r "deposit_thickness_inches.gif"; then
  # Web-interface expects the English units to be named deposit.gif
  cp deposit_thickness_inches.gif deposit.gif
fi
if test -r "DepositFile_____final.dat"; then
  mv DepositFile_____final.dat deposit_thickness_mm.txt
  unix2dos deposit_thickness_mm.txt
  rc=$((rc+$?))
  if [[ "$rc" -gt 0 ]] ; then
    echo "${SLAB} Error running unix2dos deposit_thickness_mm.txt: rc=$rc"
    exit $rc
  fi
fi

# Recreating the trajectory plot (using previously calculated trajecties), but using
# the consistant basemap
if test -r ftraj1.dat; then
  if [ "$USECONTAINERTRAJ" == "T" ]; then
    echo "${SLAB}   Running ${CONTAINEREXE} script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
    ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                    ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 1 ${CONTAINERRUNDIR}
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh 1: rc=$rc"
      echo "${SLAB} Skipping post-processing"
      echo "${SLAB} No trajectory output produced; continuing with run script"
      #exit $rc
    fi
  else
    echo "${SLAB}   Running installed script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 1
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
      echo "${SLAB} Error running GFSVolc_to_gif_ac_traj.sh 1: rc=$rc"
      echo "${SLAB} Skipping post-processing"
      echo "${SLAB} No trajectory output produced; continuing with run script"
      #exit $rc
    fi
  fi
else
  echo "${SLAB} Skipping trajectory plots: no traj files exist in this directory."
fi
echo "${SLAB} -------------------------------------------------------------------------------"

#
# Delete extra files from Ash3d run
# Post-processing extra files should be deleted in the post-processing script
#
if [ "$CLEANFILES" == "T" ]; then
  echo "${SLAB} Deleting extra files"
  rm -f progress.txt Ash3d.lst GlobalAirports_ewert.txt
  rm -f CloudHeight_*.dat
  rm -f CloudLoad_*.dat
  rm -f Wind_nc
fi

echo "${SLAB} Making zip file"

nout_files=24
out_files=("${INFILE_MAIN}"         \
"ash3d_runlog.txt"                  \
"ash_arrivaltimes_airports.kmz"     \
"ashfall_arrivaltimes_airports.txt" \
"ashfall_arrivaltimes_hours.kmz"    \
"ashfall_arrivaltimes_hours.dat"    \
"deposit_thickness_inches.gif"      \
"deposit_thickness_inches.kmz"      \
"deposit_thickness_mm.gif"          \
"deposit_thickness_mm.kmz"          \
"deposit_thickness_mm.txt"          \
"dp_shp.zip"                        \
"dp_mm_shp.zip"                     \
"DepAvlTm.zip"                      \
"trajectory_1.gif"                  \
"cloud_animation.gif"               \
"cloud_arrivaltimes_airports.kmz"   \
"cloud_arrivaltimes_airports.txt"   \
"CloudConcentration.kmz"            \
"CloudHeight.kmz"                   \
"CloudLoad.kmz"                     \
"cloud_arrivaltime_hours.kmz"       \
"CloudBottom.kmz"                   \
"ftraj1.dat")

for (( i=0;i<${nout_files};i++))
do
  echo "${SLAB} Testing for ${out_files[i]} ($i/$nout_files)"
  if test -r "${out_files[i]}"; then
    echo "${SLAB}    Found ${out_files[i]}"
    if [ "${out_files[i]}" == "ftraj1.dat" ]; then
      echo "${SLAB}    Adding trajectory data to zip file."
      zip $ZIPNAME.zip ftraj*dat
    elif [ "${out_files[i]}" == "cloud_animation.gif" ]; then
      echo "${SLAB}    Adding animations to zip file."
      zip $ZIPNAME.zip *_animation.gif
      zip $ZIPNAME.zip *UTC*.gif
    else
      echo "${SLAB}    Adding ${out_files[i]} to zip file."
      zip $ZIPNAME.zip "${out_files[i]}"
    fi
  else
    echo "${SLAB}    Did not find ${out_files[i]}"
  fi
done

#
# Make all files writeable by everyone so web process can delete as needed.
#
echo "${SLAB} Making files writeable"
find . -type f -exec chmod 666 {} \;
if [[ $? -ne 0 ]]; then
  echo "${SLAB} Error making file types readable for everyone."
  rc=$((rc + 1))
  exit $rc
fi

#
# Finished
#
if [[ $rc -ne 0 ]]; then
  echo "${SLAB} $rc errors detected."
else
  echo "${SLAB} successful completion"
fi

t2=`date -u`
echo "${SLAB} started run at          :  $t0"
echo "${SLAB} calculations ended at   :  $t1"
echo "${SLAB} post-processing ended at:  $t2"
echo "${SLAB} all done with run $4"

exit $rc

