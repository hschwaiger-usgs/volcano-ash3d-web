#!/bin/bash

# $1 will be the java thread id, ash3d client runs have ash3dclient-thread-{thread_id} as a parameter to the run.

LOGFILE=/webdata/int-vsc-ash.wr.usgs.gov/runs/killrun.log
rc=0

cat /dev/null > $LOGFILE

echo "-" >> $LOGFILE
echo "-" >> $LOGFILE
echo "-" >> $LOGFILE
echo "-" >> $LOGFILE
echo `date` >> $LOGFILE

pid=`pgrep -f ash3dclient-thread-${1}`

echo "-" >> $LOGFILE
echo "-- ps for ash3dclient-thread-${1}" >> $LOGFILE
ps -ef | grep ash3dclient-thread-${1} | grep -v grep >> $LOGFILE
echo "-" >> $LOGFILE
echo "-- ps for $pid" >> $LOGFILE
ps -ef | grep $pid | grep -v grep >> $LOGFILE
echo "-" >> $LOGFILE

echo "Killing pid $pid " >> $LOGFILE

pkill -P $pid >> $LOGFILE
kill -9 $pid >> $LOGFILE

echo "$pid Killed!!!" >> $LOGFILE

echo "-" >> $LOGFILE
echo "-- ps for ash3dclient-thread-${1}" >> $LOGFILE
ps -ef | grep ash3dclient-thread-${1} | grep -v grep >> $LOGFILE
echo "-" >> $LOGFILE
echo "-- ps for $pid" >> $LOGFILE
ps -ef | grep $pid | grep -v grep >> $LOGFILE
echo "-" >> $LOGFILE

echo `date` >> $LOGFILE

