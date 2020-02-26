import argparse
import os
import sys
import time
from PyQt5.QtCore import *
from qgis.core import *
from qgis.analysis import QgsNativeAlgorithms # To add native algorithms
from shutil import copy2


# Unpack arguments to set-up folder structure
basepath = os.path.dirname(os.path.realpath(__file__))
taskName = os.path.basename(basepath)

# Import a separately define function
sys.path.append(basepath)
from supportingFunctions import convertToPointLayer

print("Executing `main.py` of the task named " + taskName + ".")
parser = argparse.ArgumentParser(prog=taskName, \
            description='Script to select only LSMS settlements form the GIS dataset.')
parser.add_argument('QGISINST',nargs=1,type=str,\
                    help='Specify QGIS installation folder')
parser.add_argument('SELECTIDS',nargs=1,type=str,\
                    help='Location of excel file containing the selected ID-s')
parser.add_argument('GISFILE',nargs=1,type=str,\
                    help='Location of GIS dataset')
parser.add_argument('FIPFILE',nargs=1,type=str,\
                    help='Location of PIF forest grids')
parser.add_argument('NONFIPFILE',nargs=1,type=str,\
                    help='Location of non-PIF forest grids')
parser.add_argument('TEMP',nargs=1,type=str,\
                    help='Specify the folder where temporary files of this'+\
                         ' process will be stored.')
parser.add_argument('OUTCOME',nargs=1,type=str,\
                    help='Location of output folder')
parser.add_argument('--OS',default=1,nargs=1,type=int,\
                    help='Indicate the operating system: (1) - Windows; (2) - MAC OS')
parser.add_argument('--distanceThrs',default=[],nargs='*',type=int,\
                    help='Define the maximum distance that is allowed between'+\
                         ' a forest grid and a settlement. Defeault: no threshold.')
#parser.add_argument('--treatmForestMaxForestID',default=12,nargs=1,type=int,\
#                    help='When forestID-s are ordered and the first X forests'+\
#                         ' are the treated forests, then this parameter defines'+\
#                         ' the highest forestID that is still a treatment forest.'+\
#                         ' Default: 12.')
#parser.add_argument('--pifMaxGridID',default=8182,nargs=1,type=int,\
#                    help='When forest grid ID-s are ordered and the first X forests'+\
#                         ' are the PIF forest grids, then this parameter defines'+\
#                         ' the highest gridid that is still a PIF forest. '+\
#                         ' Default: 8182.')
fold = parser.parse_args()

## ESTABLISH QGIS paths based on operating system
if (fold.OS[0] == 1):
    ## Windows
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/apps/qgis'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/apps/qgis/python/plugins'
else if (fold.OS[1] == 2):
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/MacOS'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/Resources/python/plugins'



# Make a copy of the GIS dataset to avoid making changes to the original file
filenameSHP = os.path.basename(fold.GISFILE[0])
path = fold.GISFILE[0].replace(filenameSHP,'')
filename = filenameSHP.replace('.shp','')
for file in os.listdir(path):
    if filename in file:
        copy2(path+file,fold.TEMP[0]+u'/'+file)

# Initiate QGIS in Python without an interface
QgsApplication.setPrefixPath(QGIS_PREF_PATH,True)
qgs = QgsApplication([],False)
qgs.initQgis()

# Set up the `processing` module
sys.path.append(QGIS_PLUG_PATH)
import processing
from processing.core.Processing import Processing
Processing.initialize()
## Add Native QGIS algorithms - Need to be added after initializing processing
## this loads 'qgis:distancematrix', an algorithms that we use later
qgs.processingRegistry().addProvider(QgsNativeAlgorithms())



# Run the main script
project = QgsProject.instance()
project.clear()
project.setCrs(QgsCoordinateReferenceSystem('EPSG:4326'))
project.setEllipsoid('WGS84')


##  1. First select LSMS settlements in the shapefile and export them to a separate
##  one
####  Load the dataset on selected ID-s and the shapefile with GIS settlements
matches = QgsVectorLayer(fold.SELECTIDS[0],'selection','ogr')
GIS = QgsVectorLayer(fold.TEMP[0]+u'/'+filenameSHP,'GIS_settls','ogr')
project.addMapLayers([matches,GIS])


