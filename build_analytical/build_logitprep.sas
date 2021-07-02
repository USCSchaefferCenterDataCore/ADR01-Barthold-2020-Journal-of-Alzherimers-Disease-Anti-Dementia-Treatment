/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 3/15/2019;

* PURPOSE: Create analytical data set for logit regression;

* INPUT: analytical, samp_geoses;
* OUTPUT: analytical_logit;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname demdx "../../data/dementiadx";
libname aht "../../data/aht/base";
libname bene "&datalib.&clean_data./BeneStatus";
%let method=any;
%let maxyr=2016;

proc contents data=addrugs.ADrx_0616_long; run;

***** Creating claim and possession day counts for ACHeI and meman;
%macro acheipdays(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years;

* pull claims for year;
data pde&year;
	&set. set addrugs.ADdrugs_0616_prscrbr (where=(year(srvc_dt)=&year));
	&merge. merge addrugs.ADdrugs_0616_prscrbr (in=a where=(year(srvc_dt)=&year)) pde&prev_year._pdays (in=b keep=bene_id push_&prev_year.);
	by bene_id;
	&merge. if a;
	if max(donep,galan,rivas)=1;
run;

* if there are mlutiple claims on the same day, then assuming combo and taking the max pdays;
proc sort data=pde&year; by bene_id srvc_dt dayssply; run;
	
data pde&year._2;
	set pde&year.;
	by bene_id srvc_dt dayssply;
	if last.srvc_dt;
run;

* Early fills pushes
	- for people that fill their prescription before emptying their last, carry the extra pills forward
	- extrapill_push is the amount, from that fill date, that is superfluous for reaching the next fill date. Capped at 10;

data pde&year._3;
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1];
	if _n_ ne obs then set pde&year._2 (firstobs=2 keep=srvc_dt rename=(srvc_dt=uplag_srvc_dt));
	set pde&year._2 nobs=obs;
	count+1;
run;

proc sort data=pde&year._3; by bene_id srvc_dt count; run;

data pde&year._4;
	set pde&year._3;
	by bene_id srvc_dt;
	if last.bene_id then uplag_srvc_dt=.;
	
	* adjusting doy flags so that they are the same as dougs - will make an adjusted version;
	doy_srvc_dt=intck('day',mdy(1,1,&year),srvc_dt)+1;
	doy_uplag_srvc_dt=intck('day',mdy(1,1,&year),uplag_srvc_dt)+1;
	
	extrapill_push=(doy_srvc_dt+dayssply)-doy_uplag_srvc_dt; * will be blank at the end of the year;
	if extrapill_push<0 then extrapill_push=0;
	if extrapill_push>10 then extrapill_push=10;
	* pushstock is the accumulated stock of extra pills. Capped at 10;
	pushstock=extrapill_push;
	&merge. if first.bene_id then pushstock=sum(pushstock,push_&prev_year.);
	
		* The methodology below will do the following:
  	1. Add the previous pushstock to the current pushstock
  	2. Calculate the number of pills to be added to the dayssply, which is the minimum of the
  		 need or the pushstock. Dayssply2=sum(dayssply,min(need,pushstock1))
  	3. Subtract the need from the pushstock sum and capping the minimum at 0 so that pushstock will never be negative.
  		 E.g. if the need is 5 and the pushstock is 3, the pushstock will be the max of 0 and -2 which is 0.
    4. Make sure the max of the pushstock that gets carried into the next day is 10.
       E.g. if the pushstock before substracting the need is 15, need is 3 then the pushstock is 15-3=12
       the pushstock that gets carried over will be the min of 10 or 12, which is 10.;

 	* creating need variable;
 	need = doy_uplag_srvc_dt-(sum(doy_srvc_dt,dayssply));
 	if last.bene_id then need=365-(sum(doy_srvc_dt,dayssply));
 	if need < 0 then need = 0 ;

 	* pushing extra pills forward;
 	retain pushstock1; * first retaining pushstock1 so that the previous pushstock will get moved to the next one;
 	if first.bene_id then pushstock1=0; * resetting the pushstock1 to 0 at the beginning of the year;
 	pushstock1=sum(pushstock1,pushstock);
 	dayssply2=sum(dayssply,min(need,pushstock1));
 	pushstock1=min(max(sum(pushstock1,-need),0),10);

	if last.bene_id then do;
		* final push from early fills;
		earlyfill_push=min(max(pushstock1,0),10);
		* extra pills from last prescription at end of year is capped at 90;
		lastfill_push=min(max(doy_srvc_dt+dayssply-365,0),90);
	end;

	array adrx_a [*] adrx_a1-adrx_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i < sum(doy_srvc_dt,dayssply2) then adrx_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=acheiclms_&year.)
	sum(dayssply)=filldays_&year. min(srvc_dt)=minfilldt_&year. max(srvc_dt)=maxfilldt_&year.
	max(adrx_a1-adrx_a365 earlyfill_push lastfill_push galan)=;
