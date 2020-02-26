capture   log close

local prevId    = `1' - 1
local liveRun   `2'
local condition `5'

if ("`liveRun'" == "1"){
    capture shell rmdir     "$outputFolder/Synthetic/ADD_RES" /s /q
}
capture shell mkdir     "$outputFolder/Synthetic/ADD_RES"

cd "$outputFolder/Synthetic/ADD_RES"

local execAnnualEst = 1
local execFullPast  = 1
local execPlacMouhn = 1
local execSelForest = 1
local grapAnnualEst = 1

#delimit ;
if (1==1){;
    clear mata;
    clear results;
    clear matrix;

    use "${intermFolder`prevId'}/burkina_faso_fires-YEAR_FOREST.dta", clear;
    xtset     forestid year;
    keep      if forestid <= 70;

    *** Define outcome and covariate variables;
    if ("`3'" == ""){;
        local   outCVars  "fire1";
    };
    else {;
        local   outCVars  "`3'";
    };
    local   covVars   "gridid";
    drop    if year == 2018;

    keep forestid forest_name year `outCVars' `covVars' post* treatment;

    *** Loop over outcome variables;
    foreach y of varlist `outCVars'{;
        clear mata;
        clear results;
        clear matrix;

        capture mkdir       "$outputFolder/Synthetic/ADD_RES/`y'";
        cd                  "$outputFolder/Synthetic/ADD_RES/`y'";

        ** Sample selection to adjust work non-working forests;
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

        local xStartT    = 2007;
        local xEndT      = `startYear';
        qui numlist      "`xStartT'/`xEndT'", integer ascending;
        local mspePer    "`r(numlist)'";


        **** Loop over different robust tests;
        forvalues testType=1(1)3{;
            preserve;
            local     executeFlag     = 0;
            local     executeGrpFlag  = 0;
            *** Specify robustness test parameters;
            if (`testType'==1) & (`execFullPast'==1){;
                *** Type1: Include all past outcomes to the SC estimates;
                ***         General robustness of the estimates;
                *** Define specific parameters;
                local fileExt         "`y'_FULLP";
                local specification = "`y' `covVars' " +
                                      "`y'(2004) `y'(2005) `y'(2006) `y'(2007) " +
                                      "`y'(2008) `y'(2009) `y'(2010) `y'(2011) " +
                                      "`y'(2012) `y'(2013)";
                local executeFlag    = (`testType'==1) * `execAnnualEst' * `execFullPast';
                local executeGrpFlag = (`testType'==1) * `grapAnnualEst' * `execFullPast';
            };
            else if (`testType'==2) & (`execPlacMouhn'==1){;
                *** Type2: Placebo estimates for the control forests along the Mouhoun river;
                ***        Robustness check against spillover effect;
                *** Define specific parameters;
                local fileExt         "`y'_PLCMHN";
                local specification = "`y' `covVars' " +
                                      "`y'(2009) `y'(2010) `y'(2011) `y'(2012) " +
                                      "`y'(2013)";
                local executeFlag     = (`testType'==2) * `execAnnualEst' * `execPlacMouhn';
                local executeGrpFlag  = (`testType'==2) * `grapAnnualEst' * `execPlacMouhn';

                *** Specific data manipulation;
                drop      if (treatment==1);
                replace   treatment = 1     if (mouhoun_main==1) & (treatment==0);
                replace   postTreatment   = treatment * post;
                replace   post2Treatment  = treatment * post2;

            };
            else if (`testType'==3) & (`execSelForest'==1){;
                *** Type3: Original estimates but dropping control villages along the Mouhoun river;
                ***        Robustness check against spillover effect;
                *** Define specific parameters;
                local fileExt         "`y'_SF";
                local specification = "`y' `covVars' " +
                                      "`y'(2009) `y'(2010) `y'(2011) `y'(2012) " +
                                      "`y'(2013)";
                local executeFlag     = (`testType'==3) * `execAnnualEst' * `execSelForest';
                local executeGrpFlag  = (`testType'==3) * `grapAnnualEst' * `execSelForest';
                *** Specific data manipulation;
                drop      if (treatment==0) & (neighb_T==1);
            };


            di "Checkpoint. Test type: `testType'; Annual Est: `execAnnualEst'; Execfullpas: `execFullPast'; Execute flag: `executeFlag'";
            if (`executeFlag'==1){;
                *** Run estimations if relevant flags are aligned;
                log using     "$outputFolder/Synthetic/ADD_RES/`y'/synth_res_`fileExt'",t replace;

                capture erase   SC_`fileExt'.dta;
                capture erase   TC_`fileExt'.png;
                capture erase   EFF_`fileExt'.png;

                synth_runner    `specification',
                                d(`treatVar') keep(SC_`fileExt') margin(0.05);
                log close;
            };


            *** Start of graphing section;
            if (`executeFlag'==1) | (`executeGrpFlag'==1){;
              **    Merge with estimated treatment effects;
              merge 1:1 forestid year using SC_`fileExt', nogen keep(match);
              gen   `y'_synth     = `y' - effect;

              if (`executeFlag'==1){;
                  effect_graphs,      tc_options(title(TC_`fileExt'))
                                      effect_options(title(EFF_`fileExt'));
                  graph export        "TC_`fileExt'.png", name(tc) as(png) replace;
                  graph export        "EFF_`fileExt'.png", name(effect) as(png) replace;
              };

              bysort treatment year: egen `y'_TM          = mean(`y');
              bysort treatment year: egen `y'_synth_TM    = mean(`y'_synth);

              *** Get the ID-s of treated units;
              qui   levelsof forestid if (treatment==1);
              local treatUnits      "`r(levels)'";
              local fID    = `: word 1 of `treatUnits'';

              *** Generate Treated-Synthetic Outcome graphs for treated units;
              twoway (line `y'_TM year if forestid==`fID', lc(blue) lw(thick))
                     (line `y'_synth_TM year if forestid==`fID', lc(red) lp(dash)),
                     legend(label(1 "Treated") label(2 "Synthetic control"))
                     xline(`startYear',lc(black))
                     name(tc_manual);
              graph  save tc_manual   "TC_`fileExt'_manual.png", replace;
              graph  export           "TC_`fileExt'_manual.png", width(7000) replace;

              *** Generate forest-level T-synthC graphs;
              if (`grapAnnualEst' == 1){;
                  local names     "";
                  foreach id of local treatUnits{;
                      twoway (line `y' year if (forestid==`id'), lc(blue) lw(thick))
                             (line `y'_synth year if (forestid==`id'), lc(red) lp(dash)),
                             legend(label(1 "Treated") label(2 "Synthetic"))
                             xline(`startYear', lc(black))
                             title(F`id')
                             name(TC_`fileExt'_`id');
                      local names   "`names' TC_`fileExt'_`id'";
                  };

                  graph combine `names', cols(3) iscale(0.25);
                  graph save Graph      "TC_`fileExt'_forests.gph", replace;
                  graph export          "TC_`fileExt'_forests.png", width(7000) replace;

              };
              *** End of forest-level graphs;
              graph close _all;
            };
            *** End of Graphing section;
            restore;
        };
        **** End of loop over testTypes;
    };
    *** End of loop over outcome variables;
    cd      "$outputFolder/Synthetic/";
};
*** Main if end;

#delimit cr
