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

#      Usage: runAsh3d_ac.sh INPUT_PATH, ZIP_NAME, DASHBOARD_IND (T or F), RUN_ID, JAVA_THREAD_ID
#       e.g. /data/www/ash3d-api/htdocs/ash3druns/runAsh3d.sh          \
#               /data/www/ash3d-api/htdocs/ash3druns/ash3d_run_334738/ \
#               ash3d_adv_test_adv_20201015-23:07:46z                  \
#               F                                                      \
#               334738                                                 \
#               ash3dclient-thread-370

echo "------------------------------------------------------------"
echo "running runAsh3d.sh with parameters:"
echo "  run directory           = $1"
echo "  zip file name           = $2"
echo "  Dashboard case (T or F) = $3"
echo "  Run ID                  = $4"
echo "  Java thread ID          = $5"
echo `date`
echo "------------------------------------------------------------"
# specify run type here: ADV = Advanced
#                        DEP = Deposit
#                        ACL = Ash Cloud
RUNTYPE="ADV"
CLEANFILES="T"
USECONTAINER="T"
CONTAINEREXE="podman"
CONTAINERRUNDIR="/run/user/1004/libpod/tmp"

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
GFSDATAHOME="${WINDROOT}/gfs"

ASH3DBINDIR="${ASH3DROOT}/bin"
ASH3DSCRIPTDIR="${ASH3DROOT}/bin/scripts"
ASH3DSHARE="$ASH3DROOT/share"
ASH3DSHARE_PP="${ASH3DSHARE}/post_proc"

#Determine last downloaded windfile
LAST_DOWNLOADED=`cat ${WINDROOT}/gfs/last_downloaded.txt`
echo "last downloaded windfile =${LAST_DOWNLOADED}"

INFILE_PRELIM="ash3d_input_prelim.inp"             #input file used for preliminary Ash3d run
INFILE_MAIN="ash3d_input.inp"                 #input file used for main Ash3d run

echo "checking input arguments"
if [ -z $1 ] ; then
    echo "Error: you must specify an input directory containing the file ash3d_input.inp."
    echo "Usage: runAsh3d.sh rundir zipname dash_flag run_ID java_thread_ID"
    exit 1
  else
    RUNDIR=$1
    echo "run directory is $1"
fi

if [ -z $2 ] ; then
    echo "Error: you must specify a zip file name"
    exit 1
  else
    ZIPNAME=$2
fi

if [ -z $3 ] ; then
    echo "Dashboard flag not set.  Setting to 'F'"
    DASHBOARD_RUN='F'
  else
    DASHBOARD_RUN=$3
fi

if [ -z $4 ] ; then
    echo "Run ID not set"
    RUNID="000000"
  else
    RUNID=$4
fi

if [ -z $5 ] ; then
    echo "Java thread ID not set"
    JAVAID='000'
  else
    JAVAID=$5
fi

#Assign default filenames and directory names and variables to be plotted
# default variable netcdfnames
nVARS=8
var_n=(depothick ashcon_max cloud_height cloud_load depotime depothick depothick ash_arrival_time)
if [ "$RUNTYPE" == "ADV"  ] ; then
    if test -r ${ASH3DBINDIR}/Ash3d_res ; then
        echo "Using Ash3d_res for advanced run"
        ASH3DEXEC="${ASH3DBINDIR}/Ash3d_res"
      else
        ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
    fi
    MAKEINPUT1="makeAsh3dinput1_ac"
    MAKEINPUT2="makeAsh3dinput2_ac"
    INFILE_SIMPLE="ash3d_input_simp.inp"
      # For advanced runs, plot all variables
    plotvars=(1 1 1 1 1 1 1 1)
  elif [ "$RUNTYPE" == "DEP"  ] ; then
    ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
    MAKEINPUT1="makeAsh3dinput1_dp"
    MAKEINPUT2="makeAsh3dinput2_dp"
    INFILE_SIMPLE="ash3d_input_dp.inp"
      # For deposit runs, plot final deposit (inches and mm)
    plotvars=(0 0 0 0 0 1 1 0)
  elif [ "$RUNTYPE" == "ACL"  ] ; then
    ASH3DEXEC="${ASH3DBINDIR}/Ash3d"
    MAKEINPUT1="makeAsh3dinput1_ac"
    MAKEINPUT2="makeAsh3dinput2_ac"
    INFILE_SIMPLE="ash3d_input_ac.inp"
      # For cloud runs, plot cloud_height and cloud_load
    if [[ $DASHBOARD_RUN == T* ]] ; then
        plotvars=(0 0 1 1 0 0 0 0)
      else
        plotvars=(0 0 0 1 0 0 0 0)
    fi
