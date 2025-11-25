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
#      This script reads the provided Ash3d NetCDF output file, then parses the header,
#      setting the variables needed. Because its function is to set variables in the callingn
#      script, it must be 'source'ed, rather than executed.
#
#      Usage: source ReadNCheader.sh ASH3D_NCFILE
#       e.g. source /opt/USGS/Ash3d/bin/scripts/ReadNCheader.sh          \
#               3d_tephra_fall.nc 
#
# Files needed:
#   3d_tephra_fall.nc     : output from an Ash3d run
#   map_range_traj.txt    : output from MetTraj_F
#   ftraj[1-7].dat        : output from MetTraj_F
# Programs needed:
#   convert_to_decimal    : 
#   date,awk,sed,bc       : unix tools
#   ncdump                : NetCDF processing tool
#
SLABl="[ReadNCheader.sh]: "            # Script label prepended on all echo to stdout (local)
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
# Set dependent path variables
ASH3DBINDIR="${ASH3DHOME}/bin"
ASH3DSCRIPTDIR="${ASH3DHOME}/bin/scripts"
ASH3DSHARE="$ASH3DHOME/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

# Test for the existance of required files.
   # Files are checked below once we have the RUNDIR
# Test for the existance/executability of required programs.
command -v "${ASH3DBINDIR}/convert_to_decimal"     > /dev/null 2>&1 ||  { echo >&2 "convert_to_decimal not found. Exiting"; exit 1;}
command -v date      > /dev/null 2>&1 ||  { echo >&2 "date not found. Exiting"; exit 1;}
command -v awk       > /dev/null 2>&1 ||  { echo >&2 "awk not found. Exiting"; exit 1;}
command -v sed       > /dev/null 2>&1 ||  { echo >&2 "sed not found. Exiting"; exit 1;}
command -v bc        > /dev/null 2>&1 ||  { echo >&2 "bc not found. Exiting"; exit 1;}

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
# Customizable settings
# Parsing command-line arguments

if [ "$#" -eq 1 ]; then
  ASH3D_NCFILE=$1
else
  echo "${SLABl} No input file given. Assuming default of 3d_tephra_fall.nc"
  ASH3D_NCFILE=="3d_tephra_fall.nc"
fi

# Now testing for files that are needed
if [ -f "$ASH3D_NCFILE" ]; then
  echo "${SLABl} Found file $ASH3D_NCFILE"
else
  echo "${SLABl} ERROR: no ${ASH3D_NCFILE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# GET VARIABLES FROM 3d_tephra_fall.nc
volc=`ncdump -h ${ASH3D_NCFILE} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLABl} ncdump command failed.  Exiting script"
  exit $rc
fi
#echo $volc > volc.txt
#date=`ncdump -h ${ASH3D_NCFILE} | grep Date | cut -d\" -f2 | cut -c 1-10`

#Ash3d run date
RUNDATE=`ncdump -h ${ASH3D_NCFILE} | grep date | cut -d\" -f2`
#time of eruption start
year=`ncdump -h ${ASH3D_NCFILE} | grep ReferenceTime | cut -d\" -f2 | cut -c1-4`
month=`ncdump -h ${ASH3D_NCFILE} | grep ReferenceTime | cut -d\" -f2 | cut -c5-6`
day=`ncdump -h ${ASH3D_NCFILE} | grep ReferenceTime | cut -d\" -f2 | cut -c7-8`
hour=`ncdump -h ${ASH3D_NCFILE} | grep ReferenceTime | cut -d\" -f2 | cut -c9-10`
minute=`ncdump -h ${ASH3D_NCFILE} | grep ReferenceTime | cut -d\" -f2 | cut -c12-13`
hours_real=`echo "$hour + $minute / 60" | bc -l`

#latitude & longitude of lower left corner of map
LLLON=`ncdump -h ${ASH3D_NCFILE} | grep b1l3 | cut -d\" -f2 | awk '{print $1}'`
LLLAT=`ncdump -h ${ASH3D_NCFILE} | grep b1l3 | cut -d\" -f2 | awk '{print $2}'`
DLON=`ncdump -h ${ASH3D_NCFILE} | grep b1l4 | cut -d\" -f2 | awk '{print $1}'`
DLAT=`ncdump -h ${ASH3D_NCFILE} | grep b1l4 | cut -d\" -f2 | awk '{print $2}'`
URLON=`echo "$LLLON+$DLON" | bc -l`
URLAT=`echo "$LLLAT+$DLAT" | bc -l`

