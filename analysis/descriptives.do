local     prevId  = `1' - 1

local execMonthlyVars 1
local execAnnualVars  1
local missingVars     1


capture   shell rmdir "$outputFolder/Descriptives" /s /q
          shell mkdir "$outputFolder/Descriptives"


**          Some descriptive time-series.
****        First for the full panel dataset;
capture   log close

shell   mkdir "$outputFolder/Descriptives/TS_graphs_full"
shell   mkdir "$outputFolder/Descriptives/TS_graphs_FIP"

****      First with monthly variables;
if (`execMonthlyVars' == 1){
  #delimit ;
  use "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;
      local   sample  "";

      forvalues i = 1(1)2{;
          preserve;
          if (`i' == 1){;
                local   sample "full";
          };
          else if (`i' == 2){;
                keep    if fip == 1;
                local   sample "FIP";
          };

          collapse
              (first)
                  time
              (mean)
                  fire      conf50      conf80
                  fireBurn  conf50Burn  conf80Burn
                  ndvi      evi         ndvi_imp      evi_imp
              ,by(year month);

          local outcomeVars   "fire* conf50* conf80* ndvi* evi*";
          foreach y of varlist `outcomeVars'{;
              twoway
                  (line `y' time if time >= `=monthly("2007M10","YM")' & time <= `=monthly("2014M10","YM")', msize(1) lcolor(blue)),
                  legend(label(1 "All forests"))
                  xline(`=monthly("2014M10","YM")', lcolor(black))
                  xlabel(`=monthly("2007M10","YM")'(12)`=monthly("2014M10","YM")',
                    angle(vertical));
              graph export "$outputFolder/Descriptives/TS_graphs_`sample'/TS_raw_`sample'_`y'.png",
                  width(7000) replace;
          };
          restore;
      };

  *** Generate one time series graph with all forests separately exhibited;
  #delimit ;
  use "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;
      local twowayGraphSeries   "";
      forvalues i=88(-1)1{;
          if (`i' != 86){;
              if (`i' <= 12){;
                  local lColor    "blue";
              };
              else {;
                  local lColor    "gray";
              };
              local twowayGraphSeries   "`twowayGraphSeries' (line conf50 time if forestid == `i', lcolor(`lColor'))";
          };
      };

      twoway `twowayGraphSeries',
        xline(`=monthly("2014M10","YM")', lcolor(black))
        xlabel(`=monthly("2004M1","YM")'(12)`=monthly("2018M10","YM")',
        angle(vertical)) note("Blue lines are treated, gray lines are non-treated forests")
        legend(off);
      graph export        "$outputFolder/Descriptives/fullS_forest_month_conf50.png",
          width(7000) replace;
  ** All forests fire on one plot;
  #delimit ;

  #delimit cr
}

****      Then with annual variables;
if (`execAnnualVars' == 1){
    #delimit ;
    use "${intermFolder`prevId'}/burkina_faso_fires-YEAR_FOREST.dta", clear;
        local   sample  "";

        forvalues i = 1(1)2{;
            preserve;
            if (`i' == 1){;
                  local   sample "full";
            };
            else if (`i' == 2){;
                  keep    if fip == 1;
                  local   sample "FIP";
            };

            collapse
                (mean)
                    rny_*    prs_*      dry_*        preR_*
                ,by(year);

            local outcomeVars   "prs_* dry_* preR_*";
            foreach y of varlist `outcomeVars'{;
                if (strpos(`"`y'"',"preR4_") > 0){;
                    local treatYear   2015;
                };
                else {;
                    local treatYear   2014;
                };

                twoway
                    (line `y' year if year >= 2008 & year <= 2014, msize(1)),
                    legend(label(1 "All forests"))
                    xline(`treatYear', lcolor(black))
                    xlabel(2008(2)2014);
                graph export "$outputFolder/Descriptives/TS_graphs_`sample'/TS_raw_`sample'_`y'.png",
                    width(7000) replace;
            };
            restore;
        };
    #delimit cr
}


****      Generate figures showing the extent of missing values in ndvi-evi;
if (`missingVars' == 1){
    #delimit ;
    use "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;

    shell   mkdir "$outputFolder/Descriptives/TS_missing_graphs";

    keep forestid fip treatment year month time miss* ndvi* evi*;
    ***** Generate Missing time series for Treatment, non-treated fip, and all non-treated forests;
    preserve;
        keep  if (fip == 1) & (treatment == 0); /// only non-treated FIP forests;
        replace treatment   = 2 if (treatment == 0);
        collapse
            (mean)
                miss*
            ,by(treatment time);

        tempfile  temp1;
        save      "`temp1'";
    restore;

    preserve;
        collapse
          (mean)
              miss*
          , by(treatment time);
        append using "`temp1'";

        foreach y in ndvi evi{;
          di "A";
            twoway (line miss`y' time if treatment == 1)
                   (line miss`y' time if treatment == 0)
                   (line miss`y' time if treatment == 2),
                legend(label(1 "Treated forests") label(2 "Non-treated forests")
                      label(3 "Non-treated FIP forests"))
                xline(`=monthly("2014M10","YM")', lcolor(black))
                xlabel(`=monthly("2004M1","YM")'(12)`=monthly("2018M10","YM")', angle(vertical));
          di "B";
            graph export "$outputFolder/Descriptives/TS_missing_graphs/TS_`y'_missing.png",
              width(7000) replace;
        };
    restore;

    ****  Generate some tables showing the months with high missing values in forest-month-level
    ****  ndvi or evi;

    preserve;
      drop  miss*;

      foreach y of varlist ndvi* evi*{;
          bysort treatment time:  gen miss`y'     = (`y' == .);
      };

      collapse
        (first)
          year  month
        (mean)
            missndvi* missevi*
        ,by(treatment time);

      gen timeString = string(year)+"M"+string(month);

      tabout timeString treatment if (missndvi > .6)&((month < 6)|(month > 8))
          using "$outputFolder/Descriptives/TS_missing_graphs/weakImp_time.tex",
          sum cells(mean missndvi) f(2) replace;
          *title(Months with high share of missing NDVI missing values at the forest level);

    restore;
    #delimit cr
}
