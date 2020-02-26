capture   log close

local prevId  = `1' - 1

cd "$outputFolder/Synthetic/ADD_RES"


*** This file takes the panel of treated, control, and synthetic control forests
*** and runs a panel-DID regression where the treatment indicator is interacted
*** with an LSMS variable (averaged for at the forest-level).
*** -- This panel-DID regression relies on the estimated Synthetic Controls;
*** Outcome variable:   fire occurrence
*** DID specification:  Y_{it} = \alpha_i + \eta_t + \text{D}^{\text{PostT}}_{it}
***                              +  \beta_2 \text{D}^{\text{PostT}}_{it} X_{i}
***                              + \varepsilon_{it}


#delimit ;
if (1==1){;
    clear mata;
    clear results;
    clear matrix;

    use "${intermFolder`prevId'}/burkina_faso_fires-YEAR_FOREST.dta", clear;
    xtset   forestid year;
    keep    if forestid <= 75;
    drop    if year == 2018;

    *** Define outcome;
    if ("`3'" == "")      local   outCVars  "fire11";
    if ("`3'" == "1")      local   outCVars  "`3'";


    local otherCov    "gridid";
    local covVars     "HH_educ_prim HH_educ_second_fin N_HH avg_HHsize avg_dur_value A5BIS org_fert inorg_fert";
    *  mV07;
    keep forestid forest_name year `outCVars' `otherCov' `covVars' post* treatment
          mouhoun_main neighb_T;


    *** Begin the loop over all outcome variables in the list;
    foreach y of varlist `outCVars'{;
        clear mata;
        clear results;
        clear matrix;
        local   fileExt         "`y'_SF";

        cd    "$outputFolder/Synthetic/ADD_RES/`y'";


        ***     Use the more robust result without controls forests neighboring T forests;
        drop    if treatment==0 & neighb_T==1;
        drop    mouhoun_main neighb_T;

        *** Standardization of 2014 LSMS variables - constant over time
        *** (~comparability in interpretatin of coeffients);
        foreach x of varlist `covVars'{;
            egen    m`x'  = mean(`x');
            egen    s`x'  = sd(`x');
            replace `x'   = (`x'-m`x') / s`x';
            drop m`x' s`x';
        };


        *** Generate the panel of synthetic control outcomes and add to the original
        *** dataset;
        preserve;
            merge 1:1 forestid year using SC_fire11_SF, nogen keep(match);
            gen   `y'_synth = `y' - effect;

            keep      if treatment  == 1;
            replace   `y'           = `y'_synth       if year >= 2014;
            replace   forestid      = forestid + 100;
            replace   treatment     = 0;
            replace   postTreatment = 0;
            replace   post2Treatment= 0;
            drop      lead effect *rmspe `y'_synth;

            tempfile  syntheticOutcomes;
            save      `syntheticOutcomes';
        restore;

        append using `syntheticOutcomes', gen(appended);
        xtset forestid year;




        *** Relabel names for the coefplot figures;
        label variable N_HH           "N of households";
        label variable inorg_fert     "% of HH using inorg. fert.";
        label variable org_fert       "% of HH using org. fert.";
        label variable avg_dur_value "Household asset value";
        label variable HH_educ_prim   "% of HH head with prim. educ.";
        label variable avg_HHsize     "Avg. HH size";
        label variable A5BIS          "% of agricultural HHs";
        label variable HH_educ_second_fin "% of HH head with second. educ.";


        *** Generate the interaction term of the treatment indicator and the LSMS variables;
        *** ~ this allows coefplots to directly refer to the interaction coeff-s;
        foreach x of varlist `covVars'{;
            gen `x'_interaction = `x' * postTreatment;
            local lbl: variable label `x';
            di "`lbl'";
            label variable `x'_interaction "`lbl'";
        };


        *** Run the panel DID regressions separately for each LSMS variable;
        local coefplots "";
        foreach x of varlist `covVars'{;
            log using "$outputFolder/Synthetic/ADD_RES/`y'/het_eff_`x'", t replace;
            local condition "if forestid<=12 | forestid>100";

            *** Regressions;
            xtreg `y' c.`x'##i.treatment##i.post i.year             , fe vce(robust);
            xtreg `y' c.`x'##i.treatment##i.post i.year `condition' , fe vce(robust);
            xtreg `y' i.postTreatment `x'_interaction i.year `condition' , fe vce(robust);
            estimates store d_`x';

            ***   Only store the last regression which compares the panel of treated
            ***   forests and the panel of their synthetic controls;
            ***   (that is control forests are dropped)

            local coefplots "`coefplots' (d_`x', keep(`x'_interaction))";
            log close;
        };


        *** Plot the estimated interaction terms reflecting heterogeneity;
        coefplot `coefplots' ,  xline(0) mlabpos(5)
                                mlabel( cond(@pval<=.05, string(@b,"%4.3f")+"**", "") )
                                title("Heterogenous effects") legend(off) sort;
        graph save        "$outputFolder/Synthetic/ADD_RES/`y'/Heterogenous_effects", replace;
        graph export      "$outputFolder/Synthetic/ADD_RES/`y'/Heterogenous_effects.png", replace;
    };
    *** End the loop over all outcome variables in the list;
};

#delimit cr
