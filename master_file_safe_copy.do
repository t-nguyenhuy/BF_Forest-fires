clear all

** Install necessary stata packages
**** Packages available in ssc
#delimit ;
foreach package in spmap shp2dta mif2dta matchit freqindex outreg2 synth npsynth
 ivreg2 xtivreg2 ranktest{;
	capture which `package';
	if _rc==111 ssc install `package';
};
#delimit cr
**** Packages not in ssc
qui net sj 5-3 st0026_2
net install st0026_2.pkg



** Defining folder structure
**** User-specific folders
if (c(username)=="u1273269"){
	**** Location of QGIS resources: So far tested with QGIS 3.4.2 (standalone)
  global    qgisInstFold "C:/Program Files/QGIS 3.4"

	**** Project files and etc.
  global    projectfolder "D:/Dropbox/Share work/ForestFire_BF"
  global    sleepTimeG 550
}


if (c(username)=="sergeadjognon"){
	**** Location of QGIS resources: So far tested with QGIS 3.4.2 (standalone)
  global    qgisInstFold "/Applications/QGIS3"

	**** Project files and etc.
  global    projectfolder "/Volumes/My Passport for Mac/CloudDocs/Dropbox/World Bank projects/PROJECTS/1-BURKINA FORESTRY/Tung Data/ForestFire_BF"
  global    sleepTimeG 550
}


**** pyQGIS-specific paths
global  qgisCorePath "$qgisInstFold/bin"
* Define qgisPrefix: https://docs.qgis.org/testing/en/docs/pyqgis_developer_cookbook/intro.html#id9
global  qgisPrefix    "$qgisInstFold/apps/qgis"


**** Location of project files
global      tasknameS1 "GIS_map_processing"
global      tasknameS2 "LSMS_GIS_merging_Stata"
global      tasknameS3 "select_LSMSsettls_in_GIS"
global      tasknameS4 "construct_dta_files"
global      tasknameS5 "analysis"

cd "$projectfolder"
global      rawDataFolder "$projectfolder/DataSet/Raw Dataset"
global      intermDataFolder "$projectfolder/DataSet/Intermediate"
global      finalDataFolder "$projectfolder/DataSet/Final"
global      outputFolder "$projectfolder/Output"


global      doFilesFolder "$projectfolder/DoFiles"
**** Set-up folders for temporary and intermediate outcome files.
foreach i of numlist 1 2 3 4{
  local variable "tasknameS`i'"
  *capture shell rmdir "$intermDataFolder/TEMP_$`variable'" /s /q
  *capture shell rmdir "$intermDataFolder/$`variable'" /s /q
  *shell mkdir "$intermDataFolder/TEMP_$`variable'"
  *shell mkdir "$intermDataFolder/$`variable'"
  global tempFolder`i' "$intermDataFolder/TEMP_$`variable'"
  global intermFolder`i' "$intermDataFolder/$`variable'"
}



** Running scripts
** Note that for the arguments of the python scripts are defined in the
** corresponding `main.py' file of the given step.

** Step 1: Join the shapefiles on settlements from OCHA-ROWCA and from Serge
**** Requires QGIS libraries to execute
*#delimit ;
*shell "$qgisCorePath/python-qgis.bat"
* 	"$doFilesFolder/$tasknameS1/main.py"
*	"$qgisInstFold" "$rawDataFolder" "$intermFolder1" "$tempFolder1"
*	"$rawDataFolder/qgis_layer_styles" --copy all;
*#delimit cr


** Step 2: Identify the settlements from the LSMS survey in the GIS settlements
**         dataset.
**** Requires STATA
*do "$doFilesFolder/$tasknameS2/main.do" 2


** Step 3: Generate a separate GIS map layer with only LSMS settlements
**** Requires QGIS libraries to execute
*#delimit ;
*shell "$qgisCorePath/python-qgis.bat"
*	"$doFilesFolder/$tasknameS3/main.py"
*	"$qgisInstFold" "$intermFolder2/ZD_village/zd_village_match.xls"
*	"$intermFolder1/extended_settlm.shp"
*	"$rawDataFolder/Forest_grids/pif_grids.shp"
*	"$rawDataFolder/Forest_grids/nonpif_grids.shp"
*	"$tempFolder3"
*	"$intermFolder3" --distanceThrs 0 5 10 11 12 13 14 15 20;
*#delimit cr

** Step 4: Combining the dataset to generate the datafile for the analysis
**** Requires STATA
do "$doFilesFolder/$tasknameS4/main.do" 4 15

** Step 5: Run the analysis
**** Requires STATA
do "$doFilesFolder/$tasknameS5/main.do" 5
