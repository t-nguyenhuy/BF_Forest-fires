class paramClass:
  def __init__(self,inputs):
    self.GISFILE = [inputs[0]]
    self.IGBFILE = [inputs[1]]
    self.OUTCOME = [inputs[2]]
    self.distanceThrs = inputs[3]
import processing
igbFolds = ['D:/Surfdrive/Working folders - PhD/Forest Fire - BF - LSMS_GIS/DataSet/Intermediate/select_LSMSsettls_in_GIS', \
            'D:/Surfdrive/Working folders - PhD/Forest Fire - BF - LSMS_GIS/DataSet/Intermediate/GIS_map_processing/IGB_Placettes.shp',\
            'D:/Surfdrive/Working folders - PhD/Forest Fire - BF - LSMS_GIS/DataSet/Intermediate/select_LSMSsettls_in_GIS',\
            [5,10,11,12,13,14,15,20]]
fold = paramClass(igbFolds)
GIS = QgsVectorLayer(fold.GISFILE[0],'extended_settlm_SEL','ogr')
IGB = QgsVectorLayer(fold.IGBFILE[0],'IGB_Placettes','ogr')
thresholdDummies = []
for thresh in fold.distanceThrs:
    thresholdDummies += [QgsField('Thresh_'+str(thresh),QVariant.Int)]


igbDistanceMatrix_args = {'INPUT': IGB,
                          'INPUT_FIELD': 'FID_',
                          'MATRIX_TYPE': 0,
                          'NEAREST_POINTS': 1,
                          'OUTPUT': 'memory:',
                          'TARGET': GIS,
                          'TARGET_FIELD': 'OBJECTID'}
processing.tools.general.runAndLoadResults('qgis:distancematrix',\
                            igbDistanceMatrix_args)
igbMatchTable = QgsProject.instance().mapLayersByName('Distance matrix')[0]
igbMatchTable.setName('igb_match')
igbMatchTable.startEditing()
igbMatchTable.dataProvider().addAttributes(thresholdDummies)
igbMatchTable.commitChanges()
igbMatchTable.startEditing()
for feature in igbMatchTable.getFeatures():
    for thresh in fold.distanceThrs:
        igbMatchTable.changeAttributeValue(feature.id(),\
                igbMatchTable.fields().lookupField('Thresh_'+str(thresh)),\
                0+(feature['Distance']/1000<=thresh))
igbMatchTable.commitChanges()

_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(igbMatchTable,\
                                      fold.OUTCOME[0]+'/igb_matchTable.csv',\
                                      'utf-8',QgsCoordinateReferenceSystem(),\
                                      'CSV')
_writerResponse = QgsVectorFileWriter.writeAsVectorFormat(IGB,\
                                      fold.OUTCOME[0]+'/IBG_attrTable.csv',\
                                      'utf-8',QgsCoordinateReferenceSystem(),\
                                      'CSV')
