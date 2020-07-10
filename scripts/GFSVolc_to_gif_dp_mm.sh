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
echo "running GFSVolc_to_gif_dp_mm.sh"
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"
RUNDATE=`date -u "+%D %T"`

# We need to know if we must prefix all gmt commands with 'gmt', as required by version 5
GMTv=5
type gmt >/dev/null 2>&1 || { echo >&2 "Command 'gmt' not found.  Assuming GMTv4."; GMTv=4;}
GMTpre=("-" "-" "-" "-" " "   "gmt ")
GMTelp=("-" "-" "-" "-" "ELLIPSOID" "PROJ_ELLIPSOID")
GMTnan=("-" "-" "-" "-" "-Ts" "-Q")
GMTrgr=("-" "-" "-" "-" "grdreformat" "grdconvert")
echo "GMT version = ${GMTv}"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

export PATH=/usr/local/bin:$PATH

if [ "$CLEANFILES" == "T" ]; then
    echo "removing old files"
    rm -f *.xyz *.grd contour_range.txt map_range.txt
fi
infile="3d_tephra_fall.nc"

volc=`ncdump -h ${infile} | grep b1l1 | cut -d\" -f2 | cut -c1-30 | cut -d# -f1`
date=`ncdump -h ${infile} | grep Date | cut -d\" -f2 | cut -c 1-10`
echo $volc > volc.txt
rm -f var.txt
echo "dp_mm" > var.txt
year=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c1-4`
month=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c5-6`
day=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c7-8`
hour=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c9-10`
minute=`ncdump -h ${infile} | grep ReferenceTime | cut -d\" -f2 | cut -c12-13`


LLLON=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $1}'`
LLLAT=`ncdump -h ${infile} | grep b1l3 | cut -d\" -f2 | awk '{print $2}'`
DLON=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $1}'`
DLAT=`ncdump -h ${infile} | grep b1l4 | cut -d\" -f2 | awk '{print $2}'`

#get volcano longitude, latitude
VCLON=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $1}'`
#the cut command doesn't recognize consecutive spaces as a single delimiter,
#therefore I have to use awk to get the latitude from the second field in b1l5
VCLAT=`ncdump -h ${infile} | grep b1l5 | cut -d\" -f2 | awk '{print $2}'`
echo "VCLON="$VCLON ", VCLAT="$VCLAT

