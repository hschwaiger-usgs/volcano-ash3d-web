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
echo "running runAsh3d_ac.sh with parameters:"
echo "  run directory  = $1"
echo "  zip file name  = $2"
echo "  Dashboard case = $3"
echo "  Advanced run   = $4"
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"
USECONTAINER="T"
CONTAINEREXE="podman"

t0=`date -u`                                     # record start time
rc=0                                             # error message accumulator

HOST=`hostname | cut -c1-9`
echo "HOST=$HOST"
if [ "$USECONTAINER" == "T" ]; then
  echo "Post processing scripts with be run with containers via ${CONTAINEREXE}"
fi
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
if [ -z $1 ] ; then
    echo "Error: you must specify an input directory containing the file ash3d_input_ac.inp"
    echo "Usage: runAsh3d_ac.sh rundir zipname dash_flag advanced_flag"
    exit 1
  else
    RUNDIR=$1
    echo "run directory is $1"
fi

if [ -z $2 ] ; then
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
if test -r ${RUNDIR} ; then
    cd $RUNDIR
    FULLRUNDIR=`pwd`
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
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error removing old files: rc=$rc"
            exit 1
        fi
    fi

    echo "copying airports file, cities file, and readme file"
    cp ${ASH3DSHARE}/GlobalAirports_ewert.txt .
    cp ${ASH3DSHARE}/readme.pdf .
    ln -s ${ASH3DSHARE_PP}/world_cities.txt .
    cp ${ASH3DSHARE_PP}/VAAC* .
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error copying files: rc=$rc"
        exit 1
    fi

    echo "creating soft links to wind files"
    rm -f Wind_nc
    ln -s  ${WINDROOT} Wind_nc
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error linking ${WINDROOT}: rc=$rc"
        exit 1
    fi

    echo "running ash3dinput1_ac ${INFILE_SIMPLE} ${INFILE_PRELIM}"
    if test -r ${ASH3DBINDIR}/makeAsh3dinput1_ac ; then
        ${ASH3DBINDIR}/makeAsh3dinput1_ac ${INFILE_SIMPLE} ${INFILE_PRELIM} \
                                          ${LAST_DOWNLOADED}
      else
        echo "Error: ${ASH3DBINDIR}/makeAsh3dinput1_ac doesn't exist"
        exit 1
    fi
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running makeAsh3dinput1_ac: rc=$rc"
        exit 1
    fi

    if test -r ${INFILE_PRELIM} ; then
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
        echo "Error running Preliminary Ash3d run: rc=$rc"
        exit 1
    fi

    echo "zipping up kml files for preliminary Ash3d run"
    zip CloudLoad_prelim.kmz CloudLoad.kml

    if [ "$CLEANFILES" == "T" ]; then
        echo "removing kml files"
        rm -f *.kml AshArrivalTimes.txt
    fi

    echo "making ${INFILE_MAIN}"
    if test -r ${ASH3DBINDIR}/makeAsh3dinput2_ac ; then
        ${ASH3DBINDIR}/makeAsh3dinput2_ac ${INFILE_PRELIM} ${INFILE_MAIN}
      else
        echo "Error: ${ASH3DBINDIR}/makeAsh3dinput2_ac does not exist"
        exit 1
    fi
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running makeAsh3dinput2_ac: rc=$rc"
        exit 1
    fi

    if test -r ${INFILE_MAIN} ; then
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
if test -r ${USGSROOT}/bin/MetTraj_F; then
    echo "Calling runGFS_traj.sh"
    ${ASH3DSCRIPTDIR}/runGFS_traj.sh
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running runGFS_traj.sh: rc=$rc"
        exit 1
    fi
    if [ "$USECONTAINER" == "T" ]; then
        echo "  Running ${CONTAINEREXE} script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
                        ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_traj.sh 0
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh: rc=$rc"
            exit 1
        fi
      else
        echo "  Running installed script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
        ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 0
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running GFSVolc_to_gif_ac_traj.sh: rc=$rc"
            exit 1
        fi
    fi
  else
     echo "${USGSROOT}/bin/MetTraj_F does not exist.  Skipping trajectory runs."
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
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running main Ash3d run: rc=$rc"
    exit 1
