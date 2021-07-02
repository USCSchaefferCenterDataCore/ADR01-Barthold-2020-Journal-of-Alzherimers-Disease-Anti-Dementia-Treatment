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
	
	array drug [*] drug1-drug4;
	array dx [*] dx1-dx3;
	array scen [*] scen1-scen12;
	
	do d=1 to dim(drug);
		do x=1 to dim(dx);
					scen[3*(d-1)+x]=drug[d]*dx[x];
		end;
	end;
	
run;

proc means data=figure2 noprint;
	output out=figure2_results mean(scen1-scen12)=mean1-mean12 sum(scen1-scen12)=sum1-sum12;
run;

ods excel file="./output/figure_prevalence_all&maxyear..xlsx";
proc print data=figure2_results; run;
ods excel close;
