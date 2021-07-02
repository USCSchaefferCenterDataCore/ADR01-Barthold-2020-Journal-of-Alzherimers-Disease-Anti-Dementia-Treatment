/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 11/7/2018;

* PURPOSE: Table 2 of AD Drug Use descriptive analysis;

* INPUT: adrd_inc_2001_2016, adrx_inc_2007_2016;
* OUTPUT: analysis;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";

%let minyear=2008;
%let maxyear=2016;

* Finding users in each year;
data table2 addrugs.table2;
	merge addrugs.analytical&maxyear. (in=a) addrugs.samp_geoses (in=b);
	by bene_id;
	if a;
	
	* Identifying table 2 sample in each year - those who used drugs in that year and is in sample that year;
	array tb2samp [&minyear:&maxyear] tb2samp&minyear-tb2samp&maxyear;
	array adrx_ [&minyear:&maxyear] adrx&minyear-adrx&maxyear;
	array insamp [&minyear:&maxyear] insamp&minyear-insamp&maxyear;
	
	do year=&minyear to &maxyear;
		if adrx_[year]=1 and insamp[year]=1 then tb2samp[year]=1;
	end;

	* for checks purposes, checking how many people in tb2samp every year are in samp year of rxinit;
	array rxinit_samp [&minyear:&maxyear] rxinit_samp&minyear-rxinit_samp&maxyear;
	array rxinit_year [&minyear:&maxyear] rxinit_year&minyear-rxinit_year&maxyear;
	array tb2samp_age [&minyear:&maxyear] tb2samp_age&minyear-tb2samp_age&maxyear;
	do year=&minyear to &maxyear;
		if tb2samp[year]=1 then do;
			tb2samp_age[year]=birth_date;
			rxinit_samp[year]=0;
			if rxinit ne . then do;
				rxinit_samp[year]=(insamp[year(rxinit)]);
				rxinit_year[year]=year(rxinit);
			end;
		end;
	end;
	
	* check if year of rxinit_spec increases across years - would be the only logical explanation for increase;
	rxinit_yr=year(rxinit);
	
	* Use;
	array achei [&minyear:&maxyear] achei&minyear-achei&maxyear;
	array combo [&minyear:&maxyear] combo&minyear-combo&maxyear;
	array donep_ [&minyear:&maxyear] donep&minyear-donep&maxyear;
	array galan_ [&minyear:&maxyear] galan&minyear-galan&maxyear;
	array meman_ [&minyear:&maxyear] meman&minyear-meman&maxyear;
	array rivas_ [&minyear:&maxyear] rivas&minyear-rivas&maxyear;
	array molnum [&minyear:&maxyear] moleculesnum&minyear-moleculesnum&maxyear;
	
	do year=&minyear to &maxyear;
			achei[year]=max(0,achei[year])*tb2samp[year];
			combo[year]=max(0,combo[year])*tb2samp[year];
			donep_[year]=max(0,donep_[year])*tb2samp[year];
			galan_[year]=max(0,galan_[year])*tb2samp[year];
			meman_[year]=max(0,meman_[year])*tb2samp[year];
			rivas_[year]=max(0,rivas_[year])*tb2samp[year];
			molnum[year]=max(0,molnum[year])*tb2samp[year];
	end;
	
	* dx prior to dec 31 of year;
	array priorAD [&minyear:&maxyear] priorAD&minyear-priorAD&maxyear;
	array priordem [&minyear:&maxyear] priorDem&minyear-priorDem&maxyear;
	array priorADRD [&minyear:&maxyear] priorADRD&minyear-priorADRD&maxyear;
	array priorsymp [&minyear:&maxyear] priorsymp&minyear-priorsymp&maxyear;
	array priorADRDp [&minyear:&maxyear] priorADRDp&minyear-priorADRDp&maxyear;
	array priornone [&minyear:&maxyear] priornone&minyear-priornone&maxyear;
	
	do year=&minyear to &maxyear;
		if tb2samp[year]=1 then do;
			priorAD[year]=0;
			priorDem[year]=0;
			priorADRD[year]=0;
			priorsymp[year]=0;
			priorADRDp[year]=0;
			priornone[year]=0;
			if .<AD_inc<=mdy(12,31,year) then priorAD[year]=1;
			if .<dem_inc<=mdy(12,31,year) then priordem[year]=1;
			if .<ADRD_inc<=mdy(12,31,year) then priorADRD[year]=1;
			if .<symp_inc<=mdy(12,31,year) then priorsymp[year]=1;
			if .<ADRDplus_inc<=mdy(12,31,year) then priorADRDp[year]=1;
			else priornone[year]=1;
		end;
	end;

	* patient characteristics;
	array female [&minyear:&maxyear] female&minyear-female&maxyear;
	array white [&minyear:&maxyear] white&minyear-white&maxyear;
	array black [&minyear:&maxyear] black&minyear-black&maxyear;
	array hispanic [&minyear:&maxyear] hispanic&minyear-hispanic&maxyear;
	array asian [&minyear:&maxyear] asian&minyear-asian&maxyear;
	array hccyr [&minyear:&maxyear] hcc&minyear-hcc&maxyear;
	array hsgyr [&minyear:&maxyear] pct_hsgrads&minyear-pct_hsgrads&maxyear;
	array incyr [&minyear:&maxyear] med_income&minyear-med_income&maxyear;
	array rxinit_age [&minyear:&maxyear] rxinit_age&minyear-rxinit_age&maxyear;
	array spec1 [&minyear:&maxyear] spec1_&minyear-spec1_&maxyear;
	
	do year=&minyear to &maxyear;
		if tb2samp[year]=1 then do;
			if rxinit ne . then do;
				if insamp[year(rxinit)] then rxinit_age[year]=(rxinit-birth_date)/365;
			end;
			female[year]=0;
			white[year]=0;
			black[year]=0;
			hispanic[year]=0;
			asian[year]=0;
			if sex=2 then female[year]=1;
			if race_bg=1 then white[year]=1;
			else if race_bg=2 then black[year]=1;
			else if race_bg=4 then asian[year]=1;
			else if race_bg=5 then hispanic[year]=1;
		end;
		hccyr[year]=hccyr[year]*tb2samp[year];
		hsgyr[year]=hsgyr[year]*tb2samp[year];
		incyr[year]=incyr[year]*tb2samp[year];
	end;

	* use characteristics;
	array spec [&minyear:&maxyear] spec&minyear-spec&maxyear;
	array pdays [&minyear:&maxyear] pdays_&minyear-pdays_&maxyear;
	array clms [&minyear:&maxyear] clms&minyear-clms&maxyear;
	
	do year=&minyear to &maxyear;
		if rxinit ne . then do; if insamp[year(rxinit)] then spec[year]=rxinit_spec*tb2samp[year]; end;
		pdays[year]=pdays[year]*tb2samp[year];
		clms[year]=clms[year]*tb2samp[year];
	end;
	
