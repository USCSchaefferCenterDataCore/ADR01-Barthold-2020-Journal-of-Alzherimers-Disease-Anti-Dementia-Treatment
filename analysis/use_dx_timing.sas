/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 11/6/2018;

* PURPOSE: Figure 2 and 3 of AD Drug Use descriptive analysis;

* INPUT: adrd_inc_2001_2016, adrx_inc_2007_2016;
* OUTPUT: analysis;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname exp "../../data/adrd_inc_explore";

%let maxyear=2016;

* Figure 3;
data figure3;
	merge addrugs.analytical&maxyear. (in=a) 
	exp.ffsptd_samp_monthly_fix (in=b keep=bene_id ffsptd2008: ffsptd2009: ffsptd2010: ffsptd2011: ffsptd2012: ffsptd2013: ffsptd2014: ffsptd2015: ffsptd2016:);
	by bene_id;	
	
	array insamp [2008:&maxyear.] insamp2008-insamp&maxyear.;
	
	* Age at dx;
	format birth_date mmddyy10.;
	agedx=(ADRDplus_inc-birth_date)/365;
	if 75<=agedx<80 then agedx_cat="1. 75-79";
	if 80<=agedx<85 then agedx_cat="2. 80-84";
	if 85<=agedx<90 then agedx_cat="3. 85-89";
	
	* Require 36 months survival after first drug use or first diagnosis;
	firstdate=min(rxinit,ADRDplus_inc);
	format firstdate mmddyy10.;
	
	array ffsptd [*] ffsptd2008_1-ffsptd2008_12 ffsptd2009_1-ffsptd2009_12 ffsptd2010_1-ffsptd2010_12 ffsptd2011_1-ffsptd2011_12 ffsptd2012_1-ffsptd2012_12
										ffsptd2013_1-ffsptd2013_12 ffsptd2014_1-ffsptd2014_12 ffsptd2015_1-ffsptd2015_12 ffsptd2016_1-ffsptd2016_12;
	if firstdate ne . then do;
		
		rxmostart=month(rxinit)+12*(year(rxinit)-2008);
		rxmoend=rxmostart+36;
		if 1<=rxmoend<=84 then do mo=rxmostart to rxmoend;
			if ffsptd[mo] ne "Y" then drop=1;
		end;
		if rxmoend>84 then drop=1;
		
		if drop ne 1 then surv36mo=1;
	end;
	
	* 6 time gap scenarios - need them to be in sample between diagnosis and drug initiation;
	if surv36mo=1 and rxinit ne . and rxinit>=mdy(1,1,2008) and insamp[year(rxinit)] then do;
	
		leftsamp_ADRDp=0;
		if year(ADRDplus_inc)>=2008 then do year=min(year(rxinit),year(ADRDplus_inc)) to max(year(rxinit),year(ADRDplus_inc));
			if insamp[year] ne 1 then leftsamp_ADRDp=1;
		end;
		if leftsamp_ADRDp=0 then do;
			if ADRDplus_inc_spec=1 then tgap1=rxinit-ADRDplus_inc;
			if ADRDplus_inc_spec=0 then tgap2=rxinit-ADRDplus_inc;
			tgap7=rxinit-ADRDplus_inc;
		end;
		
		leftsamp_ADRD=0;
		if year(ADRD_inc)>=2008 then do year=min(year(rxinit),year(ADRD_inc)) to max(year(rxinit),year(ADRD_inc));
			if insamp[year] ne 1 then leftsamp_ADRD=1;
		end;
		if leftsamp_ADRD=0 then do;
			if ADRD_inc_spec=1 then tgap3=rxinit-ADRD_inc;
			if ADRD_inc_spec=0 then tgap4=rxinit-ADRD_inc;
			tgap8=rxinit-ADRD_inc;
		end;
		
		leftsamp_AD=0;
		if year(AD_inc)>=2008 then do year=min(year(rxinit),year(AD_inc)) to max(year(rxinit),year(AD_inc));
			if insamp[year] ne 1 then leftsamp_AD=1;
		end;
		if leftsamp_AD=0 then do;
			if AD_inc_spec=1 then tgap5=rxinit-AD_inc;
			if AD_inc_spec=0 then tgap6=rxinit-AD_inc;
			tgap9=rxinit-AD_inc;
		end;
	
	end;
	
	* 4 drug scenarios: all, achei's only, meman only, combo;
	if ever_adrx then drug1=1;
	if ever_achei then drug2=1;
	if ever_combo then drug3=1;
	if ever_meman then drug4=1;
	
	* 3 sex scenarios: all, male, female;
	sex1=1;
	if sex=1 then sex2=1;
	if sex=2 then sex3=1;
	
	* 5 race scenarios: all, white, black, hispanic, asian;
	race1=1;
	if race_bg=1 then race2=1;
	if race_bg=2 then race3=1;
	if race_bg=5 then race4=1;
	if race_bg=4 then race5=1;
	
	array scen [*] scen1-scen540;
	array sex_ [*] sex1-sex3;
	array race [*] race1-race5;
	array tgap [*] tgap1-tgap9;
	array drug [*] drug1-drug4;
	
	do d=1 to dim(drug);
		do r=1 to dim(race);
			do s=1 to dim(sex_);
				do t=1 to dim(tgap);
					scen[135*(d-1)+27*(r-1)+9*(s-1)+t]=floorz(tgap[t]/182.5)*0.5*race[r]*sex_[s]*drug[d];
				end;
			end;
		end;
	end;

