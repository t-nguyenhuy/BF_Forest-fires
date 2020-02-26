# Import modules
import argparse
import getpass
import os
import time
import sys
from PyQt5.QtCore import * # To use QVariant
from qgis.core import *
from qgis.analysis import QgsNativeAlgorithms # To add native algorithms
from shutil import rmtree, copytree
## Other modules imported later in the script
# import processing
# from processing.core.Processing import Processing

# Unpack arguments to set-up folder structure
# print("Entering A")
taskName = os.path.basename(os.path.dirname(os.path.realpath(__file__)))
print("Executing `main.py` of the task named " + taskName + ".")
parser = argparse.ArgumentParser(prog=taskName, \
            description='Script to join settlement points across the selected maps.')
parser.add_argument('QGISINST',nargs=1,type=str,\
                    help='Specify QGIS installation folder')
parser.add_argument('RAWFOLDER',nargs=1,type=str,\
                    help='Specify folder containing raw files')
parser.add_argument('OUTCOME',nargs=1,type=str,\
                    help='Specify the folder where ' +\
                         'outcomes files of this process will be stored.')
parser.add_argument('TEMP',nargs=1,type=str,\
                    help='Specify the folder where temporary files of this'+\
                         ' process will be stored.')
parser.add_argument('STYLE',nargs=1,type=str,\
                    help='Specify the folder where features\' style are '+\
                         'stored.')
parser.add_argument('--OS',default=1,nargs=1,type=int,\
                    help='Indicate the operating system: (1) - Windows; (2) - MAC OS')
parser.add_argument('--copy',default='all',choices=['all','missing','common'],\
                    help='This specifies which observations from `using` '+\
                         'should be appended to the `master` dataset (). '+\
                         '- `all`: append all units from `using` to `master`\n' +\
                         '- `missing`: append only units from `using` missing' +\
                         ' master\n' +\
                         '- `common`: append only units common in both sets')
fold = parser.parse_args()


## ESTABLISH QGIS paths based on operating system
if (fold.OS[0] == 1):
    ## Windows
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/apps/qgis'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/apps/qgis/python/plugins'
else if (fold.OS[1] == 2):
    QGIS_PREF_PATH = fold.QGISINST[0]+u'/MacOS'
    QGIS_PLUG_PATH = fold.QGISINST[0]+u'/Plugins'



# Initiate QGIS in Python without an interface
# print("Entering B")
QgsApplication.setPrefixPath(QGIS_PREF_PATH,True)
qgs = QgsApplication([],False)
qgs.initQgis()


# Set up the `processing` module
sys.path.append(QGIS_PLUG_PATH)
import processing
from processing.core.Processing import Processing
## from processing.tools.general import runAndLoadresults
Processing.initialize()
## Add Native QGIS algorithms - Need to be added after initializing processing
## this loads 'qgis:intersection', an algorithms that we use later
qgs.processingRegistry().addProvider(QgsNativeAlgorithms())


# Run the main script
## Define variables managing the QgisProject and the structure of the layers
project = QgsProject.instance()
project.clear()
layerRoot = project.layerTreeRoot()
layerTree = {}
layerGroups = {}
layerGroupsChildren = {}


## Add administrative boundaries
# print("Entering D")
#### Set-up the structure of layers in the layer
border_name = 'borders'
layerGroups[border_name] = layerRoot.addGroup(border_name)
layerGroupsChildren[border_name] = []
style_level = ['','reg_style','prov_style','communes_style']
#### Reading shapefiles
for i in range(3):
    # Determine relevant filename
    fileroute = fold.RAWFOLDER[0] + u'/adm_boundaries' + \
                u'/bfa_admbnda_adm'+str(i+1)+u'_igb'
    filename = [t_file for t_file in os.listdir(fileroute) \
                if (u'.shp' in t_file)][0]
    # Load the shapefile and apply the fitting style
    newBorderLayer = QgsVectorLayer(fileroute+u'/'+filename, \
                    'adm_bound_'+str(i+1),'ogr')
    newBorderLayer.loadNamedStyle(fold.STYLE[0]+u'/'+style_level[i+1]+u'.qml')
    newBorderLayer.triggerRepaint()
    project.addMapLayer(newBorderLayer)
    # Organize the layer node to the right border