#get source parameters from netcdf file
EDur=`ncdump -v er_duration ${infile} | grep er_duration \
              | grep "=" | grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EPlH=`ncdump -v er_plumeheight ${infile} | grep er_plumeheight \
              | grep "=" | grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`
EVol=`ncdump -v er_volume ${infile} | grep er_volume | grep "=" \
              | grep -v ":" | cut -f2 -d"=" | cut -f2 -d" "`

#If volume equals minimum threshold volume, add annotation
EVol_int=`echo "$EVol * 10000" | bc -l | sed 's/\.[0-9]*//'`   #convert EVol to an integer
if [ $EVol_int -eq 1 ] ; then
    EVol="0.0001"
    Threshval="(min. threshold)"
  else
    Threshval=""
fi

DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer

#get start time of wind file
echo "getting windfile time"
#Need to make sure NWPStartTime is in the output file
windtime=`ncdump -h ${infile} | grep NWPStartTime | cut -c20-39`
echo "windtime=$windtime"
iwindformat=`ncdump -h ${infile} |grep b3l1 | cut -c16-20`
if [ ${iwindformat} -eq 25 ]; then
     windfile="NCEP reanalysis 2.5 degree for $windtime"
  else
     windfile="GFS forecast 0.5 degree for $windtime"
fi

echo "Processing " $volc " on " $date

## First process the netcdf file
infilell="3d_tephra_fall.nc"

if test 1 -eq 1
   then

   gsbins=`ncdump -h $infilell | grep "bn =" | cut -c6-8`      # # of grain-size bins
   zbins=`ncdump -h $infilell | grep "z =" | cut -c6-7`        # # of elevation levels
   tmax=`ncdump -h $infilell | grep "UNLIMITED" | cut -c22-23` # maximum time

   ## Extracting all the deposit info
    t=$((tmax-1))
#   for t in `seq 0 $((tmax-1))`;
#   do
       echo " ${volc} : Generating deposit grids for time = " ${t}
       # Summing over vertical column and grainsizes
       # First make all the grid files
       for i in `seq 0 $((gsbins-1))`;
       do
          ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "$infilell?depocon[$t,$i]" dep_out_t${t}_g${i}.grd
       done  #end of loop over gsbins

       # Now loop through again and add them up
       ${GMTpre[GMTv]} grdmath 1.0 dep_out_t${t}_g0.grd MUL = dep_tot_out_t${t}.grd
       for i in `seq 1 $((gsbins-1))`;
       do
          echo "doing grdmath on dep_out_t${t}_g${i}.grd to dep_tot_out_t${t}.grd"
          ${GMTpre[GMTv]} grdmath dep_out_t${t}_g${i}.grd dep_tot_out_t${t}.grd ADD = dep_tot_out_t${t}.grd
       done  # end of loop over gsbins
#   done  # end of time loop

   # Create the final deposit grid
   tfinal=$((tmax-1))
   echo " ${volc} : Generating final deposit grid from dep_tot_out_t${tfinal}.grd"
   ${GMTpre[GMTv]} grdmath 1.0 dep_tot_out_t${tfinal}.grd MUL = dep_tot_out.grd
else
  #
   t=$((tmax-1))
   lon1=`${GMTpre[GMTv]} grdinfo ${infilell} -C | cut -f2`
   lon2=`${GMTpre[GMTv]} grdinfo ${infilell} -C | cut -f3`
   lat1=`${GMTpre[GMTv]} grdinfo ${infilell} -C | cut -f4`
   lat2=`${GMTpre[GMTv]} grdinfo ${infilell} -C | cut -f5`
   # use dc (desk calculator)
   lons1=`echo "$lon1 - 360.0" | bc -l`
   lons2=`echo "$lon2 - 360.0" | bc -l`
   tvar=(depothick ashcon_max cloud_height cloud_load)

   ${GMTpre[GMTv]} ${GMTrgr[GMTv]} "${infile}?depothick[$t]" dep_tot_out.grd
   ${GMTpre[GMTv]} grdedit dep_tot_out.grd -R${lons1}/${lons2}/${lat1}/${lat2}

fi

###############################################################################
#create .lev files of contour values
echo "0.01    214 222 105" > dp_0.01.lev   #deposit (0.01 mm)
echo "0.03    249 167 113" > dp_0.03.lev   #deposit (0.03 mm)
echo "0.1    128   0 128"  > dp_0.1.lev    #deposit (0.1 mm)
echo "0.3      0   0 255"  > dp_0.3.lev    #deposit (0.3 mm)
echo "1.0      0 128 255"  >   dp_1.lev    #deposit (1 mm)
echo "3.0      0 255 128"  >   dp_3.lev    #deposit (3 mm)
echo "10.0   195 195   0"  >  dp_10.lev    #deposit (1 cm)
echo "30.0   255 128   0"  >  dp_30.lev    #deposit (3 cm)
echo "100.0  255   0   0"  > dp_100.lev    #deposit (10cm)
echo "300.0  128   0   0"  > dp_300.lev    #deposit (30cm)

#get latitude & longitude range
lonmin=$LLLON
latmin=$LLLAT
lonmax=`echo "$LLLON + $DLON" | bc -l`
latmax=`echo "$LLLAT + $DLAT" | bc -l`
echo "lonmin="$lonmin ", lonmax="$lonmax ", latmin="$latmin ", latmax="$latmax
echo "$lonmin $lonmax $latmin $latmax $VCLON $VCLAT" > map_range.txt

#set mapping parameters
DLON_INT="$(echo $DLON | sed 's/\.[0-9]*//')"  #convert DLON to an integer
if [ $DLON_INT -le 2 ]
then
   BASE="-Ba0.25/a0.25"                  # label every 5 degress lat/lon
   KMSCALE="30"
   MISCALE="20"
   DETAIL="-Di"
 elif [ $DLON_INT -le 5 ] ; then
   BASE="-Ba1/a1"                  # label every 5 degress lat/lon
   KMSCALE="50"
   MISCALE="30"
   DETAIL="-Di"
 elif [ $DLON_INT -le 10 ] ; then
   BASE="-Ba2/a2"                  # label every 5 degress lat/lon
   KMSCALE="100"
   MISCALE="50"
   DETAIL="-Di"
 else
   BASE="-Ba5/a5"                    #label every 10 degrees lat/lon
   KMSCALE="200"
   MISCALE="100"
   DETAIL="-Dl"
fi
#set mapping parameters
AREA="-R$lonmin/$lonmax/$latmin/$latmax"
#AREA="-Rdep_tot_out.grd"            #sets the map boundaries based on the file dep_tot_out.grd
#BASE="-Ba2/a1"                      #"a1/a1" means annotations every 1 degree. "g1/g1"=gridlines every 1 degree
PROJ="-JM${VCLON}/${VCLAT}/20"      # Mercator projection, with origina at lat & lon of volcano, 20 cm width
#DETAIL="-Dl"                        # low resolution coastlines (-Dc=crude, -Di=intermediate, -Dl=low)
COAST="-G220/220/220 -W"            # RGB values for land areas (220/220/220=light gray)
BOUNDARIES="-Na"                    # -N=draw political boundaries, a=all national, Am. state & marine b.
RIVERS="-I1/1p,blue -I2/0.25p,blue" # Perm. large rivers used 1p blue line, other large rivers 0.25p blue line

mapscale1_x=`echo "$lonmin + 0.6*$DLON" | bc -l`                #x location of km scale bar
mapscale1_y=`echo "$latmin + 0.07 * ($latmax - $latmin)" | bc -l`      #y location of km scale bar
km_symbol=`echo "$mapscale1_y + 0.05 * ($latmax - $latmin)" | bc -l`  #location of km symbol
mapscale2_x=`echo "$lonmin + 0.6*$DLON" | bc -l`                #x location of km scale bar
mapscale2_y=`echo "$latmin + 0.15 * ($latmax - $latmin)" | bc -l`      #y location of km scale bar
mile_symbol=`echo "$mapscale2_y + 0.05 * ($latmax - $latmin)" | bc -l`  #location of mile symbol
if [ $GMTv -eq 4 ] ; then
    SCALE1="-L${mapscale1_x}/${mapscale1_y}/${km_symbol}/${KMSCALE}+p+f255"  #specs for drawing km scale bar
    SCALE2="-L${mapscale2_x}/${mapscale2_y}/${mile_symbol}/${MISCALE}m+p+f255"  #specs for drawing mile scale bar
else
    SCALE1="-L${mapscale1_x}/${mapscale1_y}/${km_symbol}/${KMSCALE}"  #specs for drawing km scale bar
    SCALE2="-L${mapscale2_x}/${mapscale2_y}/${mile_symbol}/${MISCALE}M+"  #specs for drawing mile scale bar
fi
###############################################################################
#MAKE THE DEPOSIT MAP
echo " ${volc} : Creating deposit map"
${GMTpre[GMTv]} gmtset ${GMTelp[GMTv]} Sphere
${GMTpre[GMTv]} pscoast $AREA $PROJ $BASE $DETAIL $COAST $BOUNDARIES $RIVERS -K > temp.ps #Plot base map
# Note: If you get errors with pscoast not finding the gshhg files, you can find where gmt is looking for the
#       files by running the above pscoast command with -Vd.  Then you can link the gshhg files to the correct
#       location.  e.g.
#         mkdir /usr/share/gmt/coast
#         ln -s /usr/share/gshhg-gmt-nc4/*nc /usr/share/gmt/coast/

if [ $GMTv -eq 4 ] ; then
    # GMT v4 writes contours with -D[basename] and writes files with [basename][lev][segment]_[e,i].xyz; with e,i for interior or exterior
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.01.lev -D -A- -W6/214/222/105 -Dcontourfile -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.03.lev -D -A- -W6/249/167/113 -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.1.lev -D -A- -W6/128/0/128    -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.3.lev -D -A- -W6/0/0/255      -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_1.lev   -D -A- -W6/0/128/255    -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_3.lev   -D -A- -W6/0/255/128    -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_10.lev  -D -A- -W6/195/195/0    -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_30.lev  -D -A- -W6/255/128/0    -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_100.lev -D -A- -W6/255/0/0      -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_300.lev -D -A- -W6/128/0/0      -O -K >> temp.ps
else
    # GMT v5 [GMTv]writes contour files as a separate step from drawing and writes all segments to one file
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.01.lev -A- -W3,214/222/105 -Dcontourfile_0.01_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.03.lev -A- -W3,249/167/113 -Dcontourfile_0.03_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.1.lev  -A- -W3,128/0/128   -Dcontourfile_0.1_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.3.lev  -A- -W3,0/0/255     -Dcontourfile_0.3_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_1.lev    -A- -W3,0/128/255   -Dcontourfile_1_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_3.lev    -A- -W3,0/255/128   -Dcontourfile_3_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_10.lev   -A- -W3,195/195/0   -Dcontourfile_10_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_30.lev   -A- -W3,255/128/0   -Dcontourfile_30_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_100.lev  -A- -W3,255/0/0     -Dcontourfile_100_0_i.xyz
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_300.lev  -A- -W3,128/0/0     -Dcontourfile_3000_0_i.xyz

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

    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.01.lev -A- -W3,214/222/105   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.03.lev -A- -W3,249/167/113   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.1.lev  -A- -W3,128/0/128   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_0.3.lev  -A- -W3,0/0/255     -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_1.lev    -A- -W3,0/128/255   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_3.lev    -A- -W3,0/255/128   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_10.lev   -A- -W3,195/195/0   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_30.lev   -A- -W3,255/128/0   -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_100.lev  -A- -W3,255/0/0     -O -K >> temp.ps
    ${GMTpre[GMTv]} grdcontour dep_tot_out.grd   $AREA $PROJ $BASE -Cdp_300.lev  -A- -W3,128/0/0     -O -K >> temp.ps
fi

echo $VCLON $VCLAT '1.0' | ${GMTpre[GMTv]} psxy $AREA $PROJ -St0.1i -Gblack -Wthinnest -O -K >> temp.ps  #Plot Volcano

echo "running legend_placer_dp_mm"
${ASH3DBINDIR}/legend_placer_dp_mm

echo "adding cities"
cp ${ASH3DSHARE_PP}/world_cities.txt .
${ASH3DBINDIR}/citywriter ${lonmin} ${lonmax} ${latmin} ${latmax}
if test -r cities.xy
then
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

#Write caveats to figure
captionx_UL=`cat legend_positions_dp_mm.txt   | grep "legend1x_UL" | cut -c13-20`
captiony_UL=`cat legend_positions_dp_mm.txt   | grep "legend1x_UL" | cut -c36-42`
legendx_UL=$((`cat legend_positions_dp_mm.txt | grep "legend2x_UL" | cut -c13-15`))
legendy_UL=$((`cat legend_positions_dp_mm.txt | grep "legend2x_UL" | cut -c31-33`))

echo "writing caption.txt"
cat << EOF > caption.txt
> $captionx_UL $captiony_UL 12 0 0 TL 14p 3.0i l
   @%1%Volcano: @%0%$volc

   @%1%Run date: @%0%$RUNDATE UTC

   @%1%Eruption start: @%0%${year} ${month} ${day} ${hour}:${minute} UTC

   @%1%Plume height: @%0%$EPlH\n km asl

   @%1%Duration: @%0%$EDur\n hours

   @%1%Volume: @%0%$EVol km3 DRE $Threshval

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
vidx_UL=$(($width*72/100))
vidy_UL=$(($height*85/100))

convert temp.gif deposit_thickness_mm.gif
if test -r official.txt; then
    convert -append -background white deposit_thickness_mm.gif \
              ${ASH3DSHARE_PP}/caveats_official.png deposit_thickness_mm.gif
else
    convert -append -background white deposit_thickness_mm.gif \
              ${ASH3DSHARE_PP}/caveats_notofficial.png deposit_thickness_mm.gif
fi
composite -geometry +${vidx_UL}+${vidy_UL} ${ASH3DSHARE_PP}/USGSvid.png \
      deposit_thickness_mm.gif  deposit_thickness_mm.gif
composite -geometry +${legendx_UL}+${legendy_UL} ${ASH3DSHARE_PP}/legend_dep.png \
       deposit_thickness_mm.gif  deposit_thickness_mm.gif

if [ "$CLEANFILES" == "T" ]; then
   # Clean up more temporary files
   rm *.grd *.lev caption.txt map_range.txt
   rm temp.* legend_positions_dp_mm.txt
fi

#Make shapefile
echo "Generating shapefile"
rm -f dp_mm.shp dp_mm.prj dp_mm.shx dp_mm.dbf dp_mm_shp.zip
python ${ASH3DSCRIPTDIR}/xyz2shp.py
if [ "$CLEANFILES" == "T" ]; then
    rm contour*.xyz volc.txt var.txt
fi

width=`identify deposit_thickness_mm.gif | cut -f3 -d' ' | cut -f1 -d'x'`
height=`identify deposit_thickness_mm.gif | cut -f3 -d' ' | cut -f2 -d'x'`
echo "Figure width=$width, height=$height"
echo "Eruption start time: $year $month $day $hour"
echo "plume height (km) =$EPlH"
echo "eruption duration (hrs) =$EDur"
echo "erupted volume (km3 DRE) ="$EVol
echo "all done"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "finished GFSVolc_to_gif_dp_mm.sh"
echo `date`
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
