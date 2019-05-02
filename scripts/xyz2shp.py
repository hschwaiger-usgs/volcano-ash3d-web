# http://gis.stackexchange.com/questions/898/convert-xy-points-to-a-line
import dircache, os
import glob
import csv
import subprocess                 # For issuing commands to the OS.
from datetime import datetime

try:
    from osgeo import ogr
except ImportError:
    import ogr
try:
    from osgeo import osr
except ImportError:
    import osr


# Get name of volcano
volcnamefid = open('volc.txt', 'r')
volcnameEOF = volcnamefid.readline()
volcname = volcnameEOF[0:len(volcnameEOF)-1]
volcnamefid.close()
volcname.strip()

# Get variable to plot
varnamefid = open('var.txt', 'r')
varnameEOF = varnamefid.readline()
varname = varnameEOF[0:len(varnameEOF)-1]
varnamefid.close()
varname.strip()

files = glob.glob("*.xyz")

ogr.UseExceptions()

spatialReference = osr.SpatialReference()
spatialReference.ImportFromProj4('+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')

SHP_FILENAME = varname + ".shp"
PRJ_FILENAME = varname + ".prj"
SHX_FILENAME = varname + ".shx"
DBF_FILENAME = varname + ".dbf"
ZIP_FILENAME = varname + "_shp.zip"
#print volcname + " :: " + varname + " :: " + SHP_FILENAME
#print(volcname + " :: " + varname + " :: " + SHP_FILENAME)

if varname == "dp_mm":
  value_unit = "_Deposit_mm"
elif varname == "dp":
  value_unit = "_Deposit_inches"
elif varname == "ac":
  value_unit = "_MaxAshCon_mg_m3"

# Create new shapefile
ds = ogr.GetDriverByName('ESRI Shapefile').CreateDataSource(SHP_FILENAME)
# Create new layer in shapefile for this contour level
layername = volcname + value_unit
layer = ds.CreateLayer(layername, spatialReference, ogr.wkbLineString)
layerDefinition = layer.GetLayerDefn()
fd = ogr.FieldDefn('name', ogr.OFTString)
layer.CreateField(fd)
fd = ogr.FieldDefn('value', ogr.OFTReal)
layer.CreateField(fd)
fd = ogr.FieldDefn('index', ogr.OFTInteger)
layer.CreateField(fd)

for f in files:
  root = os.path.splitext(f)[0]
  ext  = os.path.splitext(f)[1]
  # double-check that we're reading an xyz file
  if(ext==".xyz"):
    CSV_FILENAME = f
    s0 = root.split('_')[0] # "contour"
    s1 = root.split('_')[1] # contour level
    s2 = root.split('_')[2] # index for this contour level
    s3 = root.split('_')[3] # i or b for internal or boundary
    #print "Reading ", CSV_FILENAME

    fid = open(CSV_FILENAME, 'r')
    r = csv.reader(fid, delimiter='\t', quotechar=None)
    # load data rows into memory
    rows = [row for row in r]
    fid.close()

    ### Prepare data for export to shapefile
    # Create a new line geometry
    line = ogr.Geometry(type=ogr.wkbLineString)
    # Add points to line
    #lon_idx, lat_idx = header['Longitude'], header['Latitude']
    lon_idx = 0
    lat_idx = 1
    for row in rows:
      line.AddPoint(float(row[lon_idx]), float(row[lat_idx]))

    # Add line as a new feature to the shapefile
    feature = ogr.Feature(layer.GetLayerDefn())
    feature.SetField('name', layername)
    feature.SetField('value', float(s1))
    feature.SetField('index', int(s2))
    feature.SetGeometryDirectly(line)
    layer.CreateFeature(feature)
    layer.SyncToDisk()

    # Cleanup
    feature.Destroy()

ds.Destroy()

command = ('zip',ZIP_FILENAME,PRJ_FILENAME,SHX_FILENAME,SHP_FILENAME,DBF_FILENAME)
subprocess.check_call(command)
command = ('rm',PRJ_FILENAME,SHX_FILENAME,SHP_FILENAME,DBF_FILENAME)
subprocess.check_call(command)


