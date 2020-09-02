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
#  first/second pass , rundirectory
echo "------------------------------------------------------------"
echo "running GFSVolc_to_gif_ac_traj.sh with parameter:"
echo "  $1"
if [ $1 -eq 0 ]; then
  echo " 0 = first pass"
fi
if [ $1 -eq 1 ]; then
  echo " 1 = second pass"
fi
if [ "$#" -eq 2 ]; then
  echo "Second command line argument detected: setting run directory"
  RUNHOME=$2
 else
  echo "No second command line argument detected, using cwd"
  RUNHOME=`pwd`
fi
cd ${RUNHOME}
echo `date`
echo "------------------------------------------------------------"
rc=0                                             # error message accumulator
CLEANFILES="T"

# We need to know if we must prefix all gmt commands with 'gmt', as required by version 5
GMTv=5
type gmt >/dev/null 2>&1 || { echo >&2 "Command 'gmt' not found.  Assuming GMTv4."; GMTv=4;}
GMTpre=("-" "-" "-" "-" " "   "gmt ")
GMTelp=("-" "-" "-" "-" "ELLIPSOID" "PROJ_ELLIPSOID")
GMTnan=("-" "-" "-" "-" "-Ts" "-Q")
GMTrgr=("-" "-" "-" "-" "grdreformat" "grdconvert")
GMTpen=("-" "-" "-" "-" "/" ",")
echo "GMT version = ${GMTv}"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

if test -r world_cities.txt
  then
    echo "Found file world_cities.txt"
  else
    ln -s ${ASH3DSHARE_PP}/world_cities.txt .
fi

export PATH=/usr/local/bin:$PATH
infile=${RUNHOME}/"3d_tephra_fall.nc"

#******************************************************************************
#MAKE SURE 3D_tephra_fall.nc EXISTS
if test -r ${infile}
then
    echo "reading from ${infile} file"
  else
    echo "error: no ${infile} file. Exiting"
    rc=$((rc + $?))
    exit $rc
fi

#******************************************************************************
#GET VARIABLES FROM 3D_tephra-fall.nc
volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "ncdump command failed.  Exiting script"
    exit $rc
fi
date=`ncdump -h ${infile} | grep Date | cut -d\" -f2 | cut -c 1-10`

echo "Processing " $volc " on " $date

#time of eruption start
year=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c1-4`
month=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c5-6`
day=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c7-8`
hour=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c9-10`
minute=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c12-13`
hours_real=`echo "$hour + $minute / 60" | bc -l`


if [ $1 -eq 0 ]; then
  # This is the initial run before the full Ash3d run
  SUB=0
  LLLON=`cat map_range_traj.txt | awk '{print $1}'`
  LLLAT=`cat map_range_traj.txt | awk '{print $3}'`
  URLON=`cat map_range_traj.txt | awk '{print $2}'`
  URLAT=`cat map_range_traj.txt | awk '{print $4}'`
  DLON=`echo "$URLON-$LLLON" | bc -l`
  DLAT=`echo "$URLAT-$LLLAT" | bc -l`
  # Now we need to adjust the limits so that the map has the approximately correct aspect ratio
  dum=`echo "$DLAT * 2.0" | bc -l`
  test1=`echo "$DLON < $dum" | bc -l`
  echo "test1 = $test1"
  #if (( $DLON < $dum )); then
  if [ $test1 -eq 1 ]; then
    echo "Resetting DLON"
    DLON=$dum
    URLON=`echo "$LLLON+$DLON" | bc -l`
  fi
else
  # This is a follow-up run after the full Ash3d run has completed.
  # This run will have the same basemap as the other Ash3d graphics
  SUB=1
  LLLON=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $1}'`
  LLLAT=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $2}'`
  DLON=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $1}'`
  DLAT=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $2}'`
  URLON=`echo "$LLLON+$DLON" | bc -l`
  URLAT=`echo "$LLLAT+$DLAT" | bc -l`
fi

echo "LLLON=$LLLON, LLLAT=$LLLAT, DLON=$DLON, DLAT=$DLAT"
echo "URLON=$URLON, URLAT=$URLAT"
VCLON=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $1}'`
#the cut command doesn't recognize consecutive spaces as a single delimiter,
#therefore I have to use awk to get the latitude from the second field in b1l5
VCLAT=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $2}'`

