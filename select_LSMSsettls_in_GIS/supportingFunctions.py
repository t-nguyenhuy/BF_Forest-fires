from qgis.core import QgsVectorLayer, QgsFeature

def convertToPointLayer(input_layer,title):
    Outcome_layer = QgsVectorLayer('Point?crs=epsg:4326',title,'memory')
    Outcome_layer.dataProvider().addAttributes(input_layer.fields())
    Outcome_layer.startEditing()
    newFeatures = []
    for sourceF in input_layer.getFeatures():
        centroid = sourceF.geometry().centroid()
        fieldS = sourceF.fields()
        attributeS = sourceF.attributes()

        newF = QgsFeature(fieldS)
        newF.setGeometry(centroid)
        newF.setAttributes(attributeS)
        newFeatures.append(newF)
    Outcome_layer.addFeatures(newFeatures)
    Outcome_layer.commitChanges()
    return Outcome_layer
