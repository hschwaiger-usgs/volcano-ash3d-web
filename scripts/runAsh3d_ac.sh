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

#      Usage: runAsh3d_ac.sh rundir zipname dash_flag advanced_flag

echo "------------------------------------------------------------"
echo "running runAsh3d_ac.sh"
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"

t0=`date -u`                                     # record start time
rc=0                                             # error message accumulator

HOST=`hostname | cut -c1-9`
echo "HOST=$HOST"

USGSROOT="/opt/USGS"
ASH3DROOT="${USGSROOT}/Ash3d"
WINDROOT="/data/WindFiles"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

GFSDATAHOME="${WINDROOT}/gfs"

#Determine last downloaded windfile
LAST_DOWNLOADED=`cat ${WINDROOT}/gfs/last_downloaded.txt`
echo "last downloaded windfile =${LAST_DOWNLOADED}"

#Assign default filenames and directory names
INFILE_SIMPLE="ash3d_input_ac.inp"                #simplified input file
INFILE_PRELIM="ash3d_input_prelim.inp"             #input file used for preliminary Ash3d run
INFILE_MAIN="ash3d_input.txt"                 #input file used for main Ash3d run

echo "checking input argument"
if [ -z $1 ]
then
    echo "Error: you must specify an input directory containing the file ash3d_input_ac.inp"
    echo "Usage: runAsh3d_ac.sh rundir zipname dash_flag advanced_flag"
    exit 1
  else
    RUNDIR=$1
    echo "run directory is $1"
fi

if [ -z $2 ]
then
	echo "Error: you must specify a zip file name"
	exit 1
else
        #ZIPNAME=`echo $2 | tr '/' '-'`        #if there are slashes in the name, replace them with dashes
        ZIPNAME=$2
fi

DASHBOARD_RUN=$3
#for advanced runs, to create an input file, $ADVANCED_RUN="advanced1"
#                   to run an existing input file, $ADVANCED_RUN="advanced2"
ADVANCED_RUN=$4
echo "ADVANCED_RUN = $ADVANCED_RUN"
if [ "$ADVANCED_RUN" = "advanced1" ]; then
    echo "Advanced run, preliminary."
  elif [ "$ADVANCED_RUN" = "advanced2" ]; then
    echo "Advanced run using main input file"
fi

echo "changing directories to ${RUNDIR}"
if test -r ${RUNDIR}
then
    cd $RUNDIR
    echo "DASHBOARD_RUN = $DASHBOARD_RUN $3" > test.txt
  else
    echo "Error: Directory ${RUNDIR} does not exist."
    exit 1
fi

if [[ $? -ne 0 ]]; then
           rc=$((rc + 1))
fi

#if it's an advanced tab run and argument 4 is set to "advanced2",
#then skip to the last half of the script and read directly from the
#input file
if [ "$ADVANCED_RUN" != "advanced2" ]; then
     #Skip to last part of file is this is an advanced run with setting "advanced2"

    if [ "$CLEANFILES" == "T" ]; then
        echo "removing old input & output files"
        rm -f *.gif *.kmz *.zip ${INFILE_PRELIM} ${INFILE_MAIN} *.txt cities.xy *.dat *.pdf 3d_tephra_fall.nc
        rm -f *.lst Wind_nc *.xyz *.png depTS_*.gnu dp.*
        rc=$((rc + $?))
        echo "rc=$rc"
    fi

    echo "copying airports file, cities file, and readme file"
    cp ${ASH3DSHARE}/GlobalAirports_ewert.txt .
    cp ${ASH3DSHARE}/readme.pdf .
    cp ${ASH3DSHARE_PP}/USGS_warning3.png .
    ln -s ${ASH3DSHARE_PP}/world_cities.txt .
    cp ${ASH3DSHARE_PP}/concentration_legend.png .
    cp ${ASH3DSHARE_PP}/CloudHeight_hsv.png .
    cp ${ASH3DSHARE_PP}/CloudLoad_hsv.png .
    cp ${ASH3DSHARE_PP}/cloud_arrival_time.png .
    rc=$((rc + $?))
    echo "rc=$rc"

    echo "creating soft links to wind files"
    rm Wind_nc
    ln -s  ${WINDROOT} Wind_nc
    rc=$((rc + $?))
    echo "rc=$rc"

    echo "running ash3dinput1_ac ${INFILE_SIMPLE} ${INFILE_PRELIM}"
    if test -r ${ASH3DBINDIR}/makeAsh3dinput1_ac
    then
        ${ASH3DBINDIR}/makeAsh3dinput1_ac ${INFILE_SIMPLE} ${INFILE_PRELIM} \
                                          ${LAST_DOWNLOADED}
    else
        echo "Error: ${ASH3DBINDIR}/makeAsh3dinput1_ac doesn't exist"
        exit 1
    fi
    rc=$((rc + $?))
    echo "rc=$rc"
    if [[ "$rc" -gt 0 ]] ; then
        echo "rc=$rc"
        exit 1
    fi

    if test -r ${INFILE_PRELIM}
    then
        echo "${INFILE_PRELIM} created okay"
    else
        echo "Error: ${INFILE_PRELIM} not created"
        exit 1
    fi

    echo "*******************************************************************************"
    echo "*******************************************************************************"
    echo "**********                  Preliminary Ash3d run                    **********"
    echo "*******************************************************************************"
    echo "*******************************************************************************"
    ${ASH3DBINDIR}/Ash3d ${INFILE_PRELIM} | tee ashlog_prelim.txt
    echo "-------------------------------------------------------------------------------"
    echo "-------------------------------------------------------------------------------"
    echo "----------             Completed  Preliminary Ash3d run              ----------"
    echo "-------------------------------------------------------------------------------"
    echo "-------------------------------------------------------------------------------"
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "rc=$rc"
        exit 1
    fi

    echo "zipping up kml files"
    zip CloudLoad_prelim.kmz CloudLoad.kml CloudLoad_hsv.png USGS_warning3.png

    if [ "$CLEANFILES" == "T" ]; then
        echo "removing kml files"
        rm -f *.kml AshArrivalTimes.txt
    fi

    echo "making ${INFILE_MAIN}"
    if test -r ${ASH3DBINDIR}/makeAsh3dinput2_ac
    then
        ${ASH3DBINDIR}/makeAsh3dinput2_ac ${INFILE_PRELIM} ${INFILE_MAIN}

    else
        echo "Error: ${ASH3DBINDIR}/makeAsh3dinput2_ac does not exist"
        exit 1
    fi

    if test -r ${INFILE_MAIN}
    then
        echo "${INFILE_MAIN} created okay"
    else
        echo "Error: ${INFILE_MAIN} not created"
        exit 1
    fi
