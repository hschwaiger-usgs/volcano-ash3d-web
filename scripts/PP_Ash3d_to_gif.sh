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

#wh-loopc.sh:           enables while loops?

# Parsing command-line arguments
echo "checking input arguments"
if [ -z $1 ] ; then
    echo "Error: you must specify the variable to plot"
    #echo "Usage: runAsh3d.sh rundir zipname dash_flag run_ID java_thread_ID"
    exit 1
fi


pp=3
ASH3DPLOT=$p
#  variable code , rundirectory
echo "------------------------------------------------------------"
echo "running PP_Ash3d_to_gif.sh with parameter:"
echo "  $1"
if [ $1 -eq 0 ]; then
  echo " 0 = depothick"
elif [ $1 -eq 1 ]; then
  echo " 1 = ashcon_max"
elif [ $1 -eq 2 ]; then
  echo " 2 = cloud_height"
elif [ $1 -eq 3 ]; then
  echo " 3 = cloud_load"
elif [ $1 -eq 4 ]; then
  echo " 4 = depotime"
elif [ $1 -eq 5 ]; then
  echo " 5 = depothick final (inches)"
elif [ $1 -eq 6 ]; then
  echo " 6 = depothick final (mm)"
elif [ $1 -eq 7 ]; then
  echo " 7 = ash_arrival_time"
fi

#if [ "$#" -eq 2 ]; then
#  echo "Second command line argument detected: setting run directory"
#  RUNHOME=$2
#  else
  RUNHOME=`pwd`
#fi
cd ${RUNHOME}
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"
# Date of post-processing (may not be run date of simulation)
PPDATE=`date -u "+%D %T"`

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

# variable netcdfnames
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
var=${var_n[$1]}
echo " "
echo "                Generating images for *** $var ***"
echo " "

export PATH=/usr/local/bin:$PATH
infile=${RUNHOME}/"3d_tephra_fall.nc"

#******************************************************************************
#MAKE SURE 3D_tephra_fall.nc EXISTS
if test -r ${infile} ; then
    echo "Preparing to read from ${infile} file"
  else
    echo "error: no ${infile} file. Exiting"
    exit 1
