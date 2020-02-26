** Define a supporting function focusing on copying variables (but not the data)
#delimit ;
capture program drop gencopyvar;
program define gencopyvar;
	syntax, oldvar(str) newvar(str) condi(str);
	gen 													`newvar' = `oldvar' 		if `condi';
	label values `newvar' `: 			value label `oldvar'';
	label variable `newvar' "`: 	variable label `oldvar''";
end;

local prevId 	= $taskId-1;
local pprevId = $taskId-2;
#delimit cr


* Generate average village-level population size measures from the
* individual_level dataset
**** Use only the first wave individual-level household survey to construct
**** the household-size measure
use "$currSurveyData/emc2014_p1_individu_27022015.dta", clear
	*** Calculate household sizes
	bysort zd menage: egen N_members 	= count(numind)
	qui gen zd_menage_ID 							= zd*1000+menage
	qui gen hhh_numind_temp 					= numind if (B5==1) // Save the ID of household head
	bysort zd menage: egen hhh_numind = max(hhh_numind_temp)

	*** Household-head years of education
	gen HH_educ_prim									= B14 >= 3 if (B5 == 1)
	gen HH_educ_second_prem						= B14 >= 4 if (B5 == 1)
	gen HH_educ_second_fin						= B14 >= 5 if (B5 == 1)
	gen HH_educ_sup										= B14 == 7 if (B5 == 1)


	collapse (mean) zd menage N_members hhh_numind (max) HH_educ_prim HH_educ_second_prem HH_educ_second_fin HH_educ_sup, by(zd_menage_ID)
	collapse (mean) N_members HH_educ_prim HH_educ_second_prem HH_educ_second_fin HH_educ_sup, by(zd)
	rename N_members avg_HHsize
	label variable avg_HHsize "Average number of household members"
	merge 1:1 zd using "${intermFolder`pprevId'}/ZD_VILLAGE/zd_village_original.dta", ///
		keepusing(NBMENAGE) nogen
	rename NBMENAGE N_HH
	label variable N_HH "Number of households"
	gen EstPop = avg_HHsize * N_HH
	label variable EstPop "Estimated population in ZD"
	label variable HH_educ_prim "Share of household heads with Primary Educ."
	label variable HH_educ_second_prem "Share of household heads with Secondary Educ (1st cycle)"
	label variable HH_educ_second_fin  "Share of household heads with Secondary Educ (final cycle)"
	label variable HH_educ_sup	"Sahre of household heads with higher educ."
save "$$currTempFold/emc2014_HH_size.dta", replace


** Share of Agricultural households, agricultural households with plots, collective-indiv-management
use "$currSurveyData/emc2014_agri_caracteristiques_parcelles.dta", clear
	drop 								if A13 > 2
	replace							A8 = 5 if (zd == 395)&(menage == 4)
	replace							A8 = 4 if (zd == 830)&(menage == 12)
	drop 								if (zd == 830)&(menage==12)&(V07 == 1)
	gen 								V07_rec = 1 if V07 == 2   // Collectively managed parcels
	replace							V07_rec = 0 if V07 == 1	  // Individually managed parcels
	bysort zd menage:		egen mV07 = mean(V07_rec)
	collapse (first) A5BIS A8 mV07, by(zd menage)

	gen		A8_cond				= A8 				if (A5BIS == 1)
	gen		A8_condD			= (A8 > 0) 	if (A5BIS == 1)

	replace A5BIS = 0 	if A5BIS == 2
	collapse (mean) A5BIS mV07, by(zd)
	label variable A5BIS "Share of agricultural households."
	label variable mV07  "Share of parcels under collective cultivation."
save "$$currTempFold/emc2014_agri_HH_shares.dta", replace


** Share of agricultural households using fertilizers
use "$currSurveyData/emc2014_agri_couts_intrants.dta", clear
	gen 									zd_menage_ID = 100 * zd + menage
	drop 									if (A5BIS == 2)|(A13 > 2)
	drop									if (zd == 830) & (menage == 12) & (A7 == 3)
	drop									if (zd == 419) & (menage == 7)
	drop 									A15A A15AJOUR A15AMOIS A15AANNEE A15B A16A A16AJOUR ///
												A16AMOIS A16AANNEE A16B A17A A17AJOUR A17AMOIS A17B ///
												A12B A12BHEURE A12BMINUTE
	reshape	wide					INTRANT_LIB W2 W3UNITE W3QUANTITE W4 W5 W6 W7UNITE ///
	 											W7QUANTITE W7MONTANT W8 W9UNITE W9QUANTITE W9MONTANT, ///
												i(zd_menage_ID) j(W1)

	gen 			org_fert		= (W21 == 1) | (W22 == 1) | (W23 == 1)
	gen				inorg_fert	= (W24 == 1) | (W25 == 1) | (W26 == 1)
	gen				other_fert	= (W27 == 1)

	collapse (mean) org_fert inorg_fert other_fert, by(zd)
	label variable org_fert "Share of agri. HHs using org. fert-s."
	label variable inorg_fert "Share of agri. HHs using inorg. fert-s."
	label variable other_fert "Share of agri. HHs using other fert-s."
