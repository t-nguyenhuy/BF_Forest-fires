foreach y of local outcomeVariables{;
    twoway (line `y' time if (treatment==1)&(time<=monthly("2013m8","YM")))
      (line `y' time if (treatment==0)&(time<=monthly("2013m8","YM"))),
      legend(label(1 "treated") label(2 "not treated")) title("Pre-2013");
    graph export "$outputFolder/Descriptives/`y'/raw_`sample'_`y'_pre2013.png",width(7000) replace;
};

foreach y of local outcomeVariables{;
    twoway (line `y' time if (treatment==1)&(time>monthly("2013m8","YM")))
      (line `y' time if (treatment==0)&(time>monthly("2013m8","YM"))),
      legend(label(1 "treated") label(2 "not treated")) title("Post-2013");
    graph export "$outputFolder/Descriptives/`y'/raw_`sample'_`y'_post2013.png",width(7000) replace;
};


foreach y of local outcomeVariables{;
    twoway (line `y' time if (treatment==1)&(time<=monthly("2013m8","YM")))
      (line `y' time if (treatment==0)&(time<=monthly("2013m8","YM"))),
      legend(label(1 "treated") label(2 "not treated")) title("Pre-2013");
    graph export "$outputFolder/Descriptives/`y'/raw_`sample'_`y'_SELBL_pre2013.png",width(7000) replace;
};

foreach y of local outcomeVariables{;
    twoway (line `y' time if (treatment==1)&(time>monthly("2013m8","YM")))
      (line `y' time if (treatment==0)&(time>monthly("2013m8","YM"))),
      legend(label(1 "treated") label(2 "not treated")) title("Post-2013");
    graph export "$outputFolder/Descriptives/`y'/raw_`sample'_`y'_SELBL_post2013.png",width(7000) replace;
};
