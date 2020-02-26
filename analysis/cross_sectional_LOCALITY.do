capture     log close


***     This file runs a cross-sectional regresion to find relevant determinants
***     of fire occurrence. Outcome variable: average fireoccurrence pre-treatment
***     between 2010-2013 (right before PIF). Explanatory variables: 2014 LSMS variables.


local prevId        = `1'- 1
local liveRun       `2'
local cwFolder      "$outputFolder/Descriptives/cross_sectional_local/"

if "`liveRun'"=="1"{
    capture shell rmdir "`cwFolder'" /s /q
}
capture shell mkdir "`cwFolder'"
cd      "`cwFolder'"


#delimit ;
  clear mata;
  clear results;
  clear matrix;

  use     "${intermFolder`prevId'}/burkina_faso_fires_forestblock-YEAR.dta", clear;
  xtset   forestBlockID year;
  keep    if forestid < 86;
  keep    if gridid >= 10;      // Note:  Sampling blocks with at least 10 grids;
  drop    if year == 2018;

  *** Define outcome variables;
  if ("`3'" == "")    local   outCVars  "fire11 fire12";
  if ("`3'" != "")    local   outCVars  "`3'";


  local       covVars   = "           N_HH            avg_HHsize " +
                          "HH_educ_prim       HH_educ_second_fin           " +
                          "org_fert           inorg_fert        lavg_dur_value " +
                          "A5BIS";
  keep        forestBlockID forestid year `outCVars' `covVars' post* treatment;

  ** Cross-sectional;
  *preserve;
    drop  if year <= 2010 | year > 2013;


    *** Standardization of 2014 LSMS variables - constant over time
    *** (~comparability in interpretatin of coeffients);
    foreach x of varlist `covVars' {;
        egen m`x' = mean(`x');
        egen s`x' = sd(`x');
        replace `x' = (`x' - m`x') / s`x';
    };


    label variable N_HH           "N of households";
    label variable inorg_fert     "% of HH using inorg. fert.";
    label variable org_fert       "% of HH using org. fert.";
    label variable lavg_dur_value "ln(Household asset value)";
    label variable HH_educ_prim   "% of HH head with prim. educ.";
    label variable avg_HHsize     "Avg. HH size";
    label variable A5BIS          "% of agricultural HHs";
    label variable HH_educ_second_fin "% of HH head with second. educ.";


    log using   "cross_sec_res_`y'", t replace;
        foreach y of varlist `outCVars'{;
            ***   Calculate average outcome variable;
            bysort forestBlockID (year): egen avg_`y' = mean(`y');

            ***    Cross sectional regression;
            reg avg_`y' `covVars' if year == 2013   & N_HH < 5, vce(cluster forestid);
            estimates store `y';

            twoway (scatter N_HH avg_`y' if year == 2013);
            graph export "N_HH-vs-avg_`y'.png", replace;
        };
    log close;


    ***   Plot coefficients;
    coefplot fire11,  drop(_cons) xline(0) mlabpos(5)
                          mlabel( cond(@pval<=.05, string(@b,"%4.3f")+"**", "") )
                          title("Correlates of fire occurrences")
                          subtitle("Fire occurrence average bw. 2010-2013 (N=167)");
                          *legend(order(2 "November" 4 "December"));

    graph save    "Descriptive_regression.gph", replace;
    graph export  "Descriptive_regression.png", replace;
  *restore;

#delimit cr
