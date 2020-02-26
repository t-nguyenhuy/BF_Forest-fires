set more off


local mainF "D:\Surfdrive\Working folders - PhD\Forest Fire - BF - LSMS_GIS"
*capture shell rmdir "`mainF'\DataSet\Intermediate\Cross-sectional fires" /s /q
capture shell mkdir "`mainF'\DataSet\Intermediate\Cross-sectional fires"


use "`mainF'\DataSet\Raw Dataset\Forest_fire_panel\burkina_faso_fires_fullpanel.dta", clear

#delimit ;
keep if (month==9)|(month==10);
foreach y in fire confidence50 confidence80{;
  local var "`y'";
  if "`y'"      =="confidence50"{;
    local var   "conf50";
  };
  else if "`y'" =="confidence80"{;
    local var   "conf80";
  };
  bysort gridid year: egen `var'_pres = sum(`y');
};


foreach yearExtract in 2009 2010 2011 2012 2013 2014 2015 2016 2017{;
	preserve;
	keep if (month==10)&(year==`yearExtract');
	export delimited forestid forest_name gridid fire_pres conf50_pres conf80_pres using
		  "`mainF'\DataSet\Intermediate\Cross-sectional fires\preF_`yearExtract'.csv",
	     replace;
	restore;
};
#delimit cr






use "`mainF'\DataSet\Raw Dataset\Forest_fire_panel\burkina_faso_fires_fullpanel.dta", clear

#delimit ;
keep if (month==11);
foreach y in fire confidence50 confidence80{;
  local var "`y'";
  if "`y'"      =="confidence50"{;
    local var   "conf50";
  };
  else if "`y'" =="confidence80"{;
    local var   "conf80";
  };
  bysort gridid year: egen `var'_pres = sum(`y');
};


foreach yearExtract in 2009 2010 2011 2012 2013 2014 2015 2016 2017{;
  preserve;
  keep if (month==11)&(year==`yearExtract');
  export delimited forestid forest_name gridid fire_pres conf50_pres conf80_pres using
      "`mainF'\DataSet\Intermediate\Cross-sectional fires\preFN_`yearExtract'.csv",
      replace;
  restore;
};
#delimit cr
