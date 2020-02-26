local   collapseForestData  1
local   distanceSample      1
local   collapseBlockData   1

if (`collapseForestData' == 1){
#delimit ;
    *** First, with the grid level dataset;
    use "$$currTempFold/burkina_faso_fires_fullpanel.dta", clear;

    ** Drop non-relevant observations;
    drop    if forestid      ==  86;
    drop    if (year <= 2003);
    drop    if (minndvi <= 0 )|(minevi <= 0);


    ** Generate outcome variables with non-aEdge variables;
    if (`distanceSample' == 1){;
        **** First generate the list of variables;
        local outCs   "";
        foreach var of varlist fire* conf50* conf80* ndvi* evi* rny_*
                               prs_* dry_* preR_* miss*{;
                local  outCs  "`outCs' `var'";
        };
        **** Then generate the related outcome variables;
        forvalues thresh = 1000(400)1800{;
            di    "Current threshold: `thresh' meters.";
            gen   nDist_`thresh'_d = (dist_aEdge >= `thresh');
            bysort forestid time:   egen nDist_`thresh'_a   = sum(nDist_`thresh'_d);
            bysort forestid:        egen nDist_`thresh'     = median(nDist_`thresh'_a);
            drop      nDist_`thresh'_d nDist_`thresh'_a;

            local i = 0;
            foreach var of local outCs{;
                  local i = `i' + 1;
                  di ">> Current variable: `var' ~ (`i' / 44).";
                  bysort forestid time: egen `var'_aE`thresh'_m   = mean(`var')
                                                              if dist_aEdge >= `thresh';
                  bysort forestid time: egen `var'_aE`thresh'     = mean(`var'_aE`thresh');
                  drop    `var'_aE`thresh'_m;
            };
        };
    };

    *** First generate forest-monthly data;
    collapse
        (first)
              forest_name     fip     treatment     agrSeason   year    month
              area            forestSize  histFor_* nDist*
        (count)
              gridid
        (mean)
              fire*   conf50*   conf80*   ndvi*    evi*
              rny_*   prs_*     dry_*     preR_*
              miss*
              avg_HHsize      HH_educ*    N_HH     EstPop
              A5BIS   mV07*   *fert      avg_dur_value
              L08_LightingW   L14_CookingW          landInt*
        ,by(forestid time);
        label variable missndvi   "Share of grids with missing ndvi value.";
        label variable missevi   "Share of grids with missing evi value.";

    gen post            = (time > =monthly("2014M10", "YM"));
    gen postTreatment   = post * treatment;
    gen post2           = (time >= monthly("2015M10", "YM"));
    gen post2Treatment  = post2 * treatment;




    ** Imputing ndvi and evi values;
    foreach y in ndvi evi{;
        **** Identify weak imputations;
        bysort treatment time: egen     weakImp_`y'    = count(`y');
        bysort treatment time: replace  weakImp_`y'    = ((weakImp_`y'/_N) <= 0.4);
        label variable  weakImp_`y'   "Indicator whether share of missing obs-s across forests is higher than 0.6 or not.";

        **** Imputing mean of winsorized values;
        bysort treatment time: egen      `y'_wm         = mean(`y'_w);
        gen                              `y'_imp        = `y';
        replace                          `y'_imp        = `y'_wm      if `y' ==.;
        drop    `y'_wm;
        label variable  `y'_imp       "Imputed `y' variables with the winsorized means across treatment forests.";
    };


    ** Generate annaul averages;
    foreach var of varlist    fire* conf* ndvi* evi*{;
        bysort forestid year:   egen  `var'_aAvg    = mean(`var');
        bysort forestid year:   egen  `var'_aAvgnR_T= mean(`var')
              if (month!=6)&(month!=7)&(month!=8);
        bysort forestid year:   egen  `var'_aAvgnR  = mean(`var'_aAvgnR_T);
        drop    `var'_aAvgnR_T;
    };





    ** Generate new periodic vegetation cover variables with the imputed outcomes;
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
        foreach var in ndvi_imp evi_imp ndiv_ipol evi_ipol{;
            bysort forestid agrSeason: egen `varNam'`var'   = mean(`var')  if `pMonth';
            bysort forestid agrSeason: egen `varNam'`var'_s = mean(`varNam'`var');
            bysort forestid agrSeason: replace `varNam'`var' = `varNam'`var'_s;
            drop `varNam'`var'_s;
            replace `varNam'`var'   = .           if (month <= 5);
            bysort forestid year:      egen `varNam'`var'_s  = mean(`varNam'`var');
            bysort forestid year:   replace `varNam'`var'    = `varNam'`var'_s;
            drop      `varNam'`var'_s;
        };
    };
    *** ## END LOOP ##;

    xtset forestid  time;

    save "$currIntermOut/burkina_faso_fires-MONTH_FOREST.dta", replace;







    #delimit ;
    *** Reshape dataset to reflect annual data;
    gen  forestidYear = forestid * 10000 + year;

    #delimit ;
    foreach y of varlist rny_* prs_* dry_* preR_*{;
    	bysort forestid year: replace `y' = .		if (month <= 5);
    	bysort forestid year: egen `y'_mean = mean(`y');
    	bysort forestid year: replace `y'_mean = round(`y'_mean, .000001);
    	bysort forestid year: replace `y'= `y'_mean;
    	drop `y'_mean;
    };

    *** Recalculate the share of missing observations;
    drop miss*;
    foreach y in ndvi evi{;
        bysort forestid year: egen    miss`y'    = count(`y') ;
        bysort forestid year: replace miss`y'    = (_N - miss`y')/(_N);
        label  variable   miss`y'   "Missing values in `y' over the year for the forest";
    };




    *** Reshape variables that are not annual averages;
    drop agrSeason time post* post2*;

    local reshapeVarlist    "";
    foreach var of varlist fire* conf50* conf80* ndvi* evi* weakImp_*{;
      if (strpos(`"`var'"',"aAvg")==0) & (strpos(`"`var'"',"aAvgnR")==0){;
            local reshapeVarlist      "`reshapeVarlist' `var'";
      };
    };

    ** LSMS variables;
    local LSMSvars = "avg_HHsize HH_educ_prim HH_educ_second_prem " ///
                      + "HH_educ_second_fin HH_educ_sup N_HH A5BIS " ///
                      + "mV07 org_fert inorg_fert other_fert avg_dur_value " ///
                      + "L14_CookingW landIntFoodCons landIntFoodConsSh " ///
                      + "landIntFuelCons EstPop";
    foreach var of local LSMSvars{;
        bysort forestid year: egen `var'_med = median(`var');
        replace                    `var'  = `var'_med;
        drop                       `var'_med;
    };

    *** Reshape data to annual observations while keeping monthly data;
    reshape wide `reshapeVarlist' , i(forestidYear) j(month);
    xtset forestid year;

    gen   post            = (year >= 2014);
    gen   postTreatment   = post * treatment;
    gen   post2           = (year >= 2015);
    gen   post2Treatment  = post2 * treatment;


    order forestid forest_name year fip treatment year gridid
        post  post2
    	  rny_fire rny_conf50 rny_conf80 rny_ndvi rny_evi
    	  prs_fire prs_conf50 prs_conf80 prs_ndvi prs_evi
    	  dry_fire dry_conf50 dry_conf80 dry_ndvi dry_evi
    	  preR_fire preR_conf50 preR_conf80 preR_ndvi preR_evi
    	  rny_ndvi_imp rny_evi_imp
    	  prs_ndvi_imp prs_evi_imp
    	  dry_ndvi_imp dry_evi_imp
    	  preR_ndvi_imp preR_evi_imp
    	  histFor_fire histFor_conf50 histFor_conf80
    	  histFor_fireGr_fire histFor_fireGr_conf50 histFor_fireGr_conf80
    	  histFor_fireDumPr_fire histFor_fireDumPr_conf50 histFor_fireDumPr_conf80;

    save "$currIntermOut/burkina_faso_fires-YEAR_FOREST.dta", replace;

    import excel using "$rawDataFolder/mouhoun_t_neighb/geography.xlsx",
        sheet("Sheet1") firstrow clear;
    drop        forest_name;
    tempfile    forest_location;
    save        `forest_location';

    use "$currIntermOut/burkina_faso_fires-YEAR_FOREST.dta", clear;

    merge m:1 forestid using `forest_location',   nogen;
    save "$currIntermOut/burkina_faso_fires-YEAR_FOREST.dta", replace;


    #delimit cr
}






