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
echo "running runGFS_puff.sh"
echo `date`
echo "------------------------------------------------------------"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"
WINDROOT="/data/WindFiles"

GFSDATAHOME="${WINDROOT}/gfs"
PUFFWIND="${WINDROOT}/puff/gfs"

ln -s ${PUFFWIND} .

INFILE_SIMPLE="ash3d_input_ac.inp"                #simplified input file
LON=`sed -n 2p ${INFILE_SIMPLE} | cut -d' ' -f1`
LAT=`sed -n 2p ${INFILE_SIMPLE} | cut -d' ' -f2`
HPLMkm=`sed -n 4p ${INFILE_SIMPLE} | cut -d' ' -f1`
HPLMm=`echo "${HPLMkm} 1000.0 * p" |dc`
BPLMm=`sed -n 3p ${INFILE_SIMPLE} | cut -d' ' -f1`
EDUR=`sed -n 4p ${INFILE_SIMPLE} | cut -d' ' -f2`
SDUR=`sed -n 4p ${INFILE_SIMPLE} | cut -d' ' -f3`
YEAR=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f1`
if [[ "$YEAR" -eq 0 ]] ; then
  YEAR=`date -u +"%Y"`
  MONTH=`date -u +"%m"`
  DAY=`date -u +"%d"`
  HOUR=`date -u +"%H"`
  MIN=`date -u +"%M"`
else
  MONTH=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f2`
  DAY=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f3`
  HOURf=`sed -n 5p ${INFILE_SIMPLE} | cut -d' ' -f4`
  HOURi=${HOURf%.*}
  if [[ "$HOURi" -lt 10 ]] ; then
    HOUR=0${HOURi}
  else
    HOUR=$HOURi
  fi
  MINf=`echo "($HOURf - $HOURi) * 60" | bc `
  MINi=${MINf%.*}
  if [[ "$MINi" -lt 10 ]] ; then
    MIN=0${MINi}
  else
    MIN=$MINi
  fi
fi
echo "YEAR=${YEAR}"
echo "MONTH=${MONTH}"
echo "DAY=${DAY}"
echo "HOUR=${HOUR} ${HOURf} ${HOURi}"
echo "MIN=${MIN} ${MINf} ${MINi}"

SDURi=${SDUR%.*}
if [[ "$SDURi" -gt 48 ]] ; then
 SHOURS="6.0"
fi
if [[ "$SDURi" -le 48 ]] ; then
 SHOURS="3.0"
fi
if [[ "$SDURi" -le 16 ]] ; then
 SHOURS="1.0"
fi
if [[ "$SDURi" -le 8 ]] ; then
 SHOURS="0.5"
fi

RUNDIR=`pwd`

echo "SHOURS=$SHOURS"
FHOURS=`echo "scale=3;${HOUR} + ${MIN}/60.0" | bc`
echo "-----------------------------------------------------"
echo "Running puff : Plume H = ${HPLMm}" 
echo "/home/ash3d/www/html/puff/bin/puff \
--quiet="true" --gridSize="0.5x2000" \
--averageOutput="true" --repeat="5" --gridOutput="true" \
--opath=${RUNDIR} \
--lonLat $LON/$LAT \
--rcfile /home/ash3d/www/html/puff/etc/puffrc \
--volcFile /home/ash3d/www/html/puff/etc/volcanos.txt \
--ashLogMean=-6 --model=gfs --restartFile=none --regionalWinds=30 \
--diffuseH=10000 --phiDist="" \
--saveHours=${SHOURS} --nAsh=2000 --runHours=${SDUR} \
--eruptHours=${EDUR} --plumeShape=linear --ashLogSdev=1 \
--plumeMax=${HPLMm} \
--dem=none --plumeZwidth=3 --plumeMin=${BPLMm} \
--eruptDate="${YEAR} ${MONTH} ${DAY} ${HOUR}:${MIN}" \
--diffuseZ=10 --plumeHwidth=0"

#/webdata/volcview.wr.usgs.gov/puff/bin/puff \
/home/ash3d/www/html/puff/bin/puff \
--quiet="true" --gridSize="0.5x2000" \
--averageOutput="true" --repeat="5" --gridOutput="true" \
--opath=${RUNDIR} \
--lonLat $LON/$LAT \
--rcfile /home/ash3d/www/html/puff/etc/puffrc \
--volcFile /home/ash3d/www/html/puff/etc/volcanos.txt \
--ashLogMean=-6 --model=gfs --restartFile=none --regionalWinds=30 \
--diffuseH=10000 --phiDist="" \
--saveHours=${SHOURS} --nAsh=2000 --runHours=${SDUR} \
--eruptHours=${EDUR} --plumeShape=linear --ashLogSdev=1 \
--plumeMax=${HPLMm} \
--dem=none --plumeZwidth=3 --plumeMin=${BPLMm} \
--eruptDate="${YEAR} ${MONTH} ${DAY} ${HOUR}:${MIN}" --diffuseZ=10 --plumeHwidth=0
echo "-----------------------------------------------------"

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished runGFS_puff.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting runGFS_puff.sh with status $rc"
exit $rc

