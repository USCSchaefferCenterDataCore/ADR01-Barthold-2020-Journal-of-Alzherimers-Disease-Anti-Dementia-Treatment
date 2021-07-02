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

%let maxyear=2016;

* Figure 2;
data figure2;
	set addrugs.analytical&maxyear.;
	
	array insamp [2008:&maxyear.] insamp2008-insamp&maxyear.;
	
	* 3 drug scenarios;
	drug1=0;
	drug2=0;
	drug3=0;
	drug4=0;
	if ever_adrx=1 then drug1=1;
	if ever_achei=1 then drug2=1;
	if ever_combo=1 then drug3=1;
	if ever_meman=1 then drug4=1;
	
	* 3 incident groups;
	if mdy(1,1,2008)<=ADRDplus_inc<=mdy(1,1,&maxyear.) then do;
		if insamp[year(ADRDplus_inc)] then dx1=1;
	end;
	if mdy(1,1,2008)<=ADRD_inc<=mdy(1,1,&maxyear.) then do;
		if insamp[year(ADRD_inc)] then dx2=1;
	end;
	if mdy(1,1,2008)<=AD_inc<=mdy(1,1,&maxyear.) then do;
		if insamp[year(AD_inc)] then dx3=1;
	end;
	
	* race;
	if race_bg=1 then race1=1;
	if race_bg=2 then race2=1;
	if race_bg=5 then race3=1;
	if race_bg=4 then race4=1;
	
	* sex;
	if sex=1 then sex1=1;
	if sex=2 then sex2=1;
	
	array drug [*] drug1-drug4;
	array dx [*] dx1-dx3;
	array race [*] race1-race4;
	array sex_ [*] sex1-sex2;
	array scen [*] scen1-scen96;
	
	do d=1 to dim(drug);
		do x=1 to dim(dx);
			do s=1 to dim(sex_);
				do r=1 to dim(race);
					scen[24*(d-1)+8*(x-1)+4*(s-1)+r]=drug[d]*dx[x]*sex_[s]*race[r];
				end;
			end;
		end;
	end;
	
run;

proc means data=figure2 noprint;
	output out=figure2_results mean(scen1-scen96)=mean1-mean96 sum(scen1-scen96)=sum1-sum96;
run;

proc transpose data=figure2_results out=figure2_results_m (drop=_name_) prefix=mean; var mean1-mean96; run;
proc transpose data=figure2_results out=figure2_results_s (drop=_name_) prefix=sum; var sum1-sum96; run;
	
data figure2_results1;
	merge figure2_results_m figure2_results_s;
run;

proc print data=figure2_results1; run;

ods excel file="./output/figure_prevalence_bysexrace&maxyear..xlsx";
proc print data=figure2_results1; run;
ods excel close;