fi

echo "changing directories to ${RUNDIR}"
if test -r ${RUNDIR} ; then
    cd $RUNDIR
    FULLRUNDIR=`pwd`
  else
    echo "Error: Directory ${RUNDIR} does not exist."
    exit 1
fi
if [[ $? -ne 0 ]]; then
    rc=$((rc + 1))
fi

if [ "$CLEANFILES" == "T" ]; then
    echo "removing old input & output files"
    rm -f *.gif *.kmz *.zip ${INFILE_PRELIM} ${INFILE_MAIN} *.txt cities.xy *.dat *.pdf 3d_tephra_fall.nc
    rm -f *.lst Wind_nc *.xyz *.png depTS_*.gnu dp.* ash3d_runlog.txt
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error removing old files: rc=$rc"
        exit 1
    fi
fi

echo "copying airports file, cities file, and readme file"
cp ${ASH3DSHARE}/GlobalAirports_ewert.txt .
cp ${ASH3DSHARE}/readme.pdf .
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

echo "_______________________________________________________________________________"
echo ">>>>>>>>>>>>>>>>>          Setting up preliminary run           <<<<<<<<<<<<<<<"
echo "_______________________________________________________________________________"
# First, generate the full input file based on the mini-web-version, if needed
echo "running ${MAKEINPUT1} ${INFILE_SIMPLE} ${INFILE_PRELIM}"
if test -r ${ASH3DBINDIR}/${MAKEINPUT1} ; then
    ${ASH3DBINDIR}/${MAKEINPUT1} ${INFILE_SIMPLE} ${INFILE_PRELIM} \
                                 ${LAST_DOWNLOADED}
  else
    echo "Error: ${ASH3DBINDIR}/${MAKEINPUT1} doesn't exist"
    exit 1
fi
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running ${MAKEINPUT1}: rc=$rc"
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
# The default log file writen by Ash3d is Ash3d.lst, but we will capture all stdout to
# an alternative log file.  This initial 10x10 run will produce output files that will
# be processed to determine the geometry of the subsequent full run.
# For deposit runs, ${INFILE_PRELIM} and DepositFile_____final.dat are needed.
# For cloud runs, ${INFILE_PRELIM} and CloudLoad_*hrs.dat are needed.
${ASH3DEXEC} ${INFILE_PRELIM} | tee ashlog_prelim.txt
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
if test -r Deposit.kml; then
    zip Deposit_prelim.kmz Deposit.kml
fi
if test -r CloudLoad.kml; then
    zip CloudLoad_prelim.kmz CloudLoad.kml
fi

if [ "$CLEANFILES" == "T" ]; then
    echo "removing kml files"
    rm -f *.kml AshArrivalTimes.txt
fi

echo "_______________________________________________________________________________"
echo ">>>>>>>>>>>>>>>>>              Setting up main run              <<<<<<<<<<<<<<<"
echo "_______________________________________________________________________________"
echo "making ${INFILE_MAIN}"
if [ "$RUNTYPE" == "DEP" ] || [ "$RUNTYPE" == "ACL" ]  ; then
    if test -r ${ASH3DBINDIR}/${MAKEINPUT2} ; then
        ${ASH3DBINDIR}/${MAKEINPUT2} ${INFILE_PRELIM} ${INFILE_MAIN}
      else
        echo "Error: ${ASH3DBINDIR}/${MAKEINPUT2} does not exist"
        exit 1
    fi
else
    cp ash3d_input_adv.inp ${INFILE_MAIN}