run;

/************************** Checks *****************************/
proc means data=table2 noprint;
	var rxinit_samp2008-rxinit_samp&maxyear. tb2samp_age2008-tb2samp_age&maxyear.;
	output out=rxinit_samp_ck mean()= sum()= / autoname;
run;
* People are getting younger in our sample over time;

proc means data=table2 noprint;
	class rxinit_yr;
	output out=rxinit_spec_ck mean(rxinit_spec)=;
run;
* Find that more people are getting their first fill done by a specialist over time;

proc print data=rxinit_samp_ck; run;
proc print data=rxinit_spec_ck; run;
		
proc freq data=table2;
	table rxinit_year&minyear-rxinit_year&maxyear;
run;

options obs=100;
proc print data=table2;
	where max(tb2samp2008,tb2samp2009,tb2samp2010,tb2samp2011,tb2samp2012,tb2samp2013,tb2samp2014,tb2samp2015,tb2samp&maxyear.)
	and spec1_2008 ne spec2008;
	var tb2samp: bene_id insamp: adrx: rxinit: birth_date spec: pdays: firstuse:;
run;
options obs=max;
	


%macro means(var);
proc means data=table2;
	output out=table2_&var 
	sum(&var.&minyear-&var.&maxyear)=sum&minyear-sum&maxyear mean(&var.&minyear-&var.&maxyear)=mean&minyear-mean&maxyear
	std(&var.&minyear-&var.&maxyear)=std&minyear-std&maxyear;
run;
%mend;


%means(tb2samp);
%means(achei);
%means(combo);
%means(donep);
%means(galan);
%means(meman);
%means(rivas);
%means(moleculesnum);
%means(priorAD);
%means(priorDem);
%means(priorADRD);
%means(priorsymp);
%means(priorADRDp);
%means(priornone);
%means(female);
%means(white);
%means(black);
%means(hispanic);
%means(asian);
%means(hcc);
%means(med_income);
%means(pct_hsgrads);
%means(spec);
%means(pdays_);
%means(rxinit_age);

%macro results;
data table2_results;
	format row 
	%do year=&minyear %to &maxyear;
		sum&year mean&year
	%end;;
	set table2_tb2samp(in=a1)
			table2_achei(in=a2)
			table2_combo(in=a3)
			table2_donep(in=a4)
			table2_galan(in=a5)
			table2_meman(in=a6)
			table2_rivas(in=a7)
			table2_moleculesnum(in=a8)
			table2_priorAD(in=a9)
			table2_priorDem(in=a10)
			table2_priorADRD(in=a11)
			table2_priorsymp(in=a12)
			table2_priorADRDp(in=a13)
			table2_priornone(in=a14)
			table2_female(in=a15)
			table2_white(in=a16)
			table2_black(in=a17)
			table2_hispanic(in=a18)
			table2_asian(in=a19)
			table2_hcc(in=a20)
			table2_med_income(in=a21)
			table2_pct_hsgrads(in=a22)
			table2_spec(in=a23)
			table2_pdays_(in=a24)
			table2_rxinit_age(in=a25);
	length row $15.;
	if a1  then row="tb2samp";
	if a2  then row="achei";
	if a3  then row="combo";
	if a4  then row="donep";
	if a5  then row="galan";
	if a6  then row="meman";
	if a7  then row="rivas";
	if a8  then row="molnum";
	if a9  then row="priorAD";
	if a10 then row="priorDem";
	if a11 then row="priorADRD";
	if a12 then row="priorsymp";
	if a13 then row="priorADRDp";
	if a14 then row="priornone";
	if a15 then row="female";
	if a16 then row="white";
	if a17 then row="black";
	if a18 then row="hispanic";
	if a19 then row="asian";
	if a20 then row="hcc";
	if a21 then row="income";
	if a22 then row="hsg";
	if a23 then row="spec";
	if a24 then row="pdays";
	if a25 then row="rxinit_age";
run;	
%mend;

%results;

proc contents data=table2_results; run;
	
ods excel file="./output/adrx_use_trends_&maxyear..xlsx";
proc print data=table2_results; run;
ods excel close;

	
	
	
	
	
	
	
	
	
	
	


	 