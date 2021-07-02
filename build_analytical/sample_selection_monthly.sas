/*********************************************************************************************/
TITLE1 'AD Incidence Exploration';

* AUTHOR: Patricia Ferido;

* DATE: 7/3/2019;

* PURPOSE: Selecting Sample - creating a monthly version with all monthly related variables and a monthly ffsptd variable indicating 
	enrollment in FFS and Part D in that month-fixing to include HMO IND= 4 as FFS:
* INPUT: bene_status_yearYYYY, bene_demog2015;
* OUTPUT: samp_3yrffsptd_0316;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%partABlib(types=bsf);
libname bene "&datalib.&clean_data./BeneStatus";
libname exp "../../data/adrd_inc_explore";
%include "&maclib.renvars.mac";

***** Years of Data;
%let mindatayear=2002;
%let maxdatayear=2016;

***** Step 1: Pull all bsfab and bsfd records from people in our sample (insamp2007-insamp&maxdatayear.);
%macro pullbsf;
proc sql;
	%do year=&mindatayear %to &maxdatayear;
		create table bsfab&year as
		select x.*
		from bsf.bsfab&year (keep=bene_id buyin01-buyin12 hmoind01-hmoind12 where=(bene_id ne "")
		rename=(%renvars(buyin01 buyin02 buyin03 buyin04 buyin05 buyin06 buyin07 buyin08 buyin09 buyin10 buyin11 buyin12
		hmoind01 hmoind02 hmoind03 hmoind04 hmoind05 hmoind06 hmoind07 hmoind08 hmoind09 hmoind10 hmoind11 hmoind12,
		newlist=buyin&year._1 buyin&year._2 buyin&year._3 buyin&year._4 buyin&year._5 buyin&year._6 buyin&year._7 buyin&year._8 buyin&year._9 buyin&year._10 buyin&year._11 buyin&year._12
		hmoind&year._1 hmoind&year._2 hmoind&year._3 hmoind&year._4 hmoind&year._5 hmoind&year._6 hmoind&year._7 hmoind&year._8 hmoind&year._9 hmoind&year._10 hmoind&year._11 hmoind&year._12))) as x
		inner join exp.ffsptd_samp_0416 (where=(insamp2006=1 or insamp2007=1 or insamp2008=1 or insamp2009=1 or insamp2010=1 or insamp2011=1 or insamp2012=1 or insamp2013=1 or insamp2014=1
		or insamp2015=1 or insamp2016=1)) as y
		on x.bene_id=y.bene_id
		order by x.bene_id;
	%end;
quit;

proc sql;
	%do year=2006 %to 2014;
		create table bsfd&year as
		select x.*
		from bsf.bsfd&year (keep=bene_id cntrct01-cntrct12	where=(bene_id ne "") rename=(%renvars(cntrct01 cntrct02 cntrct03 cntrct04 cntrct05 cntrct06 cntrct07 cntrct08 cntrct09 cntrct10 cntrct11 cntrct12,
		newlist=cntrct&year._1 cntrct&year._2 cntrct&year._3 cntrct&year._4 cntrct&year._5 cntrct&year._6 cntrct&year._7 cntrct&year._8 cntrct&year._9 cntrct&year._10 cntrct&year._11 cntrct&year._12))) as x
		inner join exp.ffsptd_samp_0416 (where=(insamp2006=1 or insamp2007=1 or insamp2008=1 or insamp2009=1 or insamp2010=1 or insamp2011=1 or insamp2012=1 or insamp2013=1 or insamp2014=1
		or insamp2015=1 or insamp2016=1)) as y
		on x.bene_id=y.bene_id
		order by x.bene_id;
	%end;
	%do year=2015 %to &maxdatayear.;
		create table bsfd&year as
		select x.*
		from bsf.bsfd&year (keep=bene_id ptdcntrct01-ptdcntrct12	where=(bene_id ne "") rename=(%renvars(ptdcntrct01 ptdcntrct02 ptdcntrct03 ptdcntrct04 ptdcntrct05 ptdcntrct06 ptdcntrct07 ptdcntrct08 ptdcntrct09 ptdcntrct10 ptdcntrct11 ptdcntrct12,
		newlist=cntrct&year._1 cntrct&year._2 cntrct&year._3 cntrct&year._4 cntrct&year._5 cntrct&year._6 cntrct&year._7 cntrct&year._8 cntrct&year._9 cntrct&year._10 cntrct&year._11 cntrct&year._12))) as x
		inner join exp.ffsptd_samp_0416 (where=(insamp2006=1 or insamp2007=1 or insamp2008=1 or insamp2009=1 or insamp2010=1 or insamp2011=1 or insamp2012=1 or insamp2013=1 or insamp2014=1
		or insamp2015=1 or insamp2016=1)) as y
		on x.bene_id=y.bene_id
		order by x.bene_id;
	%end;
quit;

%mend;

%pullbsf;

***** Step 2: Merge bsfab and bsfd & identify ffsptd sample;
%macro bsfall;
data exp.ffsptd_samp_monthly_fix;
	merge bsfab2002-bsfab&maxdatayear. bsfd2006-bsfd&maxdatayear. exp.ffsptd_samp_0416 (keep=bene_id insamp:);
	by bene_id;
	
	if max(of insamp2006-insamp&maxdatayear)=1;
	
	* in FFS PTD if buyin in("3","C"), hmoind=0 and substr(cntrct,1,1) in("H","E","R","S");
	array ffsptd [*] $
		%do year=2006 %to &maxdatayear.;
			%do mo=1 %to 12;
				ffsptd&year._&mo
			%end;
		%end;;
	array cntrct [*] $
		%do year=2006 %to &maxdatayear.;
			%do mo=1 %to 12;
				cntrct&year._&mo
			%end;
		%end;;
	array buyin [*] $
		%do year=2006 %to &maxdatayear.;
			%do mo=1 %to 12;
				buyin&year._&mo
			%end;
		%end;;
	array hmoind [*] $
		%do year=2006 %to &maxdatayear.;
			%do mo=1 %to 12;
				hmoind&year._&mo
			%end;
		%end;;
	
	do i=1 to dim(ffsptd);
		if hmoind[i] in("0","4") and substr(cntrct[i],1,1) in("H","E","R","S") and buyin[i] in("3","C") then ffsptd[i]="Y"; 
	end;
	drop insamp:;
run;
%mend;

%bsfall;