run;

data pde&year._pdays;
	set pde&year._5;
	fillperiod_&year.=max(maxfilldt_&year.-minfilldt_&year.+1,0);
	acheipdays_&year.=max(min(sum(of adrx_a1-adrx_a365),365),.);
	* inyearPush=extra push days from early fills throughout the year (capped at 30);
	* lastfill_push=amount from the last fill that goes into next year (capped at 90);
	inyear_push=min(earlyfill_push,30);
	push_&year=max(lastfill_push,inyear_push);
	if push_&year<0 then push_&year=0;
	if push_&year>90 then push_&year=90;
	keep bene_id push: acheipdays: acheiclms:;
run;
%mend;

%acheipdays(2006,2005,*,);
%acheipdays(2007,2006,,*);
%acheipdays(2008,2007,,*);
%acheipdays(2009,2008,,*);
%acheipdays(2010,2009,,*);
%acheipdays(2011,2010,,*);
%acheipdays(2012,2011,,*);
%acheipdays(2013,2012,,*);
%acheipdays(2014,2013,,*);
%acheipdays(2015,2014,,*);
%acheipdays(2016,2015,,*);
	
* Merge all together;
data acheipdays_0616;
	merge pde2006_pdays (in=a)
				pde2007_pdays (in=b)
				pde2008_pdays (in=c)
				pde2009_pdays (in=d)
				pde2010_pdays (in=e)
				pde2011_pdays (in=f)
				pde2012_pdays (in=g)
				pde2013_pdays (in=h)
				pde2014_pdays (in=i)
				pde2015_pdays (in=h)
				pde2016_pdays (in=i);
	by bene_id;
	y2006=a;
	y2007=b;
	y2008=c;
	y2009=d;
	y2010=e;
	y2011=f;
	y2012=g;
	y2013=h;
	y2014=i;
	y2015=j;
	y2016=k;

	if first.bene_id; * shouldn't change anything? originally 5300792;
	
	drop i;
run;
	
***** Creating claim and possession day counts for ACHeI and meman;
%macro memanpdays(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years;

* pull claims for year;
data pde&year;
	&set. set addrugs.ADdrugs_0616_prscrbr (where=(year(srvc_dt)=&year));
	&merge. merge addrugs.ADdrugs_0616_prscrbr (in=a where=(year(srvc_dt)=&year)) pde&prev_year._pdays (in=b keep=bene_id push_&prev_year.);
	by bene_id;
	&merge. if a;
	if meman=1;
run;

* if there are mlutiple claims on the same day, then assuming combo and taking the max pdays;
proc sort data=pde&year; by bene_id srvc_dt dayssply; run;
	
data pde&year._2;
	set pde&year.;
	by bene_id srvc_dt dayssply;
	if last.srvc_dt;
run;

* Early fills pushes
	- for people that fill their prescription before emptying their last, carry the extra pills forward
	- extrapill_push is the amount, from that fill date, that is superfluous for reaching the next fill date. Capped at 10;

data pde&year._3;
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1];
	if _n_ ne obs then set pde&year._2 (firstobs=2 keep=srvc_dt rename=(srvc_dt=uplag_srvc_dt));
	set pde&year._2 nobs=obs;
	count+1;
run;

proc sort data=pde&year._3; by bene_id srvc_dt count; run;

