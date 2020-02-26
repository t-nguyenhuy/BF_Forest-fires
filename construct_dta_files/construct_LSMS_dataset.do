local pprevId = $taskId-2


#delimit ;
use     zd OBJECTID  using "${intermFolder`pprevId'}/ZD_VILLAGE/zd_village_match.dta", clear;
keep    if OBJECTID !=.;



** Add extracted variables;
****** Number of enumeration zone level HH-s and average HH size;
merge   m:1 zd    using "$$currTempFold/emc2014_HH_size.dta",
    keepusing(N_HH avg_HHsize EstPop HH_educ*) keep(master match);
    drop _merge;

***** Share of agricultural households and share of lands collectively cultivated.;
merge m:1 zd          using "$$currTempFold/emc2014_agri_HH_shares.dta",
    keepusing(A5BIS mV07) keep(master match);
    drop _merge;

***** Share of agricultural households using fertilizers;
merge m:1 zd          using "$$currTempFold/emc2014_agri_intrants.dta",
    keepusing(org_fert inorg_fert other_fert) keep(master match);
    drop _merge;

***** Average household asset index (durable goods);
merge m:1 zd          using "$$currTempFold/emc2014_biensdurables.dta",
    keepusing(avg_dur_value) keep(master match);
    drop _merge;

***** Share of households using wood for lighting or cooking;
merge m:1 zd          using "$$currTempFold/emc2014_HH_logement.dta",
      keepusing(L08_LightingW L14_CookingW) keep(master match);
    drop _merge;

**** Land-intensive food consumption (in monetary terms and in share);
merge m:1 zd          using "$$currTempFold/emc2014_zd_cons7jours.dta",
      keepusing(landIntFoodCons landIntFoodConsSh) keep(master match);
    drop _merge;

**** Wood-based fuel (in monetary terms and in share);
merge m:1 zd          using "$$currTempFold/emc2014_zd_cons3mois.dta",
      keepusing(landIntFuelCons landIntFuelCons) keep(master match);
    drop _merge;



* Round-off variables, save labels, and generate totals;
qui   ds zd OBJECTID N_HH, not;
local varlist   "`r(varlist)'";
foreach varx in `r(varlist)'{;
    capture confirm string var    `varx';
    if _rc != 0 {;
        qui replace `varx'  = round(`varx',0.0001);
    };
    local l`varx':                variable label `varx';
};
bysort OBJECTID: egen nHH         = sum(N_HH);
bysort OBJECTID: egen EstTotPop   = sum(EstPop);



** Collapse, re-label, re-name and save;
collapse  (first) zd EstTotPop nHH  (mean) `varlist' [pweight=EstPop], by(OBJECTID);

foreach varx in `varlist'{;
    label variable `varx' "`l`varx''";
};

gen   lavg_dur_value = log(avg_dur_value);
label variable lavg_dur_value     "Log of average household durables value.";

drop   EstPop;
label variable  nHH         "Number of households";
label variable  EstTotPop   "Estimated population in ZD ~";
rename nHH        N_HH;
rename EstTotPop  EstPop;
save "$$currTempFold/LSMS_vars.dta", replace;
#delimit cr
