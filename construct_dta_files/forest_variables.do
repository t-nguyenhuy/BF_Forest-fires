#delimit ;
use "$rawDataFolder/Forest_fire_panel/burkina_faso_fires_fullpanel.dta", clear;
drop if (year!=2017)&(month!=12);
keep forestid forest_name gridid;
collapse (first) forest_name (count) gridid, by(forestid);
rename gridid forestSize;
label variable forestSize "Captured by the number of grids";
tempfile forestSizeData;
save "`forestSizeData'";
* save "$$currTempFold/forest_size.dta", replace;

** Then calculate the measure of pre-treatment fire occurrences;
**** Two types of measures:;
**** (i): forest level aggregate capturing the number of grids on fire over the years;
**** (ii): probability of being burned;
use "$rawDataFolder/Forest_fire_panel/burkina_faso_fires_fullpanel.dta";
keep if year < 2014;
gen fireGr = (fire>0);
gen fireGr_conf50 = (confidence50>0);
gen fireGr_conf80 = (confidence80>0);
gen fireDumPr = (fire>0);
gen fireDumPr_conf50 = (confidence50>0);
gen fireDumPr_conf80 = (confidence80>0);


collapse (sum) fire confidence50 confidence80 fireGr fireGr_conf50
  fireGr_conf80 (mean) fireDumPr fireDumPr_conf50 fireDumPr_conf80, by(year forestid);
collapse (mean) fire confidence50 confidence80 fireGr fireGr_conf50
  fireGr_conf80 (mean) fireDumPr fireDumPr_conf50 fireDumPr_conf80, by(forestid);
merge 1:1 forestid using "`forestSizeData'", nogen;
drop forest_name;
order forestid ;



label variable fireGr "Total number of forest fires";
label variable fireGr "Total number of grids burnt in this forest";
label variable fireGr_conf50 "Total number of grids burnt in this forest (with at least 50% conf.)";
label variable fireGr_conf80 "Total number of grids burnt in this forest (with at least 80% conf.)";
label variable fireDumPr "Probability that grids in this forest were burnt";
label variable fireDumPr_conf50 "Probability that grids in this forest were burnt (with at least 50% conf.)";
label variable fireDumPr_conf80 "Probability that grids in this forest were burnt (with at least 80% conf.)";
local renameList "fire confidence50 confidence80 fireGr fireGr_conf50 fireGr_conf80 fireDumPr fireDumPr_conf50 fireDumPr_conf80";
foreach var of local renameList{;
  rename `var' histFor_`var';
};
save "$$currTempFold/forest_data.dta", replace;
erase "`forestSizeData'";
#delimit cr
