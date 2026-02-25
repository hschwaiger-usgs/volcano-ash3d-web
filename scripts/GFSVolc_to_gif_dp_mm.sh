#!/bin/bash
#
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
# This script is called from runAsh3d.sh and runAsh3d_dp.sh and plots the final deposit
# thickness in mm.
# Run information is extracted from 3d_tephra_fall.nc
#
#      Usage: GFSVolc_to_gif_dp_mm.sh [RunDir]
#       e.g. /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_dp_mm.sh          \
#               /var/www/html/ash3d-api/htdocs/ash3druns/ash3d_run_334738/
#
# Files needed:
#   world_cities.txt      : shared post-processing file
#   3d_tephra_fall.nc     : output from an Ash3d run
#   USGSvid.png           : institutional logo needed for final map
#   caveats_notofficial.png : disclaimer banner added to figure
# Programs needed:
#   gmt_test.sh           : script that identifies gmt version and sets variables
#   ReadNCheader.sh       : script that reads NetCDF header
#   legend_placer_dp      : 
#   date,awk,sed,bc,head  : unix tools
#   gmt                   : Generic Mapping Tools
#   convert               : ImageMagick package
#   identify              : ImageMagick package
#   composite             : ImageMagick package
#   Ash3d_PostProc        : used for generating shapefiles
#
SLAB="[GFSVolc_to_gif_dp_mm.sh]: "            # Script label prepended on all echo to stdout
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
#  [rundirectory]
echo "${SLAB} ------------------------------------------------------------"
echo "${SLAB} Running GFSVolc_to_gif_dp_mm.sh:"
if [ "$#" -eq 1 ]; then
   echo "Command line argument detected: setting run directory"
   RUNHOME=$1
 else
  echo "${SLAB} No command line argument detected, using pwd"
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
  echo "${SLAB}   Found required file: ${WORLDCITIES}"
else
  echo "${SLAB}   ERROR: no ${WORLDCITIES} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
LOGO=${ASH3DSHARE_PP}/USGSvid.png
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${LOGO}"
else
  echo "${SLAB}   ERROR: no ${LOGO} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
LEGEND=${ASH3DSHARE_PP}/legend_dep.png
echo "${SLAB} Checking for ${LEGEND}"
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${LEGEND}"
else
  echo "${SLAB}   ERROR: no ${LEGEND} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi
CAVEAT=${ASH3DSHARE_PP}/caveats_notofficial.png
echo "${SLAB} Checking for ${CAVEAT}"
if [ -f "${LOGO}" ]; then
  echo "${SLAB}   Found file required file: ${CAVEAT}"
else
  echo "${SLAB}   ERROR: no ${CAVEAT} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# Test for the existance/executability of required programs and files.
command -v "${ASH3DSCRIPTDIR}/gmt_test.sh"     > /dev/null 2>&1 ||  { echo >&2 "${SLAB} gmt_test.sh not found. Exiting"; exit 1;}
command -v "${ASH3DSCRIPTDIR}/ReadNCheader.sh" > /dev/null 2>&1 ||  { echo >&2 "${SLAB} ReadNCheader.sh not found. Exiting"; exit 1;}
command -v "${ASH3DBINDIR}/legend_placer_dp"   > /dev/null 2>&1 ||  { echo >&2 "${SLAB} legend_placer_dp not found. Exiting"; exit 1;}
command -v "${ASH3DBINDIR}/Ash3d_PostProc"     > /dev/null 2>&1 ||  { echo >&2 "${SLAB} Ash3d_PostProc not found. Exiting"; exit 1;}
command -v date      > /dev/null 2>&1 ||  { echo >&2 "${SLAB} date not found. Exiting"; exit 1;}
command -v awk       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} awk not found. Exiting"; exit 1;}
command -v sed       > /dev/null 2>&1 ||  { echo >&2 "${SLAB} sed not found. Exiting"; exit 1;}
command -v bc        > /dev/null 2>&1 ||  { echo >&2 "${SLAB} bc not found. Exiting"; exit 1;}
command -v head      > /dev/null 2>&1 ||  { echo >&2 "${SLAB} head not found. Exiting"; exit 1;}
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
if [ -f "$ASH3D_NCFILE" ]; then
  echo "${SLAB} Found file $ASH3D_NCFILE"
