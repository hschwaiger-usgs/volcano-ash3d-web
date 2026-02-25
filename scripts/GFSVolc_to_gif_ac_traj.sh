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
#      This script is called from runAsh3d.sh and runAsh3d_ac.sh and plots a trajectory map of the
#      run (ftraj[1-7].dat) using the max/min of the data if called with runID=0 or using the
#      exiting basemap if runID=1.
#      Run information is extracted from 3d_tephra_fall.nc
#
#      Usage: GFSVolc_to_gif_ac_traj.sh passID RunDir
#       e.g. /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_traj.sh          \
#               0                                                           \
#               /var/www/html/ash3d-api/htdocs/ash3druns/ash3d_run_334738/
#
# Files needed:
#   world_cities.txt      : shared post-processing file
#   3d_tephra_fall.nc     : output from an Ash3d run
#   map_range_traj.txt    : output from MetTraj_F
#   ftraj[1-7].dat        : output from MetTraj_F
#   USGSvid.png           : institutional logo needed for final map
#   legend_hysplit.png    : legend for trajectory data
#   caveats_notofficial_trajectory.png : disclaimer banner added to figure
# Programs needed:
#   gmt_test.sh           : script that identifies gmt version and sets variables
#   ReadNCheader.sh       : script that reads NetCDF header
#   legend_placer_ac_traj : determine data legend position, writting file legend_positions_ac.txt
#   date,awk,sed,bc       : unix tools
#   gmt                   : Generic Mapping Tools
#   ncdump                : NetCDF processing tool
#   convert               : ImageMagick package
#   identify              : ImageMagick package
#   composite             : ImageMagick package
#
SLAB="[GFSVolc_to_gif_ac_traj.sh]: "            # Script label prepended on all echo to stdout
#
export PATH=/usr/local/bin:$PATH

###############################################################################
# PRELIMINARY SCRIPT CALL CHECK
###############################################################################
# Customizable settings

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
#  first/second pass , rundirectory
NARGS=$#
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} running GFSVolc_to_gif_ac_traj.sh with $NARGS parameters:"
if [ $NARGS -gt 0 ]; then
  PASSID=$1
else
  PASSID=0
fi
if [ $PASSID -eq 0 ]; then
  echo "${SLAB}  0 = first pass"
fi
if [ $PASSID -eq 1 ]; then
  echo "${SLAB}  1 = second pass"
fi
if [ "$NARGS" -eq 2 ]; then
  echo "${SLAB} Second command line argument detected: setting run directory"
  RUNHOME=$2
 else
  echo "${SLAB} No second command line argument detected, using pwd"
  RUNHOME=`pwd`
fi
cd ${RUNHOME}
echo `date`
echo "${SLAB} ------------------------------------------------------------"

###############################################################################
# PRELIMINARY SYSTEM CHECK
###############################################################################
rc=0                                                       # error message accumulator
# Test for the existance of required files.
WORLDCITIES="${ASH3DSHARE_PP}/world_cities.txt"
echo "${SLAB} Checking for all required auxillary files."
if [ -f "${WORLDCITIES}" ]; then
  echo "${SLAB}   Found file required file: ${WORLDCITIES}"
else
  echo "${SLAB}   ERROR: no ${WORLDCITIES} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

LOGO=${ASH3DSHARE_PP}/USGSvid.png
echo "${SLAB} Checking for ${LOGO}"
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${LOGO}"
else
  echo "${SLAB}   ERROR: no ${LOGO} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

LEGEND=${ASH3DSHARE_PP}/legend_hysplit.png
echo "${SLAB} Checking for ${LEGEND}"
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${LEGEND}"
else
  echo "${SLAB}   ERROR: no ${LEGEND} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

CAVEAT=${ASH3DSHARE_PP}/caveats_notofficial_trajectory.png
echo "${SLAB} Checking for ${CAVEAT}"
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${CAVEAT}"
else
  echo "${SLAB}   ERROR: no ${CAVEAT} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# Test for the existance/executability of required programs and files.