fi     #end of block skipped for advanced runs when $ADVANCED_RUN="advanced2"

if [ "$CLEANFILES" == "T" ]; then
    echo "removing .dat file, preliminary ash3d input file"
    echo "rm -f *.dat"
    rm -f *.dat
fi

# Run the trajectory model with the parameters in the simple input file
if test -r ${USGSROOT}/MetTraj; then
   echo "Calling runGFS_traj.sh"
   ${ASH3DSCRIPTDIR}/runGFS_traj.sh
   ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 0
else
   echo "${USGSROOT}/MetTraj does not exist.  Skipping trajectory runs."
fi
if [ "$ADVANCED_RUN" = "advanced1" ]; then
    echo "Created input file for advanced tab.  Stopping"
    exit 1
fi

echo "*******************************************************************************"
echo "*******************************************************************************"
echo "**********                   Main Ash3d run                          **********"
echo "*******************************************************************************"
echo "*******************************************************************************"
${ASH3DBINDIR}/Ash3d ${INFILE_MAIN} | tee ashlog.txt
echo "-------------------------------------------------------------------------------"
echo "-------------------------------------------------------------------------------"
echo "----------                Completed  Main Ash3d run                  ----------"
echo "-------------------------------------------------------------------------------"
echo "-------------------------------------------------------------------------------"
rc=$((rc + $?))
echo "rc=$rc"

rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error: rc=$rc"
    exit 1
fi

echo "zipping up kml files"
zip cloud_arrivaltimes_airports.kmz AshArrivalTimes.kml    USGS_warning3.png depTS*png
rc=$((rc + $?))
zip cloud_arrivaltimes_hours.kmz    CloudArrivalTime.kml   USGS_warning3.png cloud_arrival_time.png
rc=$((rc + $?))
zip CloudConcentration.kmz          CloudConcentration.kml USGS_warning3.png concentration_legend.png
rc=$((rc + $?))
zip CloudHeight.kmz                 CloudHeight.kml        USGS_warning3.png CloudHeight_hsv.png
rc=$((rc + $?))
zip CloudLoad.kmz                   CloudLoad.kml          USGS_warning3.png CloudLoad_hsv.png
rc=$((rc + $?))
echo "rc=$rc"
if [[ "$rc" -gt 0 ]] ; then
    echo "Error: rc=$rc"
    exit 1
fi

echo "running makeAshArrivalTimes_ac"
${ASH3DBINDIR}/makeAshArrivalTimes_ac
rc=$((rc+$?))
echo "rc=$rc"

echo "moving AshArrivalTimes.txt to AshArrivalTimes_old.txt"
mv AshArrivalTimes.txt AshArrivalTimes_old.txt
rc=$((rc+$?))
echo "rc=$rc"
if [[ "$rc" -gt 0 ]] ; then
    echo "Error: rc=$rc"
    exit 1
