import argparse
import os
import sys

from PyQt5.QtCore import *
from qgis.core import *
from qgis.analysis import QgsNativeAlgorithms # To add native algorithms
from shutil import copy2

# Unpack arguments to set-up folder structure
basepath = os.path.dirname(os.path.realpath(__file__))
taskName = os.path.basename(basepath)

# Import a separately define function
sys.path.append(basepath)
from supportingFunctions import convertToPointLayer, copyLayerToMemory



print("Executing `distance_to_edge.py` of the task named " + taskName + ".")

parser = argparse.ArgumentParser(prog=taskName, \
            description='Script to determine each grids\' distance to the edge.')
parser.add_argument('QGISINST',nargs=1,type=str,\
                    help='Specify QGIS installation folder')
parser.add_argument('EDGE_GRIDS',nargs=1,type=str,\
                    help='Location of .csv file containing edge dummy.')
parser.add_argument('FIPFILE',nargs=1,type=str,\
                    help='Location of PIF forest grids')
parser.add_argument('NONFIPFILE',nargs=1,type=str,\
                    help='Location of non-PIF forest grids')
parser.add_argument('TEMP',nargs=1,type=str,\
                    help='Specify the folder where temporary files of this'+\
                         ' process will be stored.')
parser.add_argument('--OS',default=1,nargs=1,type=int,\
                    help='Indicate the operating system: (1) - Windows; (2) - MAC OS')
fold = parser.parse_args()

## ESTABLISH QGIS paths based on operating system
if (fold.OS[0] == 1):
    ## Windows
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/apps/qgis'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/apps/qgis/python/plugins'
else if (fold.OS[1] == 2):
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/MacOS'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/Resources/python/plugins'



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
#####################
project = QgsProject.instance()
project.clear()
project.setCrs(QgsCoordinateReferenceSystem('EPSG:4326'))
project.setEllipsoid('WGS84')

## Add layers and EDGE-FOREST data;
### First the edge data (edge here indicates the edge of the forest, not green area)
gridLay_name    = 'GRID_EDGE'
gridid_edge     = QgsVectorLayer("file:///"+fold.EDGE_GRIDS[0],gridLay_name,'delimitedtext')


### Then the forest grids
FIP_S           = QgsVectorLayer(fold.FIPFILE[0]    ,'FIP_grids_s'      ,'ogr')
nonFIP_S        = QgsVectorLayer(fold.NONFIPFILE[0] ,'nonFIP_grids_s'   ,'ogr')
FIP             = copyLayerToMemory(FIP_S   ,True,True,'FIP_grids')
nonFIP          = copyLayerToMemory(nonFIP_S,True,True,'nonFIP_grids')

####    Before converting to PointLayer, add variable indicating whether the grid
####    is on the edge of the green area or not
for gridLay in [FIP,nonFIP]:
    ## Add new fields to the layers
    gridLay.startEditing()
    gridLay.dataProvider().addAttributes([QgsField('NeighbCount',QVariant.Int),\
                                          QgsField('AreaEdge',  QVariant.Int)])
    gridLay.commitChanges()

    ### First, identify duplicated grids (belonging to different forests)
    gridGridIDs     = []
    duplGridIDs     = []
    deleteFeatsList = []

    for f in gridLay.getFeatures():
        if (f['gridid'] in gridGridIDs):
            deleteFeatsList.append(f.id())
        else:
            gridGridIDs.append(f['gridid'])

    gridLay.startEditing()
    gridLay.dataProvider().deleteFeatures(deleteFeatsList)
    gridLay.commitChanges()

    ## Construct spatial index
    spatIndx            = QgsSpatialIndex(gridLay)

    ## Add to all the relevant variables
    gridLay.startEditing()
    fieldIndxNeigh      = gridLay.fields().indexFromName('NeighbCount')
    fieldIndxAE         = gridLay.fields().indexFromName('AreaEdge')

    for f in gridLay.getFeatures():
        width    = f.geometry().boundingBox().width()
        NeighIDs = spatIndx.intersects(f.geometry().boundingBox().buffered(width * 0.25))
        gridLay.changeAttributeValue(f.id(),fieldIndxNeigh,\
                len(NeighIDs)   )
        gridLay.changeAttributeValue(f.id(),fieldIndxAE,\
                0+( len(NeighIDs) < 9))
    gridLay.commitChanges()



