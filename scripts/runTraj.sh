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
#      This script reads ash3d_input_ac.inp from the cwd and runs MetTraj_F. The file
#      /data/WindFiles/gfs/last_downloaded.txt is expected to be present so that MetTraj_F
#      can use the correct NWP data.
#
#      Usage: runTraj.sh
#
# Files needed:
#   last_downloaded.txt     : created by convert_gfs.sh; needed by makeAsh3dinput1_[ac,dp]
#   ash3d_input_ac.inp      : minimal input file created by the Ash3d web client
# Programs needed:
#   date,sed,awk,bc         : unix tools
#   MetTraj_F               : trajectory executable

# %s/echo "/echo "${SLAB} /g
#
SLAB="[runTraj.sh]: "            # Script label prepended on all echo to stdout
#
###############################################################################
# PRELIMINARY SYSTEM CHECK
###############################################################################
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

# Set dependent path variables
ASH3DBINDIR="${ASH3DHOME}/bin"

rc=0                                                       # error message accumulator
# Test for the existance of required files.
GFS_LAST="${WINDROOT}/gfs/last_downloaded.txt"             # Needed to link to the correct forecast package
echo "${SLAB} Checking for ${GFS_LAST}"
if [ -f "${GFS_LAST}" ]; then
  echo "${SLAB}   Found file required file: ${GFS_LAST}"
else
  echo "${SLAB}   ERROR: no ${GFS_LAST} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# Test for the existance/executability of required programs and files.
command -v "${USGSROOT}/bin/MetTraj_F"     > /dev/null 2>&1 ||  { echo >&2 "${SLAB} MetTraj_F not found. Exiting"; exit 1;}
command -v date      > /dev/null 2>&1 ||  { echo >&2 "${SLAB} date not found. Exiting"; exit 1;}
command -v awk       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} awk not found. Exiting"; exit 1;}
command -v sed       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} sed not found. Exiting"; exit 1;}
command -v bc        > /dev/null 2>&1 ||  { echo >&2 "${SLAB} bc not found. Exiting"; exit 1;}

if test -r ash3d_input_ac.inp; then
    INFILE_SIMPLE="ash3d_input_ac.inp"
elif test -r ash3d_input_dp.inp; then
    INFILE_SIMPLE="ash3d_input_dp.inp"
else
    INFILE_SIMPLE="ash3d_input_simp.inp"
fi

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
NARGS=$#
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} running runTraj.sh with $NARGS parameters:"
echo `date`
echo "${SLAB} ------------------------------------------------------------"

LON=`sed -n 2p ${INFILE_SIMPLE} | cut -d' ' -f1`
LAT=`sed -n 2p ${INFILE_SIMPLE} | awk '{print $2}'`
YEAR=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f1`
if [[ "$YEAR" -eq 0 ]] ; then
  # This is a forecast run of the latest windfile
  # Get the offset hour
  HOURf=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f4`
  # Now parse the 'last_downloaded.txt' file for the windfile start hour
  YEAR=`cat ${GFS_LAST} | cut -c1-4`
  MONTH=`cat ${GFS_LAST} | cut -c5-6`
  DAY=`cat ${GFS_LAST} | cut -c7-8`
  HOUR=`cat ${GFS_LAST} | cut -c9-10`

  #YEAR=`date -u +"%Y"`
  #MONTH=`date -u +"%m"`
  #DAY=`date -u +"%d"`
  #HOUR=`date -u +"%H"`
  #MIN=`date -u +"%M"`
else
  MONTH=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f2`
  DAY=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f3`
  HOUR='00'
  HOURf=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f4`
fi

FHOURS=`echo "scale=3;${HOUR} + ${HOURf}" | bc`
echo "${SLAB} -----------------------------------------------------"
echo "${SLAB} Running Forward Trajectory model"
#  5000 ft (1.5240 km) Red       (255/0/0)
# 10000 ft (3.0480 km) Blue      (0/0/255)
# 15000 ft (4.5720 km) Green     (0/255/0)
# 20000 ft (6.0960 km) Cyan      (0/255/255)
# 30000 ft (9.1440 km) Magenta   (255/0/255)
# 40000 ft (12.192 km) Yellow    (255/255/0)
# 50000 ft (15.240 km) Blue-grey (51/153/204)
echo "${SLAB} Calling MetTraj_F lon lat YYYY MM DD HH hrs nlev lv1 lv2 lv3 lv4 lv5 lv6 lv7"
echo "${SLAB} Where: lon  = $LON"
echo "${SLAB}        lat  = $LAT"
echo "${SLAB}        YYYY = $YEAR"
echo "${SLAB}        MM   = $MONTH"
echo "${SLAB}        DD   = $DAY"
echo "${SLAB}        HH   = $FHOURS"
echo "${SLAB}        hrs  = 24"
echo "${SLAB}        nlev = 7"
echo "${SLAB}        lv1  = 1.52"
echo "${SLAB}        lv2  = 3.05"
echo "${SLAB}        lv3  = 4.57"
echo "${SLAB}        lv4  = 6.10"
echo "${SLAB}        lv5  = 9.14"
echo "${SLAB}        lv6  = 12.20"
echo "${SLAB}        lv7  = 15.24"
echo "${SLAB} ${USGSROOT}/bin/MetTraj_F $LON $LAT ${YEAR} ${MONTH} ${DAY} ${FHOURS} 24 7 1.52 3.05 4.57 6.10 9.14 12.20 15.24"
${USGSROOT}/bin/MetTraj_F $LON $LAT ${YEAR} ${MONTH} ${DAY} ${FHOURS} 24 7 1.52 3.05 4.57 6.10 9.14 12.20 15.24
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB}   Error running MetTraj_F: rc=$rc"
  exit $rc
fi

echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "${SLAB} finished runTraj.sh"
echo `date`
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "${SLAB} exiting runTraj.sh with status $rc"
exit $rc

