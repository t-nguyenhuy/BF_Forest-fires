capture   log close
**** Paramaters handled:
* - 1: Task number
* - 2: Whether it is a live-run
* - 3: Outcome variable
* - 4: Start of the treatment
* - 5: Sample selection

local     prevId       =  `1' -1
local     liveRun       `2'
local     execFireEsts = 1
local     cwFolder      "$outputFolder/Synthetic/Blocks"
local     nested       "nested"

if ("`liveRun'" == "1"){
    capture shell rmdir   "`cwFolder'" /s /q
}
cd        "`cwFolder'"
local     dispYMin    2008

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

    *** Define outcome variables;
    if ("`3'" == ""){;
        local   outCVars  "fire11";
    };
    else {;
        local   outCVars  "`3'";
    };
    local       covVars   = "distance           EstPop            avg_HHsize " +
                            "HH_educ_prim       HH_educ_second_fin           " +
                            "org_fert           inorg_fert        lavg_dur_value " +
                            "A5BIS";
    keep        forestBlockID forestid year `outCVars' `covVars' post* treatment;

    foreach y of varlist `outCVars'{;
        clear mata;
        clear results;
        clear matrix;

        capture mkdir       "`cwFolder'/`y'";
        cd                  "`cwFolder'/`y'";

        ** Sample selection to adjust for problematic blocks;
        if !("`5'"==""){;
            drop if `5';
        };

        *** Establish treatment indicator variable;
        if ("`4'"=="2014") | ("`4'"==""){;
            local treatVar  "postTreatment";
            local startYear 2014;
            if ("`4'" == ""){;
                di "Warning: no year was specified as the beginning of the treatment. Def.: 2014.";
            };
        };
        else if ("`4'" == "2015"){;
            local treatVar  "post2Treatment";
            local startYear 2015;
            local covVars   "`covVars' `y'(2014)";
        };

        local xStartT     = 2007
        local xEndT       = `startYear';
        qui numlist       "`xStartT'/`xEndT'", integer ascending;
        local mspePer     "`r(numlist)'";

        ** If non-imputed vegetation cover index, drop Blocks with missing value;
        if (strpos("`y'","evi")|strpos("`y'","ndvi")|strpos("`y'","aE")){;
            gen                     miss_`y'_obs = (`y' == .);
            bysort forestBlockID:   egen miss_`y'   = max(miss_`y'_obs);
            drop                    if miss_`y' == 1;
            drop                    miss_`y'_obs;
        };

        if (`execFireEsts'==1){;
              log using "synth_res_`y'_BLOCK.txt", t replace;

              capture erase   SC_`y'.dta;
              capture erase   TC_`y'.png;
              capture erase   EFF_`y'.png;


              synth_runner    `y' `covVars'
                              `y'(2005) `y'(2006) `y'(2007) `y'(2008)
                              `y'(2009) `y'(2010) `y'(2011) `y'(2012) `y'(2013),
                              d(`treatVar') keep(SC`y') `nested' margin(0.05);
              log close;
        };

        capture confirm file "SC_`y'.dta";

        *** Built-in graphs;
        if (1==1) & (_rc==0){;

            merge 1:1             forestBlockID year using "SC_`y'.dta", nogen keep(match);
            gen	  `y'_synth		    = `y' - effect;

            if (`execFireEsts' == 1){;
              effect_graphs,      tc_options(title(TC_`y'))
                                  effect_options(title(EFF_`y'));
              graph export        "TC_`y'.png", name(tc) as(png) replace;
              graph export        "EFF_`y'.png", name(effect) as(png) replace;
            };


              *** Manually formatted graphs;
              bysort treatment year: egen `y'_TM            = mean(`y');
              bysort treatment year: egen `y'_synth_TM      = mean(`y'_synth);

              capture graph drop              tc_manual;
              qui levelsof  forestBlockID     if treatment==1;
              local   unitT                   `: word 1 of `r(levels)'';
              twoway (line `y'_TM     year if forestBlockID==`unitT' & year > `dispYMin', lc(blue) lw(thick))
                     (line `y'_synth_TM  year if forestBlockID==`unitT' & year > `dispYMin', lc(red) lp(dash)),
                     legend(label(1 "Treated") label(2 "Synthetic control"))
                     xline(`startYear', lc(black))
                     ytitle("Fire occurrence")
                     name(tc_manual);
              graph  save tc_manual  "TC_manual.png", replace;
              graph  export          "TC_manual.png", width(7000) replace;



              *** EFF_manual;
              local  graphS "";
              qui levelsof  forestBlockID     if treatment==1;
              foreach ID in `r(levelsof)'{;
                  local graphS =
                    "`graphS' (line effect  year if forestBlockID==`ID' & year > `dispYMin', lc(blue))";
              };
              twoway `graphs',  legend(label(1 "Effect"))     xline(`startYear', lc(black))
                                ytitle("Effect")
                                name(eff_manual);
              graph  save eff_manual  "EFF_manual", replace;
              graph export            "EFF_manual.png", width(7000) replace;

        };

        capture graph close _all;
        capture graph drop TC_manual;
        capture graph drop EFF_manual;
        capture graph drop effect;

    };
};

#delimit cr




** Sc Estimates on forest fires;
/*
if (`execFireEsts' == 1){;
    ** Define outcome variables to be analyzed;
    * local outCVars "dry3_fireBurn dry3_conf50 dry3_conf50Burn";
    local outCVars "dry3_fireBurn dry3_conf50 dry3_conf50Burn";
    local outCVars    "fire11 ";

    *** Define the parameters of the SCM analysis;
    qui   numlist     "2004/2013", integer ascending;
    local mspePer     "`r(numlist)'";

    foreach y of local outCVars{;
        if (strpos("`y'","fire") > 0){;
            local baseVar   "fire";
        };
        else if (strpos("`y'","conf50") > 0){;
            local baseVar   "conf50";
        };
        else if (strpos("`y'","conf80") > 0){;
            local baseVar   "conf80";
        };


        use     "${intermFolder`prevId'}/burkina_faso_fires_forestblock-ANNUAL.dta", clear;

        ** Drop incomplete year and forest blocks that are less than 5km^2;
        drop    if forestid == 86;
        drop    if (year <= 2003) | (year  == 2018);
        drop    if gridid_M   <= 5;
        drop    if forestBlockID == 12489;
        xtset   forestBlockID year;

        ** Define and select "covariates";
        local   covS      "histFor_`baseVar'_M    histFor_fireGr_`baseVar'_M
                          histFor_fireDumPr_`baseVar'_M
                          avg_HHsize    EstPop    ";
        *L08_LightingW   L14_CookingW;
        keep    `y'       year  gridid_M  forestid forestBlockID
                          `covS'      postTreatment;

        log using         "$outputFolder/Synthetic/synth_res_`y'_BLOCK.txt", t replace;

        capture erase     SC_`y'_BLOCK.dta;
        capture erase     TC_`y'_BLOCK.png;
        capture erase     EFF_`y'_BLOCK.png;

        synth_runner      `y'   `covS',
                          d(postTreatment) mspeperiod("`mspePer'")
                          keep(SC_`y'_BLOCK) nested;

                          di "pval_joint_post `=e(pval_joint_post)'";
                          di "pval_joint_post_t `=e(pval_joint_post_t)'";
                          di "avg_pre_rmspe_p `=e(avg_pre_rmspe_p)'";
                          di "avg_val_rmspe_p `=e(avg_val_rmspe_p)'";


        ** Generate graphs showing actual and estimated outcomes, and T effects;
        merge 1:1         forestBlockID year    using SC_`y'_BLOCK, nogen;
        gen `y'_synth     = `y' - effect;

        effect_graphs;
        graph export      "TC_`y'_BLOCK.png", name(tc) as(png) replace;
        graph export      "EFF_`y'_BLOCK.png", name(effect) as(png) replace;


        log close;
        sleep 2000;


    };

};
*/