fi
#******************************************************************************
#if [ "$CLEANFILES" == "T" ]; then
#    echo "Removing old files"
#    rm -f *.xyz *.grd contour_range.txt map_range.txt
#fi
echo "Processing " $volc " on " $PPDATE
#Ash3d run date
RUNDATE=`ncdump -h ${infile} | grep date | cut -d\" -f2`
#time of eruption start
year=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c1-4`
month=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c5-6`
day=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c7-8`
hour=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c9-10`
minute=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c12-13`
hours_real=`echo "$hour + $minute / 60" | bc -l`

tmax=`ncdump     -h ${infile} | grep "t = UNLIMITED" | grep -v pt | cut -c22-23` # maximum time dimension
t0=`ncdump     -v t ${infile} | grep \ t\ = | cut -f4 -d" " | cut -f1 -d","`
t1=`ncdump     -v t ${infile} | grep \ t\ = | cut -f5 -d" " | cut -f1 -d","`
time_interval=`echo "($t1 - $t0)" |bc -l`
echo "Found $tmax time steps with an interval of ${time_interval}"

######################
# Get the number of time steps we need
 #   depotime;       Fin.Dep (in);  Fin.Dep (mm)     ash_arrival_time
if [ $1 -eq 4 ] || [ $1 -eq 5 ] || [ $1 -eq 6 ] || [ $1 -eq 7 ] ; then
    #  For final times or non-time-series, set time to the last value
    tstart=$(( $tmax-1 ))
    echo "We are working on a final/static variable so set tstart = $tstart"
  else
    # For normal time-series variables, start at the beginning
    tstart=0
    echo "We are working on a transient variable so set tstart = $tstart"
fi

echo "Preparing to make the Ash3d_PostProc maps."
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
    echo " Creating map for time = ${time}" 
    if   [ $1 -eq 0 ] ; then # depothick (time-series)
        echo "Plotting contours (var = $1) for step = $t from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 3 3 $((t+1))
    elif [ $1 -eq 1 ] ; then # ashcon_max
        echo "Plotting contours (var = $1) for step = $t from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 9 3 $((t+1))
    elif [ $1 -eq 2 ] ; then # cloud_height
        echo "Plotting contours (var = $1) for step = $t from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 10 3 $((t+1))
    elif [ $1 -eq 3 ] ; then # cloud_load
        echo "Plotting contours (var = $1) for step = $t from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 12 3 $((t+1))
    elif [ $1 -eq 4 ] ; then # depotime
        echo "Plotting contours (var = $1) (final step) from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 7 3
    elif [ $1 -eq 5 ] ; then # depothick final (inches)
        echo "Plotting contours (var = $1) (final step) from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 6 3
    elif [ $1 -eq 6 ] ; then # depothick final (mm)
        echo "Plotting contours (var = $1) (final step) from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 5 3
    elif [ $1 -eq 7 ] ; then # ash_arrival_time
        echo "Plotting contours (var = $1) (final step) from ${infile}"
        ASH3DPLOT=$p ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 14 3
    else
        echo $1
        echo "I don't know which variable to plot"
        exit
    fi
    # Get the name of the last png created and convert to gif
    ofile=`ls -1tr *png | tail -1`
    convert $ofile temp.gif

    convert temp.gif output_t${time}.gif
    if test -r official.txt; then
       convert -append -background white output_t${time}.gif \
               ${ASH3DSHARE_PP}/caveats_official.png output_t${time}.gif
      else
       convert -append -background white output_t${time}.gif \
               ${ASH3DSHARE_PP}/caveats_notofficial.png output_t${time}.gif
    fi
done
# End of time loop

# Finalizing output (animations, shape files, etc.)
if [ $1 -eq 0 ] || [ $1 -eq 1 ] || [ $1 -eq 2 ] || [ $1 -eq 3 ] ; then
    echo "combining gifs to  make animation"
    convert -delay 25 -loop 0 `ls -1tr output_t*.gif` ${var}_animation.gif

    if [ $1 -eq 3 ]; then
        cp ${var}_animation.gif cloud_animation.gif
    fi
  elif [ $1 -eq 5 ]; then
    # Make shapefile for depothick final (inches)
    echo "Generating shapefile for depothick final (inches)"
    rm -f depothik.shx depothik.shp depothik.prj depothik.dbf dp_in_shp.zip
    ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 6 5
    if test -r depothik.zip ; then
      mv depothik.zip dp_in_shp.zip
    else
      zip dp_in_shp.zip depothik.shx depothik.shp depothik.prj depothik.dbf
    fi
    if [ "$CLEANFILES" == "T" ]; then
        echo "Removing temp files for shapefile generation"
        rm depothik.shx depothik.shp depothik.prj depothik.dbf
    fi
  elif [ $1 -eq 6 ]; then
    # Make shapefile for depothick final (mm)
    echo "Generating shapefile for depothick final (mm)"
    rm -f depothik.shx depothik.shp depothik.prj depothik.dbf dp_mm_shp.zip
    ${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 5 5
    if test -r depothik.zip ; then
      mv depothik.zip dp_mm_shp.zip
    else
      zip dp_mm_shp.zip depothik.shx depothik.shp depothik.prj depothik.dbf
    fi
    if [ "$CLEANFILES" == "T" ]; then
        echo "Removing temp files for shapefile generation"
        rm depothik.shx depothik.shp depothik.prj depothik.dbf
    fi
fi

echo "Renaming gif images"
if [ $1 -eq 0 ] || [ $1 -eq 1 ] || [ $1 -eq 2 ] || [ $1 -eq 3 ] ; then
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
    echo "moving file output_t${time}.gif to ${filename}_${var}.gif"
    if [ $1 -eq 5 ]; then
        cp output_t${time}.gif deposit_thickness_inches.gif
      elif [ $1 -eq 6 ]; then
        cp output_t${time}.gif deposit_thickness_mm.gif
    fi
    mv output_t${time}.gif ${filename}_${var}.gif
    t=$(($t+1))
done

# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
   echo "End of PP_Ash3d_to_gif.sh: removing files."
   rm -f volc.dat volc.txt
   rm -f outvar.* cities.xy
   rm -f *png temp.gif Ash3d_pp.log
fi

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished PP_Ash3d_to_gif.sh $1 $var"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting PP_Ash3d_to_gif.sh with status $rc"
exit $rc

