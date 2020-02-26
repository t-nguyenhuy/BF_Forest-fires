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
              ,by(treatment year month);

          local outcomeVars   "fire* conf50* conf80* ndvi* evi*";
          foreach y of varlist `outcomeVars'{;
              twoway
                  (line `y' time if treatment == 1, msize(1))
                  (line `y' time if treatment == 0),
                  legend(label(1 "Treated forests") label(2 "Non-treated forests"))
                  xline(`=monthly("2014M10","YM")', lcolor(black))
                  xlabel(`=monthly("2004M1","YM")'(12)`=monthly("2018M10","YM")',
                    angle(vertical));
              graph export "$outputFolder/Descriptives/TS_graphs_`sample'/TS_raw_`sample'_`y'.png",
                  width(7000) replace;
          };
          restore;
      };


  *** Updated figures;
  use if year < 2018 using "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;
      keep forestid fip treatment year month time  fire fireBurn conf50 conf50Burn conf80 conf80Burn;

      collapse (first) time ///
		           (mean) fire* conf50* conf80* ,by(treatment year month);

      foreach y in fire fireBurn conf50 conf50Burn conf80 conf80Burn{;
          twoway  (bar `y' time if (year<2018)&(treatment==0), col(gray) fi(inten20))
                  (line `y' time if (year < 2018) & (treatment == 1), lc(blue)),
                xline(`=monthly("2014M10","YM")', lcolor(black))
                xlabel(`=monthly("2004M1","YM")'(12)`=monthly("2017M12","YM")', angle(vertical))
                legend(order(2 1) label(1 "Control forests") label(2 "Treated forests"))
                yscale(range(0 1)) ylabel(0(0.2)1) xtitle("Time");

          graph export "$outputFolder/Descriptives/TS_graphs_full/TS_raw_full_TC_`y'.png", width(7000) replace;
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
                    rny1_*    prs2_*      dry3_*        preR4_*
                ,by(treatment year);

            local outcomeVars   "prs2_* dry3_* preR4_*";
            foreach y of varlist `outcomeVars'{;
                if (strpos(`"`y'"',"preR4_") > 0){;
                    local treatYear   2015;
                };
                else {;
                    local treatYear   2014;
                };

                twoway
                    (line `y' year if treatment == 1, msize(1))
                    (line `y' year if treatment == 0),
                    legend(label(1 "Treated forests") label(2 "Non-treated forests"))
                    xline(`treatYear', lcolor(black))
                    xlabel(2004(2)2018);
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
    use if year < 2018 using "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;

    shell   mkdir "$outputFolder/Descriptives/TS_missing_graphs";

    keep forestid fip treatment year month time miss* ndvi* evi*;
    ***** Generate Missing time series for Treatment, non-treated fip, and all non-treated forests;
    preserve;
        collapse (first) time
                  (mean) miss* ,by(treatment year month);

        foreach y in ndvi evi{;

          twoway  (bar `y' time if (year<2018)&(treatment==0), col(gray) fi(inten20))
                  (line `y' time if (year < 2018) & (treatment == 1), lc(blue)),
                xline(`=monthly("2014M10","YM")', lcolor(black))
                xlabel(`=monthly("2004M1","YM")'(12)`=monthly("2017M12","YM")', angle(vertical))
                legend(order(2 1) label(1 "Control forests") label(2 "Treated forests"))
                yscale(range(0 1)) ylabel(0(0.2)1) xtitle("Time");

            graph export "$outputFolder/Descriptives/TS_missing_graphs/TS_`y'_missing.png",
              width(7000) replace;
        };
    restore;

    ****  Generate some table showing the months with high missing values in forest-month-level
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
