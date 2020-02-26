local prevId = `1'-1
local replaceFlag 0

capture shell rmdir "$outputFolder/Non-matched regressions" /s /q
shell mkdir "$outputFolder/Non-matched regressions"

#delimit ;
local regOutputFold "$outputFolder/Non-matched regressions";
local outcomeVariablesBlock "fire_scaled confidence50_scaled confidence80_scaled ndvi evi";
local outcomeVariablesGrid "fire confidence50 confidence80 ndvi evi";
local outcomeVariablesGrid "ndvi evi";
local LSMS_variables "area histFor_confidence50 EstPop L08_LightingW L14_CookingW
                      landIntFoodConsSh";
local mean_LSMS_vars "";
#delimit cr


**** Regression using grid-level observations
#delimit ;
use "${tempFolder`prevId'}/burkina_faso_fires_fullpanel.dta", clear;
  gen forestGrid = gridid * 100 + forestid;
  gen time = monthly(string(year)+"m"+string(month),"YM");
  format time %tm;
  xtset forestGrid time, monthly;
  *keep if (year > 2006);

  gen post = time >= monthly("2014m10","YM");
  gen post2 = (time>=monthly("2015M10","YM"));
  foreach y of local outcomeVariablesGrid{;
      bysort forestGrid: egen avg_`y' = mean(`y');
  };
  foreach x of local LSMS_variables{;
      bysort forestGrid: egen avg_`x' = mean(`x');
      local mean_LSMS_vars "`mean_LSMS_vars' avg_`x'";
  };

    *** Panel DID-s;
    forvalues i = 1(1)2{;
        local sample "_d86_VEG";
        if `i'==1{;
          di ">> Forest grids - Full sample: ";
          keep if forestid!=86;
        };
        else {;
          di ">> Forest grids - PIF sample:";
        };
        if `i'==2{;
            local sample "_d86_VEG_PIF";
            keep if fip == 1;
        };
        foreach y of local outcomeVariablesGrid{;
            di `"`y'"';
            local cond "";
            if (`"`y'"'=="ndvi")|(`"`y'"'=="evi"){;
              local cond "if avg_`y'>0";
            };
            qui xtreg `y' i.post##i.treatment i.year i.month `cond', fe vce(cluster forestid);
            estimates store fe;
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", replace ctitle(FE, T:2014)
              keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment##i.month i.year `cond', fe vce(cluster forestid);
            estimates store fe_monthInter;
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2014)
              keep(1.post 1.post#1.treatment 1.post#1.treatment#i.month)
              addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post2##i.treatment i.year i.month `cond', fe vce(cluster forestid);
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2015)
              keep(1.post2 1.post2#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post2##i.treatment##i.month i.year `cond', fe vce(cluster forestid);
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2015)
              keep(1.post2 1.post2#1.treatment 1.post2#1.treatment#i.month)
              addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment i.year i.month `cond', re vce(cluster forestid);
            estimates store re;
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(RE, T:2014)
              keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment i.year i.month `mean_LSMS_vars' `cond', re
              vce(cluster forestid);
            qui test `mean_LSMS_vars';
              local ChiTPval = round(r(p),.001);
            outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(CRE, T:2014)
                keep(1.post 1.post#1.treatment) addstat("Wald-test",`ChiTPval')
                addtext(Year FE, Yes, Month FE, Yes);

            *hausman fe re, sigmamore;
            estimates clear;
        };
    };
  #delimit cr

  /*
  **** Regessions using forest blocks;
  #delimit ;
  use "${intermFolder`prevId'}/burkina_faso_fires_forestblock_thresh999.dta", clear;
    keep if forestid!=86;
    gen post2 = (time>=monthly("2015M10","YM"));
    forvalues i=1(1)2{;
        if `i'==1{;
          di ">> Forest blocks - Full sample: ";
        };
        else {;
          di ">> Foresr blocks - PIF sample:";
        };
        local sample "";
        if `i'==2{;
            local sample "_PIF";
            keep if fip == 1;
        };
        foreach y of local outcomeVariablesBlock{;
            di `"`y'"';
            qui xtreg `y' i.post##i.treatment i.year i.month, fe vce(cluster forestid);
            estimates store fe;
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", replace ctitle(FE, T:2014)
              keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment##i.month i.year, fe vce(cluster forestid);
            estimates store fe_monthInter;
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", append ctitle(FE, T:2014)
              keep(1.post 1.post#1.treatment 1.post#1.treatment#i.month)
              addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post2##i.treatment i.year i.month, fe vce(cluster forestid);
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", append ctitle(FE, T:2015)
              keep(1.post2 1.post2#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post2##i.treatment##i.month i.year, fe vce(cluster forestid);
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", append ctitle(FE, T:2015)
              keep(1.post2 1.post2#1.treatment 1.post2#1.treatment#i.month)
              addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment i.year i.month, re vce(cluster forestid);
            estimates store re;
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", append ctitle(RE, T:2014)
              keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

            qui xtreg `y' i.post##i.treatment i.year i.month `LSMS_variables', re
              vce(cluster forestid);
            qui test `LSMS_variables';
              local ChiTPval = round(r(p),.001);
            outreg2 using "`regOutputFold'/blocks`sample'_`y'.doc", append ctitle(CRE, T:2014)
                keep(1.post 1.post#1.treatment) addstat("Wald-test",`ChiTPval')
                addtext(Year FE, Yes, Month FE, Yes);

            *hausman fe re, sigmamore;
            estimates clear;
        };
    };
  #delimit cr
  */
