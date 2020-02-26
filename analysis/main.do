* 1st parameter: task number
* 2nd parameter: chosen

set more off
local taskID `1'
local currTaskName "${tasknameS`taskID'}"
global currIntermOut "${intermFolder`taskId'}"
global currTempFold "${tempFolder`taskID'}"
global currDoFiles "$doFilesFolder/`currTaskName'"

local descrLocalityCrosSec    1
local descrGenerateGraphs     0
local SCEstForestMainEff      0
local SCEstForestRobustE      0
local SCEstLocaliMainEff      0
local treatmHeterogForest     1
local treatmHeterogBlocks     1


**** Descriptive outputs
    **** First graphs
    if ("`descrGenerateGraphs'"=="1")     do "$currDoFiles/descriptives.do" `1'
    **** Improved graphs
    if ("`descrGenerateGraphs'"=="1")     do "$currDoFiles/desctiprives_graphs2.do" `1'


    *** Cross-sectional regression of locality fire occurrence on LSMS variables
    if ("`descrLocalityCrosSec'"=="1")    do "$currDoFiles/cross_sectional_LOCALITY.do" `1'



** SC estimates
**** Parameters:
**** 2: Outcome variable
**** 3: Beginning of the treatment (YEAR)
**** 4: Sample selection condition
    do "$currDoFiles/sctabout.do"         // Supporting function to put SC estimates to latex
    if ("`SCEstForestMainEff'"=="1")      do "$currDoFiles/FOREST_synth_control.do" `1' 0 `2' `3' `4'
    if ("`SCEstForestRobustE'"=="1")      do "$currDoFiles/FOREST_synth_ROBUST.do" `1' 0 `2' `3' `4'
    if ("`SCEstLocaliMainEff'"=="1")      do "$currDoFiles/LOCALITY_synth_control.do" `1'


** Treatment heterogeneity
    *do "$currDoFiles/treatment_effects.do" `1' `2' `3' // Previous preliminary analyses
    if ("`treatmHeterogForest'"=="1")     do "$currDoFiles/FOREST_synth_ROBUST_heterog.do" `1'
    if ("`treatmHeterogBlocks'"=="1")     do "$currDoFiles/treatment_effects_blocks.do" `1' `2' `3'


****** THESE ARE NOT RELEVANT, keeping it for achive
**** Non-matched regressions
*do "$currDoFiles/non_matched_estimates_FOREST.do" `1'

**** Non-matched IV regressions
*do "$currDoFiles/IV_regress.do" `1'
