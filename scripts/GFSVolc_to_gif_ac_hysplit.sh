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

echo "------------------------------------------------------------"
echo "running GFSVolc_to_gif_ac_hysplit.sh"
if [ -z "$1" ]; then
  echo "Command line argument detected: setting run directory"
  RUNHOME=$1
 else
  RUNHOME=`pwd`
fi
cd ${RUNHOME}
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"

# We need to know if we must prefix all gmt commands with 'gmt', as required by version 5
GMTv=5
type gmt >/dev/null 2>&1 || { echo >&2 "Command 'gmt' not found.  Assuming GMTv4."; GMTv=4;}
GMTpre=("-" "-" "-" "-" " "   "gmt ")
GMTelp=("-" "-" "-" "-" "ELLIPSOID" "PROJ_ELLIPSOID")
GMTnan=("-" "-" "-" "-" "-Ts" "-Q")
GMTrgr=("-" "-" "-" "-" "grdreformat" "grdconvert")
GMTpen=("-" "-" "-" "-" "/" ",")
echo "GMT version = ${GMTv}: prefix = ${GMTpre[GMTv]}"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"
WINDROOT="/data/WindFiles"
HYSPLITDATAHOME="${WINDROOT}/Hysplit_traj"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"
if test -r world_cities.txt ; then
    echo "Found file world_cities.txt"
  else
    ln -s ${ASH3DSHARE_PP}/world_cities.txt .
fi

export PATH=/usr/local/bin:$PATH
infile=${RUNHOME}/"3d_tephra_fall.nc"

# Defnie Hysplit list
# This must be consistant with what is in get_Hysplit.sh
nvolcs=34
volcname[1]="Akutan"
volcname[2]="Aniakchak"
volcname[3]="Atka"
volcname[4]="Augustine"
volcname[5]="Bogoslof"
volcname[6]="Churchill"
volcname[7]="Cleveland"
volcname[8]="Dutton"
volcname[9]="Gareloi"
volcname[10]="Great_Sitkin"
volcname[11]="Griggs"
volcname[12]="Hayes"
volcname[13]="Iliamna"
volcname[14]="Kaguyak"
volcname[15]="Kanaga"
volcname[16]="Kasatochi"
volcname[17]="Katmai"
volcname[18]="Mageik"
volcname[19]="Makushin"
volcname[20]="Martin"
volcname[21]="Novarupta"
volcname[22]="Okmok"
volcname[23]="Pavlof"
volcname[24]="Pavlof_Sister"
volcname[25]="Redoubt"
volcname[26]="Seguam"
volcname[27]="Semisopochnoi"
volcname[28]="Shishaldin"
volcname[29]="Spurr"
volcname[30]="Trident"
volcname[31]="Ugashik-Peulik"
volcname[32]="Veniaminof"
volcname[33]="Westdahl"
volcname[34]="Wrangell"

#******************************************************************************
#MAKE SURE 3D_tephra_fall.nc EXISTS
# Note: we need the ash3d stuff just to get a consistant basemap for the hysplit data
if test -r ${infile} ; then
    echo "reading from ${infile} file"
  else
    echo "error: no ${infile} file. Exiting"
    exit 1
fi

#******************************************************************************
#GET VARIABLES FROM 3D_tephra-fall.nc
volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
#volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d' ' -f1`
for (( iv=1;iv<35;iv++))
do
  echo "Looking for ${volc} in ${volcname[iv]}"
  if echo "${volc}" | grep ${volcname[iv]}; then
    echo "Found Ash3d run in Hysplit volcano list"
    ivolcHysplit=${iv}
  fi
done

rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
	echo "ncdump command failed.  Exiting script"
	exit 1
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

FC_Hysplit="00"
if (( $hour > 5 )); then
  FC_Hysplit="06"
fi
if (( $hour > 11 )); then
  FC_Hysplit="12"
fi
if (( $hour > 17 )); then
  FC_Hysplit="18"
fi

YY=`echo $year | cut -c3-4`
YYMMDDHH=${YY}${month}${day}${FC_Hysplit}

#YYMMDDHH="17041412"
HysplitDir="${HYSPLITDATAHOME}/volc${ivolcHysplit}/${YYMMDDHH}"
echo "Testing for existance of directory ${HysplitDir}"
if [ -d "${HysplitDir}" ]; then
  echo "Found directory with trajectory data"
  echo "  Trajectories will be taken from ${HYSPLITDATAHOME}/volc${ivolcHysplit}/${YYMMDDHH}"
else
  echo "No Hysplit data found for this volcano / time"
  exit
fi