else
  echo "${SLAB} ERROR: no ${ASH3D_NCFILE} file. Exiting"
  rc=$((rc + $?))
  exit $rc
fi

# variable netcdfnames
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
varID=6
var=${var_n[varID]}
echo "${SLAB}  "
echo "${SLAB}                 Generating images for *** $var ***"
echo "${SLAB}  "

#******************************************************************************
if [ "$CLEANFILES" == "T" ]; then
  echo "${SLAB} Removing old files"
  rm -f *.xyz *.grd contour_range.txt map_range.txt
fi

#******************************************************************************
echo "${SLAB} Preparing to read from ${ASH3D_NCFILE} file"
echo "${SLAB} ******************************************************************************"
#GET VARIABLES FROM 3D_tephra-fall.nc
source ${ASH3DSCRIPTDIR}/ReadNCheader.sh ${ASH3D_NCFILE}
echo "${SLAB} Finished reading netcdf header."
echo "${SLAB} ******************************************************************************"

#******************************************************************************
#EXTRACT INFORMATION ABOUT THE REQUESTED VARIABLE
echo "${SLAB} Extracting ${var} information from ${ASH3D_NCFILE} for each time step."
t=$((tmax-1))
# We need to convert the NaN's to zero to get the lowest contour
gmt grdconvert "$ASH3D_NCFILE?area" zero.grd
gmt grdmath 0.0 zero.grd MUL = zero.grd
gmt grdconvert "$ASH3D_NCFILE?$var[$t]" var_out_final.grd
gmt grdmath var_out_final.grd zero.grd AND = var_out_final.grd
#   depotime;       ash_arrival_time

###############################################################################
echo "${SLAB} Finished generating all the grd files"

###############################################################################
##  Now make the maps
#get latitude & longitude range
lonmin=$LLLON
latmin=$LLLAT
lonmax=`echo "$LLLON + $DLON" | bc -l`
latmax=`echo "$LLLAT + $DLAT" | bc -l`
echo "${SLAB}  lonmin="$lonmin ", lonmax="$lonmax ", latmin="$latmin ", latmax="$latmax
echo "$lonmin $lonmax $latmin $latmax $VCLON $VCLAT" > map_range.txt

echo "${SLAB} Preparing to make the GMT maps for deposit."
#if [ $1 -eq 0 ] || [ $1 -eq 5 ] || [ $1 -eq 6 ] ; then
  #  This is a special loop to general contours for depothick
  #create .lev files of contour values
  # NWS values
  #echo "0.1    255   0   0" > dp_0.1.lev    #deposit (0.1 mm)
  #echo "0.8      0   0 255" > dp_0.8.lev    #deposit (0.8 mm)
  #echo "6.0      0 183 255" >   dp_6.lev    #deposit (6 mm)
  #echo "25.0   255   0 255" >  dp_25.lev    #deposit (2.5cm)
  #echo "100.     0  51  51" > dp_100.lev    #deposit (10cm)

  ## Metric
  #echo "0.01    214 222 105" > dpm_0.01.lev   #deposit (0.01 mm)
  #echo "0.03    249 167 113" > dpm_0.03.lev   #deposit (0.03 mm)
  #echo "0.1    128   0 128"  > dpm_0.1.lev    #deposit (0.1 mm)
  #echo "0.3      0   0 255"  > dpm_0.3.lev    #deposit (0.3 mm)
  #echo "1.0      0 128 255"  >   dpm_1.lev    #deposit (1 mm)
  #echo "3.0      0 255 128"  >   dpm_3.lev    #deposit (3 mm)
  #echo "10.0   195 195   0"  >  dpm_10.lev    #deposit (1 cm)
  #echo "30.0   255 128   0"  >  dpm_30.lev    #deposit (3 cm)
  #echo "100.0  255   0   0"  > dpm_100.lev    #deposit (10cm)
  #echo "300.0  128   0   0"  > dpm_300.lev    #deposit (30cm)

  # NWS values
  echo "0.1    C" > dp_0.1.lev    #deposit (0.1 mm)
  echo "0.8    C" > dp_0.8.lev    #deposit (0.8 mm)
  echo "6.0    C" >   dp_6.lev    #deposit (6 mm)
  echo "25.0   C" >  dp_25.lev    #deposit (2.5cm)
  echo "100.   C" > dp_100.lev    #deposit (10cm)

  # Metric
  echo "0.01   C" > dpm_0.01.lev   #deposit (0.01 mm)
  echo "0.03   C" > dpm_0.03.lev   #deposit (0.03 mm)
  echo "0.1    C"  > dpm_0.1.lev   #deposit (0.1 mm)
  echo "0.3    C"  > dpm_0.3.lev   #deposit (0.3 mm)
  echo "1.0    C"  >   dpm_1.lev   #deposit (1 mm)
  echo "3.0    C"  >   dpm_3.lev   #deposit (3 mm)
  echo "10.0   C"  >  dpm_10.lev   #deposit (1 cm)
  echo "30.0   C"  >  dpm_30.lev   #deposit (3 cm)
  echo "100.0  C"  > dpm_100.lev   #deposit (10cm)
  echo "300.0  C"  > dpm_300.lev   #deposit (30cm)