command -v "${ASH3DSCRIPTDIR}/gmt_test.sh"        > /dev/null 2>&1 ||  { echo >&2 "${SLAB} gmt_test.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/ReadNCheader.sh"    > /dev/null 2>&1 ||  { echo >&2 "${SLAB} ReadNCheader.sh not found. Exiting"; exit 1;}
command -v "${ASH3DBINDIR}/legend_placer_ac_traj" > /dev/null 2>&1 ||  { echo >&2 "${SLAB} legend_placer_ac_traj not found. Exiting"; exit 1;}
command -v date      > /dev/null 2>&1 ||  { echo >&2 "${SLAB} date not found. Exiting"; exit 1;}
command -v awk       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} awk not found. Exiting"; exit 1;}
command -v sed       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} sed not found. Exiting"; exit 1;}
command -v bc        > /dev/null 2>&1 ||  { echo >&2 "${SLAB} bc not found. Exiting"; exit 1;}
command -v ncdump    > /dev/null 2>&1 ||  { echo >&2 "${SLAB} ncdump not found. Exiting"; exit 1;}
command -v convert   > /dev/null 2>&1 ||  { echo >&2 "${SLAB} convert not found. Exiting"; exit 1;}
command -v identify  > /dev/null 2>&1 ||  { echo >&2 "${SLAB} identify not found. Exiting"; exit 1;}
command -v composite > /dev/null 2>&1 ||  { echo >&2 "${SLAB} composite not found. Exiting"; exit 1;}

# We need to know if we must prefix all gmt commands with 'gmt', as required by version 5/6
source ${ASH3DSCRIPTDIR}/gmt_test.sh

rc=0                                             # error message accumulator
CLEANFILES="T"
# Date of post-processing (may not be run date of simulation)
PPDATE=`date -u "+%D %T"`

# Link to shared post-processing files
ln -sf ${ASH3DSHARE_PP}/world_cities.txt .

# Now testing for files that are needed
ASH3D_NCFILE="${RUNHOME}/3d_tephra_fall.nc"
MRANGE="${RUNHOME}/map_range_traj.txt"
FTJ1="${RUNHOME}/ftraj1.dat"
FTJ2="${RUNHOME}/ftraj2.dat"
FTJ3="${RUNHOME}/ftraj3.dat"
FTJ4="${RUNHOME}/ftraj4.dat"
FTJ5="${RUNHOME}/ftraj5.dat"
FTJ6="${RUNHOME}/ftraj6.dat"
FTJ7="${RUNHOME}/ftraj7.dat"
echo "${SLAB} Checking for ${ASH3D_NCFILE}"
if [ -f "${ASH3D_NCFILE}" ]; then
  echo "${SLAB}   Found file required file: ${ASH3D_NCFILE}"
else
  echo "${SLAB}   ERROR: no ${ASH3D_NCFILE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
if [ -f "${MRANGE}" ]; then
  echo "${SLAB}   Found file required file: ${MRANGE}"
else
  echo "${SLAB}   ERROR: no ${MRANGE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
if [ -f "${FTJ1}" ]; then
  echo "${SLAB}   Found file required file: ${FTJ1}"
else
  echo "${SLAB}   ERROR: no ${FTJ1} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

#******************************************************************************
echo "${SLAB} Preparing to read from ${ASH3D_NCFILE} file"
echo "${SLAB} ******************************************************************************"
#GET VARIABLES FROM 3D_tephra-fall.nc
source ${ASH3DSCRIPTDIR}/ReadNCheader.sh ${ASH3D_NCFILE}
echo "${SLAB} Finished reading netcdf header."
echo "${SLAB} ******************************************************************************"

