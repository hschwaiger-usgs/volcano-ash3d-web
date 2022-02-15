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
#  [rundirectory]
echo "------------------------------------------------------------"
echo "running GFSVolc_to_gif_dp.sh"
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
RUNDATE=`date -u "+%D %T"`

# We need to know if we must prefix all gmt commands with 'gmt', as required by version 5/6
GMTv=5
type gmt >/dev/null 2>&1 || { echo >&2 "Command 'gmt' not found.  Assuming GMTv4."; GMTv=4;}
if [ $GMTv -ne 4 ] ; then
    GMTv=`gmt --version | cut -c1`
fi
GMTpre=("-" "-" "-" "-" " "   "gmt " "gmt ")
GMTelp=("-" "-" "-" "-" "ELLIPSOID" "PROJ_ELLIPSOID" "PROJ_ELLIPSOID")
GMTnan=("-" "-" "-" "-" "-Ts" "-Q" "-Q")
GMTrgr=("-" "-" "-" "-" "grdreformat" "grdconvert" "grdconvert")
GMTpen=("-" "-" "-" "-" "/" ",")
echo "GMT version = ${GMTv}"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"
#cp ${ASH3DSHARE_PP}/VAAC* .
if test -r world_cities.txt ; then
    echo "Found file world_cities.txt"
  else
    ln -s ${ASH3DSHARE_PP}/world_cities.txt .
fi

# variable netcdfnames
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
var=${var_n[5]}
echo " "
echo "                Generating images for *** $var ***"
echo " "

echo "Copying cpt files used for flooded contours"
cp ${ASH3DSHARE_PP}/Ash3d_$var*cpt .

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
if [ "$CLEANFILES" == "T" ]; then
    echo "removing old files"
    rm -f *.xyz *.grd contour_range.txt map_range.txt
fi
#GET VARIABLES FROM 3D_tephra-fall.nc
volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "ncdump command failed.  Exiting script"
    exit 1
fi
echo $volc > volc.txt
date=`ncdump -h ${infile} | grep Date | cut -d\" -f2 | cut -c 1-10`
rm -f var.txt
echo "dp" > var.txt
echo "Processing " $volc " on " $date
#time of eruption start
year=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c1-4`
month=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c5-6`
day=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c7-8`
#day=17
#year=2021
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

#get volcano longitude, latitude
VCLON=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $1}'`
VCLAT=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $2}'`
echo "VCLON="$VCLON ", VCLAT="$VCLAT

#get source parameters from netcdf file
EDur=`ncdump -v er_duration ${infile} | grep er_duration | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EPlH=`ncdump -v er_plumeheight ${infile} | grep er_plumeheight | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EVol_fl=`ncdump -v er_volume ${infile} | grep er_volume | grep "=" | \
        grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`

FineAshFrac=0.05
#FineAshFrac=1.0
EVol_dec=`${ASH3DBINDIR}/convert_to_decimal $EVol_fl`   #if it's in scientific notation, convert to real
EVol_ac=`echo "( $EVol_dec / $FineAshFrac)" | bc -l`
EVol_dp=$EVol_dec

# Remove the trailing zeros
echo $EVol_ac  | awk ' sub("\\.*0+$","") ' > tmp.txt
EVol_ac=`cat tmp.txt`
echo $EVol_dp  | awk ' sub("\\.*0+$","") ' > tmp.txt
EVol_dp=`cat tmp.txt`
EVol=$EVol_dp
#If volume equals minimum threshold volume, add annotation
EVol_int=`echo "$EVol * 10000" | bc -l | sed 's/\.[0-9]*//'`   #convert EVol to an integer
if [ $EVol_int -eq 1 ] ; then
    EVol="0.0001"
    Threshval="(min. threshold)"
  else
    Threshval=""
fi

#get start time of wind file
echo "getting windfile time"
windtime=`ncdump -h ${infile} | grep NWPStartTime | cut -c20-39`
gsbins=`ncdump   -h ${infile} | grep "bn =" | cut -c6-8`        # of grain-size bins
zbins=`ncdump    -h ${infile} | grep "z ="  | cut -c6-7`        # # of elevation levels
tmax=`ncdump     -h ${infile} | grep "t = UNLIMITED" | cut -c22-23` # maximum time dimension
t0=`ncdump     -v t ${infile} | grep \ t\ = | cut -f4 -d" " | cut -f1 -d","`
t1=`ncdump     -v t ${infile} | grep \ t\ = | cut -f5 -d" " | cut -f1 -d","`
time_interval=`echo "($t1 - $t0)" |bc -l`
iwindformat=`ncdump -h ${infile} |grep b3l1 | cut -f2 -d= | cut -f2 -d\" | cut -f2 -d' '`
echo "windtime=$windtime"
if [ ${iwindformat} -eq 25 ]; then
    windfile="NCEP reanalysis 2.5 degree"
  else
    windfile="GFS forecast 0.5 degree for $windtime"