reg_borders = QgsProject.instance().mapLayersByName('adm_bound_1')[0]
prov_borders = QgsProject.instance().mapLayersByName('adm_bound_2')[0]
comm_borders = QgsProject.instance().mapLayersByName('adm_bound_3')[0]

## Turn to data on settlements
#### Make a safe copy of the dataproviders (shapefiles) for settlements
# print("Entering E")
route= [u'/Settlements-OCHA-ROWCA',u'/adm_et_localite/Converted_localites']
if (u'COPY_RAW_FILES' in os.listdir(fold.TEMP[0])):
    for item in os.listdir(fold.TEMP[0]+u'/COPY_RAW_FILES'):
        rmtree(fold.TEMP[0]+u'/COPY_RAW_FILES/'+item)
    rmtree(fold.TEMP[0] + u'/COPY_RAW_FILES')
os.mkdir(fold.TEMP[0] + u'/COPY_RAW_FILES')
for dataSetPath in route:
    sourceDataPath = fold.RAWFOLDER[0] + dataSetPath
    targetDataPath = fold.TEMP[0] + u'/COPY_RAW_FILES' + dataSetPath
    copytree(sourceDataPath,targetDataPath)

#### Add the layers on settlements
# print("Entering F")
###### Set-up structure of layers in the tree
settl_T_n = 'settlements'
layerGroups[settl_T_n] = layerRoot.addGroup(settl_T_n)
layerGroupsChildren[settl_T_n] = []
###### Reading
route = [u'Settlements-OCHA-ROWCA',u'adm_et_localite/Converted_localites']
settLayerName = [u'settl_OCHA',u'settl_adm_loc_orig_CRS']
settLayerStyle = [u'chelieu_dept_style.qml',u'chelieu_reg_style.qml']
for i in range(2):
    fileroute = fold.TEMP[0] + u'/COPY_RAW_FILES/' + route[i]
    filename = [t_file for t_file in os.listdir(fileroute) \
                if (u'.shp' in t_file)][0]
    newSettLay = QgsVectorLayer(fileroute+u'/'+filename,settLayerName[i],'ogr')
    newSettLay.loadNamedStyle(fold.STYLE[0]+u'/'+settLayerStyle[i])
    newSettLay.renderer().symbol().symbolLayer(0).setSize(1.5)
    newSettLay.triggerRepaint()
    project.addMapLayer(newSettLay)
    # Organize border layers in the layer tree
    layerGroupsChildren[settl_T_n].append(layerRoot.findLayer(newSettLay))
settl_OCHA_orig = QgsProject.instance().mapLayersByName("settl_OCHA")[0]
settl_adm_filt_nonCRS = QgsProject.instance().mapLayersByName("settl_adm_loc_orig_CRS")[0]


