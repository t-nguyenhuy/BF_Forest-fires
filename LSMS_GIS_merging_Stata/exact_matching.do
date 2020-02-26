local sleeptime = $sleepTimeG

* Run manual exact matching - match if REGION, PROVINCE, COMMUNE AND VILLAGE name
* are exactly the same in the LSMS key and in the GIS settlement (the original
* OCHA) dataset
#delimit ;
set more off;
use "$$currIntermOut/ZD_VILLAGE/zd_village_original.dta", clear;
drop NZDRGPH NBMENAGE MILIEU;
drop if strpos(VILLAGE,"SECTEUR")>0; // For now disregard secteurs;
local numberLSMS = _N;
qui gen match_ID_1 = ""; qui gen match_ID_2 = ""; qui gen match_ID_3 = "";
qui gen match_IDExt_1 = ""; qui gen match_IDExt_2 = "";
qui gen match_IDExt_3 = ""; qui gen match_IDExt_4 = "";
save "$$currTempFold/zd_village_match.dta", replace;
sleep `sleeptime';
forvalues i=1(1)`numberLSMS'{;
	di `i';
	local regio = REGION[`i'];
	local provinc = PROVINCE[`i'];
	local commun = COMMUNE[`i'];
	local villag = VILLAGE[`i'];
	local matching_ID "";
	* First compare with the raw OCHA GIS settlement dataset;
	qui use "$$currIntermOut/GIS_settl/GIS_village.dta", clear;
	qui keep if (REGION==`"`regio'"')&(PROVINCE==`"`provinc'"')&(COMMUNE==`"`commun'"')
		&(VILLAGE==`"`villag'"');
	local selectN = _N;
	forvalues j=1(1)`selectN'{;
		local addingID = OBJECTID[`j'];
		local matching_ID "`matching_ID' `addingID'";
	};

	* Then with the extended GIS settlement dataset;
	local matching_ID2 "";
	qui use "$$currIntermOut/GIS_settl/GIS_villageExt.dta", clear;
	qui keep if (REGION==`"`regio'"')&(PROVINCE==`"`provinc'"')&(COMMUNE==`"`commun'"')
		&(VILLAGE==`"`villag'"');
	local selectN = _N;
	forvalues j=1(1)`selectN'{;
		local addingID = OBJECTID[`j'];
		local matching_ID2 "`matching_ID2' `addingID'";
	};
	qui use "$$currTempFold/zd_village_match.dta", clear;
	local counter=1;
	foreach ID of local matching_ID{;
		qui replace match_ID_`counter' = `"`ID'"' in `i';
		local counter= `counter' + 1;
	};
	local counter=1;
	foreach ID of local matching_ID2{;
		qui replace match_IDExt_`counter' = `"`ID'"' in `i';
		local counter= `counter' + 1;
	};
	*qui replace match_ID = subinstr(`"`matching_ID'"'," ","",1) in `i';
	*qui replace match_IDExt = subinstr(`"`matching_ID2'"'," ","",1) in `i';
	sleep `sleeptime';
	qui save "$$currTempFold/zd_village_match.dta", replace;
	macro drop _j _selectN _regio _provinc _commun _villag _matching_ID
		_matching_ID2 _addingID _counter;
};
qui gen matched = 0;
qui gen matchedExt = 0;
qui replace matched = 1 if match_ID_1!="";
qui replace matchedExt = 1 if match_IDExt_1!="";
destring match_*, replace;
macro drop _i _numberLSMS;
sleep `sleeptime';
qui save "$$currTempFold/zd_village_match.dta", replace;
#delimit cr
