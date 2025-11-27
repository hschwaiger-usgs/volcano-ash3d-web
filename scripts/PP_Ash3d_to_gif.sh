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
# This script is called from runAsh3d.sh, runAsh3d_ac.sh and runAsh3d_dp.sh and plots a variable
# (either static or transient) identified by varID.
# Run information is extracted from ${ASH3D_NCFILE}
#
#      Usage: PP_Ash3d_to_gif.sh varID RunDir
#       e.g. /opt/USGS/Ash3d/bin/scripts/PP_Ash3d_to_gif.sh             \
#               3                                                        \
#               /var/www/html/ash3d-api/htdocs/ash3druns/ash3d_run_334738/
#
# Files needed:
#   3d_tephra_fall.nc     : output from an Ash3d run
#   USGSvid.png           : institutional logo needed for final map
#   caveats_notofficial.png : disclaimer banner added to figure
# Programs needed:
#   ReadNCheader.sh       : script that reads NetCDF header
#   HoursSince1900        : 
#   yyyymmddhh_since_1900 : 
#   Ash3d_PostProc        : utility for generating the map
#   convert               : ImageMagick package
#
SLAB="[PP_Ash3d_to_gif.sh]: "            # Script label prepended on all echo to stdout
#
export PATH=/usr/local/bin:$PATH

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
# Customizable settings
PPLIB=3

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

# Parsing command-line arguments
#  variable code , [rundirectory]
echo "${SLAB} ------------------------------------------------------------"
if [ "$#" -eq 0 ]; then
  echo "${SLAB} No variable code provided."
  echo "${SLAB}   0 = depothick"
  echo "${SLAB}   1 = ashcon_max"
  echo "${SLAB}   2 = cloud_height"
  echo "${SLAB}   3 = cloud_load"
  echo "${SLAB}   4 = depotime"
  echo "${SLAB}   5 = depothick final (inches)"
  echo "${SLAB}   6 = depothick final (mm)"
  echo "${SLAB}   7 = ash_arrival_time"
  exit $rc
fi
echo "${SLAB} running PP_Ash3d_to_gif.sh with parameter:"
echo "${SLAB}   varID=$1"
varID=$1
if [ $varID -eq   0 ]; then
  echo "${SLAB}   0 = depothick"
elif [ $varID -eq 1 ]; then
  echo "${SLAB}   1 = ashcon_max"
elif [ $varID -eq 2 ]; then
  echo "${SLAB}   2 = cloud_height"
elif [ $varID -eq 3 ]; then
  echo "${SLAB}   3 = cloud_load"
elif [ $varID -eq 4 ]; then
  echo "${SLAB}   4 = depotime"
elif [ $varID -eq 5 ]; then
  echo "${SLAB}   5 = depothick final (inches)"
elif [ $varID -eq 6 ]; then
  echo "${SLAB}   6 = depothick final (mm)"
elif [ $varID -eq 7 ]; then
  echo "${SLAB}   7 = ash_arrival_time"
else
  echo "${SLAB} Variable code is not between 0 and 7"
  exit $rc
fi
# The optional second command-line argument is used in podman containers
# to set the run directory
if [ "$#" -eq 2 ]; then
  echo "${SLAB} Second command line argument detected: setting run directory"
  RUNHOME=$2
 else
  echo "${SLAB} No second command line argument detected, using pwd"
  RUNHOME=`pwd`
fi
cd ${RUNHOME}
echo "${SLAB} ------------------------------------------------------------"

###############################################################################
# PRELIMINARY SYSTEM CHECK
###############################################################################
rc=0                                                       # error message accumulator
# Test for the existance of required files.
LOGO=${ASH3DSHARE_PP}/USGSvid.png
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${LOGO}"
else
  echo "${SLAB}   ERROR: no ${LOGO} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
CAVEAT=${ASH3DSHARE_PP}/caveats_notofficial.png
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${CAVEAT}"
else
  echo "${SLAB}   ERROR: no ${CAVEAT} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# Test for the existance/executability of required programs and files.
