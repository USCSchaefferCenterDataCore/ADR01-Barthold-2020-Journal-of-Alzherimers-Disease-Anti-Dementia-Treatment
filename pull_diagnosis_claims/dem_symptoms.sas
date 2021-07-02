/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pull Dementia Symptoms Diagnosis Codes;
* Input: &ctyp._diag&year;
* Output: dem_symptoms_2002_2014;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname exp "../../data/adrd_inc_explore";
libname extracts cvp ("&datalib.Claim_Extracts/DiagnosisCodes","&datalib.Claim_Extracts/Providers");

****** Dementia Symptoms Dx ******
* amnesia - 780.93;
* aphsia - 784.3;
* other symbolic dysfunction, includes agnosia and apraxia - 784.69;

%let minyear=2002;
%let maxyear=2016;
%let demsymptoms="78093","7843","78469","R411","R412","R413","R4701","R481","R482","R488";
%let amnesia="78093","R411","R412","R413";
%let aphasia="7843","R4701";
%let agnosia_apraxia="78469","R481","R482","R488";

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=);
data &ctyp._&byear._&eyear;
	set 
		%do year=&byear %to &eyear;
			extracts.&ctyp._diag&year (keep=bene_id year thru_dt diag: &dxv drop=&dropv keep=&keepv)
		%end;;
		
	array diag [*] diag: &dxv;
	symptom_&ctyp=0;
	amnesia_&ctyp=0;
	aphasia_&ctyp=0;
	agnosia_apraxia_&ctyp=0;
	do i=1 to dim(diag);
		if diag[i] in(&demsymptoms) then do;
			symptom_&ctyp=1;
			if diag[i] in(&amnesia) then amnesia_&ctyp=1;
			if diag[i] in(&aphasia) then aphasia_&ctyp=1;
			if diag[i] in(&agnosia_apraxia) then agnosia_apraxia_&ctyp=1;
		end;
	end;
	if symptom_&ctyp=1;
	
	drop diag: &dxv;
	
run;
%mend;

%macro append_dx(ctyp);
data exp.demsymptoms_&ctyp._&minyear._&maxyear;
	set &ctyp._2002_2005
			&ctyp._2006_2009
			&ctyp._2010_&maxyear.;
run;


proc sql;
	create table &ctyp._&minyear._&maxyear._1 as
	select bene_id, year, thru_dt as date, max(symptom_&ctyp) as symptom_&ctyp, max(amnesia_&ctyp) as amnesia_&ctyp,
		max(aphasia_&ctyp) as aphasia_&ctyp, max(agnosia_apraxia_&ctyp) as agnosia_apraxia_&ctyp
	from exp.demsymptoms_&ctyp._&minyear._&maxyear
	group by bene_id, year, date
	order by bene_id, year, date;
quit;

%mend;


%getdx(ip,2002,2005,dxv=admit_diag principal_diag,keepv=claim_id)
%getdx(ip,2006,2009,dxv=admit_diag,keepv=claim_id)
%getdx(ip,2010,&maxyear.,dxv=admit_diag principal_diag,keepv=claim_id)
%append_dx(ip)

%getdx(snf,2002,2005,dxv=admit_diag principal_diag,keepv=claim_id)
%getdx(snf,2006,2009,dxv=admit_diag,keepv=claim_id)
%getdx(snf,2010,&maxyear.,dxv=admit_diag principal_diag,keepv=claim_id)
%append_dx(snf)


%getdx(hha,2002,2005,dxv=principal_diag,keepv=claim_id)
%getdx(hha,2006,2009,dxv=,keepv=claim_id)
%getdx(hha,2010,&maxyear.,dxv=principal_diag,keepv=claim_id)
%append_dx(hha)

%getdx(op,2002,2005,dxv=principal_diag,keepv=claim_id)
%getdx(op,2006,2009,dxv=admit_diag,keepv=claim_id)
%getdx(op,2010,&maxyear.,dxv=principal_diag,keepv=claim_id)
%append_dx(op)