fi
echo "Found $tmax time steps with an interval of ${time_interval}"
echo "Finished probing output file for run information"

#******************************************************************************
#EXTRACT INFORMATION ABOUT THE REQUESTED VARIABLE
echo "Extracting ${var} information from ${infile} for each time step."
# depothick (trans); ashcon_max;     cloud_height;   cloud_load;
#if [ $1 -eq 0 ] || [ $1 -eq 1 ] || [ $1 -eq 2 ] || [ $1 -eq 3 ] ; then
#    for t in `seq 0 $((tmax-1))`;
#    do
#      time=`echo "${t0} + ${t} * ${time_interval}" | bc -l`
#      echo "   ${volc} : Generating ash grids for time = " ${time}
#      ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infile?$var[$t]" var_out_t${time}.grd
#    done  # end of time loop

#     #    Fin.Dep (in);  Fin.Dep (mm)
#  elif [ $1 -eq 5 ] || [ $1 -eq 6 ] ; then
    t=$((tmax-1))
    # We need to convert the NaN's to zero to get the lowest contour
    ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infile?area" zero.grd
    ${GMTpre[GMTv]} grdmath 0.0 zero.grd MUL = zero.grd
    ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infile?$var[$t]" var_out_final.grd
    ${GMTpre[GMTv]} grdmath var_out_final.grd zero.grd AND = var_out_final.grd
     #   depotime;       ash_arrival_time
#  elif [ $1 -eq 4 ] || [ $1 -eq 7 ] ; then
#    ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infile?$var" var_out_final.grd
#fi

###############################################################################
## This section is an alternate branch where the individual depocon slices are
## extracted and summed
## Extracting all the deposit info
#t=$((tmax-1))
#echo " ${volc} : Generating deposit grids for time = " ${t}
## Summing over vertical column and grainsizes
## First make all the grid files
#for i in `seq 0 $((gsbins-1))`;
#do
#    ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infile?depocon[$t,$i]" dep_out_t${t}_g${i}.grd
#done  #end of loop over gsbins
#
## Now loop through again and add them up
#${GMTpre[GMTv]} grdmath 1.0 dep_out_t${t}_g0.grd MUL = dep_tot_out_t${t}.grd
#for i in `seq 1 $((gsbins-1))`;
#do
#    echo "doing grdmath on dep_out_t${t}_g${i}.grd to dep_tot_out_t${t}.grd"
#    ${GMTpre[GMTv]} grdmath dep_out_t${t}_g${i}.grd dep_tot_out_t${t}.grd ADD = dep_tot_out_t${t}.grd
#done  # end of loop over gsbins
#
## Create the final deposit grid
#tfinal=$((tmax-1))
#echo " ${volc} : Generating final deposit grid from dep_tot_out_t${tfinal}.grd"
#${GMTpre[GMTv]} grdmath 1.0 dep_tot_out_t${tfinal}.grd MUL = dep_tot_out.grd
#******************************************************************************
echo "Finished generating all the grd files"

###############################################################################
##  Now make the maps
#get latitude & longitude range
lonmin=$LLLON
latmin=$LLLAT
lonmax=`echo "$LLLON + $DLON" | bc -l`
latmax=`echo "$LLLAT + $DLAT" | bc -l`
echo "lonmin="$lonmin ", lonmax="$lonmax ", latmin="$latmin ", latmax="$latmax
echo "$lonmin $lonmax $latmin $latmax $VCLON $VCLAT" > map_range.txt

## Setting up color mapping and contour lines
CPT=Ash3d_${var}.cpt
CPTft=Ash3d_cloud_height_km50kft.cpt

