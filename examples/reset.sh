#!/bin/bash
WRKDIR=/home/hschwaiger/work/USGS/Ash3d/webruns

WRKDIR=/home/ash3d/Programs/GIT/Ash3d_web/examples
echo "$CWD"

cd ${WRKDIR}/test_cloud
rm -f *.grd *.xyz *.lev *cpt Ash3d.lst
rm -f ash3d*inp 3d_tephra_fall.nc *.gif *.txt *.zip *.xy *.kmz *.dat gmt* readme.pdf Wind_nc world_cities.txt *.png
cp ${WRKDIR}/ash3d_input_ac.inp .

cd ${WRKDIR}/test_deposit
rm -f *.grd *.xyz *.lev *cpt Ash3d.lst
rm -f ash3d*inp 3d_tephra_fall.nc *.gif *.txt *.zip *.xy *.kmz *.dat gmt* readme.pdf Wind_nc world_cities.txt *.png *.gnu dp*
cp ${WRKDIR}/ash3d_input_dp.inp .

