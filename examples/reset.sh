#!/bin/bash

#WRKDIR=/home/ash3d/Programs/GIT/Ash3d_web/examples
WRKDIR=$PWD

if [ -d "$WRKDIR" ] 
then
    echo "Cleaning files from test_cloud"
    cd ${WRKDIR}/test_cloud
    rm -f *.grd *.xyz *.lev *cpt Ash3d.lst
    rm -f ash3d*inp 3d_tephra_fall.nc *.gif *.txt *.zip *.xy *.kmz *.dat gmt* readme.pdf Wind_nc world_cities.txt *.png
    cp ${WRKDIR}/ash3d_input_ac.inp .
    echo "Cleaning files from test_deposit"
    cd ${WRKDIR}/test_deposit
    rm -f *.grd *.xyz *.lev *cpt Ash3d.lst
    rm -f ash3d*inp 3d_tephra_fall.nc *.gif *.txt *.zip *.xy *.kmz *.dat gmt* readme.pdf Wind_nc world_cities.txt *.png *.gnu dp*
    cp ${WRKDIR}/ash3d_input_dp.inp .
else
    echo "Error: $WRKDIR does not exists."
fi