# If this is the first run, then 3d_tephpra_fall.nc is from the super-coarse runn
# The map will be better if we use the limits of the ftraj[1-7].dat files
if [ $PASSID -eq 0 ]; then
  # This is the initial run before the full Ash3d run
  # If we have map_range_traj.txt from the traj run, use that
  if [ -f "map_range_traj.txt" ]; then
    LLLON=`cat map_range_traj.txt | awk '{print $1}'`
    LLLAT=`cat map_range_traj.txt | awk '{print $3}'`
    URLON=`cat map_range_traj.txt | awk '{print $2}'`
    URLAT=`cat map_range_traj.txt | awk '{print $4}'`
  else
    echo "${SLAB} Cannot find file map_range_traj.txt.  Exiting script"
    exit $rc
  fi
  DLON=`echo "$URLON - $LLLON" | bc -l`
  DLAT=`echo "$URLAT - $LLLAT" | bc -l`
  echo "${SLAB} Found map_range. Lon: $LLLON $URLON $DLON"
  echo "${SLAB}                  Lat: $LLLAT $URLAT $DLAT"
  # Now we need to adjust the limits so that the map has the approximately correct aspect ratio
  dum=`echo "$DLAT * 2.0" | bc -l`
  test1=`echo "$DLON < $dum" | bc -l`
  echo "${SLAB} test1 = $test1"
  if [ $test1 -eq 1 ]; then
    echo "${SLAB} Resetting DLON"
    DLON=$dum
    URLON=`echo "$LLLON + $DLON" | bc -l`
  fi
fi

###############################################################################
##  Now make the maps
#get latitude & longitude range
lonmin=$LLLON
latmin=$LLLAT
lonmax=`echo "$LLLON + $DLON" | bc -l`
latmax=`echo "$LLLAT + $DLAT" | bc -l`
echo "${SLAB} lonmin="$lonmin ", lonmax="$lonmax ", latmin="$latmin ", latmax="$latmax
echo "$lonmin $lonmax $latmin $latmax $VCLON $VCLAT" > map_range.txt
echo "${SLAB} running legend_placer_ac_traj"
${ASH3DBINDIR}/legend_placer_ac_traj
# This should produce legend_positions_ac.txt; check for errors
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error running legend_placer_ac_traj; Exiting script"
  exit $rc
fi

captionx_UL=`cat legend_positions_ac.txt | grep "legend1x_UL" | awk '{print $2}'`
captiony_UL=`cat legend_positions_ac.txt | grep "legend1x_UL" | awk '{print $4}'`
legendx_UL=`cat legend_positions_ac.txt  | grep "legend2x_UL" | awk '{print $2}'`
legendy_UL=`cat legend_positions_ac.txt  | grep "legend2x_UL" | awk '{print $4}'`
LLLAT=`cat legend_positions_ac.txt       | grep "latmin="     | awk '{print $2}'`
URLAT=`cat legend_positions_ac.txt       | grep "latmin="     | awk '{print $4}'`
DLAT=`echo "$URLAT - $LLLAT" | bc -l`

