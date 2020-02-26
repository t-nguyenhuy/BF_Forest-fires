capture log close
local prevId = `1'-1
use "${intermFolder`prevId'}/burkina_faso_fires_forestblock.dta", clear

**** Naive panel DID estimates
***** First include the modified treatment effect estimator based on subclassification
qui do "$currDoFiles/atts_did.ado"
local outcomeVariables "fire_scaled confidence50_scaled confidence80_scaled ndvi truncNdvi evi"

#delimit ;
preserve;
capture shell del /f "$outputFolder/naive_did.doc";
capture shell del /f "$outputFolder/naive_did.txt";
log using "$outputFolder/naive_did_LOG.txt", t replace;
foreach y of local outcomeVariables{;
  xtreg `y' i.post##i.treatment i.year i.month, fe;
  di ">> $outputFolder";
  outreg2 using "$outputFolder/naive_did.doc", alpha (.01,.05,.1)
    symbol(***,**,*) auto(3);
};
log close;
restore;
#delimit cr






#delimit ;
***** Estimating propensity scores using number of grids as area measure;
preserve;
log using "$outputFolder/propensity_score_est_LOG_diffArea.txt", t replace;
pscore treatment gridid histFor_confidence80 EstPop L08_LightingW L14_CookingW
  landIntFoodConsSh if (time==monthly("2017m12","YM")), pscore(estPScore)
  blockid(pStratID) detail numblo(7);
log close;
restore;

preserve;
log using "$outputFolder/propensity_score_est_LOG_PIF.txt", t replace;
keep if fip == 1;
pscore treatment gridid histFor_confidence80 EstPop L08_LightingW L14_CookingW
  landIntFoodConsSh if (time==monthly("2017M12","YM")), pscore(estPScore)
  blockid(pStratID) detail numblo(7);
log close;
restore;
#delimit cr


#delimit ;
***** Estimating propensity scores using area covariate;
preserve;
log using "$outputFolder/propensity_score_est_LOG.txt", t replace;
pscore treatment area histFor_confidence80 EstPop L08_LightingW L14_CookingW
  landIntFoodConsSh if (time==monthly("2017m12","YM")), pscore(estPScore)
  blockid(pStratID) detail numblo(7);
log close;
foreach x in estPScore pStratID{;
  bysort forestBlockID: egen `x'_max = max(`x');
  replace `x' = `x'_max if `x'==.;
  drop `x'_max;
};

***** Estimate cross-sectional treatment effects for treatment years;
***** Biased by time-invariant and time variant factors affecting both assigm. and;
***** outcomes;
log using "$outputFolder/atts_cross_section_LOG.txt", t replace;
foreach y of local outcomeVariables{;
  foreach yr of numlist 2015/2018{;
    atts fire_scaled treatment if (year==`yr'), pscore(estPScore) blockid(pStratID)
      detail;
  };
};
log close;

***** Estimate treatment effects using stratified difference-in-difference;
***** estimation methods.;
*log using "$outputFolder/attsdid_LOG.txt", t replace;
*foreach y of local outcomeVariables{;
*   attsDid `y' post treatment, pscore(estPScore)
*     blockid(pStratID) clustering(vce(cluster forestid))
*     timedummies(year month) suppress detail bootstrap;
*};
* log close;
restore;
#delimit cr



***** Synthetic control approach
#delimit ;
preserve;
******** the sample is strongly balanced in this case;
******** both PIF (forest<=24) and non-PIF forests are included in the sample;
keep if forestid <= 48;
******** Return the list of treated and non-treated forest blocks;
qui tab forestBlockID if (treatment==1),matrow(TREATED_BLOCKS);
local TreatBlocksIDs "";
forvalues i=1(1)`=rowsof(TREATED_BLOCKS)'{;
  di TREATED_BLOCKS[`i',1];
  local TreatBlocksIDs "`TreatBlocksIDs' `=TREATED_BLOCKS[`i',1]'";
};
qui tab forestBlockID if (treatment==0),matrow(NONTREATED_BLOCKS);
local NonTBlocksIDs "";
forvalues i=1(1)`=rowsof(NONTREATED_BLOCKS)'{;
  di NONTREATED_BLOCKS[`i',1];
  local NonTBlocksIDs "`NonTBlocksIDs' `=NONTREATED_BLOCKS[`i',1]'";
};

*local TreatBlocksIDs "1056";
local TreatBlocksIDs "";
tsset forestBlockID time;
local xVariables "area histFor_confidence80 EstPop L08_LightingW L14_CookingW
                  landIntFoodConsSh";
local preTPeriod "`=monthly("2006M8","YM")'(1)`=monthly("2014M8","YM")'";
foreach y of local outcomeVariables{;
  log using "$outputFolder/SYNTH_`y'.txt", t replace;
  foreach tUnit of local TreatBlocksIDs{;
    *synth `y' `xVariables', tru(`tUnit')
    *  trp(`=monthly("2014M10","YM")') cou(`NonTBlocksIDs') figure;
    *npsynth `y'  `xVariables' `y'(`outputPeriod'), t_0(`=monthly("2014M10","YM")')
    *  panel_var(forestBLockID) time_var(time) trunit(`tUnit') kern(normal)
    *  bandw(.75);
  };
  log close;
};
restore;
#delimit cr
