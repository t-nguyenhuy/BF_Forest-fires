local prevId = `1'-1

capture shell rmdir "$outputFolder/Non-matched regressions-IV" /s /q
shell mkdir "$outputFolder/Non-matched regressions-IV"
local regOutputFold "$outputFolder/Non-matched regressions-IV"

local outcomeVariablesGrid "Fire Conf50 Conf80 Ndvi Evi"


use "${intermFolder`prevId'}/burkina_faso_fires_fullpanel_YEARLY.dta", clear
**** Note that forestid == 86 (Sahelien area) is dropped from this dataset;
xtset forestGridId year, yearly
gen postTreatment = post * treatment

#delimit ;
foreach outcPer in dry intR{;
    ***** Base specification;
    foreach variable of local outcomeVariablesGrid{;
      estimates clear;
      xi: xtivreg2 `outcPer'`variable' post treatment i.year
          (prs`variable'= postTreatment), first savefirst fe  cluster(forestid);
      estimates store secondstage;
      estimates restore _xtivreg2_prs`variable';
      estimates store firststage;
      estimates dir;
      if `"`variable'"'=="Fire"{;
          local outregMode "replace";
      };
      else {;
          local outregMode "append";
      };
      estimates restore firststage;
      outreg2 using "`regOutputFold'/grid_id_iv_`outcPer'.doc",
          `outregMode' ctitle("FE-IV - FS, `variable'")
          drop(i.year);
      estimates restore secondstage;
      outreg2 using "`regOutputFold'/grid_id_iv_`outcPer'.doc",
          append ctitle("FE-IV - SS, `variable'")
          drop(i.year);
    };


    ***** Specification from forest fire to vegetation cover;
    #delimit ;
    foreach x in Fire Conf50 Conf80{;
        foreach variable in Ndvi Evi{;
            estimates clear;
            xi: xtivreg2 `outcPer'`variable' post treatment i.year
                (prs`x' = postTreatment), first savefirst fe
                cluster(forestid);
            estimates store secondstage;
            estimates restore _xtivreg2_prs`x';
            estimates store firststage;
            estimates dir;
            if `"`variable'"'=="Ndvi"{;
                local outregMode "replace";
            };
            else {;
                local outregMode "append";
            };
            estimates restore firststage;
            outreg2 using "`regOutputFold'/grid_id_iv_`outcPer'_FV_`x'.doc", `outregMode'
                ctitle("FE-IV - FS,`variable'")
                drop(i.year);
            estimates restore secondstage;
            outreg2 using "`regOutputFold'/grid_id_iv_`outcPer'_FV_`x'.doc", append
                ctitle("FE-IV - FS,`variable'")
                drop(i.year);
        };
    };

};
#delimit cr
