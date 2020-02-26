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
local execFullPast  = 0
local execPlacMouhn = 0
local execSelForest = 1
local grapAnnualEst = 1

** For the graphs
local yAxisMax      = 1
local dispYMin      = 2004

**
local addRes  "/ADD_RES"

*local nestedFlag  "nested"
local marginSC    0.02

*
* exceptions
* Tiogo, Noussebou, Koulbi, Bontioli2
* 2	4	8	9	10

#delimit ;
if (1==1){;
    clear mata;
    clear results;
    clear matrix;

    use "${intermFolder`prevId'}/burkina_faso_fires-YEAR_FOREST.dta", clear;
    xtset     forestid year;
    keep      if forestid <= 75;
    drop    if year == 2018;

    *** Define outcome;
    if ("`3'" == ""){;
        local   outCVars  "fire1";
    };
    else {;
        local   outCVars  "`3'";

    };

    local yTitleT "Couverture végétale (EVI)";
    local yTitleT "Fire occurrence";

    local   covVars   "gridid";

    replace forest_name = "Ouro"        if forestid==1;
    replace forest_name = "Tiogo"       if forestid==2;
    replace forest_name = "Tisse"       if forestid==3;
    replace forest_name = "Nossebou"    if forestid==4;
    replace forest_name = "Sorobouli"   if forestid==5;
    replace forest_name = "Toroba"      if forestid==6;
    replace forest_name = "Kari"        if forestid==7;
    replace forest_name = "Koulbi"      if forestid==8;
    replace forest_name = "Bontioli (Reserve Totale)"      if forestid==9;
    replace forest_name = "Bontioli (Reserve Partielle)"      if forestid==10;
    replace forest_name = "Nazinon"      if forestid==11;
    replace forest_name = "Tapoa-Boopo"      if forestid==12;

    gen post16          = (year >= 2016);
    gen post16Treatment = post16 * treatment;

    keep forestid forest_name year `outCVars' `covVars' post* treatment
         mouhoun_main neighb_T;

    *** Loop over outcome variables;
    foreach y of varlist `outCVars'{;
        clear mata;
        clear results;
        clear matrix;

        capture mkdir       "$outputFolder/Synthetic`addRes'/`y'";
        cd                  "$outputFolder/Synthetic`addRes'/`y'";

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
        else if ("`4'" == "2016"){;
            local treatVar  "post16Treatment";
            local startYear 2016;
            local covVars   "`covVars' `y'(2014) `y'(2015)";
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
                                      "`y'(2005) `y'(2006) `y'(2007) " +;
                                      "`y'(2008) `y'(2009) `y'(2010) `y'(2011) " +
                                      "`y'(2012) `y'(2013)";
                local executeFlag    = (`testType'==1) * `execAnnualEst' * `execFullPast';
                local executeGrpFlag = (`testType'==1) * `grapAnnualEst' * `execFullPast';

                * "`y'(2004) `y'(2005) `y'(2006) `y'(2007) " +;
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
                replace   treatment = 1     if (neighb_T==1) & (treatment==0);
                replace   postTreatment   = treatment * post;
                replace   post2Treatment  = treatment * post2;

            };
            else if (`testType'==3) & (`execSelForest'==1){;
                *** Type3: Original estimates but dropping control villages along the Mouhoun river;
                ***        Robustness check against spillover effect;
                *** Define specific parameters;
                local fileExt         "`y'_SF";
                local specification = "`y' `covVars' " +
                                      "`y'(2005) `y'(2006) `y'(2007) `y'(2008) " +
                                      "`y'(2009) `y'(2010) `y'(2011) `y'(2012) " +
                                      "`y'(2013)";
                local executeFlag     = (`testType'==3) * `execAnnualEst' * `execSelForest';
                local executeGrpFlag  = (`testType'==3) * `grapAnnualEst' * `execSelForest';
                *** Specific data manipulation;
                drop      if (treatment==0) & (neighb_T==1);
            };
            *local fileExt "`y'";

            di "Checkpoint. Test type: `testType'; Annual Est: `execAnnualEst'; Execfullpas: `execFullPast'; Execute flag: `executeFlag'";
            if (`executeFlag'==1){;
                *** Run estimations if relevant flags are aligned;
                log using     "$outputFolder/Synthetic`addRes'/`y'/synth_res_`fileExt'",t replace;

                capture erase   SC_`fileExt'.dta;
                capture erase   TC_`fileExt'.png;
                capture erase   EFF_`fileExt'.png;

                synth_runner    `specification',
                                d(`treatVar') keep(SC_`fileExt') margin(`marginSC') `nestedFlag';
                sctabout,       excelfile("$outputFolder/Synthetic`addRes'/output.xlsx") sheetname("Results");
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
              twoway (line `y'_TM year if (forestid==`fID')&(year>`dispYMin'), lc(blue) lw(thick))
                     (line `y'_synth_TM year if (forestid==`fID')&(year>`dispYMin'), lc(red) lp(dash)),
                     legend(label(1 "Traitement") label(2 "Contrôle estimé"))
                     xline(`startYear',lc(black)) ytitle()
                     xtitle(Année)
                     yscale(r(0 `yAxisMax')) ylabel(0(0.2)`yAxisMax') xscale(r(`dispYMin' 2017)) xlabel(`dispYMin'(2)2017)
                     name(tc_manual);
              graph  save tc_manual   "TC_`fileExt'_manual.png", replace;
              graph  export           "TC_`fileExt'_manual.png", width(7000) replace;

              *** Generate forest-level T-synthC graphs;
              if (`grapAnnualEst' == 1){;
                  local names     "";
                  *foreach id of local treatUnits{;
                  * 1 3 5 6 7 11 12;
                  foreach id in 1 2 3 4 5 6 7 8 9 10 11 12{;
                      qui levelsof forest_name if forestid==`id';
                      local F_name `r(levels)';
                      twoway (line `y' year if (forestid==`id')&(year>`dispYMin'), lc(blue) lw(thick))
                             (line `y'_synth year if (forestid==`id')&(year>`dispYMin'), lc(red) lp(dash)),
                             legend(label(1 "Traitement") label(2 "Contrôle estimé"))
                             xline(`startYear', lc(black))
                             ytitle(Couverture végétale (EVI))
                             xtitle(Année)
                             yscale(r(0 `yAxisMax')) ylabel(0(0.2)`yAxisMax') xscale(r(`dispYMin' 2017)) xlabel(`dispYMin'(2)2017)
                             title(`F_name',size(huge))
                             name(TC_`fileExt'_`id');
                      graph save TC_`fileExt'_`id'    "TC_`fileExt'_f`id'_`F_name'", replace;
                      graph export                    "TC_`fileExt'_f`id'_`F_name'.png", width(7000) replace;
                      local names   "`names' TC_`fileExt'_`id'";
                  };

                  graph combine `names',  iscale(0.25);
                  * cols(3);
                  graph save Graph      "TC_`fileExt'_forests.gph", replace;
                  graph export          "TC_`fileExt'_forests.png", width(7000) replace;

              };
              *** End of forest-level graphs;
              capture graph close _all;
              capture graph drop tc_manual;
              capture graph drop effect;
              capture graph drop TC*;
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
