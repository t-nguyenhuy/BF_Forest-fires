local prevId = `1' - 1




*** This fiel takes the treatment effects from synthetic control estimator at the
*** forest block-levels and runs a panel RE regression on these post-2014 effects
*** with the 2014 LSMS variables as explanatory variables. Note: one forest block
*** corresponds with one village in the LSMS survey.
*** -- This panel RE regression relies on the estimated effects from the SC approach;
*** Outcome variable:   annual treatment effects for treated forest blocks
*** panel RE specif.:   Y_{it} = \alpha_i + \eta_t + \beta^\prime X_{i} + \varepsilon_{it}
*** Regression sample:  - annual treatment effect observation of treated forest blocks
***                     (4 years for 25 blocks)
*** NOTE:               - forest block-level SC estimates are still in work-in-progress

***   Define the path to the presults of the SC estimator;
local estimatesFolder "$outputFolder/Synthetic/Blocks/"


#delimit ;
if (1==1){;
  clear mata;
  clear results;
  clear matrix;


  use     "${intermFolder`prevId'}/burkina_faso_fires_forestblock-YEAR.dta", clear;
  xtset   forestBlockID year;
  keep    if forestid < 86;
  keep    if gridid >= 15;
  drop    if year == 2018;


  ***   Define relevant variables;
  local otherCov    "gridid";
  local covVars     "HH_educ_prim HH_educ_second_fin N_HH avg_HHsize lavg_dur_value A5BIS org_fert inorg_fert";
  local outCVars    "fire11";


  *** Standardization of 2014 LSMS variables - constant over time
  *** (~comparability in interpretatin of coeffients);
  foreach x of varlist `covVars'{;
      egen    m`x'  = mean(`x');
      egen    s`x'  = sd(`x');
      replace `x'   = (`x'-m`x') / s`x';
      drop m`x' s`x';
  };

  *** Relabel names for the coefplot figures;
  label variable N_HH           "N of households";
  label variable inorg_fert     "% of HH using inorg. fert.";
  label variable org_fert       "% of HH using org. fert.";
  label variable lavg_dur_value "ln(Household asset value)";
  label variable HH_educ_prim   "% of HH head with prim. educ.";
  label variable avg_HHsize     "Avg. HH size";
  label variable A5BIS          "% of agricultural HHs";
  label variable HH_educ_second_fin "% of HH head with second. educ.";



  *** Begin loop for all outcome variables in the list;
  foreach y of local outCVars{;
    *** At the moment only results for one outcome variable;
    *** Add previous treatment effect results from the SC estimator;
    merge 1:1 forestBlockID year using "`estimatesFolder'fire11_SF_012020\SC_fire11.dta", nogen keep(match);

    preserve;
        *** Restrict sample and set of relevant variables;
        keep if treatment == 1;
        keep forestBlockID forestid forest_name year effect `y' `covVars';


        *** panel RE regressions;
        xtreg effect `covVars' i.year if year >= 2014, re vce(robust);
        estimates store y2014;


        *** Plot coefficients;
        coefplot (y2014 , keep(`covVars')),  mlabpos(5)
                          mlabel( cond(@pval<=.05, string(@b,"%4.3f")+"**", "") )
                          title("Heterogenous effects") legend(off) sort;
        graph save      "`estimatesFolder'fire11_SF_012020\Heterogenous_effects", replace;
        graph export    "`estimatesFolder'fire11_SF_012020\Heterogenous_effects.png", replace;

      restore;
  };
};
#delimit cr