t=0
gmt gmtset PROJ_ELLIPSOID Sphere

    #set mapping parameters
    DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer
    if [ $DLON_INT -le 2 ] ; then
        BASE="-Ba0.25/a0.25"           # label every 0.25 degrees lat/lon
        DETAIL="-Dh"                   # high resolution coastlines (-Dh=high)
        KMSCALE="30"
        MISCALE="20"
      elif [ $DLON_INT -le 5 ] ; then
        BASE="-Ba1/a1"                  # label every 1 degrees lat/lon
        DETAIL="-Dh"                    # high resolution coastlines (-Dh=high)
        KMSCALE="50"
        MISCALE="30"
      elif [ $DLON_INT -le 10 ] ; then
        BASE="-Ba2/a2"                  # label every 2 degrees lat/lon
        DETAIL="-Dh"                    # high resolution coastlines (-Dh=high)
        KMSCALE="100"
        MISCALE="50"
      elif [ $DLON_INT -le 20 ] ; then
        BASE="-Ba5/a5"                  # label every 5 degrees lat/lon
        DETAIL="-Dh"                    # high resolution coastlines (-Dh=high)
        KMSCALE="200"
        MISCALE="100"
      elif [ $DLON_INT -le 40 ] ; then
       BASE="-Ba10/a10"               # label every 10 degrees lat/lon
       DETAIL="-Dl"                   # low resolution coastlines (-Dl=low)
      elif [ $DLON_INT -le 100 ] ; then
        BASE="-Ba20/a20"               # label every 20 degrees lat/lon
        DETAIL="-Dl"                   # low resolution coastlines (-Dl=low)
        KMSCALE="400"
        MISCALE="200"
      else
        BASE="-Ba20/a20"               # label every 20 degrees lat/lon
        DETAIL="-Dl"                   # low resolution coastlines (-Dl=low)
        KMSCALE="400"
        MISCALE="200"
    fi
    #set mapping parameters
    if [ $DLON_INT -le 100 ] ; then
      AREA="-R$lonmin/$lonmax/$latmin/$latmax"
      PROJ="-JM${VCLON}/${VCLAT}/20"      # Mercator projection, with origin at lat & lon of volcano, 20 cm width
    else
      AREA="-R0/360/$latmin/$latmax"
      PROJ="-JQ0/0/20"      # Cylindrical Eq dist projection, with origin at lat & lon of volcano, 20 cm width
    fi
    COAST="-G220/220/220 -W"            # RGB values for land areas (220/220/220=light gray)
    BOUNDARIES="-Na"                    # -N=draw political boundaries, a=all national, Am. state & marine b.
  
#############################################################################
### Plot the base map
gmt pscoast $AREA $PROJ $BASE $DETAIL $COAST $BOUNDARIES -K  > temp.ps
# This is the Hysplit-like trajectory plot using the same basemap
# Trajectories currently (2017-04-11) are:
#  5000 ft (1.5240 km) Red       (255/0/0)
# 10000 ft (3.0480 km) Blue      (0/0/255)
# 15000 ft (4.5720 km) Green     (0/255/0)    NOTE: This is not plotted currently
# 20000 ft (6.0960 km) Cyan      (0/255/255)
# 30000 ft (9.1440 km) Magenta   (255/0/255)
# 40000 ft (12.192 km) Yellow    (255/255/0)
# 50000 ft (15.240 km) Blue-grey (51/153/204)
if [ -f "${FTJ1}" ]; then
  gmt psxy ${FTJ1}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/0    -V >> temp.ps
  awk '{print $1, $2, 1.0}' ${FTJ1} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/0    -O -K >> temp.ps
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ2}" ]; then
  gmt psxy ${FTJ2}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/0/255    -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ2} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/0/255    -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ3}" ]; then
  gmt psxy ${FTJ3}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/0    -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ3} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/0    -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ4}" ]; then
  gmt psxy ${FTJ4}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/255  -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ4} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/255  -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ5}" ]; then
  gmt psxy ${FTJ5}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/255  -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ5} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/255  -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ6}" ]; then
  gmt psxy ${FTJ6}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/255/0  -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ6} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/255/0  -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [ -f "${FTJ7}" ]; then
  gmt psxy ${FTJ7}   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}51/153/204 -V >> temp.ps
  rc=$((rc + $?))
  awk '{print $1, $2, 1.0}' ${FTJ7} | gmt psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G51/153/204 -O -K >> temp.ps
  rc=$((rc + $?))
else
  rc=$((rc + $?))
fi
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} ftraj[1-7].dat file is missing.  Exiting script"
  exit $rc
fi
echo "${SLAB} Finished plotting trajectory data"

#Add cities
echo "${SLAB} Finding cities in domain"
echo "${SLAB} ${ASH3DBINDIR}/citywriter ${LLLON} ${URLON} ${LLLAT} ${URLAT}"
${ASH3DBINDIR}/citywriter ${LLLON} ${URLON} ${LLLAT} ${URLAT}
if test -r cities.xy ; then
  gmt psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps
  rc=$((rc + $?))
  gmt pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
  rc=$((rc + $?))
  if [[ "$rc" -gt 0 ]] ; then
    echo "${SLAB} Error writing cities to map."
    exit $rc
  fi
  echo "${SLAB} Wrote cities to map"