data pde&year._4;
	set pde&year._3;
	by bene_id srvc_dt;
	if last.bene_id then uplag_srvc_dt=.;
	
	* adjusting doy flags so that they are the same as dougs - will make an adjusted version;
	doy_srvc_dt=intck('day',mdy(1,1,&year),srvc_dt)+1;
	doy_uplag_srvc_dt=intck('day',mdy(1,1,&year),uplag_srvc_dt)+1;
	
	extrapill_push=(doy_srvc_dt+dayssply)-doy_uplag_srvc_dt; * will be blank at the end of the year;
	if extrapill_push<0 then extrapill_push=0;
	if extrapill_push>10 then extrapill_push=10;
	* pushstock is the accumulated stock of extra pills. Capped at 10;
	pushstock=extrapill_push;
	&merge. if first.bene_id then pushstock=sum(pushstock,push_&prev_year.);
	
		* The methodology below will do the following:
  	1. Add the previous pushstock to the current pushstock
  	2. Calculate the number of pills to be added to the dayssply, which is the minimum of the
  		 need or the pushstock. Dayssply2=sum(dayssply,min(need,pushstock1))
  	3. Subtract the need from the pushstock sum and capping the minimum at 0 so that pushstock will never be negative.
  		 E.g. if the need is 5 and the pushstock is 3, the pushstock will be the max of 0 and -2 which is 0.
    4. Make sure the max of the pushstock that gets carried into the next day is 10.
       E.g. if the pushstock before substracting the need is 15, need is 3 then the pushstock is 15-3=12
       the pushstock that gets carried over will be the min of 10 or 12, which is 10.;

 	* creating need variable;
 	need = doy_uplag_srvc_dt-(sum(doy_srvc_dt,dayssply));
 	if last.bene_id then need=365-(sum(doy_srvc_dt,dayssply));
 	if need < 0 then need = 0 ;

 	* pushing extra pills forward;
 	retain pushstock1; * first retaining pushstock1 so that the previous pushstock will get moved to the next one;
 	if first.bene_id then pushstock1=0; * resetting the pushstock1 to 0 at the beginning of the year;
 	pushstock1=sum(pushstock1,pushstock);
 	dayssply2=sum(dayssply,min(need,pushstock1));
 	pushstock1=min(max(sum(pushstock1,-need),0),10);

	if last.bene_id then do;
		* final push from early fills;
		earlyfill_push=min(max(pushstock1,0),10);
		* extra pills from last prescription at end of year is capped at 90;
		lastfill_push=min(max(doy_srvc_dt+dayssply-365,0),90);
	end;

	array adrx_a [*] adrx_a1-adrx_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i < sum(doy_srvc_dt,dayssply2) then adrx_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=memanclms_&year.)
	sum(dayssply)=filldays_&year. min(srvc_dt)=minfilldt_&year. max(srvc_dt)=maxfilldt_&year.
	max(adrx_a1-adrx_a365 earlyfill_push lastfill_push galan)=;
run;

data pde&year._pdays;
	set pde&year._5;
	fillperiod_&year.=max(maxfilldt_&year.-minfilldt_&year.+1,0);
	memanpdays_&year.=max(min(sum(of adrx_a1-adrx_a365),365),.);
	* inyearPush=extra push days from early fills throughout the year (capped at 30);
	* lastfill_push=amount from the last fill that goes into next year (capped at 90);
	inyear_push=min(earlyfill_push,30);
	push_&year=max(lastfill_push,inyear_push);
	if push_&year<0 then push_&year=0;
	if push_&year>90 then push_&year=90;
	keep bene_id push: memanpdays: memanclms:;
run;
%mend;

%memanpdays(2006,2005,*,);
%memanpdays(2007,2006,,*);
%memanpdays(2008,2007,,*);
%memanpdays(2009,2008,,*);
%memanpdays(2010,2009,,*);
%memanpdays(2011,2010,,*);
%memanpdays(2012,2011,,*);
%memanpdays(2013,2012,,*);
%memanpdays(2014,2013,,*);
%memanpdays(2015,2014,,*);
%memanpdays(2016,2015,,*);
	

* Merge all together;
data memanpdays_0616;
	merge pde2006_pdays (in=a)
				pde2007_pdays (in=b)
				pde2008_pdays (in=c)
				pde2009_pdays (in=d)
				pde2010_pdays (in=e)
				pde2011_pdays (in=f)
				pde2012_pdays (in=g)
				pde2013_pdays (in=h)
				pde2014_pdays (in=i)
				pde2015_pdays (in=h)
				pde2016_pdays (in=i)				;
	by bene_id;
	y2006=a;
	y2007=b;
	y2008=c;
	y2009=d;
	y2010=e;
	y2011=f;
	y2012=g;
	y2013=h;
	y2014=i;
	y2015=j;
	y2016=k;

	if first.bene_id; * shouldn't change anything? originally 5300792;
	
	drop i;
run;


***** Create dummies for sex, race and diagnosis;
data logitprep;
	merge addrugs.analytical&maxyr. (in=a drop=alzhe alzhdmte) addrugs.samp_geoses (in=b) demdx.cc_0216 (in=c)
	acheipdays_0616 (in=d) memanpdays_0616 (in=e);
	by bene_id;
	
	* sex dummy;
	if sex=2 then female=1; else female=0;
	
	* race dummies;
	if race_bg=1 then race_dw=1; else race_dw=0;
	if race_bg=2 then race_db=1; else race_db=0;
	if race_bg=4 then race_da=1; else race_da=0;
	if race_bg=5 then race_dh=1; else race_dh=0;
	
