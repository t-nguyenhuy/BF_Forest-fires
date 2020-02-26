* Preparing Data for fuzzy string comparison
use "$$currTempFold/zd_village_match.dta", clear // Should be
***** drop matched_2 match_ID_2
drop if matched==1
save "$$currTempFold/zd_village_match_FUZZY_set.dta", replace

* Generate similarity scores using fuzzy string comparison.
#delimit ;
matchit zd VILLAGE using "$$currIntermOut/GIS_settl/GIS_villageExt.dta",
	idusing(OBJECTID) txtusing(VILLAGE);
#delimit cr

save "$$currTempFold/matching_village_afterFMatching.dta", replace

use "$$currTempFold/matching_village_afterFMatching.dta", clear

* Adding REGION, PROVINCE, COMMUNE and VILLAGE name variables to the
* comparison to help manual checking of the fuzzy matching.
#delimit ;
merge m:1 zd using "$$currTempFold/zd_village_match_FUZZY_set.dta",
	keepusing(REGION PROVINCE COMMUNE) gen(_mergekey);
rename REGION REGION_key;
rename PROVINCE PROVINCE_key;
rename COMMUNE COMMUNE_key;
merge m:m OBJECTID using "$$currIntermOut/GIS_settl/GIS_villageExt.dta",
	keepusing(REGION PROVINCE COMMUNE) gen(_mergeGIS);
gen regprovcomm_match = (REGION_key==REGION)&(PROVINCE_key==PROVINCE)&
	(COMMUNE_key==COMMUNE);
gsort +zd -similscore;
order zd OBJECTID similscore regprovcomm_match REGION* PROVINCE* COMMUNE*
	VILLAGE* _merge*;
save "$$currTempFold/fuzzy_matching_results.dta", replace;
*br zd OBJECTID similscore regprovcomm_match REGION* PROVINCE* COMMUNE* VILLAGE*
*	_merge* if (regprovcomm_match==1)|(similscore>.8);
#delimit cr