## Convert settl_adm_filt to match the CRS of settl_OCHA_orig
# print("Entering G")
if not('CRS_CORR_ADM_FILT' in os.listdir(fold.TEMP[0])):
    os.mkdir(fold.TEMP[0]+u'/CRS_CORR_ADM_FILT')
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(settl_adm_filt_nonCRS,\
    fold.TEMP[0]+u'/CRS_CORR_ADM_FILT/settl_adm_filt.shp',"utf-8",\
    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")
newSettLay = QgsVectorLayer(fold.TEMP[0]+u'/CRS_CORR_ADM_FILT/settl_adm_filt.shp',\
            u'settl_adm_loc_orig')
newSettLay.loadNamedStyle(fold.STYLE[0]+u'/chelieu_reg_style.qml')
newSettLay.renderer().symbol().symbolLayer(0).setSize(1.5)
newSettLay.triggerRepaint()
project.addMapLayer(newSettLay)
layerGroupsChildren[settl_T_n].append(layerRoot.findLayer(newSettLay))
settl_adm_filt = QgsProject.instance().mapLayersByName('settl_adm_loc_orig')[0]

## Add additional information to existing layers
#### Add commune information to the settl_OCHA dataset
# print("Entering H")
###### See necessary arguments using
###### ``processing.algorithmHelp('native:intersection')``
intersection_args = {'INPUT': settl_OCHA_orig,
                     'OVERLAY': comm_borders,
                     'INPUT_FIELDS': '',
                     'OVERLAY_FIELDS': '',
                     'OUTPUT': 'memory:'}
# processing.runAndLoadResults('qgis:intersection',intersection_args)
# print(QgsApplication.processingRegistry().createAlgorithmById('qgis:intersection'))
processing.tools.general.runAndLoadResults('qgis:intersection',intersection_args)
settl_OCHA = QgsProject.instance().mapLayersByName('Intersection')[0]
settl_OCHA.setName('settl_OCHA_intersec')
settl_OCHA.loadNamedStyle(fold.STYLE[0]+u'/chelieu_dept_style.qml')
settl_OCHA.renderer().symbol().symbolLayer(0).setSize(1.5)
settl_OCHA.triggerRepaint()
layerGroupsChildren[settl_T_n].append(layerRoot.findLayer(settl_OCHA))
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(settl_OCHA,\
                    fold.OUTCOME[0]+\
                    u'/settlements_with_communes2.shp',"utf-8",\
                    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")

#### Generate an ID field for the adm_et_localite dataset
# print("Entering I")
settl_adm_filt.dataProvider().addAttributes([QgsField('ID',QVariant.Int)])
settl_adm_filt.updateFields()
settl_adm_filt.startEditing()
iterator = 1
for feature in settl_adm_filt.getFeatures():
    settl_adm_filt.changeAttributeValue(feature.id(),\
        feature.fieldNameIndex('ID'), iterator)
    iterator += 1
settl_adm_filt.commitChanges()

#### Determine REGION for settlements in the adm_et_localite dataset
# print("Entering K")
intersection_args = {'INPUT': settl_adm_filt,
                     'OVERLAY': 'adm_bound_1',
                     'INPUT_FIELDS': '',
                     'OVERLAY_FIELDS': 'ADM1_FR',
                     'OUTPUT': 'memory:'}
processing.runAndLoadResults('qgis:intersection',intersection_args)
settl_adm_filt_int = QgsProject.instance().mapLayersByName('Intersection')[0]
settl_adm_filt_int.setName('settl_adm_loc_intersec')
layerGroupsChildren[settl_T_n].append(layerRoot.findLayer(settl_adm_filt_int))
settl_adm_filt_int.startEditing()
settl_adm_filt_int.renameAttribute(settl_adm_filt_int.fields().indexFromName('ADM1_FR'),\
    'REGION')
settl_adm_filt_int.commitChanges()

#### Copy the newly determined REGION field from the temporary layer to the
#### layer containing the `adm_et_localite` dataset
#### AND
#### Identify settlement points in the `adm_et_localite` dataset that are
#### not present in the `OCHA_ROWCA` dataset
# print("Entering L")
settl_adm_filt.dataProvider().addAttributes([QgsField("REGION",QVariant.String),\
                                            QgsField("_match",QVariant.Int)])
settl_adm_filt.updateFields()
settl_adm_filt.startEditing()
for feature in settl_adm_filt.getFeatures():
    f_id = feature['ID']
    # Copy region variable
    searchExprReg = QgsExpression("\"ID\"="+str(f_id))
    match = [i.id() for \
        i in settl_adm_filt_int.getFeatures(QgsFeatureRequest(searchExprReg))]
    if (len(match)==0):
        print("INTERSECTION ERROR AT: "+str(feature['ID']))
        settl_adm_filt.changeAttributeValue(feature.id(),\
            feature.fieldNameIndex('REGION'),'')
    else:
        settl_adm_filt.changeAttributeValue(feature.id(),\
            feature.fieldNameIndex('REGION'),\
            settl_adm_filt_int.getFeature(match[0])['REGION'])

    # Identify non-matching data
    f_name = feature['NOM'].capitalize()
    f_prov = feature['PROVINCE'].capitalize()
    searchExpr = QgsExpression("\"featureNam\"='"+f_name+\
                "' AND \"admin2Name\"='"+f_prov+"'")
    ids = [i.id() for i in settl_OCHA.getFeatures(QgsFeatureRequest(searchExpr))]
    if (len(ids)==0):
        settl_adm_filt.changeAttributeValue(feature.id(),\
            feature.fieldNameIndex("_match"),0)
    else:
        settl_adm_filt.changeAttributeValue(feature.id(),\
            feature.fieldNameIndex("_match"),1)
settl_adm_filt.commitChanges()

##### Add selected features from the `adm_et_localite` dataset to the
##### OCHA-ROWCA dataset
# print("Entering M")
settl_OCHA.startEditing()
listSearchExpr = {
  'all': "\"_match\"=0" + " OR " +"\"_match\"=1",
  'missing': "\"_match\"=0",
  'common' : "\"_match\"=1"
}
searchExpr = QgsExpression(listSearchExpr[fold.copy])
id_iterator = settl_OCHA.maximumValue(settl_OCHA.dataProvider().fieldNameIndex('OBJECTID'))+1
ids = [i.id() for i in settl_adm_filt.getFeatures()]
counter = 1
for id in ids:
    # print(str(id) + ": " +'{:2f}'.format(counter/len(ids)))
    feature = settl_adm_filt.getFeature(id)
    newEntry = QgsFeature()
    newEntry.setGeometry(QgsGeometry.fromPointXY(feature.geometry().asPoint()))
    newEntry.setFields(settl_OCHA.fields())
    newAttrs = [id_iterator,feature['NOM'].capitalize(),'',feature['NOM'].capitalize(),\
                '','','','','Burkina Faso','BF',feature['REGION'],'',\
                feature['PROVINCE'].capitalize(),'','','','',\
                'BFA','','','','','',\
                feature['NOM_DEPART'].capitalize(),'','','','',\
                feature['PROVINCE'].capitalize(),'',feature['REGION'],'','','','','','']
    newEntry.setAttributes(newAttrs)
    settl_OCHA.addFeature(newEntry)
    id_iterator += 1
    counter += 1
print("Exit final loop")
settl_OCHA.commitChanges()

## Rearrange layers to reflect a sensible structure when opened with QGIS GUI
# print("Entering N")
for key in layerGroupsChildren:
    for theLayer in layerGroupsChildren[key]:
        layerGroups[key].addChildNode(theLayer.clone())
        layerRoot.removeChildNode(theLayer)

# Convert the outcome shapefile geometries from multipoint to point
_writerRespone = QgsVectorFileWriter.writeAsVectorFormat(settl_OCHA,\
    fold.OUTCOME[0]+u'/extended_settlm.shp',"utf-8",\
    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")
multipartArgs = {'INPUT': fold.OUTCOME[0]+u'/extended_settlm.shp',\
                 'OUTPUT': 'memory:'}
processing.runAndLoadResults('native:multiparttosingleparts',multipartArgs)
settl_OCHA_conv = QgsProject.instance().mapLayersByName('Single parts')[0]

# Extract layer to shapefile
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(settl_adm_filt,\
    fold.OUTCOME[0]+u'/settl_adm_filt_ext.shp',"utf-8",\
    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")
_writerRespone = QgsVectorFileWriter.writeAsVectorFormat(settl_OCHA_conv,\
    fold.OUTCOME[0]+u'/extended_settlm.shp',"utf-8",\
    QgsCoordinateReferenceSystem("EPSG:4326"),"ESRI Shapefile")

## Save the project
project.write(fold.OUTCOME[0]+'/main_map.qgz')

# Close QGIS in Python
qgs.exitQgis()

print("5 seconds before closing this window")
time.sleep(5)
