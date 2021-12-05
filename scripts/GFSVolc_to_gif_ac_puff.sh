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
echo "running GFSVolc_to_gif_ac_puff.sh"
if [ "$#" -eq 1 ]; then
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

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

export PATH=/usr/local/bin:$PATH
infile=${RUNHOME}/"3d_tephra_fall.nc"

#******************************************************************************
#MAKE SURE 3D_tephra_fall.nc EXISTS
if test -r ${infile} ; then
    echo "reading from ${infile} file"
  else
    echo "error: no ${infile} file. Exiting"
    exit 1
fi

#******************************************************************************
#GET VARIABLES FROM 3D_tephra-fall.nc
echo "------------------"
volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
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
gsbins=`ncdump -h $infile | grep "gs =" | cut -c6-8`      # # of grain-size bins
zbins=`ncdump -h $infile | grep "z =" | cut -c6-7`        # # of elevation levels
tmax=`ncdump -h $infile | grep "t = UNLIMITED" | cut -c22-23` # maximum time dimension
t0=`ncdump -v t ${infile} | grep \ t\ = | cut -f4 -d" " | cut -f1 -d","`
t1=`ncdump -v t ${infile} | grep \ t\ = | cut -f5 -d" " | cut -f1 -d","`
time_interval=`echo "($t1 - $t0)" |bc -l`
iwindformat=`ncdump -h ${infile} |grep b3l1 | cut -c16-20`
if [ ${iwindformat} -eq 25 ]; then
     windfile="NCEP reanalysis 2.5 degree"
  else
     windfile="GFS forecast 0.5 degree for $windtime"
fi
echo "time_interval=${time_interval}"

#******************************************************************************
#EXTRACT AIRBORNE ASH INFORMATION
#echo "extracting airborne ash information from ${infile}"
t=$((tmax-1))
#for t in `seq 0 $((tmax-1))`;
#do
#  time=`echo "${t0} + ${t} * ${time_interval}" | bc -l`
#  echo " ${volc} : Generating airborne ash grids for time = " ${time}
#  # Summing over vertical column (assuming one grainsize)
#  grdreformat "$infile?ashcon_max[$t]" ac_tot_out_t${time}.grd
#  grdreformat "$infile?cloud_height[$t]" ch_out_t${time}.grd
#done  # end of time loop

#See whether the first time has any ash that exceeds 0.2 mg/m3
#echo "doing grdmath to find max concentration for time ${t0}"
#grdmath ac_tot_out_t${t0}.grd UPPER = tmp.grd

###############################################################################
##  Now make the maps
if test 1 -eq 1 ; then
#echo "0.2 0 0 255"  > ac_0.2.lev     #concentration and RGB color of 0.2 mg/m3 air concentration
#echo "2.0 255 0 0" > ac_2.0.lev     #concentration and RGB color of 2.0 mg/m3 air concentration
CPT=Ash3d_cloud_height.cpt
CPTm=Ash3d_cloud_height_m.cpt
#CPTft=Ash3d_cloud_height_50kft.cpt
CPTft=/opt/USGS/Ash3d/share/post_proc/Ash3d_cloud_height_50kft.cpt

#t=$((tmax-1))
#for (( t=0;t<=tmax-1;t++))
#do
t=0
for ifile in `ls -1 *.cdf`
do
   echo "Processing $ifile"
   ncks -H -C -v lon -s "%f\t\n" ${ifile}  > lon.dat
   ncks -H -C -v lat -s "%f\t\n" ${ifile}  > lat.dat
   ncks -H -C -v hgt -s "%f\n"   ${ifile}  > hgt.dat
   paste lon.dat lat.dat hgt.dat > puff.dat

   time=`echo "${t0} + ${t} * ${time_interval}" | bc -l` 
   echo " ${volc} : Creating map for time = ${time}" 
   # Set up some default values
   # Projected wind data assumes sphere with radius 6371.229 km
   # GMT's sperical ellipsoid assume a radius of    6371.008771 km
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

   ##################
   # Plot puff particles for this time step
   awk '{print $1, $2, $3}' puff.dat | ${GMTpre[GMTv]} psxy $AREA $PROJ -Sc0.03i -C$CPTft -O -K >> temp.ps

   #Plot Volcano
   echo $VCLON $VCLAT '1.0' | ${GMTpre[GMTv]} psxy $AREA $PROJ -St0.1i -Gblack -Wthinnest -O -K >> temp.ps

   #Add cities
   ${ASH3DBINDIR}/citywriter ${LLLON} ${URLON} ${LLLAT} ${URLAT}
   if test -r cities.xy ; then
       ${GMTpre[GMTv]} psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps
       ${GMTpre[GMTv]} pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
   fi

   #psscale -D1.25i/0.5i/2i/0.15ih -C$CPTft -B25/:"ft": -O -K >> temp.ps
   #psscale -D1.25i/0.5i/2i/0.15ih -C$CPT -B10f5/:km: -O -K >> temp.ps