run;

options obs=100;
proc print data=figure3;
	where surv36mo ne 1 and scen1 ne .;
	var bene_id surv36mo scen1 tgap1 rxinit ADRDplus_inc insamp:;
run;

proc univariate data=figure3 noprint outtable=agecat1_ck;
	where agedx_cat="1. 75-79";
	var agedx;
run;

proc univariate data=figure3 noprint outtable=agecat2_ck;
	where agedx_cat="2. 80-84";
	var agedx;
run;

proc univariate data=figure3 noprint outtable=agecat3_ck;
	where agedx_cat="3. 85-89";
	var agedx;
run;

proc print data=agecat1_ck; run;
proc print data=agecat2_ck; run;
proc print data=agecat3_ck; run;
	
proc print data=figure3;
	where race5=1 and tgap7 ne .;
	var scen: sex1-sex3 sex race_bg race1-race5 tgap: drug: ever_adrx ever_achei ever_combo ever_meman;
run;
options obs=max;

%macro freq;
	proc freq data=figure3 noprint;
		%do i=1 %to 270;
			table scen&i / out=freq_scen&i (rename=(scen&i=scen count=count&i percent=pct&i));
		%end;
	run;

	data figure3_results_adrx;
		merge %do i=1 %to 270;
			freq_scen&i
		%end;;
		by scen;
	run;

	proc freq data=figure3 noprint;
		where agedx_cat="1. 75-79";
		%do i=1 %to 135;
			table scen&i / out=freq_agecat1_scen&i (rename=(scen&i=scen count=count&i percent=pct&i));
		%end;
	run;
	
	proc freq data=figure3 noprint;
		where agedx_cat="2. 80-84";
		%do i=1 %to 135;
			table scen&i / out=freq_agecat2_scen&i (rename=(scen&i=scen count=count&i percent=pct&i));
		%end;
	run; 
	
	proc freq data=figure3 noprint;
		where agedx_cat="3. 85-89";
		%do i=1 %to 135;
			table scen&i / out=freq_agecat3_scen&i (rename=(scen&i=scen count=count&i percent=pct&i));
		%end;
	run;	
	
	data figure3_results_agecat1;
		merge %do i=1 %to 135;
			freq_agecat1_scen&i
		%end;;
		by scen;
	run;
	
	data figure3_results_agecat2;
		merge %do i=1 %to 135;
			freq_agecat2_scen&i
		%end;;
		by scen;
	run;
	
	data figure3_results_agecat3;
		merge %do i=1 %to 135;
			freq_agecat3_scen&i
		%end;;
		by scen;
	run;
	
	data figure3_results_achei;
		merge %do i=136 %to 270;
			freq_scen&i
		%end;;
		by scen;
	run;
	
	data figure3_results_combo;
		merge %do i=271 %to 405;
			freq_scen&i
		%end;;
		by scen;
	run;
	
	data figure3_results_meman;
		merge %do i=406 %to 540;
			freq_scen&i
		%end;;
		by scen;
	run;

%mend;

%freq;

ods excel file="./output/figure_use_dx_timing&maxyear..xlsx";
proc print data=figure3_results_adrx; run;
proc print data=figure3_results_achei; run;
proc print data=figure3_results_agecat1; run;
proc print data=figure3_results_agecat2; run;
proc print data=figure3_results_agecat3; run;
proc print data=figure3_results_meman; run;
proc print data=figure3_results_combo; run;
ods excel close;