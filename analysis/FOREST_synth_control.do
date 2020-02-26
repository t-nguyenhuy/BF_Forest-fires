capture   log close

local prevId    = `1' - 1
local liveRun   `2'
local condition `5'

if ("`liveRun'" == "1"){
    capture shell rmdir     "$outputFolder/Synthetic" /s /q
    capture shell mkdir     "$outputFolder/Synthetic"
}

cd    "$outputFolder/Synthetic"


local execAnnualEst   = 0
local grapAnnualEst   = 1
local execMonthlyEst  = 0
local grapMonthlyEst  = 0



#delimit ;

if (1 == 1){;
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
    local   covVars   "gridid histFor_fire histFor_fireGr_fire";
    local   covVars   "gridid";
    drop    if year == 2018;

    keep forestid forest_name year `outCVars' post* gridid histFor* treatment;

    foreach y of varlist `outCVars'{;
        clear mata;
        clear results;
        clear matrix;

        *capture shell rmdir     "$outputFolder/Synthetic/`y'" /s /q;
        *capture shell mkdir     "$outputFolder/Synthetic/`y'";
        capture mkdir            "$outputFolder/Synthetic/`y'";

        cd    "$outputFolder/Synthetic/`y'";

        *preserve;

        if !("`5'"==""){;
            drop if `5';
        };

        *** Depending on the outcome variable, start of treatment is different;
        if ("`4'" == "2014") | ("`4'" == ""){;
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

        ** If non-imputed vegeation cover index, drop ones with missing value
        di "`y'";
        if (strpos("`y'","evi"))|(strpos("`y'","ndvi"))|(strpos("`y'","aE")>0){;
            di "In";
            gen                          miss_`y'_obs = (`y' == .);
            bysort  forestid: egen miss_`y'     = max(miss_`y'_obs);
            drop    if miss_`y' == 1;
            drop    miss_`y'_obs;
        };


        if (`execAnnualEst' == 1){;
            log using        "$outputFolder/Synthetic/`y'/synth_res_`y'.txt",t replace;

            capture erase   SC_`y'.dta;
            capture erase   TC_`y'.png;
            capture erase   EFF_`y'.png;


            synth_runner    `y'   `covVars'
                        `y'(2009) `y'(2010) `y'(2011) `y'(2012) `y'(2013),
                        d(`treatVar') keep(SC_`y') nested margin(0.05);
            log close;
        };

        merge 1:1 forestid year using SC_`y', nogen keep(match);
        gen   `y'_synth     = `y' - effect;

        if (`execAnnualEst' == 1){;
            effect_graphs,      tc_options(title(TC_`y'))
                                effect_options(title(EFF_`y'));
            graph export        "TC_`y'.png", name(tc) as(png) replace;
            graph export        "EFF_`y'.png", name(effect) as(png) replace;
        };


        bysort treatment year: egen `y'_TM        = mean(`y');
        bysort treatment year: egen `y'_synth_TM  = mean(`y'_synth);

        twoway (line `y'_TM year if (forestid == 1), lc(blue) lw(thick))
               (line `y'_synth_TM year if (forestid == 1), lc(red) lp(dash)),
               legend(label(1 "Treated") label(2 "Synthetic control"))
               xline(`startYear',lc(black))
               name(tc_manual);
        graph save tc_manual  "TC_`y'_manual.gph", replace;
        graph export          "TC_`y'_manual.png", width(7000) replace;

        if (`grapAnnualEst' == 1){;
            local names   "";
            forvalues i = 1(1)12{;
                if (("`5'"!="") & (strpos("`5'","`y'==`i'") == 0)) | ("`5'"==""){;
                    twoway (line `y' year if (forestid == `i'), lc(blue) lw(thick))
                           (line `y'_synth year if (forestid == `i'), lc(red) lp(dash)),
                           legend(label(1 "Treated") label(2 "Synthetic"))
                           xline(`startYear', lc(black))
                           title(F`i')
                           name(TC_`y'_`i');
                    graph save      "TC_`y'_`i'", replace;

                    local names   "`names' TC_`y'_`i'";
                };
            };

            graph combine `names', rows(4) cols(3) iscale(0.25);
            graph save Graph      "TC_`y'_forests.gph", replace;
            graph export          "TC_`y'_forests.png", width(7000) replace;
        };

        graph close _all;
        *restore;
    };

    cd    "$outputFolder/Synthetic/";
};
#delimit cr