echo "Preparing to make the GMT maps."
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
    echo "0.1    C"  > dpm_0.1.lev    #deposit (0.1 mm)
    echo "0.3    C"  > dpm_0.3.lev    #deposit (0.3 mm)
    echo "1.0    C"  >   dpm_1.lev    #deposit (1 mm)
    echo "3.0    C"  >   dpm_3.lev    #deposit (3 mm)
    echo "10.0   C"  >  dpm_10.lev    #deposit (1 cm)
    echo "30.0   C"  >  dpm_30.lev    #deposit (3 cm)
    echo "100.0  C"  > dpm_100.lev    #deposit (10cm)
    echo "300.0  C"  > dpm_300.lev    #deposit (30cm)
#fi

######################
# Get the number of time steps we need
 #   depotime;       Fin.Dep (in);  Fin.Dep (mm)     ash_arrival_time
#if [ $1 -eq 4 ] || [ $1 -eq 5 ] || [ $1 -eq 6 ] || [ $1 -eq 7 ] ; then
#    #  For final times or non-time-series, set time to the last value
    tstart=$(( $tmax-1 ))
    echo "We are working on a final/static variable so set tstart = $tstart"
#  else
#    # For normal time-series variables, start at the beginning
#    tstart=0
#    #tstart=$(( $tmax-1 ))
#    echo "We are working on a transient variable so set tstart = $tstart"
#fi

echo "Preparing to make the GMT maps."
#  Time loop would go here

# Set up some default values
# Projected wind data assumes sphere with radius 6371.229 km
# GMT's sperical ellipsoid assume a radius of    6371.008771 km
${GMTpre[GMTv]} gmtset ${GMTelp[GMTv]} Sphere

#set mapping parameters
DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer
if [ $DLON_INT -le 2 ] ; then
   BASE="-Ba0.25/a0.25"            # label every 5 degress lat/lon
   DETAIL="-Dh"                    # high resolution coastlines (-Dc=crude)
   KMSCALE="30"
   MISCALE="20"
 elif [ $DLON_INT -le 5 ] ; then
   BASE="-Ba1/a1"                  # label every 5 degress lat/lon
   DETAIL="-Dh"                    # high resolution coastlines (-Dc=crude)
   KMSCALE="50"
   MISCALE="30"
 elif [ $DLON_INT -le 10 ] ; then
   BASE="-Ba2/a2"                  # label every 5 degress lat/lon
   DETAIL="-Dh"                    # high resolution coastlines (-Dc=crude)
   KMSCALE="100"
   MISCALE="50"
 else
   BASE="-Ba5/a5"                  #label every 10 degrees lat/lon
   DETAIL="-Dh"                    # high resolution coastlines (-Dc=crude)
   KMSCALE="200"
   MISCALE="100"
fi
#set mapping parameters
AREA="-R$lonmin/$lonmax/$latmin/$latmax"
PROJ="-JM${VCLON}/${VCLAT}/20"      # Mercator projection, with origin at lat & lon of volcano, 20 cm width
COAST="-G220/220/220 -W"            # RGB values for land areas (220/220/220=light gray)
BOUNDARIES="-Na"                    # -N=draw political boundaries, a=all national, Am. state & marine b.
RIVERS="-I1/1p,blue -I2/0.25p,blue" # Perm. large rivers used 1p blue line, other large rivers 0.25p blue line

mapscale1_x=`echo "$lonmin + 0.6*$DLON" | bc -l`                #x location of km scale bar
mapscale1_y=`echo "$latmin + 0.07 * ($latmax - $latmin)" | bc -l`      #y location of km scale bar
km_symbol=`echo "$mapscale1_y + 0.05 * ($latmax - $latmin)" | bc -l`  #location of km symbol
mapscale2_x=`echo "$lonmin + 0.6*$DLON" | bc -l`                #x location of km scale bar
mapscale2_y=`echo "$latmin + 0.15 * ($latmax - $latmin)" | bc -l`      #y location of km scale bar
mile_symbol=`echo "$mapscale2_y + 0.05 * ($latmax - $latmin)" | bc -l`  #location of km symbol
if [ $GMTv -eq 4 ] ; then
    SCALE1="-L${mapscale1_x}/${mapscale1_y}/${km_symbol}/${KMSCALE}+p+f255"  #specs for drawing km scale bar
    SCALE2="-L${mapscale2_x}/${mapscale2_y}/${mile_symbol}/${MISCALE}m+p+f255"  #specs for drawing mile scale bar