run;

***** Turning long;
data logitprep1;
	set logitprep;
	by bene_id;
	
	array insamp [2008:&maxyr.] insamp2008-insamp&maxyr.;
	array hccyr [2008:&maxyr.] hcc2008-hcc&maxyr.;
	array hsgyr [2008:&maxyr.] pct_hsgrads2008-pct_hsgrads&maxyr.;
	array incyr [2008:&maxyr.] med_income2008-med_income&maxyr.;
	array age_beg [2008:&maxyr.] age_beg2008-age_beg&maxyr.;
	array pdays_ [2008:&maxyr.] pdays_2008-pdays_&maxyr.;
	array clms_ [2008:&maxyr.] clms_2008-clms_&maxyr.;
	array zipyr [2008:&maxyr.] zip2008-zip&maxyr.;
	array adrx_ [2008:&maxyr.] adrx2008-adrx&maxyr.;
	array acheiclms_ [2008:&maxyr.] acheiclms_2008-acheiclms_&maxyr.;
	array memanclms_ [2008:&maxyr.] memanclms_2008-memanclms_&maxyr.;
	array acheipdays_ [2008:&maxyr.] acheipdays_2008-acheipdays_&maxyr.;
	array memanpdays_ [2008:&maxyr.] memanpdays_2008-memanpdays_&maxyr.;
	
	yrssincedx=0;
	if ADRDplus_inc ne . then do yr=2008 to &maxyr.;
		if insamp[yr]=1 then do;
			dx_dsymp=0;
			dx_dnadd=0;
			dx_dad=0;
			
			year=yr;
			hcc=hccyr[yr];
			hsg=hsgyr[yr];
			inc=incyr[yr];
			age=age_beg[yr];
			zip=zipyr[yr];
			
			pdays=pdays_[yr];
			clms=clms_[yr];
			adrx=adrx_[yr];
			
			acheipdays=acheipdays_[yr];
			acheiclms=acheiclms_[yr];
			
			memanpdays=memanpdays_[yr];
			memanclms=memanclms_[yr];
			
			if year(ADRDplus_inc)<=year then yrssincedx=yr-year(ADRDplus_inc);
			
			if .<year(copde)<=year then cc_copd=1; else cc_copd=0;
			if .<year(asthma_ever)<=year then cc_asthma=1; else cc_asthma=0;
			if .<year(chrnkdne)<=year then cc_ckd=1; else cc_ckd=0;
			if .<year(hypert_ever)<=year then cc_hypert=1; else cc_hypert=0;
			if .<year(chfe)<=year then cc_chfe=1; else cc_chfe=0;
			if .<year(glaucmae)<=year then cc_glaucma=1; else cc_glaucma=0;
			if .<year(amie)<=year then cc_ami=1; else cc_ami=0;
			if .<year(atrialfe)<=year then cc_afib=1; else cc_afib=0;
			if .<year(ischmche)<=year then cc_ischmch=1; else cc_ischmch=0;
			
			if adrx=1 then adrx71=1; else adrx71=0;
			if pdays>=90 and clms>=2 then adrx902=1; else adrx902=0;
			if pdays>=180 and clms>=2 then adrx1802=1; else adrx1802=0;
			if pdays>=270 and clms>=2 then adrx2702=1; else adrx2702=0;
			
			if acheipdays>=7 and acheiclms>=1 then achei71=1; else achei71=0;
			if acheipdays>=90 and acheiclms>=2 then achei902=1; else achei902=0;
			if acheipdays>=180 and acheiclms>=2 then achei1802=1; else achei1802=0;
			if acheipdays>=270 and acheiclms>=2 then achei2702=1; else achei2702=0;
			
			if memanpdays>=7 and memanclms>=1 then meman71=1; else meman71=0;
			if memanpdays>=90 and memanclms>=2 then meman902=1; else meman902=0;
			if memanpdays>=180 and memanclms>=2 then meman1802=1; else meman1802=0;
			if memanpdays>=270 and memanclms>=2 then meman2702=1; else meman2702=0;
			
			if .<symp_inc<=mdy(12,31,year) then dxgroup=3; 
			if .<dem_inc<=mdy(12,31,year) then dxgroup=2;
			if .<ad_inc<=mdy(12,31,year) then dxgroup=1;
			if dxgroup=3 then dx_dsymp=1;
			if dxgroup=2 then dx_dnadd=1;
			if dxgroup=1 then dx_dad=1;
			if max(dx_dsymp,dx_dnadd,dx_dad)=1 then output;
		end;
	end;
	