#get volcano longitude, latitude
VCLON=`ncdump -h ${ASH3D_NCFILE} | grep b1l5 | cut -d\" -f2 | awk '{print $1}'`
VCLAT=`ncdump -h ${ASH3D_NCFILE} | grep b1l5 | cut -d\" -f2 | awk '{print $2}'`
echo "VCLON="$VCLON ", VCLAT="$VCLAT

#get source parameters from netcdf file
EDur=`ncdump -v er_duration ${ASH3D_NCFILE} | grep er_duration | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EPlH=`ncdump -v er_plumeheight ${ASH3D_NCFILE} | grep er_plumeheight | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EVol_fl=`ncdump -v er_volume ${ASH3D_NCFILE} | grep er_volume | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`

FineAshFrac=0.05
EVol_dec=`${ASH3DBINDIR}/convert_to_decimal $EVol_fl`   #if it's in scientific notation, convert to real
EVol_ac=`echo "($EVol_dec / $FineAshFrac)" | bc -l`
EVol_dp=$EVol_dec

# Remove the trailing zeros
echo $EVol_ac  | awk ' sub("\\.*0+$","") ' > tmp.txt
EVol_ac=`cat tmp.txt`
echo $EVol_dp  | awk ' sub("\\.*0+$","") ' > tmp.txt
EVol_dp=`cat tmp.txt`
rm -rf tmp.txt
if test -r ash3d_input_ac.inp; then
  EVol=${EVol_ac}
 else
  EVol=${EVol_dp}
fi
#If volume equals minimum threshold volume, add annotation
EVol_int=`echo "$EVol * 10000" | bc -l | sed 's/\.[0-9]*//'`   #convert EVol to an integer
if [ $EVol_int -eq 1 ] ; then
    EVol="0.0001"
    Threshval="(min. threshold)"
  else
    Threshval=""
fi

#get start time of wind file
echo "${SLABl} getting windfile time"
windtime=`ncdump -h ${ASH3D_NCFILE} | grep NWPStartTime | cut -c20-39`
gsbins=`ncdump   -h ${ASH3D_NCFILE} | grep "bn =" | cut -c6-8`        # of grain-size bins
zbins=`ncdump    -h ${ASH3D_NCFILE} | grep "z ="  | cut -c6-7`        # # of elevation levels
tmax=`ncdump     -h ${ASH3D_NCFILE} | grep "t = UNLIMITED" | grep -v pt | cut -c22-23` # maximum time dimension
t0=`ncdump     -v t ${ASH3D_NCFILE} | grep \ t\ = | cut -f4 -d" " | cut -f1 -d","`
t1=`ncdump     -v t ${ASH3D_NCFILE} | grep \ t\ = | cut -f5 -d" " | cut -f1 -d","`
time_interval=`echo "($t1 - $t0)" | bc -l`
iwindformat=`ncdump -h ${ASH3D_NCFILE} | grep b3l1 | cut -f2 -d\" | cut -f1 -d# |  tr -s " " | awk '{print $2}'`
echo "${SLABl} windtime=$windtime"
echo "${SLABl} iwindformat=$iwindformat"
echo "${SLABl} windtime=$windtime"
if [ ${iwindformat} -eq 25 ]; then
  windfile="NCEP reanalysis 2.5 degree"
elif [ ${iwindformat} -eq 34 ]; then
  windfile="ECMWF forecast 0.25 degree for $windtime"
else
  windfile="GFS forecast 0.5 degree for $windtime"
fi
echo "${SLABl} Found $tmax time steps with an interval of ${time_interval}"
echo "${SLABl} Finished probing output file for run information"

###############################################################################
##  Now make the maps
#get latitude & longitude range
#lonmin=$LLLON
#latmin=$LLLAT
#lonmax=`echo "$LLLON + $DLON" | bc -l`
#latmax=`echo "$LLLAT + $DLAT" | bc -l`
#echo "${SLABl} lonmin="$lonmin ", lonmax="$lonmax ", latmin="$latmin ", latmax="$latmax
#echo "$lonmin $lonmax $latmin $latmax $VCLON $VCLAT" > map_range.txt