else
  echo "${SLAB} No cities found in domain"
fi

# Write model info to figure
#  First write two caption blocks, printing them to temporary figures,
#  then merging the two figures to a banner figure
cat << EOF > caption_pgo1.txt
<b>Volcano:</b> $volc
<b>Run date:</b> $RUNDATE UTC
<b>Wind file:</b> $windfile
EOF
convert \
    -size 230x60 \
    -pointsize 8 \
    -font Courier-New \
    pango:@caption_pgo1.txt legend1.png
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error using convert with text legend 1."
  cat caption_pgo1.txt
  exit $rc
fi

cat << EOF > caption_pgo2.txt
<b>Eruption start:</b> ${year} ${month} ${day} ${hour}:${minute} UTC
<b>Plume height:</b> $EPlH km asl
<b>Duration:</b> $EDur hours
<b>Volume:</b> $EVol km<sup>3</sup> DRE (5% airborne)
EOF
convert \
    -size 230x60 \
    -pointsize 8 \
    -font Courier-New \
    pango:@caption_pgo2.txt legend2.png
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error using convert with text legend 2."
  cat caption_pgo2.txt
  exit $rc
fi
convert +append -background white legend1.png legend2.png ${LOGO} legend.png
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error using convert to build legend bar."
  exit $rc
fi

# Last gmt command is to plot the volcano and close out the ps file
echo $VCLON $VCLAT '1.0' | gmt psxy $AREA $PROJ -St0.1i -Gblack -Wthinnest -O >> temp.ps
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error writing volcano to map."
  exit $rc
fi

#  Convert to gif
if [ $GMTv -eq 5 ] ; then
  gmt psconvert temp.ps -A -Tg
  rc=$((rc + $?))
  convert -rotate 90 temp.png -resize 630x500 -alpha off temp.gif
  rc=$((rc + $?))
elif [ $GMTv -eq 6 ] ; then
  gmt psconvert temp.ps -A -Tg
  rc=$((rc + $?))
  convert temp.png -resize 630x500 -alpha off temp.gif
  rc=$((rc + $?))
fi
if [[ "$rc" -gt 0 ]] ; then
  echo "${SLAB} Error converting png to gif."
  exit $rc
fi

# Adding the ESP legend
#composite -geometry +30+25 legend.png temp.gif temp.gif
#  first insert a bit of white space above the legend
convert -append -background white -splice 0x10+0+0 legend.png legend.png
#  Now add this padded legend to the bottom of temp.gif
convert -gravity center -append -background white temp.gif legend.png temp.gif

width=`identify temp.gif | cut -f3 -d' ' | cut -f1 -d'x'`
height=`identify temp.gif | cut -f3 -d' ' | cut -f2 -d'x'`
vidx_UL=$(($width*73/100))
vidy_UL=$(($height*82/100))

# Add disclaimer banner
convert -append -background white temp.gif ${CAVEAT} temp.gif
# Add data legend
composite -geometry +${legendx_UL}+${legendy_UL} ${LEGEND} temp.gif temp.gif

# Finally, move temporary map file to final name
mv temp.gif trajectory_${PASSID}.gif

# Clean up temporary files
if [ "$CLEANFILES" == "T" ]; then
   rm -f gmt.conf gmt.history
   rm -f world_cities.txt cities.xy
   rm -f temp.ps temp.png
   rm -f caption_pgo*.txt legend*png
   rm -f map_range.txt
   rm -f legend_positions_ac.txt
fi

echo "${SLAB} Eruption start time: "$year $month $day $hour
echo "${SLAB} plume height (km) ="$EPlH
echo "${SLAB} eruption duration (hrs) ="$EDur
#echo "${SLAB} erupted volume (km3 DRE) ="$EVol
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "${SLAB} finished GFSVolc_to_gif_ac_traj.sh"
echo `date`
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "${SLAB} exiting GFSVolc_to_gif_ac_traj.sh with status $rc"
exit $rc