#latitude & longitude of lower left corner of map
LLLON=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $1}'`
LLLAT=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $2}'`
DLON=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $1}'`
DLAT=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $2}'`
URLON=`echo "$LLLON+$DLON" | bc -l`
URLAT=`echo "$LLLAT+$DLAT" | bc -l`
echo "LLLON=$LLLON, LLLAT=$LLLAT, DLON=$DLON, DLAT=$DLAT"
echo "URLON=$URLON, URLAT=$URLAT"
VCLON=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $1}'`
#the cut command doesn't recognize consecutive spaces as a single delimiter,
#therefore I have to use awk to get the latitude from the second field in b1l5
VCLAT=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $2}'`

echo "$LLLON $URLON $LLLAT $URLAT $VCLON $VCLAT" > map_range.txt
echo "running legend_placer_ac"
${ASH3DBINDIR}/legend_placer_ac
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
EVol3=`ncdump -v er_volume ${infile} | grep er_volume | grep "=" | \
	grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EVol2=`${ASH3DBINDIR}/convert_to_decimal $EVol3`   #if it's in scientific notation, convert to real
EVol=`echo "($EVol2 * 20)" |bc -l`

#If volume equals minimum threshold volume, add annotation
EVol_int=`echo "$EVol * 10000" | bc -l | sed 's/\.[0-9]*//'`   #convert EVol to an integer
if [ $EVol_int -eq 1 ] ; then
    EVol="0.0001"
    Threshval="(min. threshold)"
  else
    Threshval=""
fi

windtime=`ncdump -h ${infile} | grep NWPStartTime | cut -c20-39`
#windfile="GFS forecast 0.5 degree for $windtime"
windfile="GFS forecast 0.5 degree"

###############################################################################
##  Now make the maps

t=0
${GMTpre[GMTv]} gmtset ${GMTelp[GMTv]} Sphere

AREA="-R$LLLON/$URLON/$LLLAT/$URLAT"
#AREA="-Rac_tot_out_t${time}.grd"
DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer
if [ $DLON_INT -le 5 ] ; then
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
# 15000 ft (4.5720 km) Green     (0/255/0)
# 20000 ft (6.0960 km) Cyan      (0/255/255)
# 30000 ft (9.1440 km) Magenta   (255/0/255)
# 40000 ft (12.192 km) Yellow    (255/255/0)
# 50000 ft (15.240 km) Blue-grey (51/153/204)
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj1.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/0    -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj2.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/0/255    -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj3.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/0    -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj4.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}0/255/255  -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj5.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/0/255  -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj6.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}255/255/0  -V >> temp.ps
${GMTpre[GMTv]} psxy ${HysplitDir}/ftraj7.dat   $AREA $PROJ -P -K -O -W4${GMTpen[GMTv]}51/153/204 -V >> temp.ps

awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj1.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/0    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj2.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/0/255    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj3.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/0    -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj4.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G0/255/255  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj5.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/0/255  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj6.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G255/255/0  -O -K >> temp.ps
awk '{print $1, $2, 1.0}' ${HysplitDir}/ftraj7.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ $BASE -Sc0.10i -W1${GMTpen[GMTv]}0/0/0 -G51/153/204 -O -K >> temp.ps
echo "Finished plotting trajectory data"

#Add cities
${ASH3DBINDIR}/citywriter ${LLLON} ${URLON} ${LLLAT} ${URLAT}
if test -r cities.xy ; then
    ${GMTpre[GMTv]} psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps
    ${GMTpre[GMTv]} pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
    echo "Wrote cities to map"
fi

   #Write caveats to figure
caption_width=`echo "0.25 * $DLON" | bc -l`
cat << EOF > caption.txt
> $captionx_UL $captiony_UL 12 0 0 TL 14p 3.0i l
   @%1% NOAA HYSPLIT MODEL @%0%

   @%1%Volcano: @%0%$volc

   @%1%Trajectory start: @%0%${year} ${month} ${day} ${FC_Hysplit} UTC

   @%1%Duration: @%0%6\n hours

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
   convert -append -background white temp.gif ${ASH3DSHARE_PP}/caveats.gif \
                                                               temp.gif
 else
   convert -append -background white temp.gif \
              ${ASH3DSHARE_PP}/caveats_notofficial_NOAA_hysplit.png temp.gif
fi
#composite -geometry +${vidx_UL}+${vidy_UL} ${ASH3DSHARE_PP}/USGSvid.gif \
#      temp.gif  temp.gif
composite -geometry +${legendx_UL}+${legendy_UL} ${ASH3DSHARE_PP}/legend_hysplit.gif \
      temp.gif  temp.gif

mv temp.gif Hysplit_trajectory.gif

# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
    rm map_range.txt legend_positions_ac.txt
    rm temp.*
fi

echo "Eruption start time: "$year $month $day $hour
echo "plume height (km) ="$EPlH
echo "eruption duration (hrs) ="$EDur
echo "erupted volume (km3 DRE) ="$EVol
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GFSVolc_to_gif_ac_hysplit.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting GFSVolc_to_gif_ac_hysplit.sh with status $rc"
exit $rc

