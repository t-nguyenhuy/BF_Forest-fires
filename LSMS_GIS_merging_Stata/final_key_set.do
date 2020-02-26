* Load the result from exact matching and add the results from the fuzzy string
* comparison

** Convert the results from the fuzzy string comparison from excel to dta
#delimit ;
import excel "$rawDataFolder/missing_matches.xls", sheet("RESULTS")
	firstrow clear;
drop ID ID2;
save "$$currTempFold/fuzzy_matching_keys.dta", replace;
#delimit cr

** Add the results from the fuzzy matching to the exact matching results
#delimit ;
use "$$currTempFold/zd_village_match.dta", clear;
destring match_*, replace;
merge m:1 zd using "$$currTempFold/fuzzy_matching_keys.dta",
	keepusing(OBJECTID OBJECTID2) gen(_merge_fuzzy);
drop if _merge_fuzzy==2;
replace OBJECTID = match_ID_1 if OBJECTID==.;
replace OBJECTID = match_IDExt_1 if OBJECTID==.;
#delimit cr

** Copy GIS settlement variables to the dataset
#delimit ;
foreach x of varlist REGION PROVINCE COMMUNE VILLAGE{;
	rename `x' `x'_LSMS;
};
merge m:1 OBJECTID using "$$currIntermOut/GIS_settl/GIS_villageExt.dta",
	keepusing(REGION PROVINCE COMMUNE VILLAGE) gen(_merge_gis);
drop if _merge_gis==2;
gsort +zd;
foreach x of varlist REGION PROVINCE COMMUNE VILLAGE{;
	rename `x' `x'_GIS;
};
order zd *_LSMS OBJECTID *_GIS match_* _merge*;
forvalues i=1(1)3{;
	rename match_ID_`i' e_m_ID_`i';
};
forvalues i=1(1)4{;
	rename match_IDExt_`i' e_m_IDExt_`i';
};
save "$$currIntermOut/ZD_VILLAGE/zd_village_match.dta", replace;
export excel zd *_LSMS OBJECTID *_GIS using
	"$$currIntermOut/ZD_VILLAGE/zd_village_match.xls", firstrow(variables) replace;
#delimit cr
