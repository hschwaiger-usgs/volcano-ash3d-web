#!/bin/bash
INFILE_FULL=$1
INFILE_SIMPLE="ash3d_input_simp.inp"
LNname=78
LNcoord=80
LNerup=100
LNemtime=164    # This assumues 1 eruption
VLC=`sed -n ${LNname}p  ${INFILE_FULL} | cut -c1-15`
LON=`sed -n ${LNcoord}p ${INFILE_FULL} | cut -d' ' -f1`
LAT=`sed -n ${LNcoord}p ${INFILE_FULL} | cut -d' ' -f2`
ELV=`sed -n ${LNcoord}p ${INFILE_FULL} | cut -d' ' -f3`
ELV="0.0"

YY=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f1`
MM=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f2`
DD=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f3`
HH=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f4`
DR=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f5`
PH=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f6`
EV=`sed -n ${LNerup}p ${INFILE_FULL} | cut -d' ' -f7`

ST=`sed -n ${LNemtime}p ${INFILE_FULL} | cut -d' ' -f1`


echo "${VLC}"                   > $INFILE_SIMPLE
echo "${LON} ${LAT}"           >> $INFILE_SIMPLE
echo "${ELV}"                  >> $INFILE_SIMPLE
echo "${PH} ${DR} ${ST} ${EV}" >> $INFILE_SIMPLE
echo "${YY} ${MM} ${DD} ${HH}" >> $INFILE_SIMPLE



