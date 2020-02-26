#delimit ;
clear;
local thresholds "0 `1'";
* First, add the ID of the settlement ID-s linked to the forest grids to the;
* dataset and the forest_level variables;
* --> match gridid tomerge_to_main_dataset.do OBJECTid;
**** Convert the forest grid - settlement link csv file to a STATA dataset;
local prevId    = $taskId-1;
local pprevId   = $taskId-2;

local mainFullDataset 1;

if (`mainFullDataset'==1){;
    forvalues i=1(1)1{;
      if `i'==1{;
          local filename "forestgrid_settlement_assignments";
          local varPostFix "";
      };
      else {;
          local filename "forestgrid_settlement_assignments_p`1'";
          local varPostFix "2";
      };

      import delimited "${intermFolder`prevId'}/`filename'.csv", clear;
          rename inputid gridid;
          rename targetid OBJECTID`varPostFix';
          ***** Remove duplicates;
          bysort gridid: gen dup = cond(_N==1,0,_n);
          drop if dup>1;
          drop dup;
      save "$${currTempFold}/`filename'.dta",replace;
    };


    **** Convert grid edge data to STATA format from .CSV;
    import delimited       "${tempFolder`prevId'}/edgDist_pFIP_grids.csv", clear;
        rename distance     dist_aEdge;
        rename areaedge     aEdge;
        label variable dist_aEdge "Distance from the edge of forestry area (not the edge of gazetted forest).";
        label variable aEdge      "Dummy: edge of forestry area (not the edge of gazetted forest).";
        tempfile  tempF1;
        save      "`tempF1'";

    import delimited        "${tempFolder`prevId'}/edgDist_pnonFIP_grids.csv", clear;
        rename distance     dist_aEdge;
        rename areaedge     aEdge;
        label variable      dist_aEdge "Distance from the edge of forestry area (not the edge of gazetted forest).";
        label variable      aEdge      "Dummy: edge of forestry area (not the edge of gazetted forest).";
        append using        "`tempF1'";
        save                "${tempFolder`prevId'}/edgDist_grids.dta", replace;






    use "$rawDataFolder/Forest_fire_panel/burkina_faso_fires_fullpanel.dta", clear;
        *** Merge the linked settlement ID-s to the forest grid panel;
        *** Then, merge forest_level-variables;
        merge m:1 gridid      using "$$currTempFold/forestgrid_settlement_assignments.dta", nogen;
        merge m:1 forestid    using "$$currTempFold/forest_data.dta", nogen;
        sleep 2000;
        save "$$currTempFold/burkina_faso_fires_fullpanel.dta", replace;

        * Second, add the enumeration zone identifiers to the dataset and the covariates;
        * from the LSMS survey;
        * --> match OBJECT to zd;

        **** Add enumeration identifiers;
        merge m:m OBJECTID    using "${intermFolder`pprevId'}/ZD_VILLAGE/zd_village_match.dta",
          keepusing(zd) keep(master match) nogen;


        **** Add LSMS covariates;
            ****** Number of enumeration zone level HH-s and average HH size;
            merge m:1 zd          using "$$currTempFold/emc2014_HH_size.dta",
             keepusing(N_HH avg_HHsize EstPop HH_educ*) keep(master match);
            drop _merge;

            ***** Share of agricultural households and share of lands collectively cultivated.;
            merge m:1 zd          using "$$currTempFold/emc2014_agri_HH_shares.dta",
              keepusing(A5BIS mV07) keep(master match);
            drop _merge;

            ***** Share of agricultural households using fertilizers;
            merge m:1 zd          using "$$currTempFold/emc2014_agri_intrants.dta",
              keepusing(org_fert inorg_fert other_fert) keep(master match);
            drop _merge;

            ***** Average household asset index (durable goods);
            merge m:1 zd          using "$$currTempFold/emc2014_biensdurables.dta",
              keepusing(avg_dur_value) keep(master match);
            drop _merge;

            ***** Share of households using wood for lighting or cooking;
            merge m:1 zd          using "$$currTempFold/emc2014_HH_logement.dta",
              keepusing(L08_LightingW L14_CookingW) keep(master match);
            drop _merge;

            **** Land-intensive food consumption (in monetary terms and in share);
            merge m:1 zd          using "$$currTempFold/emc2014_zd_cons7jours.dta",
              keepusing(landIntFoodCons landIntFoodConsSh) keep(master match);
            drop _merge;

            **** Wood-based fuel (in monetary terms and in share);
            merge m:1 zd          using "$$currTempFold/emc2014_zd_cons3mois.dta",
              keepusing(landIntFuelCons landIntFuelCons) keep(master match);
            drop _merge;

        sleep 2000;

        **** Merge ndvi and evi vegetation cover variables;
        merge 1:1 forestid gridid year month
            using "$rawDataFolder/Forest_fire_panel/ndvi_evi_allgrids_2000_2018.dta",
            keepusing(ndvi landsat landsat_dup fip evi);

        **** Merge distance to green area edge;
        merge m:m gridid            using "${tempFolder`prevId'}/edgDist_grids.dta",
                keep(master match) nogen;




        **  !!!!!!!!!!!!!!!!!!!!!!
        ** Construct and change relevant variables;
        **** Forest-grid id since some grids are related to more forests;
        gen forestGridId        = gridid * 100 + forestid;

        **** Complete treatment variable before saving;
        replace       treatment = 1 if forestid <= 12;
        replace       treatment = 0 if forestid > 12;

        ** Generate time variable for panel data format;
        gen time            = monthly(string(year)+"m"+string(month), "YM");
        format time %tm;

        ** Treating negative and missing values of ndvi and evi;
        foreach y of varlist ndvi evi{;
            * https://gis.stackexchange.com/questions/284480/aggregating-averaging-ndvi-across-pixels-arithmetic-mean-seems-bad-choice;
            *** This suggests to set negative values to zero before averaging NDVI over grids.;
            gen     trunc`y'   = `y' if `y'>0;
            replace trunc`y'   = 0 if `y'<=0;

            bysort  forestGridId: egen mean`y'    = mean(`y');
            bysort  forestGridId: egen min`y'     = min(`y');

            gen     miss`y'   = (`y' == .);
            label variable miss`y'    "=(`y' == .)";
        };

        ** Fire occurrence variables;
        rename confidence50   conf50;
        rename confidence80   conf80;

        foreach y of varlist fire conf50 conf80{;
            gen `y'Burn       = (`y' > 0);
        };

        ** Generate "averaged agricultural period variables";
        **** Define agricultural seasons;
        gen     agrSeason       = year      if month > 5;
        replace agrSeason       = year - 1  if month <= 5;

        *** Generate period variables;
        *** ## Start loop ##;
        forvalues seas = 1(1)4{;
            *** Generate periods and corresponding pre-variables;
            if (`seas' == 1){;
                local varNam   "rny_";
                local pMonth   "(month==6)|(month==7)|(month==8)";
            };
            else if (`seas' == 2){;
                local varNam   "prs_";
                local pMonth   "(month==9)|(month==10)";
            };
            else if (`seas' == 3){;
                local varNam   "dry_";
                local pMonth   "(month==11)|(month==12)|(month==1)|(month==2)";
            };
            else if (`seas' == 4){;
                local varNam   "preR_";
                local pMonth   "(month==3)|(month==4)|(month==5)";
            };


            *** Generate the variables;
            foreach var in fire fireBurn conf50 conf50Burn conf80 conf80Burn ndvi evi {;
                di    ">> Generate seasonal variable for: `var'.";
                qui bysort forestGridId agrSeason: egen `varNam'`var'   = mean(`var')  if `pMonth';
        		    qui bysort forestGridId agrSeason: egen `varNam'`var'_s = mean(`varNam'`var');
        		    qui bysort forestGridId agrSeason: replace `varNam'`var' = `varNam'`var'_s;
                drop      `varNam'`var'_s;

                qui replace `varNam'`var'   = .           if (month <= 5);
                qui bysort forestGridId year:      egen `varNam'`var'_s  = mean(`varNam'`var');
                qui bysort forestGridId year:   replace `varNam'`var'    = `varNam'`var'_s;
                drop      `varNam'`var'_s;
            };
        };
        *** ## END LOOP ##;

    sort forestid gridid year month;
    order forestid    forest_name   fip           treatment
          gridid      gridid        agrSeason
          time        year month    t21           fire       fireBurn
          confidence  conf50        conf50Burn    conf80     conf80Burn
          ndvi        evi;

    rename histFor_confidence50   histFor_conf50;
    rename histFor_confidence80   histFor_conf80;
    rename histFor_fireGr         histFor_fireGr_fire;
    rename histFor_fireDumPr      histFor_fireDumPr_fire;

    winsor2 ndvi evi,    cut(5 96) by(time forestid) label;

    replace area = area / 1000000;
    label variable area "Forest area in square kilometers";

    label define  monthLabels
        1 "M1"    2 "M2"
        3 "M3"    4 "M4"
        5 "M5"    6 "M6"
        7 "M7"    8 "M8"
        9 "M9"    10 "M10"
        11 "M11"  12 "M12";
    label values month  monthLabels;


    save "$$currTempFold/burkina_faso_fires_fullpanel.dta", replace;
};