#   pstext -R0/3/0/5 -JX3i -O -K -m -N << EOF >> temp.ps
#> 0.25 1.25 14 0 4 TL 14p 3i j
#@%1%Puff Cloud Height
#EOF

   #calculate current time and location of label showing current time
   curtimex_UR=`echo "$LLLON + 0.98 * $DLON" | bc -l`
   curtimey_UR=`echo "$LLLAT + 0.97 * $DLAT" | bc -l`
   hours_now=`echo "$hours_real + $time" | bc -l`
   hours_since=`${USGSROOT}/bin/HoursSince1900 $year $month $day $hours_now`
   current_time=`${USGSROOT}/bin/yyyymmddhh_since_1900 $hours_since`
   cat << EOF > current_time.txt
   $curtimex_UR  $curtimey_UR  16  0  0  TR @%1%Model valid on: @%0%$current_time
EOF
   ${GMTpre[GMTv]} pstext current_time.txt $AREA $PROJ -O -Wwhite,o -N -K >> temp.ps

   #Write caveats to figure
   caption_width=`echo "0.25 * $DLON" | bc -l`
   #cat << EOF | pstext $AREA $PROJ -O -m -Wwhite -N >> temp.ps
   cat << EOF > caption.txt
> $captionx_UL $captiony_UL 12 0 0 TL 14p 3.0i l
   @%1%Volcano: @%0%$volc

   @%1%Eruption start: @%0%${year} ${month} ${day} ${hour}:${minute} UTC

   @%1%Plume height: @%0%$EPlH\n km asl

   @%1%Duration: @%0%$EDur\n hours

   @%1%Volume: @%0%$EVol km3 DRE (5% airborne) $Threshval

   @%1%Wind file: @%0%$windfile
EOF

   if [ $GMTv -eq 4 ] ; then
       ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -m -Wwhite,o -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
   else
       ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -M -Gwhite -Wblack,. -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
   fi

   #  Convert to gif
   if [ $GMTv -eq 4 ] ; then
       echo "ps2epsi temp.ps"
       ps2epsi temp.ps
       echo "epstopdf temp.epsi"
       epstopdf temp.epsi
       echo "convert -rotate 90 temp.pdf -alpha off temp.gif"
       convert -rotate 90 temp.pdf -alpha off temp.gif
   else
       ${GMTpre[GMTv]} psconvert temp.ps -A -Tg
       convert -rotate 90 temp.png -resize 630x500 -alpha off temp.gif
   fi

   width=`identify temp.gif | cut -f3 -d' ' | cut -f1 -d'x'`
   height=`identify temp.gif | cut -f3 -d' ' | cut -f2 -d'x'`
   vidx_UL=$(($width*73/100))
   vidy_UL=$(($height*82/100))
   #echo ${width} > tmp1.txt
   #echo ${height} > tmp2.txt

   composite -geometry +${legendx_UL}+${legendy_UL} ${ASH3DSHARE_PP}/CloudHeightLegend2.png \
        temp.gif temp.gif

   convert temp.gif output3_t${time}.gif
   if test -r official.txt; then
       convert -append -background white output3_t${time}.gif ${ASH3DSHARE_PP}/caveats.gif output3_t${time}.gif
    else
       convert -append -background white output3_t${time}.gif ${ASH3DSHARE_PP}/caveats_notofficial_UAF_puff.png \
                   output3_t${time}.gif
   fi
   composite -geometry +${vidx_UL}+${vidy_UL} ${ASH3DSHARE_PP}/USGSvid.png output3_t${time}.gif \
             output3_t${time}.gif
   t=`expr $t + 1`
done

if [ "$CLEANFILES" == "T" ]; then
    # Clean up more temporary files
    rm map_range.txt legend_positions_ac.txt
    rm temp.* 
    rm *.lev
fi

echo "combining gifs to  make animation"
gifsicle --delay=25 --colors 256 `ls -1tr output3_t*.gif` --loopcount=0 -o puff_animation.gif

echo 'saving 6-hour gif images'
t=0
while [ "$t" -le $(($tmax-1)) ]
do
    time=`echo "${t0} + ${t} * ${time_interval}" | bc -l`
    hours_now=`echo "$hours_real + $time" | bc -l`
    hours_since=`${USGSROOT}/bin/HoursSince1900 $year $month $day $hours_now`
    filename=`${USGSROOT}/bin/yyyymmddhh_since_1900 $hours_since`
    echo "moving file output_t${time}.gif to ${filename}.gif"
    mv output3_t${time}.gif ${filename}_puff.gif
    if [ $time_interval = "1" ]; then
       t=$(($t+3))
      elif [ $time_interval = "2" ]; then
       t=$(($t+3))
      else
       t=$(($t+1))
     fi
done

rm -f output*.gif caption.txt current_time.txt
fi

echo "Eruption start time: "$year $month $day $hour
echo "plume height (km) ="$EPlH
echo "eruption duration (hrs) ="$EDur
echo "erupted volume (km3 DRE) ="$EVol
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GFSVolc_to_gif_ac_puff.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "exiting GFSVolc_to_gif_ac_puff.sh with status $rc"
exit $rc

