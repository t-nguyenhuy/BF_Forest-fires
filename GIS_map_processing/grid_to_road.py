# python-qgis.bat "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS\DoFiles\GIS_map_processing\GIS_settl.py" "C:\Program Files\Qgis 3.8" "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS\DataSet\Raw Dataset" "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS\DataSet\Intermediate\LSMS_GIS_merging_Stata\Distance_to_road" "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS\DataSet\Raw Dataset\Forest_grids\pif_grids.shp" "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS\DataSet\Raw Dataset\Forest_grids\nonpif_grids.shp"

import os
import sys
import time
from PyQt5.QtCore import * # To use QVariant
from qgis.core import *
from qgis.analysis import QgsNativeAlgorithms # To add native algorithms

def wr_parse_arguments():
    import argparse

    taskName = os.path.basename( os.path.dirname( os.path.realpath(__file__) ) )
    print("Executing `main.py` of the task named {0}.".format(taskName))
    parser = argparse.ArgumentParser(prog=taskName, \
                description='Script to join settlement points across the selected maps.')
    parser.add_argument('QGISINST',nargs=1,type=str,\
                        help='Specify QGIS installation folder')
    parser.add_argument('RAWFOLDER',nargs=1,type=str,\
                        help='Specify folder containing raw files')
    parser.add_argument('OUTCOME',nargs=1,type=str,\
                        help='Specify the folder where ' +\
                              'outcomes files of this process will be stored.')
    parser.add_argument('FIPFILE',nargs=1,type=str,\
                        help='Location of PIF forest grids')
    parser.add_argument('NONFIPFILE',nargs=1,type=str,\
                        help='Location of non-PIF forest grids')
    parser.add_argument('--OS',default=1,nargs=1,type=int,\
                        help='Indicate the operating system: (1) - Windows; (2) - MAC OS')
    # parser.add_argument('TEMP',nargs=1,type=str,\
    #                     help='Specify the folder where temporary files of this'+\
    #                          ' process will be stored.')
    # parser.add_argument('STYLE',nargs=1,type=str,\
    #                     help='Specify the folder where features\' style are '+\
    #                          'stored.')
    # parser.add_argument('--copy',default='all',choices=['all','missing','common'],\
    #                     help='This specifies which observations from `using` '+\
    #                          'should be appended to tryhe `master` dataset (). '+\
    #                          '- `all`: append all units from `using` to `master`\n' +\
    #                          '- `missing`: append only units from `using` missing' +\
    #                          ' master\n' +\
    #                          '- `common`: append only units common in both sets')
    arguments = parser.parse_args()
    return arguments



def wr_qgis_init(function):
    def wrapped_func(*args,**kwargs):
        fold = wr_parse_arguments()

        # Initiate QGIS in Python without an interface
        ## ESTABLISH QGIS paths based on operating system
        if (fold.OS[0] == 1):
            ## Windows
            QGIS_PREF_PATH = fold.QGISINST[0]+u'/apps/qgis'
            QGIS_PLUG_PATH = fold.QGISINST[0]+u'/apps/qgis/python/plugins'
        else if (fold.OS[1] == 2):
            QGIS_PREF_PATH = fold.QGISINST[0]+u'/MacOS'
            QGIS_PLUG_PATH = fold.QGISINST[0]+u'/Plugins'


        QgsApplication.setPrefixPath(QGIS_PREF_PATH,True)
        qgs = QgsApplication([],False)
        qgs.initQgis()
        print(">> QGIS initialized.")

        # Import `processing` modules
        sys.path.append(QGIS_PLUG_PATH)
        import processing
        from processing.core.Processing import Processing
        ## from processing.tools.general import runAndLoadresults
        Processing.initialize()
        print(">> Processing initialized.")

        # Add Native QGIS algorithms - Need to be after initializing Processing
        ## This loads: `qgis:interesection`, an algorithm needed later
        qgs.processingRegistry().addProvider(QgsNativeAlgorithms())
        print(">> Native algorithms added.")

        # Start with a blank project
        project = QgsProject.instance()
        project.clear()

        # RUN THE MAIN FUNCTION!
        exitFlag = function(fold, qgs, project)
        print(">> Finished with main function.")

        # Close QGIS in Python
        qgs.exitQgis()
        print(">> Exited from QGIS.")
        # Wait before exiting
        print("5 seconds before closing this window.")
        time.sleep(5)
        return exitFlag
    return wrapped_func


def add_borders(layerRoot, layerGroups, layerGroupsChildren, fold, project):
    border_name = 'borders'
    layerGroups[border_name] = layerRoot.addGroup(border_name)
    layerGroupsChildren[border_name] = []
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
        project.addMapLayer(newBorderLayer)
        # Organize the layer node to the right border
    reg_borders = QgsProject.instance().mapLayersByName('adm_bound_1')[0]
    prov_borders = QgsProject.instance().mapLayersByName('adm_bound_2')[0]
    comm_borders = QgsProject.instance().mapLayersByName('adm_bound_3')[0]
    return [layerGroups, layerGroupsChildren,reg_borders,
                         prov_borders, comm_borders]