if (`collapseBlockData' == 1){
      #delimit ;
      use   "$currIntermOut/burkina_faso_fires_forestblock.dta", clear;

      drop    if forestid    == 86;
      drop    if year        <= 2003;


      foreach var of varlist 			fire* conf* ndvi* evi*{;
    		bysort forestBlockID year:	egen `var'_aAvg		= mean(`var');
    		bysort forestBlockID year:	egen `var'_aAvgnR_T = mean(`var')
    												 if (month!=6)|(month!=7)|(month!=8);
    		bysort forestBlockID year:	egen `var'_aAvgnR	= mean(`var'_aAvgnR_T);
    		drop		`var'_aAvgnR_T;

    	};

    	foreach y of varlist rny_* prs_* dry_* preR_*{;

        	bysort forestBlockID year: replace `y' = .		if (month <= 5);
        	bysort forestBlockID year: egen `y'_mean = mean(`y');
        	bysort forestBlockID year: replace `y'_mean = round(`y'_mean, .000001);
        	bysort forestBlockID year: replace `y'= `y'_mean;
        	drop `y'_mean;
        };

    	drop agrSeason time;

    	foreach y of varlist	dist_aEdge gridid histFor* miss*{;
    		bysort forestBlockID year:	egen `y'_MY = mean(`y');
    		bysort forestBlockID year:  egen `y'_M	= median(`y'_MY);
    		bysort forestBlockID year:  replace `y'_M = round(`y'_M,.0001);
    		drop 	`y' `y'_MY;
    	};

    	local reshapeVarlist		"";
    	foreach var of varlist fire* conf* ndvi* evi* trunc*{;
    		if (strpos(`"`var'"',"aAvg")==0){;
    			local reshapeVarlist		"`reshapeVarlist' `var'";
    		};
    	};

      gen         forestBlockYear = .;
      recast      long forestBlockYear;
    	replace		  forestBlockYear = forestBlockID * 10000 + year;
      drop        distance;

    	reshape wide `reshapeVarlist',i(forestBlockYear) j(month);
    	xtset	forestBlockID year;

    	gen		post			= (year >= 2014);
    	gen		postTreatment	= post * treatment;
    	gen		post2			= (year >= 2015);
    	gen 	post2Treatment 	= post2 * treatment;

      save    "$currIntermout/burkina_faso_fires_forestblock-ANNUAL.dta", replace;
      #delimit cr
}