else
    SCALE1="-L${mapscale1_x}/${mapscale1_y}/${km_symbol}/${KMSCALE}"  #specs for drawing km scale bar
    SCALE2="-L${mapscale2_x}/${mapscale2_y}/${mile_symbol}/${MISCALE}M+"  #specs for drawing mile scale bar
fi

#############################################################################
### Plot the base map
# Note: If you get errors with pscoast not finding the gshhg files, you can find where gmt is looking for the
#       files by running the above pscoast command with -Vd.  Then you can link the gshhg files to the correct
#       location.  e.g.
#         mkdir /usr/share/gmt/coast
#         ln -s /usr/share/gshhg-gmt-nc4/*nc /usr/share/gmt/coast/
${GMTpre[GMTv]} pscoast $AREA $PROJ $BASE $DETAIL $COAST $BOUNDARIES $RIVERS -K > temp.ps #Plot base map

##################
# Plot variable
dep_grd=var_out_final.grd
if [ $GMTv -eq 4 ] ; then
    # GMT v4 writes contours with -D[basename] and writes files with [basename][lev][segment]_[e,i].xyz; with e,i for interior or exterior
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.1.lev -D -A- -W6/255/0/0 -Dcontourfile  -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.8.lev -D -A- -W6/0/0/255     -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_6.lev   -D -A- -W6/0/183/255   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_25.lev  -D -A- -W6/255/0/255   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_100.lev -D -A- -W6/0/51/51     -O -K >> temp.ps
else    
    # GMT v5 [GMTv]writes contour files as a separate step from drawing and writes all segments to one file
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.1.lev -A- -W3,255/0/0   -Dcontourfile_0.1_0_i.xyz
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.8.lev -A- -W3,0/0/255   -Dcontourfile_0.8_0_i.xyz
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_6.lev   -A- -W3,0/183/255 -Dcontourfile_6.0_0_i.xyz
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_25.lev  -A- -W3,255/0/255 -Dcontourfile_25_0_i.xyz
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_100.lev -A- -W3,0/51/51   -Dcontourfile_100_0_i.xyz

    # GMT v5 adds a header line to these files.  First double-check that the header is present, then remove it.
    testchar=`head -1 contourfile_0.1_0_i.xyz | cut -c1`
    if [ $testchar = '>' ] ; then
      tail -n +2 contourfile_0.1_0_i.xyz > temp.xyz
      mv temp.xyz contourfile_0.1_0_i.xyz
      tail -n +2 contourfile_0.8_0_i.xyz > temp.xyz
      mv temp.xyz contourfile_0.8_0_i.xyz
      tail -n +2 contourfile_6.0_0_i.xyz > temp.xyz
      mv temp.xyz contourfile_6.0_0_i.xyz
      tail -n +2 contourfile_25_0_i.xyz  > temp.xyz
      mv temp.xyz contourfile_25_0_i.xyz
      tail -n +2 contourfile_100_0_i.xyz > temp.xyz
      mv temp.xyz contourfile_100_0_i.xyz
    fi

    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.1.lev -A- -W3,255/0/0     -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_0.8.lev -A- -W3,0/0/255     -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_6.lev   -A- -W3,0/183/255   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_25.lev  -A- -W3,255/0/255   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour ${dep_grd} $AREA $PROJ $BASE -Cdp_100.lev -A- -W3,0/51/51     -O -K >> temp.ps
fi

# Figure out if we are processing an ash cloud variable or a deposit variable for legend
# coordinates
echo "running legend_placer_dp"
${ASH3DBINDIR}/legend_placer_dp
captionx_UL=`cat legend_positions_dp.txt   | grep "legend1x_UL" | cut -c13-20`
captiony_UL=`cat legend_positions_dp.txt   | grep "legend1x_UL" | cut -c36-42`
legendx_UL=$((`cat legend_positions_dp.txt | grep "legend2x_UL" | cut -c13-15`))
legendy_UL=$((`cat legend_positions_dp.txt | grep "legend2x_UL" | cut -c31-33`))
echo "writing caption.txt"
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
    convert +append -background white legend1.png legend2.png ${ASH3DSHARE_PP}/USGSvid.png legend.png