@wr_qgis_init
def main_function(fold, qgs, project):
    import processing
    from suppfunc import convertToPointLayer
    project.setCrs(QgsCoordinateReferenceSystem('EPSG:4326'))
    project.setEllipsoid('WGS84')

    layRoot = project.layerTreeRoot()
    layTree = {}
    layGroups = {}
    layGroupsCh = {}

    # Add borders
    [layGroups, layGroupsCh,reg,prov,comm] = add_borders(layRoot, layGroups,
                                                         layGroupsCh, fold, project)

    # Add road map
    ## conditioning varible ensures we only work with primary, secondary, and tertiary roads
    layGroups['Info'] = layRoot.addGroup('Info')
    layGroupsCh['Info'] = []
    road_layer_Path = fold.RAWFOLDER[0] + u'/bfa_trs_roads_osm/bfa_trs_roads_osm.shp'
    conditioning    = "|layerid=0|subset=\"ntlclass\"=\'primary\' OR \"ntlclass\"=\'secondary\' OR \"ntlclass\"=\'tertiary\' OR \"ntlclass\"=\'primary_link\' OR \"ntlclass\"=\'secondary_link\' OR \"ntlclass\"=\'tertiary_link\'"
    road_layer      = QgsVectorLayer(road_layer_Path+conditioning,'Road Layer','ogr')
    project.addMapLayer(road_layer)
    layGroupsCh['Info'].append(layRoot.findLayer(road_layer))
        # print(len([x for x in road_layer.getFeatures()]))
    ## Convert from line to point shapefile
    print(">>>> Road map added.")
    ARGUMENTS = {'LINES':   road_layer,
                 'ADD':     True,
                 'DIST':    1,
                 'POINTS':  fold.OUTCOME[0]+u'/bfa_trs_roads_point.shp'}
    processing.runAndLoadResults('saga:convertlinestopoints', ARGUMENTS)
    road_pLayer = QgsVectorLayer(fold.OUTCOME[0]+u'/bfa_trs_roads_point.shp',
                                'bfa_trs_roads_point','ogr')
    project.addMapLayer(road_pLayer)
    road_pLayer.setName('Road Point Layer')
    print(">>>> Road map converted to point layer")
    ## Add unique ID
    road_pLayer.startEditing()
    road_pLayer.dataProvider().addAttributes([QgsField('UniqueID',QVariant.Int)])
    road_pLayer.commitChanges()

    road_pLayer.startEditing()
    f = road_pLayer.fields().indexFromName('UniqueID')
    i = 1
    for feature in road_pLayer.getFeatures():
        road_pLayer.changeAttributeValue(feature.id(), f, i)
        i += 1
    road_pLayer.commitChanges()
    print(">>>> Added UniqueID.")


    # Add forest grid layers and convert them to point layers
    FIP     = QgsVectorLayer(fold.FIPFILE[0],'FIP grids','ogr')
    NONFIP  = QgsVectorLayer(fold.NONFIPFILE[0],'NONFIP grids','ogr')

    pointFIP        = convertToPointLayer(FIP,'FIP_point')
    pointNonFIP     = convertToPointLayer(NONFIP,'NONFIP_point')
    project.addMapLayers([pointFIP,pointNonFIP])
    layGroupsCh['Info'].append(layRoot.findLayer(pointFIP))
    layGroupsCh['Info'].append(layRoot.findLayer(pointNonFIP))
    print(">>>> Forest grids added.")

    # Calculate distance of grids form roads
    for layer in [pointFIP, pointNonFIP]:
        ARGUMENTS = { 'INPUT': layer,
                        'INPUT_FIELD': 'gridid',
                        'MATRIX_TYPE': 0,
                        'NEAREST_POINTS': 1,
                        'OUTPUT': 'memory:',
                        'TARGET': road_pLayer,
                        'TARGET_FIELD': 'UniqueID'
                      }
        processing.runAndLoadResults('qgis:distancematrix', ARGUMENTS)
        matchTable = QgsProject.instance().mapLayersByName('Distance matrix')[0]
        matchTable.setName(layer.name() + "_DIST_ROAD")
        _writerResponse = QgsVectorFileWriter.writeAsVectorFormat(matchTable, \
                                fold.OUTCOME[0] + u'/' +layer.name() + u'_Dista.csv',\
                                "utf-8", QgsCoordinateReferenceSystem(), "CSV")
    print(">>>> Distances to roads are calculated.")
    return 1



start_time = time.time()
print("Entering.")
exitFlag = main_function(sys.argv)
print("Exiting")
print("--- %s seconds ---" % (time.time() - start_time))
    # print(write_text("John",1))