#### Convert layers to Point Layers
cFIP            = convertToPointLayer(FIP,'pFIP_grids')
cnonFIP         = convertToPointLayer(nonFIP,'pnonFIP_grids')
project.addMapLayers([gridid_edge, cFIP, cnonFIP])


## Join the grids to edge and forest data and Make a copy consisting only edge grids;
## Then find for each grid the closes grid at the edge;
for gridLay in [cFIP, cnonFIP]:
    ## Join information on edge
    joinObject = QgsVectorLayerJoinInfo()
    joinObject.setJoinLayer(gridid_edge)
    joinObject.setJoinFieldName('gridid')
    joinObject.setTargetFieldName('gridid')
    joinObject.setUsingMemoryCache(True)
    gridLay.addJoin(joinObject)

    ## Select edge grids
    gridLayEd = QgsVectorLayer('Point?crs='+gridLay.sourceCrs().authid(),\
                'edge'+gridLay.name(),'memory')
    #### Add fields first
    gridLayEd.startEditing()
    gridLayEd.dataProvider().addAttributes([x for x in gridLay.fields()])
    gridLayEd.commitChanges()

    #### Add the edge features to the new layer:
    selectExpression    = QgsExpression("\"AreaEdge\"=1")
    selectFeatures      = gridLay.getFeatures(QgsFeatureRequest(selectExpression))
    gridLayEd.startEditing()
    gridLayEd.addFeatures(selectFeatures)
    gridLayEd.commitChanges()
    #### Add to MapLayers
    project.addMapLayer(gridLayEd)

    ## Find the closest edge grid;
    distanceMatrix_args = { 'INPUT':            gridLay,
                            'INPUT_FIELD':      'gridid',
                            'MATRIX_TYPE':      0,
                            'NEAREST_POINTS':   1,
                            'OUTPUT':           'memory:',
                            'TARGET':           gridLayEd,
                            'TARGET_FIELD':     'gridid',
                          }
    processing.tools.general.runAndLoadResults('qgis:distancematrix',\
                                distanceMatrix_args)

    matchTable = QgsProject.instance().mapLayersByName('Distance matrix')[0]
    matchTable.setName('edgeMatch_'+gridLayEd.name())

    ## Check matches;
    #### Add forest information of the all grids;
    joinObject_g = QgsVectorLayerJoinInfo()
    joinObject_g.setJoinLayer(gridid_edge)
    joinObject_g.setJoinFieldName('gridid')
    joinObject_g.setJoinFieldNamesSubset(['forestid'])
    joinObject_g.setTargetFieldName('InputID')
    joinObject_g.setPrefix('INPUT_')
    joinObject_g.setUsingMemoryCache(True)
    matchTable.addJoin(joinObject_g)

    #### Add forest information of the edge grids;
    joinObject_e = QgsVectorLayerJoinInfo()
    joinObject_e.setJoinLayer(gridid_edge)
    joinObject_e.setJoinFieldName('gridid')
    joinObject_e.setJoinFieldNamesSubset(['forestid'])
    joinObject_e.setTargetFieldName('TargetID')
    joinObject_e.setPrefix('TARGET_')
    joinObject_e.setUsingMemoryCache(True)
    matchTable.addJoin(joinObject_e)

    #### Add polygon edge variable
    joinObject_E = QgsVectorLayerJoinInfo()
    joinObject_E.setJoinLayer(gridLay)
    joinObject_E.setJoinFieldName('gridid')
    joinObject_E.setJoinFieldNamesSubset(['AreaEdge'])
    joinObject_E.setTargetFieldName('InputID')
    joinObject_E.setPrefix("")
    joinObject_E.setUsingMemoryCache(True)
    matchTable.addJoin(joinObject_E)

    ## Rename relevant attributes
    matchTable.startEditing()
    idAttr          = matchTable.fields().indexFromName("InputID")
    idAreaEdge      = matchTable.fields().indexFromName("AreaEdge")
    matchTable.renameAttribute(idAttr, "gridid")
    matchTable.commitChanges()

    ## Create csv files
    idDistance      = matchTable.fields().indexFromName("Distance")
    _writerResponse = QgsVectorFileWriter.writeAsVectorFormat(matchTable,       \
                      fold.TEMP[0]+"\edgDist_"+gridLay.name()+".csv","utf-8",   \
                      QgsCoordinateReferenceSystem(),"CSV",                     \
                      attributes=[idAttr,idDistance,idAreaEdge])

# Close QGIS in Python
######################
qgs.exitQgis()