command -v "${ASH3DSCRIPTDIR}/ReadNCheader.sh"      > /dev/null 2>&1 ||  { echo >&2 "${SLAB} ReadNCheader.sh not found. Exiting"; exit 1;}
command -v "${USGSROOT}/bin/HoursSince1900"         > /dev/null 2>&1 ||  { echo >&2 "${SLAB} HoursSince1900 not found. Exiting"; exit 1;}
command -v "${USGSROOT}/bin/yyyymmddhh_since_1900"  > /dev/null 2>&1 ||  { echo >&2 "${SLAB} yyyymmddhh_since_1900 not found. Exiting"; exit 1;}
command -v "${ASH3DBINDIR}/Ash3d_PostProc"          > /dev/null 2>&1 ||  { echo >&2 "${SLAB} Ash3d_PostProc not found. Exiting"; exit 1;}
command -v convert   > /dev/null 2>&1 ||  { echo >&2 "${SLAB} convert not found. Exiting"; exit 1;}

rc=0                                             # error message accumulator
CLEANFILES="T"
# Date of post-processing (may not be run date of simulation)
PPDATE=`date -u "+%D %T"`

# Link to shared post-processing files

# Now testing for files that are needed
ASH3D_NCFILE="${RUNHOME}/3d_tephra_fall.nc"
if [ -f "$ASH3D_NCFILE" ]; then
  echo "${SLAB} Found file $ASH3D_NCFILE"
else
  echo "${SLAB} ERROR: no ${ASH3D_NCFILE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# variable netcdfnames
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
var=${var_n[$varID]}
echo "${SLAB}  "
echo "${SLAB}                 Generating images for *** $var ***"
echo "${SLAB}  "

#******************************************************************************
echo "${SLAB} Preparing to read from ${ASH3D_NCFILE} file"
echo "${SLAB} ******************************************************************************"
#GET VARIABLES FROM 3D_tephra-fall.nc
source ${ASH3DSCRIPTDIR}/ReadNCheader.sh ${ASH3D_NCFILE}
echo "${SLAB} Finished reading netcdf header."
echo "${SLAB} ******************************************************************************"

######################
# Get the number of time steps we need
 #   depotime;       Fin.Dep (in);  Fin.Dep (mm)     ash_arrival_time
if [ $varID -eq 4 ] || [ $varID -eq 5 ] || [ $varID -eq 6 ] || [ $varID -eq 7 ] ; then
  #  For final times or non-time-series, set time to the last value
  tstart=$(( $tmax-1 ))
  echo "${SLAB} We are working on a final/static variable so set tstart = $tstart"
else
  # For normal time-series variables, start at the beginning
  tstart=0
  echo "${SLAB} We are working on a transient variable so set tstart = $tstart"
fi

echo "${SLAB} Preparing to make the Ash3d_PostProc maps."
 # echo "  0 = depothick"
 # echo "  1 = ashcon_max"
 # echo "  2 = cloud_height"
 # echo "  3 = cloud_load"
 # echo "  4 = depotime"
 # echo "  5 = depothick final (inches)"
 # echo "  6 = depothick final (mm)"
 # echo "  7 = ash_arrival_time"

#  Time loop
for (( t=tstart;t<=tmax-1;t++))
do
  time=`echo "${t0} + ${t} * ${time_interval}" | bc -l` 
  echo "${SLAB} ${volc} : Creating map for time = ${time}" 
  if   [ $varID -eq 0 ] ; then # depothick (time-series)
    echo "${SLAB} Plotting contours (var = varID) for step = $t from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 3 3 $((t+1))
  elif [ $varID -eq 1 ] ; then # ashcon_max
    echo "${SLAB} Plotting contours (var = varID) for step = $t from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 9 3 $((t+1))
  elif [ $varID -eq 2 ] ; then # cloud_height
    echo "${SLAB} Plotting contours (var = varID) for step = $t from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 10 3 $((t+1))
  elif [ $varID -eq 3 ] ; then # cloud_load
    echo "${SLAB} Plotting contours (var = varID) for step = $t from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 12 3 $((t+1))
  elif [ $varID -eq 4 ] ; then # depotime
    echo "${SLAB} Plotting contours (var = varID) (final step) from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 7 3
  elif [ $varID -eq 5 ] ; then # depothick final (inches)
    echo "${SLAB} Plotting contours (var = varID) (final step) from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 6 3
  elif [ $varID -eq 6 ] ; then # depothick final (mm)
    echo "${SLAB} Plotting contours (var = varID) (final step) from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 5 3
  elif [ $varID -eq 7 ] ; then # ash_arrival_time
    echo "${SLAB} Plotting contours (var = varID) (final step) from ${ASH3D_NCFILE}"
    ASH3DPLOT=${PPLIB} ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 14 3
  else
    echo $varID
    echo "${SLAB} I don't know which variable to plot"
    exit $rc
  fi
  # Get the name of the last png created and convert to gif
  ofile=`ls -1tr *png | tail -1`
  convert $ofile temp.gif

  convert temp.gif output_t${time}.gif
  convert -append -background white output_t${time}.gif ${CAVEAT} output_t${time}.gif
