** Generate zd - village dataset
#delimit ;
import excel 					"$rawDataFolder/echantillon_emc.xls", sheet("EquipeZdEmc")
											firstrow clear;
keep 				NZDEMC REGION PROVINCE COMMUNE NZDRGPH VILLAGE NBMENAGE MILIEU;
sort 				NZDEMC;
rename 			NZDEMC zd;
capture shell rmdir "$$currIntermOut/ZD_VILLAGE" /s /q;
capture shell mkdir "$$currIntermOut/ZD_VILLAGE";
save 				"$$currIntermOut/ZD_VILLAGE/zd_village_original.dta", replace;
clear;
#delimit cr


** In addition, extrad gridid-edge variables to see which grids are at the edge;
#delimit ;
use 				"$rawDataFolder/Forest_fire_panel/burkina_faso_fires_fullpanel.dta", clear;
keep				year month forestid gridid edge;
collapse 		(mean) edge forestid, by(gridid);
export 			delimited using		"$$currIntermOut/gridid_edge.csv", replace;
#delimit cr