* Rest is for generating forest-block based dataset;
local forestBlockDataset  1;

if (`forestBlockDataset' == 1){;
  use     "$$currTempFold/burkina_faso_fires_fullpanel.dta", clear;

  drop    if (minndvi <= 0)|(minevi <= 0);

  **** Collapse the dataset to the forest-block level;
  ****** - One set with all LSMS villages;
  ****** - Another set with <=15km LSMS villages;
  foreach thresh of local thresholds{;
      preserve;
          if (`thresh' != 0){;
              keep    if thresh_`thresh' == 1;
          };
          bysort time forestid zd:  gen   forestBlockID = forestid * 1000 + zd;
          collapse (first)  forestid  forest_name fip   treatment agrSeason time
                            area      OBJECTID    histFor*        forestSize
                            avg_HHsize        HH_educ*      N_HH      EstPop
                            A5BIS     mV07    *_fert        avg_dur_value
                            L08_LightingW     L14_CookingW  landInt*
                   (count)  gridid
                   (mean)   fire*   conf50*   conf80*   ndvi*   evi*
                            distance  dist_aEdge
                            miss*   trunc*
                            rny*    prs*      dry*      preR*,
                    by(year month forestBlockID);

          xtset forestBlockID time, monthly;

          if (`thresh' == 0){;
                save  "$currIntermOut/burkina_faso_fires_forestblock.dta", replace;
          };
          else {;
                save  "$currIntermOut/burkina_faso_fires_forestblock_thrs`thresh'.dta", replace;
          };

      restore;
  };
};

#delimit cr