#fi

######################
# Get the number of time steps we need
#     depotime;           Fin.Dep (in);       Fin.Dep (mm)        ash_arrival_time
#if [ $varID -eq 4 ] || [ $varID -eq 5 ] || [ $varID -eq 6 ] || [ $varID -eq 7 ] ; then
#    #  For final times or non-time-series, set time to the last value
    tstart=$(( $tmax-1 ))
    echo "${SLAB} We are working on a final/static variable so set tstart = $tstart"
#  else
#    # For normal time-series variables, start at the beginning
#    tstart=0
#    #tstart=$(( $tmax-1 ))
#    echo "We are working on a transient variable so set tstart = $tstart"
#fi

echo "${SLAB} Preparing to make the GMT maps."
#  Time loop would go here
echo "${SLAB} ${volc} : Creating map for time = final"
echo "${SLAB} Starting base map for final/non-time-series plot"

  # Set up some default values
  # Projected wind data assumes sphere with radius 6371.229 km
  # GMT's sperical ellipsoid assume a radius of    6371.008771 km
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
    KMSCALE="400"
    MISCALE="200"
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

  RIVERS="-I1/1p,blue -I2/0.25p,blue" # Perm. large rivers used 1p blue line, other large rivers 0.25p blue line

  mapscale1_x=`echo "$lonmin + 0.6 * $DLON"                     | bc -l`  # x location of km scale bar
  mapscale1_y=`echo "$latmin + 0.07 * ($latmax - $latmin)"      | bc -l`  # y location of km scale bar
  km_symbol=`echo "$mapscale1_y + 0.05 * ($latmax - $latmin)"   | bc -l`  # location of km symbol
  mapscale2_x=`echo "$lonmin + 0.6 * $DLON"                     | bc -l`  # x location of km scale bar
  mapscale2_y=`echo "$latmin + 0.15 * ($latmax - $latmin)"      | bc -l`  # y location of km scale bar
  mile_symbol=`echo "$mapscale2_y + 0.05 * ($latmax - $latmin)" | bc -l`  # location of km symbol
  SCALE1="-L${mapscale1_x}/${mapscale1_y}/${km_symbol}/${KMSCALE}"        # specs for drawing km scale bar
  SCALE2="-L${mapscale2_x}/${mapscale2_y}/${mile_symbol}/${MISCALE}M+"    # specs for drawing mile scale bar

#############################################################################
### Plot the base map
# Note: If you get errors with pscoast not finding the gshhg files, you can find where gmt is looking for the
#       files by running the above pscoast command with -Vd.  Then you can link the gshhg files to the correct
#       location.  e.g.
#         mkdir /usr/share/gmt/coast
#         ln -s /usr/share/gshhg-gmt-nc4/*nc /usr/share/gmt/coast/
gmt pscoast $AREA $PROJ $BASE $DETAIL $COAST $BOUNDARIES $RIVERS -K > temp.ps #Plot base map