#### Select observations that are not matched (using observations from `matches`)
keepIDs = [int(x['OBJECTID']) for x in matches.getFeatures() \
                    if x['OBJECTID']!=NULL]
###### Note that these ID-s are not the same as the `OBJECTID`
removeIDs = [x.id() for x in GIS.getFeatures() \
                    if not(x['OBJECTID'] in keepIDs)]
removeOBJCIDs = [x['OBJECTID'] for x in GIS.getFeatures() \
                    if not(x['OBJECTID'] in keepIDs)]
#### and remove them from the shapefile
GIS.startEditing()
for feature in GIS.getFeatures(removeIDs):
    GIS.deleteFeature(feature.id())
GIS.commitChanges()
#### Export the remaining feautres to the shapefile
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(GIS,\
                    fold.OUTCOME[0]+u'/extended_settlm_SEL.shp',"utf-8",
                    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")

##  2. Identify for each forest grid the  closest LSMS settlement
#### Load the shapefiles of PIF and non-PIF forests
FIP = QgsVectorLayer(fold.FIPFILE[0],'FIP_grids','ogr')
nonFIP = QgsVectorLayer(fold.NONFIPFILE[0],'nonFIP_grids','ogr')
project.addMapLayers([FIP,nonFIP])


#### First convert grid polygons to points so that the `distancematrix`
#### algorithm can be used
pointFIP = convertToPointLayer(FIP,'FIP_point')
pointNonFIP = convertToPointLayer(nonFIP,'NONFIP_point')
project.addMapLayers([pointFIP,pointNonFIP])


#### Then calculate the distance matrix that identifies the closest settlements
#### for each forest grid. Thisi will be stored on a layer represented by
#### `matchesLayer`, and exported to a csv filer
matchesList = []
##### Define fields for dummy variables indicating whether the calculated
##### distances exceed a certain threshold or not
thresholdDummies = []
for thresh in fold.distanceThrs:
    thresholdDummies += [QgsField('Thresh_'+str(thresh),QVariant.Int)]
for layer in [pointFIP,pointNonFIP]:
    # For each forest-grid layer, identify the closest settlements captured
    # on the `matchTable` layer
    distanceMatrix_args = { 'INPUT': layer,
                            'INPUT_FIELD': 'gridid',
                            'MATRIX_TYPE': 0,
                            'NEAREST_POINTS': 1,
                            'OUTPUT': 'memory:',
                            'TARGET': GIS,
                            'TARGET_FIELD': 'OBJECTID'
                          }
    processing.tools.general.runAndLoadResults('qgis:distancematrix',\
                                distanceMatrix_args)

    matchTable = QgsProject.instance().mapLayersByName('Distance matrix')[0]
    matchTable.setName('forest_settlement-'+layer.name())
    matchTable.startEditing()
    matchTable.dataProvider().addAttributes(thresholdDummies)
    matchTable.commitChanges()
    # Then add the matched forest grid-settlement pairs to the list
    for feature in matchTable.getFeatures():
        for thresh in fold.distanceThrs:
            feature.setAttribute('Thresh_'+str(thresh),\
                                0+(feature['Distance']/1000<=thresh))
        feature.clearGeometry()
        matchesList += [feature]


#### Export the list of forest grid-settlement pairs to a csv file
matchesLayer = QgsVectorLayer('Point?crs='+FIP.sourceCrs().authid(),\
    'matches','memory')
matchesLayer.startEditing()
matchesLayer.dataProvider().addAttributes([QgsField('InputID',QVariant.LongLong),\
                                           QgsField('TargetID',QVariant.Int),\
                                           QgsField('Distance',QVariant.Double)]+\
                                           thresholdDummies)
matchesLayer.commitChanges()
matchesLayer.startEditing()
matchesLayer.addFeatures(matchesList)
matchesLayer.commitChanges()
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(matchesLayer,\
            fold.OUTCOME[0]+'/forestgrid_settlement_assignments.csv',"utf-8",\
            QgsCoordinateReferenceSystem(),"CSV")



#### Create a layer containing only settlements linked to forest grids
###### First generate a shapefile that includes all linked settlements
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(GIS,\
            fold.OUTCOME[0]+u'/extended_settlm_linkedtogrids.shp',"utf-8",
            QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")
GIS_linked = QgsVectorLayer(fold.OUTCOME[0]+u'/extended_settlm_linkedtogrids.shp',\
            'GIS_settl_linkedtoforest','ogr')
keepIDs = [int(x['TargetID']) for x in matchesLayer.getFeatures()]
removeIDs = [x.id() for x in GIS.getFeatures() if not(x['OBJECTID'] in keepIDs)]
GIS_linked.startEditing()
for feature in GIS_linked.getFeatures(removeIDs):
    GIS_linked.deleteFeature(feature.id())
GIS_linked.commitChanges()
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(GIS_linked,\
            fold.OUTCOME[0]+u'/extended_settlm_linkedtogrids.shp',"utf-8",
            QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")


###### Then other shapefiles with different thresholds:
####### - One set containing LSMS villages within `thresh` km-s away from forest
####### - Another set containing the full set of forest grids partialled out
for thresh in fold.distanceThrs:
    _writerResponse = QgsVectorFileWriter.writeAsVectorFormat(GIS,\
                fold.OUTCOME[0]+u'/extended_settlm_linkedtogrids_'+str(thresh)+\
                '.shp',"utf-8",QgsCoordinateReferenceSystem("EPSG:4326"),\
                "ESRI Shapefile")
    GIS_linked = QgsVectorLayer(fold.OUTCOME[0]+\
                    u'/extended_settlm_linkedtogrids_'+str(thresh)+'.shp',\
                    'GIS_settl_linkedtoforest','ogr')
    ## Generate LSMS village layer within distance from the forest
    keepIDs = [int(x['TargetID']) for x in matchesLayer.getFeatures() \
                if (x['Distance']/1000<=thresh)]
    removeIDs = [x.id() for x in GIS.getFeatures() if not(int(x['OBJECTID']) in keepIDs)]
    GIS_linked.startEditing()
    for feature in GIS_linked.getFeatures(removeIDs):
        GIS_linked.deleteFeature(feature.id())
    GIS_linked.commitChanges()
    _writerResponse = QgsVectorFileWriter.writeAsVectorFormat(GIS_linked,\
                fold.OUTCOME[0]+u'/extended_settlm_linkedtogrids_'+str(thresh)+\
                '.shp',"utf-8",QgsCoordinateReferenceSystem("EPSG:4326"),\
                "ESRI Shapefile")
    ## Then generate forest grids with forests partialled out - line 135-174
    matchesList2 = []
    for layer in [pointFIP,pointNonFIP]:
        distanceMatrix_args = { 'INPUT': layer,
                                'INPUT_FIELD': 'gridid',
                                'MATRIX_TYPE': 0,
                                'NEAREST_POINTS': 1,
                                'OUTPUT': 'memory:',
                                'TARGET': GIS_linked,
                                'TARGET_FIELD': 'OBJECTID'
                              }
        processing.tools.general.runAndLoadResults('qgis:distancematrix',\
                              distanceMatrix_args)

        matchTable2 = QgsProject.instance().mapLayersByName('Distance matrix')[0]
        matchTable2.setName('forest_settlement-'+layer.name()+str(thresh))
        matchesList2 += [feature for feature in matchTable2.getFeatures()]
    matchesLayer2 = QgsVectorLayer('Point?crs='+FIP.sourceCrs().authid(),\
                    'matches','memory')
    matchesLayer2.startEditing()
    matchesLayer2.dataProvider().addAttributes([QgsField('InputID',QVariant.LongLong),\
                                               QgsField('TargetID',QVariant.Int),\
                                               QgsField('Distance',QVariant.Double)])
    matchesLayer2.commitChanges()
    matchesLayer2.startEditing()
    matchesLayer2.addFeatures(matchesList2)
    matchesLayer2.commitChanges()
    _writerResponse = QgsVectorFileWriter.writeAsVectorFormat(matchesLayer2,\
                        fold.OUTCOME[0]+'/forestgrid_settlement_assignments_p'+\
                        str(thresh)+'.csv',"utf-8",QgsCoordinateReferenceSystem(),\
                        "CSV")


# Write project file
project.write(fold.OUTCOME[0]+'/forest_grid_and_settlement_map.qgz')

# Close QGIS in Python
qgs.exitQgis()

print("5 seconds before closing this window")
time.sleep(5)
