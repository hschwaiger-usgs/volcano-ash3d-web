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
echo "running runAsh3d.sh with parameters:"
echo "  run directory           = $1"
echo "  zip file name           = $2"
echo "  Dashboard case (T or F) = $3"
echo "  Run ID                  = $4"
echo "  Java Thread ID          = $5"
echo `date`
echo "------------------------------------------------------------"
CLEANFILES="T"
USECONTAINER="T"
CONTAINEREXE="podman"

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
INFILE_MAIN="ash3d_input.inp"                 #input file used for main Ash3d run

echo "checking input arguments"
if [ -z $1 ]
then
    echo "Error: you must specify an input directory containing an ash3d input file."
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
    ZIPNAME=$2
fi

echo "changing directories to ${RUNDIR}"
if test -r ${RUNDIR}
then
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

#
#rm -f etopo.nc
#ln -s ${USGSROOT}/data/Topo/etopo.nc etopo.nc

#
#rm -f Wind_nc
#ln -s /data/WindFiles Wind_nc
#if [[ $? -ne 0 ]]; then
#	echo "Error creating symbolic link to WindFiles"
#	rc=$((rc + 1))
#	exit $rc
#fi

#cp /opt/USGS/Ash3d/share/GlobalAirports_ewert.txt .
#echo "copying readme.pdf"
#cp /opt/USGS/Ash3d/share/readme.pdf .

echo "copying airports file, cities file, and readme file"
cp ${ASH3DSHARE}/GlobalAirports_ewert.txt .
cp ${ASH3DSHARE}/readme.pdf .
ln -s ${ASH3DSHARE_PP}/world_cities.txt .
cp ${ASH3DSHARE_PP}/VAAC* .
rc=$((rc + $?))
echo "rc=$rc"

echo "creating soft links to wind files"
rm Wind_nc
ln -s  ${WINDROOT} Wind_nc
rc=$((rc + $?))
echo "rc=$rc"

#
# remove old files if present, may be remaining if this is a manual run for testing.
#
rm -f *.kmz AshArrivalTimes.txt           
rm -f *.gif

#
# command-line command that runs Ash3d
#
echo "*******************************************************************************"
echo "*******************************************************************************"
echo "**********                  Advanced Ash3d run                       **********"
echo "*******************************************************************************"
echo "*******************************************************************************"
${ASH3DBINDIR}/Ash3d ${INFILE_MAIN} | tee ashlog_main.txt
echo "-------------------------------------------------------------------------------"
echo "-------------------------------------------------------------------------------"
echo "----------             Completed  Advanced Ash3d run                 ----------"
echo "-------------------------------------------------------------------------------"

if [[ $? -ne 0 ]]; then
	echo "Error running the Ash3d Simulation"
	rc=$((rc + 1))
	exit $rc
fi

#svn info /home/ash3d/Ash3d/wd2/ash3drepository_new >> Ash3d.lst
#echo "getting ash3d version information"
#if [[ $? -ne 0 ]]; then
#	echo "Error getting version information from subversion"
#	rc=$((rc + 1))
#fi
#echo "rc=$rc"

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
echo "rc=$rc"

#
#
#
echo "unix2dos AshArrivalTimes.txt"
unix2dos AshArrivalTimes.txt

echo "converting and renaming Ash3d.lst"
unix2dos Ash3d.lst
mv Ash3d.lst ash3d_runlog.txt

#
# checking for number of gs bins.  If gsbins=1, it's a cloud simulation.  if gsbins>1,
# it's a deposit simulation. (COULD BE BOTH THOUGH, HOW TO HANDLE??????)
#
gsbins=`ncdump -h 3d_tephra_fall.nc | grep "bn =" | cut -c6-8`
echo "gsbins="$gsbins

#export NETCDFHOME=/home/ash3d/netcdf/netcdf-3.6.3
#export PATH=/usr/local/bin:/home/ash3d/GMT/GMT4.5.9/bin:$PATH
#export MANPATH=/usr/local/man:/home/ash3d/GMT/GMT4.5.9/man:$MANPATH

#if test "$gsbins" -eq 1
#  then
    echo "creating gif images of ash cloud"
    # Generate gifs for the transient variables
    #  0 = depothick
    #  1 = ashcon_max
    #  2 = cloud_height
    #  3 = cloud_load
    #    Cloud load is the default, so run that one first
    #      Note:  the animate gif for this variable is copied to "cloud_animation.gif"
    if [ "$USECONTAINER" == "T" ]; then
      ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_tvar.sh 3
    else
      echo "Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3"
      ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_tvar.sh 3
    fi
#  else
    echo "creating gif images of deposit"
    if [ "$USECONTAINER" == "T" ]; then
      ${CONTAINEREXE} run --rm -v ${FULLRUNDIR}:/run/user/1004/libpod/tmp:z ash3dpp /opt/USGS/Ash3d/bin/scripts/GFSVolc_to_gif_dp.sh
    else
      echo "Calling ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh"
      ${ASH3DSCRIPTDIR}/GFSVolc_to_gif_dp.sh
    fi
#fi

#
# Delete extra files
#
echo "deleting extra files"
rm -f temp* var.txt volc.txt world_cities.txt caption.txt legend_positions_dp.txt
rm -f map_range.txt CloudBottom.*

#
# Add all files to ash3d.zip
#
#find . -type f -exec zip $ZIPNAME.zip {} \;
echo "making zip file"
zip $ZIPNAME.zip *.kmz *.gif *.inp *.pdf AshArrivalTimes.txt 3d_tephra_fall.nc ash3d_runlog.txt
rc=$((rc + $?))
echo "rc=$rc"
if [[ $? -ne 0 ]]; then
	echo "Error creating final zip file."
	rc=$((rc + 1))
	exit $rc
fi

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
fi

#rm Wind_nc

exit $rc

