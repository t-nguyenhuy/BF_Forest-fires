#delimit ;
* Erase previously loaded version of the program;
capture program drop sctabout;


program define sctabout;
  version 14.2;
  syntax, excelfile(str) sheetname(str) [replace tyear(integer -999)];


  if "`e(cmd)'" == "synth_runner"{;
      *** Case when sctabout follows synth_runner;
      preserve;
      if strpos("`=e(depvar)'", "fireBurn") > 0{;
          local sct_depvarb  = "fireBurn";
          local sct_depvar   = "FireBurn";
      };
      else if strpos("`=e(depvar)'", "fire") > 0{;
          local sct_depvarb   = "fire";
          local sct_depvar    = "Fire";
      };
      else if strpos("`=e(depvar)'", "conf50") > 0{;
          local sct_depvarb   = "conf50";
          local sct_depvar    = "Firec50";
      };
      else if strpos("`=e(depvar)'", "conf80") > 0{;
          local sct_depvarb   = "conf80";
          local sct_depvar    = "Firec80";
      };
      local sct_month   = subinstr(e(depvar),"`sct_depvarb'","",.);
      if    (e(treat_type) == "single_period") | ("`tyear'"=="-999"){;
          local sct_tYear   = e(trperiod);
      };
      else if ("`tyear'"!="-999"){;
          local sct_tYear   = `tyear';
      };
      matrix      sct_PE      = e(b);
      matrix      sct_PS      = e(pvals_std);
      local       sct_M_size  = colsof(sct_PE);


      di  "SCTABOUT: Saving estimation results into excel file.";
      di  "             - Dependent variable: `sct_depvarb'";
      di  "             - Month: `sct_month'";
      di  "             - Year:   `sct_tYear'";

      *** Variables for exporting;
      local         sct_exportVars "Fire Firec50 Firec80 FireBurn";

      *** Check whether the file exists and work accordingly;
      capture confirm file "`excelfile'";

      if _rc==0 {;
          *** Case when file exists;
          putexcel set    "`excelfile'", modify;
          di              "File under `excelfile' was found. Opening for edits.";


          *** Load already existing results into the table;
          import excel  using "`excelfile'", firstrow cellrange(A2:F60) allstring clear;
          qui drop        if Month == "." | Month == "";
          qui destring          Month Year, replace;
          if ("`replace'"=="replace"){;
              qui drop if 1==1;
          };
      };
      else {;
          *** Case when file does not exist;
          clear;
          qui gen int    Month = .;
          qui gen int    Year  = .;
          foreach y in `sct_exportVars'{;
              qui gen str     `y' = ".";
          };
          order       Month Year `sct_exportVars';


          putexcel set "`excelfile'", sheet("Results") replace;
          putexcel    C1=("(1)")    D1=("(2)")    E1=("(3)")    F1=("(4)")
                      A2=("Month")
                      B2=("Year")
                      C2=("Fire")
                      D2=("Firec50")
                      E2=("Firec80")
                      F2=("FireBurn")
                      (A3:F60) = (".");
          putexcel    (A1:F2), overwritefmt   bold;

          di "File under `excelfile' not found. New one generated.";
      };

      *** Add variable to indicate whether row indicates point estimates or p-vals;
      qui gen       typevar = 2 if (regexm(Fire,"^\[\.[0-9]*\]$"));
      qui replace   typevar = 1 if (typevar == .);


      *** Add modifications;
      qui replace   `sct_depvar' = "."      if (Month == `sct_month') &
                                              !(regexm(`sct_depvar',"^\[\.[0-9]*\]$"));
      qui replace   `sct_depvar' = "[.]"    if (Month == `sct_month') &
                                              (regexm(`sct_depvar',"^\[\.[0-9]*\]$"));

      forvalues sct_j = 1/`sct_M_size'{;
        local sct_curr_year           = `sct_tYear' + `sct_j' - 1;
        local sct_curr_myselector     "(Month==`sct_month')&(Year==`sct_curr_year')";
        qui sum Month                 if `sct_curr_myselector';
        if r(N) == 0{;
            *** If no corresponding observations exists, generate them ;
            local           sct_new_N_obs = _N + 2;
            qui set obs     `sct_new_N_obs';
            qui replace     Month = `sct_month'     if Month == .;
            qui replace     Year  = `sct_curr_year' if (Month == `sct_month') &
                                                   (Year == .);
            qui bysort Month Year: replace typevar = _n       if `sct_curr_myselector';
            foreach y of local sct_exportVars{;
              qui bysort Month Year: replace `y' = "."        if (_n==1) &
                                                                 `sct_curr_myselector';
              qui bysort Month Year: replace `y' = "[.]"      if (_n==2) &
                                                                 `sct_curr_myselector';
            };
        };
        qui replace `sct_depvar' = "`=subinstr(string(sct_PE[1,`sct_j'],"%4.3f"),"0","",1)'"
                                                      if  `sct_curr_myselector' &
                                                          (typevar == 1);


        qui replace `sct_depvar' = "[`=subinstr(string(sct_PS[1,`sct_j'],"%4.3f"),"0","",1)']"
                                                      if  `sct_curr_myselector' &
                                                          (typevar == 2);
        *qui replace `sct_depvar' = "[`=round(sct_PS[1,`sct_j'],.001)']";
        *qui replace `sct_depvar' = "`=string(round(sct_PE[1,`sct_j'],.001),"")'"    if  `sct_curr_myselector' &;
      };




      *** Export updated table to Excel;
      foreach var of local sct_exportVars{;
          capture tostring      `var', force replace;
          qui replace               `var' = "." if (Month==.) & (Year==.) & (_n<=46);
      };

      *** -- Order observations to be exported;
      qui recode Month    (10 = 1)
                      (11 = 2)
                      (12 = 3)
                      (1  = 4)
                      (2  = 5)
                      (3  = 6)
                      (4  = 7), gen(MonthOrder);
      sort MonthOrder Year typevar;


      export excel Month Year `sct_exportVars' if _n<=46 using "`excelfile'",
            cell(A3) sheet(`sheetname') sheetmodify;

      drop Month Year `sct_exportVars' MonthOrder;
      restore;
  };
  else {;
      *** Case when sctabout does not follow synth_runner;
      display   "Error: SCTABOUT must follow synth_runner command.";
  };



  macro drop _sct*;
end;
#delimit cr