save "$$currTempFold/emc2014_agri_intrants.dta", replace

** Construct average household asset indices (valued at local currency)
use "$currSurveyData/emc2014_p1_biensdurables_27022015.dta", clear
	gen 					zd_menage_ID 			= 100 * zd + menage
	** Only keep a subset of durable goods
	local durable_list				"201 202 205 207 209 211 212 213 215 216"
	local conditions_durable	""
	foreach id of local durable_list{
			if `id' == 201{
				local conditions_durable "(code_article==201)"
			}
			else {
				local conditions_durable "`conditions_durable'|(code_article==`id')"
			}
	}
	keep 		if `conditions_durable'

	gen						tot_dur_value		= pm2 * pm4
	collapse (sum) tot_dur_value, by(zd menage)
	collapse (mean) tot_dur_value, by(zd)

	rename tot_dur_value	avg_dur_value
	label variable 	avg_dur_value		"Average asset index - durable goods (in CFAC)"

save "$$currTempFold/emc2014_biensdurables.dta", replace

** Generate data on household level wood use
**** Share of households using wood to generate light and to cook
use "$currSurveyData/emc2014_p1_logement_27022015.dta", clear
	bysort zd: gen 	n_L08_wood_dum 	= (L08==9)
	bysort zd: egen n_L08_wood 			= sum(n_L08_wood_dum)
	bysort zd: gen 	n_L08_woodSh 		= n_L08_wood/_N
	bysort zd: gen 	n_L14_wood_dum 	= (L14==4)|(L14==7)
	bysort zd: egen n_L14_wood 			= sum(n_L14_wood_dum)
	bysort zd: gen 	n_L14_woodSh 		= n_L14_wood / _N

	keep zd menage n_L08_woodSh n_L14_woodSh
	collapse (mean) n_L08_woodSh n_L14_woodSh, by(zd)
	rename n_L08_woodSh L08_LightingW
	label variable L08_LightingW "Share of HH-s using wood or coal for lighting"
	rename n_L14_woodSh L14_CookingW
	label variable L14_CookingW "Share of HH-s using wood or coal for cooking"
save "$$currTempFold/emc2014_HH_logement.dta", replace
** Note: need some other measure of wood usage related to housing..


* Consumption of land-intensive goods
**** Food
use "$currSurveyData/emc2014_p1_conso7jours_16032015.dta", clear
	keep zd menage achat autocons cadeau hhid product
	drop if (product>56)&(product!=68)&(product!=66)&(product!=67)
	reshape wide achat autocons cadeau, i(hhid) j(product)
	sort zd hhid
	****** Calculate total consumption on food (expressed in money)
	egen foodCons = rowtotal(achat1-achat51)
	egen landIntFoodConsP1 = rowtotal(achat14-achat17)
	egen landIntFoodConsP2 = rowtotal(achat22-achat24)
	gen landIntFoodCons = landIntFoodConsP1+landIntFoodConsP2
	drop landIntFoodConsP1 landIntFoodConsP2
	gen landIntFoodConsSh = landIntFoodCons / foodCons
	collapse (mean) landIntFoodCons landIntFoodConsSh, by(zd)
	label variable landIntFoodCons "Average HH consumption of land intensive food products (expr. in CFA)"
	label variable landIntFoodConsSh ///
	 "Average share of land intensive food products in food consumption (ratio of consumption in CFA-s)"
save "$$currTempFold/emc2014_zd_cons7jours.dta", replace

**** Fuel
use "$currSurveyData/emc2014_p1_conso3mois_16032015.dta", clear
	label save product using "$$currTempFold/emc2014_cons_productLabel.do", replace
	**** Reshaping the .dta file to have household-level observations
	drop if product==.
	drop cadeau hhsize1 res_entr1 hhweight1 merge1
	drop if (product>102)|((product>56)&(product<100)&(product!=68)&(product!=66)&(product!=67))
	reshape wide achat, i(hhid) j(product)
	sort zd hhid
	gen landIntFuelCons = achat66 + achat67
	collapse (mean) landIntFuelCons, by(zd)
	label variable landIntFuelCons "Average HH consumption of firewood or charcoal (expr. in CFA)"
save "$$currTempFold/emc2014_zd_cons3mois.dta", replace
