* 1st parameter: task number
* Identify the location of relevant input files
set more off
local taskId `1'
local currTaskName "tasknameS`taskId'"
global currIntermOut "intermFolder`taskId'"
global currTempFold "tempFolder`taskId'"
global currDoFiles "$doFilesFolder/$`currTaskName'"

global currIntermOutput "$intermFolder`taskId'"

global currSettlCommShapeF "$intermDataFolder/$tasknameS1/settlements_with_communes2.shp"
global currSettlCommShapeFExt "$intermDataFolder/$tasknameS1/extended_settlm.shp"

* Run the sub-scripts
** Convert the enumeration-village key file to dta
do "$currDoFiles/convert_zd_dataset.do"

** Import and prepare GIS settlement files
do "$currDoFiles/prepare_GIS.do"

** Call main file
do "$currDoFiles/exact_matching.do"

** Post-exact matching analysis
do "$currDoFiles/fuzzy_matching.do"

* Merge the results from exact and fuzzy matching
do "$currDoFiles/final_key_set.do"

macro drop currIntermOut currTempFold currDoFiles currIntermOutput
macro drop currSettlCommShapeF currSettlCommShapeFExt
