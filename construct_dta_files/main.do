* 1st parameter: task number
* 2nd parameter: chosen threshold

* Identify the location of relevant input files
set more off
global taskId `1'
local currTaskName "tasknameS$taskId"
global currSurveyData   "$rawDataFolder/BFA_2013_EMC_v01_M_STATA8/BKA_2013_EMC_v01_M_STATA8"
global currTempFold     "tempFolder$taskId"
global currDoFiles      "$doFilesFolder/${`currTaskName'}"
global currIntermOut    "${intermFolder$taskId}"


* Run the sub-scripts

** Calculate forest size
*do "$currDoFiles/forest_variables.do"

** Generate LSMS enumeration zone level variables and combine them;
*do "$currDoFiles/LSMS_village_variables.do"
*do "$currDoFiles/construct_LSMS_dataset.do"

** Add the ID of the linked LSMS villages to the forest fire dataset
do "$currDoFiles/merge_to_main_dataset_and_construct.do" `2'

** Create forest-monthly and forest-annual datasets that include periodic outcome
** variables (e.g. rainy season, post-rainy season, dry season, pre rainy season variables)
do "$currDoFiles/collapse_to_year.do"
