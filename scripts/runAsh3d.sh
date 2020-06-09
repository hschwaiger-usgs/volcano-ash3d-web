#!/bin/bash

rc=0
echo "checking input arguments"
if [ -z $1 ]
then
	echo "Error: you must specify an input directory containing an ash3d input file."
	exit 1
fi

if [ -z $2 ]
then
	echo "Error: you must specify a zip file name"
	exit 1
else
	ZIPNAME=$2
fi

cd $1
if [[ $? -ne 0 ]]; then
	echo "Error changing to run directory"
	rc=$((rc + 1))
	exit $rc
fi

#
rm -f etopo.nc
ln -s /opt/Ash3d/data/topo/etopo.nc etopo.nc

#
rm -f Wind_nc
ln -s /data/WindFiles Wind_nc
if [[ $? -ne 0 ]]; then
	echo "Error creating symbolic link to WindFiles"
	rc=$((rc + 1))
	exit $rc
fi

cp /opt/USGS/Ash3d/share/GlobalAirports_ewert.txt .
echo "copying readme.pdf"
cp /opt/USGS/Ash3d/share/readme.pdf .

#
# remove old files if present, may be remaining if this is a manual run for testing.
#
rm -f *.kmz AshArrivalTimes.txt           
rm -f *.gif

#
# command-line command that runs Ash3d
#
/opt/USGS/Ash3d/bin/Ash3d ash3d_input.inp
if [[ $? -ne 0 ]]; then
	echo "Error running the Ash3d Simulation"
	rc=$((rc + 1))
	exit $rc
fi


svn info /home/ash3d/Ash3d/wd2/ash3drepository_new >> Ash3d.lst
echo "getting ash3d version information"
if [[ $? -ne 0 ]]; then
	echo "Error getting version information from subversion"
	rc=$((rc + 1))
fi
echo "rc=$rc"

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
gsbins=`ncdump -h 3d_tephra_fall.nc | grep "gs =" | cut -c6-8`
echo "gsbins="$gsbins

export NETCDFHOME=/home/ash3d/netcdf/netcdf-3.6.3
export PATH=/usr/local/bin:/home/ash3d/GMT/GMT4.5.9/bin:$PATH
export MANPATH=/usr/local/man:/home/ash3d/GMT/GMT4.5.9/man:$MANPATH

if test "$gsbins" -eq 1
  then
    echo "creating gif images of ash cloud"
    /opt/USGS/Ash3d/bin/ash3dweb_scripts/GFSVolc_to_gif_ac.sh
  else
    echo "creating gif images of deposit"
    /opt/USGS/Ash3d/bin/ash3dweb_scripts/GFSVolc_to_gif_dp.sh
fi

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