echo "map_range.txt = $LLLON $URLON $LLLAT $URLAT $VCLON $VCLAT"
echo "$LLLON $URLON $LLLAT $URLAT $VCLON $VCLAT" > map_range.txt
echo "running legend_placer_ac_traj"
${ASH3DBINDIR}/legend_placer_ac_traj
captionx_UL=`cat legend_positions_ac.txt | grep "legend1x_UL" | awk '{print $2}'`
captiony_UL=`cat legend_positions_ac.txt | grep "legend1x_UL" | awk '{print $4}'`
legendx_UL=`cat legend_positions_ac.txt  | grep "legend2x_UL" | awk '{print $2}'`
legendy_UL=`cat legend_positions_ac.txt  | grep "legend2x_UL" | awk '{print $4}'`
LLLAT=`cat legend_positions_ac.txt       | grep "latmin="     | awk '{print $2}'`
URLAT=`cat legend_positions_ac.txt       | grep "latmin="     | awk '{print $4}'`
DLAT=`echo "$URLAT - $LLLAT" | bc -l`
echo "captionx_UL=$captionx_UL, captiony_UL=$captiony_UL"
echo "legendx_UL=$legendx_UL, 'legendy_UL=$legendy_UL"
echo "LLLAT=$LLLAT, URLAT=$URLAT, DLAT=$DLAT"

EDur=`ncdump -v er_duration ${infile} | grep er_duration | grep "=" | \
	grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EPlH=`ncdump -v er_plumeheight ${infile} | grep er_plumeheight | grep "=" | \
	grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
#EVol3=`ncdump -v er_volume ${infile} | grep er_volume | grep "=" | \
#	grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
#EVol2=`${ASH3DBINDIR}/convert_to_decimal $EVol3`   #if it's in scientific notation, convert to real
#EVol=`echo "($EVol2 * 20)" |bc -l`

#If volume equals minimum threshold volume, add annotation
#EVol_int=`echo "$EVol * 10000" | bc -l | sed 's/\.[0-9]*//'`   #convert EVol to an integer
#echo "$EVol3 $EVol2 $EVol $EVol_int"
#if [ $EVol_int -eq 1 ] ; then
#    EVol="0.0001"
#    Threshval="(min. threshold)"
#  else
#    Threshval=""
#fi

windtime=`ncdump -h ${infile} | grep NWPStartTime | cut -c20-39`
iwindformat=`ncdump -h ${infile} |grep b3l1 | cut -c16-20`
if [ ${iwindformat} -eq 25 ]; then
     windfile="NCEP reanalysis 2.5 degree"
  else
     windfile="GFS forecast 0.5 degree for $windtime"
fi
echo "time_interval=${time_interval}"

###############################################################################
##  Now make the maps

t=0
${GMTpre[GMTv]} gmtset ${GMTelp[GMTv]} Sphere

AREA="-R$LLLON/$URLON/$LLLAT/$URLAT"
#AREA="-Rac_tot_out_t${time}.grd"
DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer
if [ $DLON_INT -le 5 ]
then
   BASE="-Ba1/a1"                  # label every 5 degress lat/lon
   DETAIL="-Dh"                        # high resolution coastlines (-Dc=crude)
 elif [ $DLON_INT -le 10 ] ; then
   BASE="-Ba2/a2"                  # label every 5 degress lat/lon
   DETAIL="-Dh"                        # high resolution coastlines (-Dc=crude)
 elif [ $DLON_INT -le 20 ] ; then
   BASE="-Ba5/a5"                  # label every 5 degress lat/lon
   DETAIL="-Dh"                        # high resolution coastlines (-Dc=crude)
 else
   BASE="-Ba10/a10"                    #label every 10 degrees lat/lon
   DETAIL="-Dl"                        # low resolution coastlines (-Dc=crude)
fi
PROJ="-JM${VCLON}/${VCLAT}/20"
COAST="-G220/220/220 -W"            # RGB values for land areas (220/220/220=light gray)
BOUNDARIES="-Na"                    # -N=draw political boundaries, a=all national, Am. state & marine b.
  