fi
rc=$((rc + $?))
if [[ "$rc" -gt 0 ]] ; then
    echo "Error running ${MAKEINPUT2}: rc=$rc"
    exit 1
fi
if test -r ${INFILE_MAIN} ; then
    echo "${INFILE_MAIN} created okay"
  else
    echo "Error: ${INFILE_MAIN} not created"
    exit 1
fi

if [ "$CLEANFILES" == "T" ]; then
    echo "removing .dat file, preliminary ash3d input file"
    rm -f depTS*.dat depTS*.gnu progress.txt
fi

# Run the trajectory model with the parameters in the simple input file
echo "-------------------------------------------------------------------------------"
if test -r ${USGSROOT}/bin/MetTraj_F; then
    echo "Calling runGFS_traj.sh"
    # This script reads the simplified input file, runs MetTraj_F and writes ftraj*.dat
    ${ASH3DSCRIPTDIR}/runGFS_traj.sh
    rc=$((rc + $?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running runGFS_traj.sh: rc=$rc"
        exit 1
    fi
    # Now post-processing ftraj*.dat
    # The map information is pulled from 3d_tephra_fall.nc from the preliminary run
    if [ "$USECONTAINER" == "T" ]; then
        echo "  Running ${CONTAINEREXE} script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                        ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 0 ${CONTAINERRUNDIR}
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
echo "-------------------------------------------------------------------------------"

echo "*******************************************************************************"
echo "*******************************************************************************"
echo "**********                   Main Ash3d run                          **********"
echo "*******************************************************************************"
echo "*******************************************************************************"
# Again, the default log file writen by Ash3d is Ash3d.lst, but we will capture all stdout to
# an alternative log file.  
${ASH3DEXEC} ${INFILE_MAIN} | tee ashlog_main.txt
# This will produce the following output files writen directly by Ash3d:
#  3d_tephra_fall.nc
#  Ash3d.lst
#  ashlog_main.txt
#  AshArrivalTimes.kml
#  CloudArrivalTime.kml
#  CloudBottom.kml
#  CloudConcentration.kml
#  CloudHeight.kml
#  CloudLoad.kml
#  AshArrivalTimes.txt
#  DepositFile_____final.dat
#  DepositArrivalTime.kmz
#  Deposit.kmz
#  Deposit_NWS.kmz
#  ashfall_arrivaltimes_airports.txt
#  depTS_000*.gnu
#  depTS_000*.dat
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

if test -r depTS_0001.gnu; then
   echo "using gnuplot to plot deposit thickness vs. time"
   for i in `ls -1 depTS_*.gnu`
   do
     gnuplot ${i}
   done
fi

#
# Zip all kml files, make kmz files
#
echo "zipping up kml files"
for file in *.kml
do
    IFS='.'
    array=( $file )
    zip -r "${array[0]}".kmz "$file"
    if [[ $? -ne 0 ]]; then
        echo "Error zipping file $file"
        rc=$((rc + 1))
    fi
    rm "$file"
    if [[ $? -ne 0 ]]; then
        echo "Error removing extra file $file after zip"
        rc=$((rc + 1))
    fi
done

echo "unix2dos AshArrivalTimes.txt"
if [ "$RUNTYPE" == "ADV"  ] ; then
    unix2dos AshArrivalTimes.txt
  elif [ "$RUNTYPE" == "DEP"  ] ; then
    echo "First stripping AshArrivalTimes.txt of cloud data"
    ${ASH3DBINDIR}/makeAshArrivalTimes_dp
    rc=$((rc+$?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running makeAshArrivalTimes_dp: rc=$rc"
        exit 1
    fi
    # copy output of makeAshArrivalTimes_dp back to AshArrivalTimes.txt
    mv AshArrivalTimes_dp.txt AshArrivalTimes.txt
    unix2dos AshArrivalTimes.txt
    cp AshArrivalTimes.txt ashfall_arrivaltimes_airports.txt
  elif [ "$RUNTYPE" == "ACL"  ] ; then
    echo "First stripping AshArrivalTimes.txt of deposit data"
    ${ASH3DBINDIR}/makeAshArrivalTimes_ac
    rc=$((rc+$?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running makeAshArrivalTimes_ac: rc=$rc"
        exit 1
    fi
    # copy output of makeAshArrivalTimes_ac back to AshArrivalTimes.txt
    mv AshArrivalTimes_ac.txt AshArrivalTimes.txt
    unix2dos AshArrivalTimes.txt
fi

# Get time of completed Ash3d calculations
t1=`date -u`

echo "*******************************************************************************"
echo "POST-PROCESSING"
echo "*******************************************************************************"
echo "Creating gif images from the standard Ash3d output file."
for (( i=0;i<${nVARS};i++))
do
    if [ "${plotvars[i]}" == "1" ]; then
        if [ "$USECONTAINER" == "T" ]; then
            #echo "  Running ${CONTAINEREXE} script (GFSVolc_to_gif_tvar.sh) to process cloud_load results."
            #echo "${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3 ${CONTAINERRUNDIR}"
            #${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
            #                ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3 ${CONTAINERRUNDIR}
            echo "  Running ${CONTAINEREXE} script (GMT_Ash3d_to_gif.sh) to process ${var_n[i]} results."
            echo "${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z ash3dpp ${ASH3DSCRIPTDIR}/GMT_Ash3d_to_gif.sh $i ${CONTAINERRUNDIR}"
            ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                            ash3dpp ${ASH3DSCRIPTDIR}/GMT_Ash3d_to_gif.sh $i ${CONTAINERRUNDIR}
            rc=$((rc + $?))
            if [[ "$rc" -gt 0 ]] ; then
                #echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_tvar.sh $i: rc=$rc"
                echo "Error running ${CONTAINEREXE} ash3dpp GMT_Ash3d_to_gif.sh $i: rc=$rc"
                exit 1
            fi
          else
            #echo "  Running installed script ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh $i"
            #${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh $i
            echo "  Running installed script ${ASH3DSCRIPTDIR}/GMT_Ash3d_to_gif.sh $i"
            ${ASH3DSCRIPTDIR}/GMT_Ash3d_to_gif.sh $i
            rc=$((rc + $?))
            if [[ "$rc" -gt 0 ]] ; then
                #echo "Error running GFSVolc_to_gif_tvar.sh $i: rc=$rc"
                echo "Error running GMT_Ash3d_to_gif.sh $i: rc=$rc"
                exit 1
            fi
        fi
    fi
done

if test -r "deposit_thickness_inches.gif"; then
    # Web-interface expects the English units to be named deposit.gif
    cp deposit_thickness_inches.gif deposit.gif
fi
if test -r "DepositFile_____final.dat"; then
    mv DepositFile_____final.dat deposit_thickness_mm.txt
    unix2dos deposit_thickness_mm.txt
    rc=$((rc+$?))
    if [[ "$rc" -gt 0 ]] ; then
        echo "Error running unix2dos deposit_thickness_mm.txt: rc=$rc"
        exit 1
    fi
fi

# Recreating the trajectory plot (using previously calculated trajecties), but using
# the consistant basemap
if test -r ftraj1.dat; then
    if [ "$USECONTAINER" == "T" ]; then
       echo "  Running ${CONTAINEREXE} script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
       ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                        ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_traj.sh 1 ${CONTAINERRUNDIR}
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_traj.sh 1: rc=$rc"
            exit 1
        fi
      else
        echo "  Running installed script (GFSVolc_to_gif_ac_traj.sh) to process traj results."
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

echo "-------------------------------------------------------------------------------"
echo "Checking if we need to process extra output products for dashboard cases (Hysplit,puff)"
if [[ $DASHBOARD_RUN == T* ]] ; then
    echo "Now creating gif images of the hysplit run"
    if [ "$USECONTAINER" == "T" ]; then
        echo "Running ${CONTAINEREXE} image of GFSVolc_to_gif_ac_hysplit.sh"
        #${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
        #                ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_ac_hysplit.sh ${CONTAINERRUNDIR}
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
        echo "  Running ${CONTAINEREXE} script (runGFS_puff.sh) for puff" 
        ${CONTAINEREXE} run --rm -v /data/WindFiles:/home/ash3d/www/html/puff/data:z \
                                 -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                        puffapp ${ASH3DSCRIPTDIR}/runGFS_puff.sh ${CONTAINERRUNDIR}
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} puffapp runGFS_puff.sh: rc=$rc"
            exit 1
        fi
        echo "  Running ${CONTAINEREXE} script (GFSVolc_to_gif_ac_puff.sh) for puff results."
        ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:${CONTAINERRUNDIR}:z \
                        ash3dpp ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_puff.sh ${CONTAINERRUNDIR}
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running ${CONTAINEREXE} ash3dpp GFSVolc_to_gif_ac_puff.sh: rc=$rc"
            exit 1
        fi
      else
        echo "Calling runGFS_puff.sh"
        ${ASH3DSCRIPTDIR}/runGFS_puff.sh
        rc=$((rc + $?))
        if [[ "$rc" -gt 0 ]] ; then
            echo "Error running runGFS_puff.sh: rc=$rc"
            echo "Reseting error count and moving on"
            rc=0
          else
            echo "Now creating gif images of puff run"
            ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_ac_puff.sh
            rc=$((rc + $?))
            if [[ "$rc" -gt 0 ]] ; then
                echo "Error running GFSVolc_to_gif_ac_puff.sh: rc=$rc"
            fi
        fi
    fi
fi
echo "Finished supplemental output for AVO dashboard, if needed."
echo "-------------------------------------------------------------------------------"

#
# Delete extra files from Ash3d run
# Post-processing extra files should be deleted in the post-processing script
#
if [ "$CLEANFILES" == "T" ]; then
    echo "deleting extra files"
    rm -f progress.txt Ash3d.lst GlobalAirports_ewert.txt
    rm -f Wind_nc
fi

echo "Making zip file"

nout_files=28
out_files=("${INFILE_MAIN}"         \
"ashlog_main.txt"                   \
"ash_arrivaltimes_airports.kmz"     \
"ashfall_arrivaltimes_airports.txt" \
"ashfall_arrivaltimes_hours.kmz"    \
"DepositArrivalTime.kmz"            \
"Deposit_NWS.kmz"                   \
"deposit_thickness_inches.gif"      \
"deposit_thickness_inches.kmz"      \
"deposit_thickness_mm.gif"          \
"Deposit.kmz"                       \
"deposit_thickness_mm.kmz"          \
"deposit_thickness_mm.txt"          \
"dp_shp.zip"                        \
"dp_mm_shp.zip"                     \
"trajectory_1.gif"                  \
"cloud_animation.gif"               \
"cloud_arrivaltimes_airports.kmz"   \
"cloud_arrivaltimes_airports.txt"   \
"CloudConcentration.kmz"            \
"CloudHeight.kmz"                   \
"CloudLoad.kmz"                     \
"AshArrivalTimes.kmz"               \
"CloudArrivalTime.kmz"              \
"CloudBottom.kmz"                   \
"AshArrivalTimes.txt"               \
"ftraj1.dat"                        \
"readme.pdf")

for (( i=0;i<${nout_files};i++))
do
    echo "Testing for ${out_files[i]} ($i/$nout_files)"
    if test -r "${out_files[i]}"; then
        echo "   Found ${out_files[i]}"
        if [ "${out_files[i]}" == "ftraj1.dat" ]; then
            echo "   Adding trajectory data to zip file."
            zip $ZIPNAME.zip ftraj*dat
          elif [ "${out_files[i]}" == "cloud_animation.gif" ]; then
            echo "   Adding animations to zip file."
            zip $ZIPNAME.zip *_animation.gif
            zip $ZIPNAME.zip *UTC*.gif
          else
            echo "   Adding ${out_files[i]} to zip file."
            zip $ZIPNAME.zip "${out_files[i]}"
        fi
      else
        echo "   Did not find ${out_files[i]}"
    fi
done

#
# Make all files writeable by everyone so web process can delete as needed.
#
echo "making files writeable"
find . -type f -exec chmod 666 {} \;
if [[ $? -ne 0 ]]; then
    echo "Error making file types readable for everyone."
    rc=$((rc + 1))
    exit $rc
fi

#
# Finished
#
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