%getdx(car,2002,2005,dxv=,dropv=diag_ct,keepv=claim_id)
%getdx(car,2006,2009,dxv=,keepv=claim_id)
%getdx(car,2010,&maxyear.,dxv=principal_diag,keepv=claim_id)
%append_dx(car)


/* car line diagnoses */

data carline_2002_2009;
   set extracts.car_diag_line2002 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
   		 extracts.car_diag_line2003 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
   		 extracts.car_diag_line2004 (keep=bene_id year expnsdt1 line_diag claim_id line_num)	
       extracts.car_diag_line2005 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2006 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2007 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2008 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2009 (keep=bene_id year expnsdt1 line_diag claim_id line_num);
  format line_diag1 $7.;
 	line_diag1=line_diag;
 	symptom_carline=0;
	amnesia_carline=0;
	aphasia_carline=0;
	agnosia_apraxia_carline=0;       
 	if line_diag in(&demsymptoms) then do;
 		symptom_carline=1;
		if line_diag in(&amnesia) then amnesia_carline=1;
		if line_diag in(&aphasia) then aphasia_carline=1;
		if line_diag in(&agnosia_apraxia) then agnosia_apraxia_carline=1;
	end;
	if symptom_carline=1;
	drop line_diag;
	rename line_diag1=line_diag;
run;	

data carline_2010_&maxyear.;
   set extracts.car_diag_line2010 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2011 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2012 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2013 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2014 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2015 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       extracts.car_diag_line2016 (keep=bene_id year expnsdt1 line_diag claim_id line_num)
       
       ;
  format line_diag1 $7.;
  line_diag1=line_diag;
	symptom_carline=0;
	amnesia_carline=0;
	aphasia_carline=0;
	agnosia_apraxia_carline=0;       
 	if line_diag in(&demsymptoms) then do;
 		symptom_carline=1;
		if line_diag in(&amnesia) then amnesia_carline=1;
		if line_diag in(&aphasia) then aphasia_carline=1;
		if line_diag in(&agnosia_apraxia) then agnosia_apraxia_carline=1;
	end;
	if symptom_carline=1;
	drop line_diag;
	rename line_diag1=line_diag;
run;

data exp.demsymptoms_carline_2002_&maxyear.;
	set carline_2002_2009 carline_2010_&maxyear.;
run;

proc sql;
	create table carline_2002_&maxyear._1 as
	select bene_id, year, expnsdt1 as date, max(symptom_carline) as symptom_carline, max(amnesia_carline) as amnesia_carline,
		max(aphasia_carline) as aphasia_carline, max(agnosia_apraxia_carline) as agnosia_apraxia_carline
	from exp.demsymptoms_carline_2002_&maxyear.
	group by bene_id, year, date
	order by bene_id, year, date;
quit;

*** Merge all together;
data exp.dem_symptoms2002_&maxyear.;
	merge ip_2002_&maxyear._1
				hha_2002_&maxyear._1
				car_2002_&maxyear._1
				carline_2002_&maxyear._1
				snf_2002_&maxyear._1
				op_2002_&maxyear._1;
	by bene_id year date;
	if bene_id ne "";
	
	array symptom_ [*] symptom_:;
	array amnesia_ [*] amnesia_:;
	array aphasia_ [*] aphasia_:;
	array agnosia_apraxia_ [*] agnosia_apraxia_:;
	
	symptom=0;
	amnesia=0;
	aphasia=0;
	agnosia_apraxia=0;
	
	do i=1 to dim(symptom_);
		if symptom_[i]=1 then symptom=1;
		if amnesia_[i]=1 then amnesia=1;
		if aphasia_[i]=1 then aphasia=1;
		if agnosia_apraxia_[i]=1 then agnosia_apraxia=1;
	end;
	
	drop i;
	
run;

proc contents data=exp.dem_symptoms2002_&maxyear.; run;

proc freq data=exp.dem_symptoms2002_&maxyear.;
	table symptom amnesia aphasia agnosia_apraxia year;
run;

options obs=50;
proc print data=exp.dem_symptoms2002_&maxyear.; run;