#############################################################################
### Plot the base map
${GMTpre[GMTv]} pscoast $AREA $PROJ $BASE $DETAIL $COAST $BOUNDARIES -K  > temp.ps
# This is the Hysplit-like trajectory plot using the same basemap
# Trajectories currently (2017-04-11) are:
#  5000 ft (1.5240 km) Red       (255/0/0)
# 10000 ft (3.0480 km) Blue      (0/0/255)
# 15000 ft (4.5720 km) Green     (0/255/0)    NOTE: This is not plotted currently
# 20000 ft (6.0960 km) Cyan      (0/255/255)
# 30000 ft (9.1440 km) Magenta   (255/0/255)
# 40000 ft (12.192 km) Yellow    (255/255/0)
# 50000 ft (15.240 km) Blue-grey (51/153/204)
${GMTpre[GMTv]} psxy ftraj1.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/0    -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj2.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/0/255    -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj3.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/0    -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj4.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/255  -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj5.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/255  -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj6.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/255/0  -V >> temp.ps
${GMTpre[GMTv]} psxy ftraj7.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}51/153/204 -V >> temp.ps

awk '{print $1, $2, 1.0}' ftraj1.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/0    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj2.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/0/255    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj3.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/0    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj4.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/255  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj5.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/255  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj6.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/255/0  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ftraj7.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G51/153/204 -O -K >> temp.ps
echo "Finished plotting trajectory data"

#Add cities
${ASH3DBINDIR}/citywriter ${LLLON} ${URLON} ${LLLAT} ${URLAT}
if test -r cities.xy ; then
    ${GMTpre[GMTv]} psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps
    ${GMTpre[GMTv]} pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
    echo "Wrote cities to map"
  else
    echo "No cities found in domain"
fi

   #Write caveats to figure
caption_width=`echo "0.25 * $DLON" | bc -l`
cat << EOF > caption.txt
> $captionx_UL $captiony_UL 12 0 0 TL 14p 3.0i l
   @%1% USGS trajectory Forecast @%0%

   @%1%Volcano: @%0%$volc

   @%1%Trajectory start: @%0%${year} ${month} ${day} ${hour}:${minute} UTC

   @%1%Duration: @%0%24\n hours

   @%1%Wind file: @%0%$windfile
EOF

if [ $GMTv -eq 4 ] ; then
    ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -m -Wwhite,o -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
  else
    ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -M -Gwhite -Wblack,. -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
fi

#  Convert to gif
if [ $GMTv -eq 4 ] ; then
    ps2epsi temp.ps
    epstopdf temp.epsi
    convert -rotate 90 temp.pdf -alpha off temp.gif
  else
    ${GMTpre[GMTv]} psconvert temp.ps -A -Tg
    convert -rotate 90 temp.png -resize 630x500 -alpha off temp.gif
fi

width=`identify temp.gif | cut -f3 -d' ' | cut -f1 -d'x'`
height=`identify temp.gif | cut -f3 -d' ' | cut -f2 -d'x'`
vidx_UL=$(($width*73/100))
vidy_UL=$(($height*82/100))

if test -r official.txt; then
   convert -append -background white temp.gif ${ASH3DSHARE_PP}/caveats_official.png \
                                                               temp.gif
  else
   convert -append -background white temp.gif \
              ${ASH3DSHARE_PP}/caveats_notofficial_trajectory.png temp.gif
fi
composite -geometry +${vidx_UL}+${vidy_UL} ${ASH3DSHARE_PP}/USGSvid.png \
      temp.gif  temp.gif
composite -geometry +${legendx_UL}+${legendy_UL} ${ASH3DSHARE_PP}/legend_hysplit.png \
      temp.gif  temp.gif

mv temp.gif trajectory_${SUB}.gif

# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
    rm map_range.txt legend_positions_ac.txt
    rm temp.*
fi

echo "Eruption start time: "$year $month $day $hour
echo "plume height (km) ="$EPlH
echo "eruption duration (hrs) ="$EDur
#echo "erupted volume (km3 DRE) ="$EVol
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GFSVolc_to_gif_ac_traj.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting GFSVolc_to_gif_ac_traj.sh with status $rc"
exit $rc