fi
echo "overwriting AshArrivalTimes.txt"
mv AshArrivalTimes_ac.txt AshArrivalTimes.txt
rc=$((rc+$?))
echo "rc=$rc"
if [[ "$rc" -gt 0 ]] ; then
    echo "Error: rc=$rc"
    exit 1
fi

#convert line endings from unix to dos
#sed 's/$/\r/' AshArrivalTimes.txt > AshArrivalTimes2.txt
#mv AshArrivalTimes2.txt AshArrivalTimes.txt
unix2dos AshArrivalTimes.txt
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error: rc=$rc"
    exit 1
fi

if [ "$CLEANFILES" == "T" ]; then
    echo "removing extraneous files"
    rm -f *.kml
    rc=$((rc+$?))
    echo "rc=$rc"
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error: rc=$rc"
        exit 1
    fi
fi

echo "started run at:  $t0" >> Ash3d.lst
echo "  ended run at: " `date` >> Ash3d.lst

echo "creating gif images of ash cloud"
# Generate gifs for the transient variables
#  0 = depothick
#  1 = ashcon_max
#  2 = cloud_height
#  3 = cloud_load
#    Cloud load is the default, so run that one first
#      Note:  the animate gif for this variable is copied to "cloud_animation.gif"
echo "Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3"
${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3

# Recreating the trajectory plot (using previously calculated trajecties), but using
# the consistant basemap
if test -r *traj*; then
   ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 1
else
   echo "skipping trajectory plots: no traj files exist in this directory."
fi

if [[ $DASHBOARD_RUN == T* ]]
  then
    #    Now run it for cloud_height
    echo "Calling GFSVolc_to_gif_tvar.sh 2"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 2
fi
rc=$((rc+$?))
echo "rc=$rc"

echo "started run at:  $t0" >> Ash3d.lst
echo "  ended run at: " `date` >> Ash3d.lst

if [[ $DASHBOARD_RUN == T* ]]
  then
    echo "Now creating gif images of the hysplit run"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_hysplit.sh


    # HFS: add check here to verify GFS is being used, that
    #      puff is installed and puff windfiles are available
    # Run the puff model with the parameters in the simple input file
    echo "Calling runGFS_puff.sh"
    ${ASH3DSCRIPTDIR}/runGFS_puff.sh

    echo "Now creating gif images of puff run"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_puff.sh
fi

#Assign a name to the zip file
#year=`date -u | cut -c25-28`
#month=`date -u | cut -c5-7`
#day=`date -u | cut -c9-10`
#hhmm=`date -u | cut -c12-16`
#ZIPFILENAME="${volc}_${year}${month}${day}.${hhmm}UTC"

echo "copying AshArrivalTimes.txt to cloud_arrivaltimes_airports.txt"
cp AshArrivalTimes.txt cloud_arrivaltimes_airports.txt
rc=$((rc+$?))
echo "rc=$rc"

#sed 's/$/\r/' ${INFILE_MAIN} > ${INFILE_MAIN}2
#mv ${INFILE_MAIN}2 ${INFILE_MAIN}
unix2dos -m ${INFILE_MAIN}

echo "flipping and renaming Ash3d.lst"
unix2dos Ash3d.lst
mv Ash3d.lst ash3d_runlog.txt

zip $ZIPNAME.zip *UTC*.gif cloud_animation.gif cloud_arrivaltimes_airports.txt ${INFILE_MAIN} \
    cloud_arrivaltimes_airports.kmz cloud_arrivaltimes_hours.kmz CloudConcentration.kmz CloudHeight.kmz \
    CloudLoad.kmz readme.pdf *rajector*gif ash3d_runlog.txt
if test -r ftraj*.dat; then
   zip -a $ZIPNAME.zip traj*.dat
fi
rc=$((rc + $?))

echo "removing extraneous files"
echo "rm -f tmp1.txt tmp2.txt"
echo "rm -f *.cpt caption.txt fort.18 current_time.txt dep_thick.txt  Temp.epsi cities.xy"
echo "rm -f USGS_warning3.png concentration_legend.png CloudHeight_hsv.png CloudLoad_hsv.png cloud_arrival_time.png"
echo "rm -f world_cities.txt test.txt"
rm -f tmp1.txt tmp2.txt
rm -f *.cpt caption.txt fort.18 current_time.txt dep_thick.txt  Temp.epsi cities.xy
rm -f USGS_warning3.png concentration_legend.png CloudHeight_hsv.png CloudLoad_hsv.png cloud_arrival_time.png
rm -f world_cities.txt test.txt

if [[ $rc -ne 0 ]]; then
	echo "$rc errors detected."
else
	echo "successful completion"
fi

t1=`date -u`
echo "started run at:  $t0"
echo "  ended run at:  $t1"
echo "all done with run $4"

exit $rc