##################
# Plot variable
dep_grd=var_out_final.grd
# GMT v5/6 writes contour files as a separate step from drawing and writes all segments to one file
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.01.lev -A- -W3,214/222/105 -Dcontourfile_0.01_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.03.lev -A- -W3,249/167/113 -Dcontourfile_0.03_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.1.lev  -A- -W3,128/0/128   -Dcontourfile_0.1_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.3.lev  -A- -W3,0/0/255     -Dcontourfile_0.3_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_1.lev    -A- -W3,0/128/255   -Dcontourfile_1_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_3.lev    -A- -W3,0/255/128   -Dcontourfile_3_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_10.lev   -A- -W3,195/195/0   -Dcontourfile_10_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_30.lev   -A- -W3,255/128/0   -Dcontourfile_30_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_100.lev  -A- -W3,255/0/0     -Dcontourfile_100_0_i.xyz
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_300.lev  -A- -W3,128/0/0     -Dcontourfile_3000_0_i.xyz

# GMT v5 adds a header line to these files.  First double-check that the header is present, then remove it.
testchar=`head -1 contourfile_0.1_0_i.xyz | cut -c1`
if [ $testchar = '>' ] ; then
  tail -n +2 contourfile_0.01_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_0.01_0_i.xyz
  tail -n +2 contourfile_0.03_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_0.03_0_i.xyz
  tail -n +2 contourfile_0.1_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_0.1_0_i.xyz
  tail -n +2 contourfile_0.3_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_0.3_0_i.xyz
  tail -n +2 contourfile_1_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_1_0_i.xyz
  tail -n +2 contourfile_3_0_i.xyz  > temp.xyz
  mv temp.xyz contourfile_3_0_i.xyz
  tail -n +2 contourfile_10_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_10_0_i.xyz
  tail -n +2 contourfile_30_0_i.xyz  > temp.xyz
  mv temp.xyz contourfile_30_0_i.xyz
  tail -n +2 contourfile_100_0_i.xyz > temp.xyz
  mv temp.xyz contourfile_100_0_i.xyz
  tail -n +2 contourfile_3000_0_i.xyz  > temp.xyz
  mv temp.xyz contourfile_3000_0_i.xyz
fi

gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.01.lev -A- -W3,214/222/105   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.03.lev -A- -W3,249/167/113   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.1.lev  -A- -W3,128/0/128   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_0.3.lev  -A- -W3,0/0/255     -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_1.lev    -A- -W3,0/128/255   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_3.lev    -A- -W3,0/255/128   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_10.lev   -A- -W3,195/195/0   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_30.lev   -A- -W3,255/128/0   -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_100.lev  -A- -W3,255/0/0     -O -K >> temp.ps
gmt grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdpm_300.lev  -A- -W3,128/0/0     -O -K >> temp.ps

  # Figure out if we are processing an ash cloud variable or a deposit variable for legend
  # coordinates
  echo "${SLAB} running legend_placer_dp_mm"
  # legend_placer_ac requires map_range.txt
  ${ASH3DBINDIR}/legend_placer_dp_mm
  # Wrote out legend_positions_dp_mm.txt
  captionx_UL=`cat legend_positions_dp_mm.txt | grep "legend1x_UL" | cut -c13-20`
  captiony_UL=`cat legend_positions_dp_mm.txt | grep "legend1x_UL" | cut -c36-42`
  # snip out the integer pixel offset as text, converting to a number
  legendx_UL=$((`cat legend_positions_dp_mm.txt  | grep "legend2x_UL" | cut -c13-15`))
  legendy_UL=$((`cat legend_positions_dp_mm.txt  | grep "legend2x_UL" | cut -c31-33`))
  echo "${SLAB} writing caption.txt"

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

convert +append -background white legend1.png legend2.png ${LOGO} legend.png

