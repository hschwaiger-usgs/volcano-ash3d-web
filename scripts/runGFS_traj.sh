#!/bin/bash

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

echo "------------------------------------------------------------"
echo "running runGFS_traj.sh"
echo `date`
echo "------------------------------------------------------------"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"
WINDROOT="/data/WindFiles"

ASH3DBINDIR="${ASH3DROOT}/bin"
GFSDATAHOME="${WINDROOT}/gfs"

INFILE_SIMPLE="ash3d_input_ac.inp"                #simplified input file
LASTDOWN="${GFSDATAHOME}/last_downloaded.txt"
LON=`sed -n 2p ${INFILE_SIMPLE} | cut -d' ' -f1`
LAT=`sed -n 2p ${INFILE_SIMPLE} | cut -d' ' -f2`
YEAR=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f1`
if [[ "$YEAR" -eq 0 ]] ; then
  # This is a forecast run off the latest windfile
  # Get the offset hour
  HOURf=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f4`
  # Now parse the 'last_downloaded.txt' file for the windfile start hour
  YEAR=`cat ${LASTDOWN} | cut -c1-4`
  MONTH=`cat ${LASTDOWN} | cut -c5-6`
  DAY=`cat ${LASTDOWN} | cut -c7-8`
  HOUR=`cat ${LASTDOWN} | cut -c9-10`

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
echo "-----------------------------------------------------"
echo "Running Forward Trajectory model"
#  5000 ft (1.5240 km) Red       (255/0/0)
# 10000 ft (3.0480 km) Blue      (0/0/255)
# 15000 ft (4.5720 km) Green     (0/255/0)
# 20000 ft (6.0960 km) Cyan      (0/255/255)
# 30000 ft (9.1440 km) Magenta   (255/0/255)
# 40000 ft (12.192 km) Yellow    (255/255/0)
# 50000 ft (15.240 km) Blue-grey (51/153/204)
echo "${USGSROOT}/bin/MetTraj $LON $LAT ${YEAR} ${MONTH} ${DAY} ${FHOURS} 24 7 1.52 3.05 4.57 6.10 9.14 12.20 15.24"
${USGSROOT}/bin/MetTraj_F $LON $LAT ${YEAR} ${MONTH} ${DAY} ${FHOURS} 24 7 1.52 3.05 4.57 6.10 9.14 12.20 15.24

        rc=$((rc + $?))


echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished runGFS_traj.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting runGFS_traj.sh with status $rc"
exit $rc

