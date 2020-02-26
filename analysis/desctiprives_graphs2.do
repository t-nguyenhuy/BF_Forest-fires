clear all
set more off



capture shell rmdir "$outputFolder/Descriptives/TS_new" /s /q
				shell mkdir "$outputFolder/Descriptives/TS_new"

local outCFold "$outputFolder/Descriptives/TS_new"
local outCvars "fire fireBurn conf50 conf50Burn conf80 conf80Burn missndvi"
local	prevId		= `1'-1


#delmit ;

if (1==1){;
	*** First type of graph;
	use if (time > `=monthly("2007M10","YM")') & (time < `=monthly("2014M9","YM")')
							using "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;


	local outCvars "fire fireBurn conf50 conf50Burn  conf80 conf80Burn";
	keep forestid fip treatment year month time `outCvars';

	collapse (mean) `outCvars' ,by(month);


	gen 	monthorder = month - 4 		if month>4;
				replace	monthorder = 9 		if month==1;
				replace monthorder = 10 	if month==2;
				replace monthorder = 11 	if month==3;
				replace monthorder = 12 	if month==4;

	*label 	define monthlabels 9 "Janvier" 10 "Fevrier" 11 "Mars" 12 "Avril" 1 "Mai" 2 "Juin" 3 "Juillet" 4 "Aout" 5 "Septembre" 6 "Octobre" 7 "Novembre" 8 "Decembre";
	label 	define monthlabels 9 "January" 10 "February" 11 "March" 12 "April" 1 "May" 2 "June" 3 "July" 4 "August" 5 "September" 6 "October" 7 "Novembre" 8 "Decembre";
	label		value monthorder monthlabels;
	sort 		monthorder;


	foreach y of varlist `outCvars'{;
		if ( strpo("`y'","fire")>0 )				local yConf	"0 %";
		if ( strpo("`y'","conf50")>0 )			local yConf	"50 %";
		if ( strpo("`y'","conf80")>0 )			local yConf	"80 %";


		if strpos("`y'","Burn") == 0{;
				local yTitle "Fire occurrence (conf. thresh. `yConf')";
				local grTitle "Average monthly fire occurrence (2008-2014)";
		};
		else {;
				local yTitle "% (conf. thresh. `yConf')";
				local grTitle "Average share of burned grids (2008-2014)";
		};


		twoway (line `y' monthorder, lc(blue) lw(thick)),
						yscale(range(0 1)) 	ylabel(0(0.2)1)	ytitle("`yTitle'")
						xlabel(1(2)12, valuelabel alternate) xtitle("Months")
						graphregion(color(none)) title("`grTitle'");

		graph export "`outCFold'/TS_raw_full_`y'.png", width(7000) replace;
	};




	*** Second type of graph;
	use if (year >= 2008) using "${intermFolder`prevId'}/burkina_faso_fires-MONTH_FOREST.dta", clear;


	local outCvars				"dry_fire preR_fire prs_fire dry_ndvi preR_ndvi prs_ndvi";
	keep forestid fip treatment year `outCvars';

	collapse (mean) `outCvars', by(year treatment);



	foreach y of varlist `outCvars'{;
			if strpos("`y'","dry") > 0{;
				local xT	"Dry season";
				local xY	2014;
			};
			else if strpos("`y'","prs") > 0{;
				local xT	"Post-rainy season";
				local xY	2015;
			};
			else if strpos("`y'","dry") > 0{;
				local xT	"Pre-rainy season";
				local xY	2015;
			};

			twoway 	(line `y' year if treatment == 1, lc(blue) lw(thick))
							(line `y' year if treatment == 0, lc(red)  lw(medthick)),
							ytitle("Fire occurrence")
							xlabel(, alternate) xtitle("Year")
							legend(label(1 "Treated") label(2 "Control"))
							graphregion(color(none)) xline(`xY', lcolor(black) lw(thin));


			graph export "`outCFold'/TS_raw_full_`y'_AN.png", width(7000) replace;
	};
};

#delimit cr
