/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 11/7/2018;

* PURPOSE: Build geographic stats for all beneficiaries in our sample;

* INPUT: ffs
* OUTPUT: analysis;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname exp "../../data/adrd_inc_explore";
libname acs "&datalib.ContextData/SAS";
libname geo "&datalib.Clean_Data/Geography";
libname hcc "&datalib.Clean_Data/HealthStatus/HCCscores";
libname xwlk "&datalib.ContextData/Geography/Crosswalks/zip_to_2010ZCTA/MasterXwalk";

* Merge beneficiaries in sample to geographic data;
* First, I'm merging all the information to make a long beneficiary, year level data set;
* Then, I'll turn wide;

%let minyear=2007;
%let maxyear=2016;

%macro geohcc(byear,eyear);
	%do year=&byear %to &eyear;
		data samp_geo&year;
			merge exp.ffsptd_samp_0416 (in=a keep=bene_id anysamp where=(anysamp=1))
						geo.bene_geo_&year
						hcc.bene_hccscores&year (keep=bene_id resolved_hccyr);
			by bene_id;
			if a;
			year=&year;
			rename resolved_hccyr=hcc;
		run;
		
		proc sort data=samp_geo&year; by zip5 year; run;
		proc sort data=xwlk.zcta2010tozip out=zctaxwlk; by zip year; run;
			
		data samp_geo1&year;
			merge samp_geo&year (in=a) zctaxwlk (in=b rename=zip=zip5);
			by zip5 year;
			if a;
			zcta5=fuzz(zcta5ce10*1);
			if zcta5=. then missingzcta=1;
			else missingzcta=0;
		run;
		
		proc freq data=samp_geo1&year;
			table missingzcta;
		run;
		
		proc sort data=samp_geo1&year; by zcta5; run;
			
		* Merge to percent high school grads and median income;
		data samp_geo2&year;
			merge samp_geo1&year (in=a) 
						acs.acs_income_raw (in=b keep=zcta5 b19013_001e)
						acs.acs_educ_65up (in=c keep=zcta5 pct_hsgrads);
			by zcta5;
			if a;
			inc=b;
			hsg=c;
			rename b19013_001e=med_income;
		run;
		
		proc freq data=samp_geo2&year;
			table inc hsg;
		run;
		
		proc sort data=samp_geo2&year; by bene_id year; run;
	%end;
%mend;

%geohcc(&minyear,&maxyear);

* Stack all, transpose and fill in missing values with averages;
data samp_geo;
	set samp_geo2&minyear-samp_geo2&maxyear;
	by bene_id year;
run;

proc transpose data=samp_geo out=samp_geo_hsg (drop=_name_) prefix=pct_hsgrads;
	var pct_hsgrads;
	id year;
	by bene_id;
run;

proc transpose data=samp_geo out=samp_geo_hcc (drop=_name_) prefix=hcc;
	var hcc;
	id year;
	by bene_id;
run;

proc transpose data=samp_geo out=samp_geo_inc (drop=_name_) prefix=med_income;
	var med_income;
	id year;
	by bene_id;
run;

proc transpose data=samp_geo out=samp_geo_zip (drop=_name_) prefix=zip;
	var zip5;
	id year;
	by bene_id;
run;

data samp_geo_wide;
	merge samp_geo_hsg samp_geo_hcc samp_geo_inc samp_geo_zip;
	by bene_id;
	drop _label_;
run;

* Getting average values for filling in missings;
proc means data=samp_geo_wide;
	output out=averages (drop=_type_ _freq_) mean(pct_hsgrads2007-pct_hsgrads&maxyear. hcc2007-hcc&maxyear. med_income2007-med_income&maxyear.)=
	avghsg2007-avghsg&maxyear. avghcc2007-avghcc&maxyear. avginc2007-avginc&maxyear.;
run;

proc sql;
	create table samp_geo_wide1 as
	select x.*, y.*
	from samp_geo_wide as x, averages as y;
quit;

data samp_geo_wide2;
	set samp_geo_wide1;
	array hsg [2007:&maxyear.] pct_hsgrads2007-pct_hsgrads&maxyear.;
	array hcc [2007:&maxyear.] hcc2007-hcc&maxyear.;
	array inc [2007:&maxyear.] med_income2007-med_income&maxyear.;
	array avghsg [2007:&maxyear.] avghsg2007-avghsg&maxyear.;
	array avghcc [2007:&maxyear.] avghcc2007-avghcc&maxyear.;
	array avginc [2007:&maxyear.] avginc2007-avginc&maxyear.;
	
	missinghsg=0;
	missinghcc=0;
	missinginc=0;
	meanhsg=mean(of pct_hsgrads2007-pct_hsgrads&maxyear.);
	meanhcc=mean(of hcc2007-hcc&maxyear.);
	meaninc=mean(of med_income2007-med_income&maxyear.);
	* first fill in with beneficiary average;
	do year=2007 to &maxyear.;
		if hsg[year]=. then do; missinghsg=1; hsg[year]=meanhsg; end;
		if hcc[year]=. then do; missinghcc=1; hcc[year]=meanhcc; end;
		if inc[year]=. then do; missinginc=1; inc[year]=meaninc; end;
	end;
	* then fill in with across year average;
	do year=2007 to &maxyear.;
		if hsg[year]=. then do; missinghsg=2; hsg[year]=avghsg[year]; end; 
		if hcc[year]=. then do; missinghcc=2; hcc[year]=avghcc[year]; end;
		if inc[year]=. then do; missinginc=2; inc[year]=avginc[year]; end;
	end;
	* if still blank, income and hsg for &maxyear. if they never have income hsg data, then taking average across years;
	do year=2007 to &maxyear.;
		if hsg[year]=. then do; missinghsg=3; hsg[year]=mean(of pct_hsgrads2007-pct_hsgrads&maxyear.); end;
		if inc[year]=. then do; missinginc=3; inc[year]=mean(of med_income2007-med_income&maxyear.); end;
	  if hcc[year]=. then do; missinghcc=3; hcc[year]=mean(of hcc2007-hcc&maxyear.); end;
	end;
run;

proc freq data=samp_geo_wide2;
	table missinghsg missinghcc missinginc; 
run;

data addrugs.samp_geoses;
	set samp_geo_wide2;
	drop avg: missing: mean:;
run;

proc contents data=samp_geo_wide2; run;


	




				