fi

echo "zipping up kml files for main Ash3d run"
zip cloud_arrivaltimes_airports.kmz AshArrivalTimes.kml
rc=$((rc + $?))
zip cloud_arrivaltimes_hours.kmz    CloudArrivalTime.kml
rc=$((rc + $?))
zip CloudConcentration.kmz          CloudConcentration.kml
rc=$((rc + $?))
zip CloudHeight.kmz                 CloudHeight.kml
rc=$((rc + $?))
zip CloudLoad.kmz                   CloudLoad.kml
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error zipping files: rc=$rc"
    exit 1
fi

echo "running makeAshArrivalTimes_ac"
${ASH3DBINDIR}/makeAshArrivalTimes_ac
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running makeAshArrivalTimes_ac: rc=$rc"
    exit 1
fi

echo "moving AshArrivalTimes.txt to AshArrivalTimes_old.txt"
mv AshArrivalTimes.txt AshArrivalTimes_old.txt
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error renaming AshArrivalTimes.txt: rc=$rc"
    exit 1
fi
echo "overwriting AshArrivalTimes.txt"
mv AshArrivalTimes_ac.txt AshArrivalTimes.txt
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error renaming AshArrivalTimes_ac.txt: rc=$rc"
    exit 1
fi

#convert line endings from unix to dos
#sed 's/$/\r/' AshArrivalTimes.txt > AshArrivalTimes2.txt
#mv AshArrivalTimes2.txt AshArrivalTimes.txt
unix2dos AshArrivalTimes.txt
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running unix2dos AshArrivalTimes.txt: rc=$rc"
    exit 1
fi