echo "${SLAB} adding cities"
${ASH3DBINDIR}/citywriter ${lonmin} ${lonmax} ${latmin} ${latmax}
if test -r cities.xy ; then
  echo "${SLAB} Adding cities to map"
    # Add a condition to plot roads if you'd like
    #tstvolc=`ncdump -h ${ASH3D_NCFILE} | grep b1l1 | cut -d\" -f2 | cut -c1-7`
    #if [ "${tstvolc}" = "Kilauea" ] ; then
    #  gmt psxy $AREA $PROJ -m ${ASH3DSHARE_PP}/roadtrl020.gmt -W0.25p,red -O -K >> temp.ps
    #fi
    gmt psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps  
    gmt pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
fi

gmt psbasemap $AREA $PROJ $SCALE1 -O -K >> temp.ps                      #add km scale bar in overlay
gmt psbasemap $AREA $PROJ $SCALE2 -O -K >> temp.ps                      #add mile scale bar in overlay

  # Last gmt command is to plot the volcano and close out the ps file
  echo $VCLON $VCLAT '1.0' | gmt psxy $AREA $PROJ -St0.1i -Gblack -Wthinnest -O >> temp.ps

  # Convert to gif
  if [ $GMTv -eq 5 ] ; then
    gmt psconvert temp.ps -A -Tg
    convert -rotate 90 temp.png -resize 630x500 -alpha off temp.gif
  else
    gmt psconvert temp.ps -A -Tg
    convert temp.png -resize 630x500 -alpha off temp.gif
  fi

  # Adding the ESP legend
  #  first insert a bit of white space above the legend
  convert -append -background white -splice 0x10+0+0 legend.png legend.png
  #  Now add this padded legend to the bottom of temp.gif
  convert -gravity center -append -background white temp.gif legend.png temp.gif

# Add data legend
width=`identify temp.gif | cut -f3 -d' ' | cut -f1 -d'x'`
height=`identify temp.gif | cut -f3 -d' ' | cut -f2 -d'x'`
vidx_UL=$(($width*72/100))
vidy_UL=$(($height*85/100))
convert temp.gif deposit_thickness_mm.gif
convert -append -background white deposit_thickness_mm.gif ${CAVEAT} deposit_thickness_mm.gif
composite -geometry +${legendx_UL}+${legendy_UL} ${LEGEND} \
          deposit_thickness_mm.gif  deposit_thickness_mm.gif
#  End of time loop would go here

# Finalizing output (animations, shape files, etc.)
#Make shapefile
echo "Generating shapefile with Ash3d_PostProc 3d_tephra_fall.nc 5 5"
# This first line uses the default contour levels for deposit
${ASH3DBINDIR}/Ash3d_PostProc 3d_tephra_fall.nc 5 5
# This post-processing tool generates deposit_thickness_mm.txt from the NetCDF file, then
# uses gnuplot to contour the data, writing out depothik.zip as well as temporary files: tmp.png
# Rename shapefile and remove temporary files
mv depothik.zip dp_mm_shp.zip
# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
  echo "End of GFSVolc_to_gif_dp.sh: removing files."
  rm -f *.grd *.lev
  rm -f current_time.txt
  rm -f caption*.txt cities.xy map_range.txt legend_positions*txt
  rm -f legend*png
  rm -f temp.*
  rm -f gmt.conf gmt.history
  rm -f world_cities.txt
  rm -f VAAC_*.xy
  rm -f contourfile*xyz
  rm -f tmp.png
  rm -f deposit_thickness*.txt
fi

echo "${SLAB} Eruption start time: "$year $month $day $hour
echo "${SLAB} plume height (km) ="$EPlH
echo "${SLAB} eruption duration (hrs) ="$EDur
echo "${SLAB} erupted volume (km3 DRE) ="$EVol
echo "${SLAB}  "
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "${SLAB} finished GFSVolc_to_gif_dp_mm.sh $var"
echo `date`
echo "${SLAB} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "${SLAB} exiting GFSVolc_to_gif_dp_mm.sh with status $rc"
exit $rc