done
# End of time loop

# Finalizing output (animations, shape files, etc.)
if [ $varID -eq 0 ] || [ $varID -eq 1 ] || [ $varID -eq 2 ] || [ $varID -eq 3 ] ; then
  echo "${SLAB}  Combining gifs to  make animation"
  convert -delay 25 -loop 0 `ls -1tr output_t*.gif` ${var}_animation.gif

  if [ $varID -eq 3 ]; then
    cp ${var}_animation.gif cloud_animation.gif
  fi
elif [ $varID -eq 5 ]; then
  # Make shapefile for depothick final (inches)
  #rm -f var.txt
  #echo "dp" > var.txt
  echo "${SLAB} Generating shapefile with Ash3d_PostProc ${ASH3D_NCFILE} 6 5"
  rm -f depothik.shx depothik.shp depothik.prj depothik.dbf dp_in_shp.zip
  ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 6 5
  if test -r depothik.zip ; then
    mv depothik.zip dp_shp.zip
  else
    zip dp_in_shp.zip depothik.shx depothik.shp depothik.prj depothik.dbf
  fi
  if [ "$CLEANFILES" == "T" ]; then
    echo "${SLAB} Removing temp files for shapefile generation"
    rm depothik.shx depothik.shp depothik.prj depothik.dbf
  fi
elif [ $varID -eq 6 ]; then
  #rm -f var.txt
  #echo "dp_mm" > var.txt
  # Make shapefile for depothick final (mm)
  echo "${SLAB} Generating shapefile with Ash3d_PostProc ${ASH3D_NCFILE} 5 5"
  rm -f depothik.shx depothik.shp depothik.prj depothik.dbf dp_mm_shp.zip
  ${ASH3DBINDIR}/Ash3d_PostProc ${ASH3D_NCFILE} 5 5
  if test -r depothik.zip ; then
    mv depothik.zip dp_mm_shp.zip
  else
    zip dp_mm_shp.zip depothik.shx depothik.shp depothik.prj depothik.dbf
  fi
  if [ "$CLEANFILES" == "T" ]; then
    echo "${SLAB} Removing temp files for shapefile generation"
    rm depothik.shx depothik.shp depothik.prj depothik.dbf
  fi
fi

echo "${SLAB} Renaming gif images"
if [ $varID -eq 0 ] || [ $varID -eq 1 ] || [ $varID -eq 2 ] || [ $varID -eq 3 ] ; then
  t=0
else
  t=$(($tmax-1))
fi
while [ "$t" -le $(($tmax-1)) ]
do
  time=`echo "${t0} + ${t} * ${time_interval}" | bc -l`
  hours_now=`echo "$hours_real + $time" | bc -l`
  hours_since=`${USGSROOT}/bin/HoursSince1900 $year $month $day $hours_now`
  filename=`${USGSROOT}/bin/yyyymmddhh_since_1900 $hours_since`
  echo "${SLAB} Moving file $t of $tmax output_t${time}.gif to ${filename}_${var}.gif"
  if [ $varID -eq 5 ]; then
    cp output_t${time}.gif deposit_thickness_inches.gif
  elif [ $varID -eq 6 ]; then
    cp output_t${time}.gif deposit_thickness_mm.gif
  fi
  mv output_t${time}.gif ${filename}_${var}.gif
  t=$(($t+1))
done

# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
  echo "${SLAB} End of PP_Ash3d_to_gif.sh: removing files."
  rm -f volc.dat volc.txt
  rm -f outvar.* cities.xy
  rm -f *png temp.gif Ash3d_pp.log
fi

echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "${SLAB} finished PP_Ash3d_to_gif.sh $varID $var"
echo `date`
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "${SLAB} Exiting PP_Ash3d_to_gif.sh with status $rc"
exit $rc