echo "adding cities"
${ASH3DBINDIR}/citywriter ${lonmin} ${lonmax} ${latmin} ${latmax}
if test -r cities.xy ; then
    echo "Adding cities to map"
    # Add a condition to plot roads if you'd like
    #tstvolc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-7`
    #if [ "${tstvolc}" = "Kilauea" ] ; then
    #  ${GMTpre[GMTv]} psxy $AREA $PROJ -m ${ASH3DSHARE_PP}/roadtrl020.gmt -W0.25p,red -O -K >> temp.ps
    #fi
    ${GMTpre[GMTv]} psxy cities.xy $AREA $PROJ -Sc0.05i -Gblack -Wthinnest -V -O -K >> temp.ps  
    ${GMTpre[GMTv]} pstext cities.xy $AREA $PROJ -D0.1/0.1 -V -O -K >> temp.ps      #Plot names of all airports
fi

${GMTpre[GMTv]} psbasemap $AREA $PROJ $SCALE1 -O -K >> temp.ps                      #add km scale bar in overlay
${GMTpre[GMTv]} psbasemap $AREA $PROJ $SCALE2 -O -K >> temp.ps                      #add mile scale bar in overlay

# Last gmt command is to plot the volcano and close out the ps file
echo $VCLON $VCLAT '1.0' | ${GMTpre[GMTv]} psxy $AREA $PROJ -St0.1i -Gblack -Wthinnest -O >> temp.ps

## Last gmt command is to write the caption and close out the ps file
#echo "Writing caption to temp.ps"
#if [ $GMTv -eq 4 ] ; then
#    ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -m -Wwhite,o -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
#else
#    ${GMTpre[GMTv]} pstext caption.txt $AREA $PROJ -M -Gwhite -Wblack,. -F+f14,Times-Roman+jLT -N -O >> temp.ps  #-Wwhite,o paints a white recctangle with outline
#fi

#  Convert to gif
if [ $GMTv -eq 4 ] ; then
    ps2epsi temp.ps
    epstopdf temp.epsi
    convert -rotate 90 temp.pdf -alpha off temp.gif
  elif [ $GMTv -eq 5 ] ; then
    ${GMTpre[GMTv]} psconvert temp.ps -A -Tg
    convert -rotate 90 temp.png -resize 630x500 -alpha off temp.gif
  else
    ${GMTpre[GMTv]} psconvert temp.ps -A -Tg
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
convert temp.gif deposit_thickness_inches.gif
if test -r official.txt; then
    convert -append -background white deposit_thickness_inches.gif \
            ${ASH3DSHARE_PP}/caveats_official.png deposit_thickness_inches.gif
else
    convert -append -background white deposit_thickness_inches.gif \
            ${ASH3DSHARE_PP}/caveats_notofficial.png deposit_thickness_inches.gif
fi
#composite -geometry +${vidx_UL}+${vidy_UL} ${ASH3DSHARE_PP}/USGSvid.png \
#          deposit_thickness_inches.gif  deposit_thickness_inches.gif
composite -geometry +${legendx_UL}+${legendy_UL} ${ASH3DSHARE_PP}/legend_dep_nws.png \
          deposit_thickness_inches.gif  deposit_thickness_inches.gif
#  End of time loop would go here

# Finalizing output (animations, shape files, etc.)
#Make shapefile
echo "Generating shapefile"
rm -f dp.shp dp.prj dp.shx dp.dbf dp_shp.zip
python ${ASH3DSCRIPTDIR}/xyz2shp.py
if [ "$CLEANFILES" == "T" ]; then
    echo "Removing temp files for shapefile generation"
    rm contour*.xyz volc.txt var.txt
fi
# Clean up more temporary files
if [ "$CLEANFILES" == "T" ]; then
   echo "End of GFSVolc_to_gif_dp.sh: removing files."
   rm -f *.grd *.lev
   rm -f current_time.txt
   rm -f caption.txt cities.xy map_range*txt legend_positions*txt
   rm -f temp.*
   rm -f gmt.conf gmt.history
   rm -f world_cities.txt
   rm -f VAAC_*.xy *cpt
   rm -f contourfile*xyz
fi

width=`identify deposit_thickness_inches.gif | cut -f3 -d' ' | cut -f1 -d'x'`
height=`identify deposit_thickness_inches.gif | cut -f3 -d' ' | cut -f2 -d'x'`
echo "Figure width=$width, height=$height"
echo "Eruption start time: $year $month $day $hour"
echo "plume height (km) =$EPlH"
echo "eruption duration (hrs) =$EDur"
echo "erupted volume (km3 DRE) ="$EVol
echo "all done"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GFSVolc_to_gif_dp.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
