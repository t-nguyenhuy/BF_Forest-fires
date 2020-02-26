* 1st parameter: task number
* 2nd parameter: chosen

set more off
local taskID `1'
local currTaskName "${tasknameS`taskID'}"
global currIntermOut "${intermFolder`taskId'}"
global currTempFold "${tempFolder`taskID'}"
global currDoFiles "$doFilesFolder/`currTaskName'"

**** Descriptive outputs
*do "$currDoFiles/descriptives.do" `1'

** SC estimates
**** Parameters:
**** 2: Outcome variable
**** 3: Beginning of the treatment (YEAR)
**** 4: Sample selection condition
*do "$currDoFiles/FOREST_synth_control.do" `1' 0 `2' `3' `4'

*do "$currDoFiles/LOCALITY_synth_control.do" `1'

do "$currDoFiles/FOREST_synth_ROBUST.do" `1' 0 `2' `3' `4'


** Treatment heterogeneity?
*do "$currDoFiles/treatment_effects.do" `1' `2' `3'


****** THESE ARE NOT RELEVANT, keeping it for achive
**** Non-matched regressions
*do "$currDoFiles/non_matched_estimates_FOREST.do" `1'

**** Non-matched IV regressions
*do "$currDoFiles/IV_regress.do" `1'
