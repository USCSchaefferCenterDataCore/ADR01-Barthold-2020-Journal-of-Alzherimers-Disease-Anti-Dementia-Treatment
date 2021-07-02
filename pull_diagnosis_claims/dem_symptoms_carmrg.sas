/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pull Dementia Symptoms Diagnosis Codes;
* Input: &ctyp._diag&year;
* Output: dem_symptoms_2002_2013;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname exp "../../data/adrd_inc_explore";
libname extracts cvp ("&datalib.Claim_Extracts/DiagnosisCodes","&datalib.Claim_Extracts/Providers");

%let maxyear=2016;

proc sort data=exp.demsymptoms_carline_2002_&maxyear out=carline; by bene_id claim_id; run;
	
* Transposing carrier line file by bene and claim id;
proc transpose data=carline
	out=carline_t_amnesia (drop=_name_  )
	prefix=amnesia_carline;
	var amnesia_carline;
	by bene_id claim_id;
run;

proc transpose data=carline
	out=carline_t_aphasia (drop=_name_  )
	prefix=aphasia_carline;
	var aphasia_carline;
	by bene_id claim_id;
run;

proc transpose data=carline
	out=carline_t_agnosia_apraxia (drop=_name_  )
	prefix=agnosia_apraxia_carline;
	var agnosia_apraxia_carline;
	by bene_id claim_id;
run;

proc transpose data=carline
	out=carline_t_symptoms(drop=_name_  )
	prefix=symptom_carline;
	var symptom_carline;
	by bene_id claim_id;
run;

proc transpose data=carline
	out=carline_t_linedt(drop=_name_  )
	prefix=expnsdt1;
	var expnsdt1;
	by bene_id claim_id;
run;

proc sort data=exp.demsymptoms_car_2002_&maxyear out=car; by bene_id claim_id; run;

data exp.demsymptoms_carmrg_2002_&maxyear.;
	merge car (in=a)
	carline_t_symptoms carline_t_agnosia_apraxia carline_t_aphasia carline_t_amnesia
	carline_t_linedt;
	by bene_id claim_id;
	symptom_carmrg=max(symptom_car,symptom_carline1-symptom_carline13);
	aphasia_carmrg=max(aphasia_car,aphasia_carline1-aphasia_carline13);
	agnosia_apraxia_carmrg=max(agnosia_apraxia_car,agnosia_apraxia_carline1-agnosia_apraxia_carline13);
	amnesia_carmrg=max(amnesia_car,amnesia_carline1-amnesia_carline13);
	* compare dates;
	array expnsdt [*] expnsdt:;
	flag=.;
	do i=2 to dim(expnsdt);
		if expnsdt[i] ne . and expnsdt[i-1] ne . and expnsdt[i] ne expnsdt[i-1] then flag=1;
	end;
run;

proc freq data=exp.demsymptoms_carmrg_2002_&maxyear.;
	table flag / missing;
run;

options obs=100;
proc print data=exp.demsymptoms_carmrg_2002_&maxyear.; run;




