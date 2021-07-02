/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Merges Providers to dementia symptom claims;
* Input: symptom_dates;
* Output: symptom_dx_prov_&ctyp._2004_2013;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname extracts cvp ("&datalib.Claim_Extracts/DiagnosisCodes","&datalib.Claim_Extracts/Providers");
libname exp "../../data/adrd_inc_explore";

%let maxyr=2016;

* 1) Merge Provider Extract to Diagnosis Extracts by bene_id, year, claim_id & keeping relevant information;
%let clmtypes=ip snf hh op car;

* If there's already a provider for that claim and it's a new provider, then keeping both;

* macro for creating macro variables from the provider list;
%macro createmvar(list);
data _null_;
	%global max;
	str="&list";
	call symput('max',countw(str));
run;
	
data _null_;
	str="&list";
	do i=1 to &max;
		v=scan(str,i,"");
		call symput(compress('var'||i),strip(v));
	end;
%mend;

* macro for creating variables;
%macro prov(input,ctyp,byear,eyear,provv=,byvar=,keepv=,datev=);
	
%createmvar(&provv); run;

%put &max;

**** Splitting out into yearly data sets to sql merge by year;
data 
	%do year=&byear %to &eyear;
		&ctyp.dx_&year.
	%end;;
	set &input.;
	rename &datev=demdx_dt;
	keep bene_id year claim_id &byvar &datev;
	%do year=&byear %to &eyear;
		if year=&year then output &ctyp.dx_&year.;
	%end;
run;


***** Merging to provider extract by year;
%let maxlessone=%eval(&max-1);

%do year=&byear %to &eyear;
proc sql;
	create table &ctyp.prov_&year as
	select x.*,(y.year ne .) as foundprv, 
	%do i=1 %to &maxlessone;
		y.&&var&i format=$15. length=15,
	%end;
	%do i=&max %to &max;
	y.&&var&i format=$15. length=15
	%end;
	from &ctyp.dx_&year as x left join extracts.&ctyp.provider_id&year (where=(bene_id ne "")) as y
	on x.bene_id=y.bene_id and x.year=y.year and x.claim_id=y.claim_id 
	%if "&ctyp"="car_" %then %do;
		and x.line_num=y.line_num
	%end;
	order by x.bene_id, x.year, x.claim_id
	%if "&ctyp"="car_" %then %do;
		,x.line_num
	%end;;
quit;

proc contents data=&ctyp.prov_&year; run;
%end;
%mend;

**** Append all years and then run analysis;
%macro append(ctyp,byvar=);
	
data addrugs.symp_dxprv_&ctyp.&minyr._&maxyr;
	set 
		%do year=&minyr %to &maxyr;
			&ctyp.prov_&year 
		%end;;
	by bene_id year claim_id &byvar;
run;

proc freq data=addrugs.symp_dxprv_&ctyp.&minyr._&maxyr;
	table foundprv;
run;
%mend;


%prov(exp.demsymptoms_ip_2002_&maxyr.,ip_,2002,&maxyr.,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin,datev=thru_dt);
%append(ip_);

%prov(exp.demsymptoms_hha_2002_&maxyr.,hha_,2002,2005,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin,datev=thru_dt);
%prov(exp.demsymptoms_hha_2002_&maxyr.,hha_,2006,&maxyr.,provv=at_npi at_upin,datev=thru_dt);
%append(hha_);

%prov(exp.demsymptoms_op_2002_&maxyr.,op_,2002,&maxyr.,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin,datev=thru_dt);
%append(op_);

%prov(exp.demsymptoms_snf_2002_&maxyr.,snf_,2002,&maxyr.,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin,datev=thru_dt);
%append(snf_);

%prov(exp.demsymptoms_car_2002_&maxyr.,car_r,2002,&maxyr.,provv=rfr_npi rfr_upin,datev=thru_dt);
%append(car_r);

%prov(exp.demsymptoms_carline_2002_&maxyr.,car_,2002,2005,byvar=line_num,provv=hcfaspcl carrspcl prf_prfl prf_npi prf_upin prgrpnpi prv_type,keepv=line_num,datev=expnsdt1);
%prov(exp.demsymptoms_carline_2002_&maxyr.,car_,2006,&maxyr.,byvar=line_num,provv=hcfaspcl prf_prfl prf_npi prf_upin prgrpnpi prv_type,keepv=line_num,datev=expnsdt1);
%append(car_,byvar=line_num);

* checks;
proc contents data=addrugs.symp_dxprv_hha_2002_&maxyr.;
proc contents data=addrugs.symp_dxprv_ip_2002_&maxyr.;
proc contents data=addrugs.symp_dxprv_op_2002_&maxyr.;
proc contents data=addrugs.symp_dxprv_snf_2002_&maxyr.;
proc contents data=addrugs.symp_dxprv_car_r2002_&maxyr.;

%macro freq(ctyp);
proc freq data=addrugs.symp_dxprv_&ctyp.2002_&maxyr.;
	table foundprv;
	title3 "&ctyp match";
run;
%mend;

%freq(hha_);
%freq(ip_);
%freq(snf_);
%freq(car_r);
%freq(op_);

		
		
		


