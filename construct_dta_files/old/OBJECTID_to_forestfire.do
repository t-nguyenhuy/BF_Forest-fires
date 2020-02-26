#delimit ;
clear;

* First, add the ID of the settlement ID-s linked to the forest grids to the;
* dataset and the forest_level variables;
* --> match gridid to OBJECTid;
*** Convert the forest grid - settlement link csv file to a STATA dataset;
local prevId = $taskId-1;
local pprevId = $taskId-2;
import delimited "${intermFolder`prevId'}/forestgrid_settlement_assignments.csv";
rename inputid gridid;
rename targetid OBJECTID;
***** Remove duplicates;
bysort gridid: gen dup = cond(_N==1,0,_n);
drop if dup>1;
drop dup;
save "$$currTempFold/forestgrid_settlement_assignments.dta",replace;

*** Merge the linked settlement ID-s to the forest grid panel;
use "$rawDataFolder/Forest_fire_panel/burkina_faso_fires_fullpanel.dta", clear;
  merge m:1 gridid using "$$currTempFold/forestgrid_settlement_assignments.dta", nogen;
  *save "$$currTempFold/burkina_faso_fires_fullpanel.dta", replace;
  *** Then, merge forest_level-variables;
  merge m:1 forestid using "$$currTempFold/forest_data.dta", nogen;
  save "$$currTempFold/burkina_faso_fires_fullpanel.dta", replace;

* Second, add the enumeration zone identifiers to the dataset and the covariates;
* from the LSMS survey;
* --> match OBJECT to zd;
  **** Add enumeration identifiers;
  merge m:m OBJECTID using "${intermFolder`pprevId'}/ZD_VILLAGE/zd_village_match.dta",
    keepusing(zd) keep(match) nogen;
  **** Add LSMS covariates;
  ****** Number of enumeration zone level HH-s and average HH size;
  merge m:1 zd using "$$currTempFold/emc2014_HH_size.dta",
   keepusing(N_HH avg_HHsize EstPop) keep(match);
  drop _merge;

  ***** Share of households using wood for lighting or cooking;
  merge m:1 zd using "$$currTempFold/emc2014_HH_logement.dta",
    keepusing(L08_LightingW L14_CookingW) keep(match);
  drop _merge;

  **** Land-intensive food consumption (in monetary terms and in share);
  merge m:1 zd using "$$currTempFold/emc2014_zd_cons7jours.dta",
    keepusing(landIntFoodCons landIntFoodConsSh) keep(match);
  drop _merge;

  **** Wood-based fuel (in monetary terms and in share);
  merge m:1 zd using "$$currTempFold/emc2014_zd_cons3mois.dta",
    keepusing(landIntFuelCons landIntFuelCons) keep(match);
  drop _merge;

  sleep 2000;
  **** Complete treatment variable before saving;
  bysort forestid: egen maxT = max(treatment);
  replace maxT = 0 if forestid==86;
  replace treatment = maxT;
  drop maxT;
save "$$currTempFold/burkina_faso_fires_fullpanel.dta", replace;


**** Collapse the dataset to the forest-block level;
  keep if thresh_`1' == 1;
  **** Outcome variables: Generate probabilities of being burnt;
  gen burntP = (fire > 0);
  gen burntP_conf50 = (confidence50 > 0);
  gen burntP_conf80 = (confidence80 > 0);

  bysort year month forestid zd: gen forestBlockID = forestid * 1000 + zd;
  collapse (first) forestid forest_name fip treatment area OBJECTID histFor_fire
    histFor_confidence50 histFor_confidence80 histFor_fireGr histFor_fireGr_conf50
    histFor_fireGr_conf80 histFor_fireDumPr histFor_fireDumPr_conf50
    histFor_fireDumPr_conf80 forestSize avg_HHsize N_HH EstPop L08_LightingW
    L14_CookingW landIntFoodCons landIntFoodConsSh landIntFuelCons (count) gridid
    (sum) fire confidence50 confidence80 (mean) burntP burntP_conf50 burntP_conf80,
    by(year month forestBlockID);
    // 136 forestBlocks before 2014; 154 after;

  **** Define panel structure;
  gen time = monthly(string(year)+"m"+string(month),"YM");
  format time %tm;
  xtset forestBlockID time, monthly;
  gen post = time >= monthly("2014m10","YM");

  **** Outcome variables: Generate scaled forest-block-level fire numbers;
  gen fire_scaled = fire / gridid;
  gen confidence50_scaled = confidence50 / gridid;
  gen confidence80_scaled = confidence80 / gridid;

save "$currIntermOut/burkina_faso_fires_forestblock.dta", replace;
#delimit cr
