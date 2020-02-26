*** Panel DID-s;
forvalues i = 1(1)2{;
    local sample "_d86";
    if `i'==1{;
      di ">> Forest grids - Full sample: ";
      keep if forestid!=86;
    };
    else {;
      di ">> Foresr grids - PIF sample:";
    };
    if `i'==2{;
        local sample "_d86_PIF";
        keep if fip == 1;
    };
    foreach y of local outcomeVariablesGrid{;
        di `"`y'"';
        qui xtreg `y' i.post##i.treatment i.year i.month, fe vce(cluster forestid);
        estimates store fe;
        outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", replace ctitle(FE, T:2014)
          keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

        qui xtreg `y' i.post##i.treatment##i.month i.year, fe vce(cluster forestid);
        estimates store fe_monthInter;
        outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2014)
          keep(1.post 1.post#1.treatment 1.post#1.treatment#i.month)
          addtext(Year FE, Yes, Month FE, Yes);

        qui xtreg `y' i.post2##i.treatment i.year i.month, fe vce(cluster forestid);
        outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2015)
          keep(1.post2 1.post2#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

        qui xtreg `y' i.post2##i.treatment##i.month i.year, fe vce(cluster forestid);
        outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(FE, T:2015)
          keep(1.post2 1.post2#1.treatment 1.post2#1.treatment#i.month)
          addtext(Year FE, Yes, Month FE, Yes);

        qui xtreg `y' i.post##i.treatment i.year i.month, re vce(cluster forestid);
        estimates store re;
        outreg2 using "`regOutputFold'/grid`sample'_`y'.doc", append ctitle(RE, T:2014)
          keep(1.post 1.post#1.treatment) addtext(Year FE, Yes, Month FE, Yes);

        qui xtreg `y' i.post##i.treatment i.year i.month `mean_LSMS_vars', re
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
