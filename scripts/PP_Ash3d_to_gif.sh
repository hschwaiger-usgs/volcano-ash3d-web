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

#  variable code , rundirectory
echo "------------------------------------------------------------"
echo "running PP_Ash3d_to_gif.sh with parameter:"
echo "  $1"
if [ $1 -eq 0 ]; then
  echo " 0 = depothick"
fi
if [ $1 -eq 1 ]; then
  echo " 1 = ashcon_max"
fi
if [ $1 -eq 2 ]; then
  echo " 2 = cloud_height"
fi
if [ $1 -eq 3 ]; then
  echo " 3 = cloud_load"
fi
if [ $1 -eq 4 ]; then
  echo " 4 = depotime"
fi
if [ $1 -eq 5 ]; then
  echo " 5 = depothick final (inches)"
fi
if [ $1 -eq 6 ]; then
  echo " 6 = depothick final (mm)"
fi
if [ $1 -eq 7 ]; then
  echo " 7 = ash_arrival_time"
fi

# The optional second command-line argument is used in podman containers
# to set the run directory
if [ "$#" -eq 2 ]; then
  echo "Second command line argument detected: setting run directory"
  RUNHOME=$2
  else
  RUNHOME=`pwd`
fi
cd ${RUNHOME}
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"
RUNDATE=`date -u "+%D %T"`

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
tmax=`ncdump     -h ${infile} | grep "t = UNLIMITED" | grep -v pt | cut -c22-23` # maximum time dimension
t0=`ncdump     -v t ${infile} | grep \ t\ = | cut -f4 -d" " | cut -f1 -d","`
t1=`ncdump     -v t ${infile} | grep \ t\ = | cut -f5 -d" " | cut -f1 -d","`
time_interval=`echo "($t1 - $t0)" |bc -l`
echo "Found $tmax time steps with an interval of ${time_interval}"
#echo "Finished probing output file for run information"

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

echo "Preparing to make the PP maps."
#  Time loop
for (( t=tstart;t<=tmax-1;t++))
do
    time=`echo "${t0} + ${t} * ${time_interval}" | bc -l` 
    echo " ${volc} : Creating map for time = ${time}" 
    if [ $1 -eq 0 ] || [ $1 -eq 5 ] ; then
        echo "Plotting contours (var = $1) for step = $t"
        #0=depothick or 5=depothick final (NWS)
         #   ashcon_max;     cloud_load
    elif [ $1 -eq 1 ] || [ $1 -eq 3 ] ; then
        echo "Plotting contours (var = $1) for step = $t"
         #   cloud_height
    elif [ $1 -eq 2 ] ; then
        echo "Plotting contours (var = $1) for step = $t"
         #    depotime;       ash_arrival_time
    elif [ $1 -eq 4 ] || [ $1 -eq 7 ] ; then
        echo "Plotting contours (var = $1) for step = $t"
    elif [ $1 -eq 6 ] ; then
        #6=depothick final (mm)
        echo "Plotting contours (var = $1) for step = $t"
    else
        echo $1
        echo "I don't know which variable to plot"
        exit
    fi

# uncomment this
#    convert temp.gif output_t${time}.gif
#    if test -r official.txt; then
#       convert -append -background white output_t${time}.gif \
#               ${ASH3DSHARE_PP}/caveats_official.png output_t${time}.gif
#      else
#       convert -append -background white output_t${time}.gif \
#               ${ASH3DSHARE_PP}/caveats_notofficial.png output_t${time}.gif
#    fi
done
# End of time loop

exit

# Finalizing output (animations, shape files, etc.)
if [ $1 -eq 0 ] || [ $1 -eq 1 ] || [ $1 -eq 2 ] || [ $1 -eq 3 ] ; then
    echo "combining gifs to  make animation"
    convert -delay 25 -loop 0 `ls -1tr output_t*.gif` ${var}_animation.gif

    if [ $1 -eq 3 ]; then
        cp ${var}_animation.gif cloud_animation.gif
    fi
  elif [ $1 -eq 5 ]; then
    #Make shapefile
    rm -f var.txt
    echo "dp" > var.txt
    echo "Generating shapefile"
    rm -f dp.shp dp.prj dp.shx dp.dbf dp_shp.zip
    python ${ASH3DSCRIPTDIR}/xyz2shp.py
    if [ "$CLEANFILES" == "T" ]; then
        echo "Removing temp files for shapefile generation"
        rm contour*.xyz volc.txt var.txt
    fi
  elif [ $1 -eq 6 ]; then
    rm -f var.txt
    echo "dp_mm" > var.txt
    #Make shapefile
    echo "Generating shapefile"
    rm -f dp_mm.shp dp_mm.prj dp_mm.shx dp_mm.dbf dp_mm_shp.zip
    python ${ASH3DSCRIPTDIR}/xyz2shp.py
    if [ "$CLEANFILES" == "T" ]; then
        echo "Removing temp files for shapefile generation"
        rm contour*.xyz volc.txt var.txt
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
    # Advancing to the next time step
    if [ $time_interval = "1" ]; then
        t=$(($t+3))
      elif [ $time_interval = "2" ]; then
        t=$(($t+3))
      else
        t=$(($t+1))
    fi
done

# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
   echo "End of GMT_Ash3d_to_gif.sh: removing files."
   rm -f *.grd *.lev
   rm -f current_time.txt
   rm -f caption*.txt cities.xy map_range*txt legend_positions*txt
   rm -f legend*png
   rm -f temp.*
   rm -f gmt.conf gmt.history
   rm -f world_cities.txt
   rm -f VAAC_*.xy *cpt
   rm -f contourfile*xyz
fi

echo "Eruption start time: "$year $month $day $hour
echo "plume height (km) ="$EPlH
echo "eruption duration (hrs) ="$EDur
echo "erupted volume (km3 DRE) ="$EVol
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GMT_Ash3d_to_gif.sh $1 $var"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting GMT_Ash3d_to_gif.sh with status $rc"
exit $rc

