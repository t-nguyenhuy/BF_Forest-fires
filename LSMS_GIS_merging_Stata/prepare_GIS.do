* PREPARE GIS data
** Load the RAW OCHA village-commune-province-region GIS datase
clear
local listGISSets "GIS_settls.dta GIS_settlsExt.dta"
capture shell rmdir "$$currIntermOut/GIS_settl" /s /q
capture shell mkdir "$$currIntermOut/GIS_settl"
foreach dataSet of local listGISSets{
	if `"`dataSet'"'=="GIS_settls.dta"{
		local shapeFileToUse = "$currSettlCommShapeF"
		local filename ""
	}
	else{
		local shapeFileToUse = "$currSettlCommShapeFExt"
		local filename "Ext"
	}
	#delimit ;
	di "A";
	di `"`shapeFileToUse'"';
	di "$$currTempFold/GIS_settls`filename'.dta";
	di "$$currTempFold/GIS_settls_coord`filename'.dta";
	shp2dta using `"`shapeFileToUse'"',
		database("$$currTempFold/GIS_settls`filename'.dta")
		coordinates("$$currTempFold/GIS_settls_coord`filename'.dta")
		genid(ID) replace;
		** Note that calling for centroids give missing obs-s.;
	di "B";
	use "$$currTempFold/GIS_settls`filename'.dta", clear;
	drop featureRef featureAlt featureA_1 popPlaceCl admin0Name admin0Pcod
	admin1Name admin1Pcod admin2Name admin2Pcod date validOn validTo CNTRY_CODE
	RowcaCode1 RowcaCode2 RowcaCode4 validTo_2 ADM3_REF ADM3ALT1FR ADM3ALT2FR
	ADM0_FR ADM0_PCODE;


	rename featureNam VILLAGE;
	rename ADM1_FR REGION;
	rename ADM1_PCODE REGION_pcode;
	rename ADM2_FR PROVINCE;
	rename ADM2_PCODE PROVINCE_pcode;
	rename ADM3_FR COMMUNE;
	rename ADM3_PCODE COMMUNE_pcode;
	order OBJECTID ID VILLAGE REGION PROVINCE COMMUNE popPlace_1 pcode
		REGION_pcode PROVINCE_pcode COMMUNE_pcode;
	di "C";
	save "$$currIntermOut/GIS_settl/GIS_village`filename'.dta", replace;
	#delimit cr

	**** PREPARING the variables
	foreach variable in VILLAGE REGION PROVINCE COMMUNE{
		replace `variable'=upper(`variable')
		replace `variable'=subinstr(`variable'," - ","-",.)
		if (`variable'==REGION){
			replace `variable'=subinstr(`variable',"-"," ",.)
		}
	}
	di "D"
	save "$$currIntermOut/GIS_settl/GIS_village`filename'.dta", replace
	macro drop _shapeFileToUse _filename
}
clear