if [ "$CLEANFILES" == "T" ]; then
    echo "removing extraneous files"
    rm -f *.kml
    rc=$((rc+$?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error removing kml files: rc=$rc"
        exit 1
    fi
fi
# Get time of completed Ash3d calculations
t1=`date -u`

echo "*******************************************************************************"
echo "POST-PROCESSING"
echo "*******************************************************************************"
echo "creating gif images of ash cloud"
# Generate gifs for the transient variables
#  0 = depothick
#  1 = ashcon_max
#  2 = cloud_height
#  3 = cloud_load
#    Cloud load is the default, so run that one first
#      Note:  the animate gif for this variable is copied to "cloud_animation.gif"
if [ "$USECONTAINER" == "T" ]; then
    ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
                    ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_tvar.sh 3
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh 3: rc=$rc"
        exit 1
    fi
  else
    echo "Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3"
    ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running GFSVolc_to_gif_ac_traj.sh 3: rc=$rc"
        exit 1
    fi
fi

# Recreating the trajectory plot (using previously calculated trajecties), but using
# the consistant basemap
if test -r ftraj1.dat; then
    if [ "$USECONTAINER" == "T" ]; then
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
                        ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_traj.sh 1
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh 1: rc=$rc"
            exit 1
        fi
      else
      ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 1
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running GFSVolc_to_gif_ac_traj.sh 1: rc=$rc"
            exit 1
        fi
    fi
  else
    echo "skipping trajectory plots: no traj files exist in this directory."
fi

if [[ $DASHBOARD_RUN == T* ]] ; then
    echo "Since we are exporting to the AVO dashboard, post-process for cloud_height"
    #    Now run it for cloud_height
    if [ "$USECONTAINER" == "T" ]; then
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
                        ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_tvar.sh 2
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh 2: rc=$rc"
            exit 1
        fi
      else
        echo "Calling GFSVolc_to_gif_tvar.sh 2"
        ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 2
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running GFSVolc_to_gif_ac_traj.sh 2: rc=$rc"
            exit 1
        fi
    fi
fi

if [[ $DASHBOARD_RUN == T* ]] ; then
    echo "Now creating gif images of the hysplit run"
    if [ "$USECONTAINER" == "T" ]; then
        echo "Running ${CONTAINEREXE} image of GFSVolc_to_gif_ac_hysplit.sh"
        #${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
        #                ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_hysplit.sh
        #rc=$((rc + $?))
        #if [[ "$rc" -gt 0 ]] ; then
        #    echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_hysplit.sh: rc=$rc"
        #    exit 1
        #fi
      else
        echo "Running GFSVolc_to_gif_ac_hysplit.sh"
        #${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_hysplit.sh
        #rc=$((rc + $?))
        #if [[ "$rc" -gt 0 ]] ; then
        #    echo "Error running GFSVolc_to_gif_ac_hysplit.sh: rc=$rc"
        #    exit 1
        #fi
    fi

    # HFS: add check here to verify GFS is being used, that
    #      puff is installed and puff windfiles are available
    # Run the puff model with the parameters in the simple input file
    if [ "$USECONTAINER" == "T" ]; then
        ${CONTAINEREXE} run --rm -v /data/WindFiles:/home/ash3d/www/html/puff/data:z \
                                 -v /home/ash3d/Ash3d/test/test_cloud:/run/user/1004/libpod/tmp:z \
                        puffapp /opt/USGS/Ash3d/bin/scripts/runGFS_puff.sh
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} puffapp runGFS_puff.sh: rc=$rc"
            exit 1
        fi
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z \
                        ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_puff.sh
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_puff.sh: rc=$rc"
            exit 1
        fi
      else
        echo "Calling runGFS_puff.sh"
        ${ASH3DSCRIPTDIR}/runGFS_puff.sh
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running runGFS_puff.sh: rc=$rc"
            exit 1
        fi
        echo "Now creating gif images of puff run"
        ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_puff.sh
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running GFSVolc_to_gif_ac_puff.sh: rc=$rc"
            exit 1
        fi
    fi
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
if [[ "$rc" -gt 0 ]] ; then
    echo "Error copying AshArrivalTimes.txt: rc=$rc"
    exit 1
fi

#sed 's/$/\r/' ${INFILE_MAIN} > ${INFILE_MAIN}2
#mv ${INFILE_MAIN}2 ${INFILE_MAIN}
unix2dos -m ${INFILE_MAIN}
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running unix2dos -m ${INFILE_MAIN}: rc=$rc"
    exit 1
fi
echo "flipping and renaming Ash3d.lst"
unix2dos Ash3d.lst
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running unix2dos Ash3d.lst: rc=$rc"
    exit 1
fi
mv Ash3d.lst ash3d_runlog.txt

zip $ZIPNAME.zip *UTC*.gif \
                 ash3d_input.txt ash3d_runlog.txt \
                 cloud_animation.gif \
                 cloud_arrivaltimes_airports.kmz cloud_arrivaltimes_airports.txt \
                 CloudConcentration.kmz CloudHeight.kmz CloudLoad.kmz
rc=$((rc+$?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error creating final zip file: rc=$rc"
    exit 1
fi

#zip $ZIPNAME.zip *UTC*.gif cloud_animation.gif cloud_arrivaltimes_airports.txt ${INFILE_MAIN} \
#    cloud_arrivaltimes_airports.kmz cloud_arrivaltimes_hours.kmz CloudConcentration.kmz CloudHeight.kmz \
#    CloudLoad.kmz readme.pdf *rajector*gif ash3d_runlog.txt
if test -r ftraj1.dat; then
    #zip -a $ZIPNAME.zip traj*.dat
    zip $ZIPNAME.zip traj*.dat
fi
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error adding trajectory files to zip file: rc=$rc"
    exit 1
fi

echo "removing extraneous files"
rm -f tmp1.txt tmp2.txt
rm -f *.cpt caption.txt fort.18 current_time.txt dep_thick.txt  Temp.epsi cities.xy
#rm -f world_cities.txt test.txt

if [[ $rc -ne 0 ]]; then
    echo "$rc errors detected."
  else
    echo "successful completion"
fi

t2=`date -u`
echo "started run at          :  $t0"
echo "calculations ended at   :  $t1"
echo "post-processing ended at:  $t2"
echo "all done with run $4"

exit $rc

