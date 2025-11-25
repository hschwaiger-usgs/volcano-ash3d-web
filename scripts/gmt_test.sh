

#
SLABl="[gmt_test.sh]: "            # Script label prepended on all echo to stdout (local)
#

# We need to know if we must prefix all gmt commands with 'gmt', as required by versions >5
GMTv=5
type gmt >/dev/null 2>&1 || { echo >&2 "Command 'gmt' not found.  Assuming GMTv4."; GMTv=4;}
if [ $GMTv -eq 4 ] ; then
    echo "${SLABl} GMT 4 is no longer supported."
    echo "${SLABl} Please update to GMT 5 or 6"
    exit 1
 else
    GMTv=`gmt --version | cut -c1`
fi
# vers.  0   1   2   3   4(deprecated) 5                6
GMTpre=("-" "-" "-" "-" " "           "gmt "           "gmt ")
GMTelp=("-" "-" "-" "-" "ELLIPSOID"   "PROJ_ELLIPSOID" "PROJ_ELLIPSOID")
GMTnan=("-" "-" "-" "-" "-Ts"         "-Q"             "-Q")
GMTrgr=("-" "-" "-" "-" "grdreformat" "grdconvert"     "grdconvert")
GMTpen=("-" "-" "-" "-" "/"           ","              ",")
echo "${SLABl} GMT version = ${GMTv}: prefix = ${GMTpre[GMTv]}"