run;

proc sort data=logitprep1; by bene_id year; run;
proc sort data=aht.phy_long0616 out=phy_long0616; by bene_id year; run;

***** Identifying LIS and Dual using bene status file - long;
%macro duallis;
data duallis;
	set
		%do year=2008 %to &maxyr.; 
		bene.bene_status_year&year (keep=bene_id year lis_allyr lis_mo_yr dual_full_allyr dual_full_mo_yr
		anydual anydual_full anydual_restrict anylis)
		%end;;
	if anydual_full="Y" or anydual_restrict="Y" then dual=1; else dual=0;
	if anylis="Y" then lis=1; else lis=0;
run;

proc sort data=duallis; by bene_id year; run;
%mend;

%duallis;

data logitprep2;
	merge logitprep1 (in=a) phy_long0616 (in=b) duallis (in=c keep=bene_id year dual lis);
	by bene_id year;
	if a;
	keep bene_id year hcc hsg inc age race_dw race_db race_da race_dh dx_d: female adrx71 adrx902 adrx1802 adrx2702
	zip achei71 achei902 achei1802 achei2702 meman71 meman902 meman1802 meman2702
	cc: yrssincedx dual lis phyvis AD_inc dem_inc ADRDplus_inc symp_inc;
run;

* Checks;

proc univariate data=logitprep2; var phyvis hcc hsg inc; run;
	
***** Creating quartlies for phyvis, hcc, hsg, and inc;
proc means data=logitprep2 nway noprint;
	var phyvis hcc hsg inc;
	output out=stats min= p25= p50= p75= / autoname;
run;

proc contents data=stats; run;
	
proc sql;
	create table addrugs.analytical_logit&maxyr. as
	select x.*,
	case when y.phyvis_min<=x.phyvis<y.phyvis_p25 then 1
			 when y.phyvis_p25<=x.phyvis<=y.phyvis_p50 then 2
			 when y.phyvis_p50<=x.phyvis<=y.phyvis_p75 then 3
			 when y.phyvis_p75<=x.phyvis then 4
	end as phyvis4,
	case when y.hcc_min<=x.hcc<y.hcc_p25 then 1
			 when y.hcc_p25<=x.hcc<y.hcc_p50 then 2
			 when y.hcc_p50<=x.hcc<y.hcc_p75 then 3
			 when y.hcc_p75<=x.hcc then 4
	end as hcc4,
	case when y.hsg_min<=x.hsg<y.hsg_p25 then 1
			 when y.hsg_p25<=x.hsg<y.hsg_p50 then 2
			 when y.hsg_p50<=x.hsg<y.hsg_p75 then 3
			 when y.hsg_p75<=x.hsg then 4
	end as hsg4,
	case when y.inc_min<=x.inc<y.inc_p25 then 1
			 when y.inc_p25<=x.inc<y.inc_p50 then 2
			 when y.inc_p50<=x.inc<y.inc_p75 then 3
			 when y.inc_p75<=x.inc then 4
	end as inc4	
	from logitprep2 as x, stats as y
	order by bene_id, year;
quit;

proc contents data=addrugs.analytical_logit&maxyr.; run;
	
proc univariate data=addrugs.analytical_logit&maxyr.; run;
	
proc print data=stats; run;

	/* Create a yearly data set of having seen a specialist 
	 Specialist is defined using ordering algorithm from ADRD incidence 
	 and followup */
	 
data bene_addrugs;
	set addrugs.adrd_dxprv_specrate_any addrugs.symp_dxprv_specrate_any;
	by bene_id demdx_dt;
	if spec=1 then specdt=demdx_dt;
	else if spec=0 then nonspecdt=demdx_dt;
	keep bene_id specdt nonspecdt spec year;
run;

proc means data=bene_addrugs noprint;
	class bene_id;
	output out=bene_firstspec min(specdt nonspecdt)=first_specdt first_nonspecdt;
run;

proc print data=bene_addrugs (obs=100); run;

data addrugs.analytical_logit_spec&maxyr.;
	merge addrugs.analytical_logit&maxyr. (in=a) bene_firstspec (in=b);
	by bene_id;
	if a;
	foundspec=b;
	spec=0;
	if .<first_specdt<=mdy(12,31,year) then spec=1;
run;

proc freq data=addrugs.analytical_logit_spec&maxyr.;
	table spec;
run;

proc print data=addrugs.analytical_logit_spec&maxyr. (obs=100);
	where spec=0 and first_specdt ne .;
	var bene_id year first_specdt spec;
run;

	