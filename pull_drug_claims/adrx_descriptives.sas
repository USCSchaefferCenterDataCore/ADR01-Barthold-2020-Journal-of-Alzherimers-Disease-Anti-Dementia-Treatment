/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 4/20/2018;

* PURPOSE: Merge Part D AD rx events to Part D Identifiers and Prescriber information;

* INPUT: ADdrugs_0615;
* OUTPUT: adrx_2007_2016;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname exp "../../data/explore";

***** Merging NPI information to drug claims;

proc sql;
	create table addrugs.ADdrugs_0616_prscrbr as
	select x.*,y.primary_spec as primary_prscrbr_spec, y.primary_neuro as primary_prscrbr_neuro,
	y.primary_geria as primary_prscrbr_geria, y.primary_psych as primary_prscrbr_psych, 
	y.other_tax_spec as other_prscrbr_spec, y.other_neuro as other_neuro_spec, y.other_geria as other_prscrbr_geria,
	y.other_psych as other_prscrbr_psych, y.any_spec as any_prscrbr_spec, y.primary_hcfa, y.npi,
	(y.npi ne "") as match
	from addrugs.ADdrugs_0616 as x left join addrugs.npi_cogspec_dictionary as y
	on x.prscrbid=y.npi
	order by bene_id, year, srvc_dt;
quit;
	
proc freq data=addrugs.ADdrugs_0616_prscrbr;
	table match / missing;
run;
	
* Checking match by year ;
proc means data=addrugs.ADdrugs_0616_prscrbr noprint;
	class year;
	var match;
	output out=match_byyear mean()=;
run;

proc print data=match_byyear; run;

* Summary statistics on prscrbr data set;
proc contents data=addrugs.ADdrugs_0616_prscrbr; run;

* Number of claims by year;
proc means data=addrugs.ADdrugs_0616_prscrbr noprint;
	class year;
	var addrug donep galan meman rivas primary_prscrbr_spec;
	output out=clms_byyear (drop=_type_) sum(addrug donep galan meman rivas)= mean(primary_prscrbr_spec)=;
run;

* Number of users by year;
proc means data=addrugs.ADdrugs_0616_prscrbr nway noprint;
	class year bene_id;
	var addrug donep galan meman rivas;
	output out=users_byyear (drop=_type_) max()=;
run;

proc means data=users_byyear noprint;
	class year;
	var addrug donep galan meman rivas;
	output out=users_byyear1 (drop=_type_) sum()=;
run;

proc print data=clms_byyear; run;
proc print data=users_byyear1; run;


%macro pdays(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years;

* pull claims for year;
data pde&year;
	&set. set addrugs.ADdrugs_0616_prscrbr (where=(year(srvc_dt)=&year));
	&merge. merge addrugs.ADdrugs_0616_prscrbr (in=a where=(year(srvc_dt)=&year)) pde&prev_year._pdays (in=b keep=bene_id push_&prev_year.);
	by bene_id;
	&merge. if a;
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
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) then adrx_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=clms_&year.)
	sum(dayssply)=filldays_&year. min(srvc_dt)=minfilldt_&year. max(srvc_dt)=maxfilldt_&year.
	max(adrx_a1-adrx_a365 earlyfill_push lastfill_push galan)=;
run;

data pde&year._pdays;
	set pde&year._5;
	fillperiod_&year.=max(maxfilldt_&year.-minfilldt_&year.+1,0);
	pdays_&year.=max(min(sum(of adrx_a1-adrx_a365),365),.);
	* inyearPush=extra push days from early fills throughout the year (capped at 30);
	* lastfill_push=amount from the last fill that goes into next year (capped at 90);
	inyear_push=min(earlyfill_push,30);
	push_&year=max(lastfill_push,inyear_push);
	if push_&year<0 then push_&year=0;
	if push_&year>90 then push_&year=90;
	keep bene_id push: pdays: fillperiod: maxfilldt: minfilldt: clms: filldays:;
run;
%mend;

%pdays(2006,2005,*,);
%pdays(2007,2006,,*);
%pdays(2008,2007,,*);
%pdays(2009,2008,,*);
%pdays(2010,2009,,*);
%pdays(2011,2010,,*);
%pdays(2012,2011,,*);
%pdays(2013,2012,,*);
%pdays(2014,2013,,*);
%pdays(2015,2014,,*);
%pdays(2016,2015,,*);
	
* Merge all together;
data pdays_0616;
	merge pde2006_pdays (in=a)
				pde2007_pdays (in=b)
				pde2008_pdays (in=c)
				pde2009_pdays (in=d)
				pde2010_pdays (in=e)
				pde2011_pdays (in=f)
				pde2012_pdays (in=g)
				pde2013_pdays (in=h)
				pde2014_pdays (in=i)
				pde2015_pdays (in=j)
				pde2016_pdays (in=k);
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
	
	* timing variables;
	array y [*] y2006-y2016;
	array ydec [*] y2016 y2015 y2014 y2013 y2012 y2011 y2010 y2009 y2008 y2007 y2006;
	do i=1 to dim(y);
		if y[i]=1 then lastyoo=i+2005;
		if ydec[i]=1 then firstyoo=2017-i;
	end;

	yearcount=lastyoo-firstyoo+1;

	* utilization variables;
	array util [*] fillperiod_2006-fillperiod_2016 clms_2006 - clms_2016
		filldays_2006-filldays_2016 pdays_2006-pdays_2016;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	clms=sum(of clms_2006-clms_2016);
	filldays=sum(of filldays_2006-filldays_2016);
	pdays=sum(of pdays_2006-pdays_2016);

	* timing variables;
	minfilldt=min(of minfilldt_2006-minfilldt_2016);
	maxfilldt=max(of maxfilldt_2006-maxfilldt_2016);

	fillperiod=maxfilldt - minfilldt+1;

	pdayspy=pdays/yearcount;
	filldayspy=filldays/yearcount;
	clmspy=clms/yearcount;

	if first.bene_id; * shouldn't change anything? originally 5300792;
	
	drop i;
run;
			  
proc univariate data=pdays_0616 noprint outtable=pdays_stats_0616; run;
	
proc print data=pdays_stats_0616; run;
	
proc contents data=pdays_0616; run;
			  
%macro adrx;
data addrugs.ADrx_0616_long;
	set addrugs.ADdrugs_0616_prscrbr (where=(dayssply>=7)); * dropping dayssply less than 7;
	by bene_id year srvc_dt;
		
	format firstuse mmddyy10.;
	if first.bene_id then do;
		firstuse=.;
		firstuse_spec=.;
		%do year=2006 %to 2016;
			meman&year=.;
			donep&year=.;
			galan&year=.;
			rivas&year=.;
			adrx&year=.;
			achei&year=.;
			combo&year=.;			
			moleculesnum&year=.;
		%end;
	end;
	
	retain firstuse firstuse_spec
	meman2006-meman2016 donep2006-donep2016 galan2006-galan2016 rivas2006-rivas2016 
	achei2006-achei2016 combo2006-combo2016 adrx2006-adrx2016
	moleculesnum2006-moleculesnum2016;
	
	* Getting initation date;
	if firstuse=. and addrug then do;
		firstuse=srvc_dt;
		firstuse_spec=primary_prscrbr_spec;
	end;
	
	%do year=2006 %to 2016;
		if year=&year then do;
			
			* Creating flags for whether or not they used the drugs in those years;
			if meman then meman&year=1;
			if donep then donep&year=1;
			if galan then galan&year=1;
			if rivas then rivas&year=1;
			if last.year then do;
				if max(meman&year,donep&year,galan&year,rivas&year) then adrx&year=1;
				if max(donep&year,galan&year,rivas&year) then achei&year=1;
				if meman&year and achei&year then combo&year=1;
			end;
			
			* Counting number of molecules used in that year;
			if last.year then moleculesnum&year=sum(meman&year,donep&year,galan&year,rivas&year);
			
		end;
	%end;
	
	
run;

data addrugs.adrxinc_0616;
	merge addrugs.adrx_0616_long (in=a) pdays_0616 (in=b);
	by bene_id;
	
	in_adrx=a;
	in_pdays=b;
	
	* making bene_id level;
	if last.bene_id;
	
	array memanyr [*] meman2006-meman2016;
	array rivasyr [*] rivas2006-rivas2016;
	array donepyr [*] donep2006-donep2016;
	array galanyr [*] galan2006-galan2016;
	array comboyr [*] combo2006-combo2016;
	array acheiyr [*] achei2006-achei2016;
	array adrxyr [*] adrx2006-adrx2016;
	array pdays_ [*] pdays_2006-pdays_2016;
	array clms_ [*] clms_2006-clms_2016;
	
	* making clms and pdays . instead of 0 if theyre 0 - not including 0 in average;
	do i=1 to dim(pdays_);
		if pdays_[i]=0 then pdays_[i]=.;
		if clms_[i]=0 then clms_[i]=.;
	end;
	
	* Ever use;
	ever_meman=.;
	ever_rivas=.;
	ever_donep=.;
	ever_galan=.;
	ever_combo=.;
	ever_achei=.;
	ever_adrx=.;
	
	do i=1 to dim(memanyr);
		if memanyr[i] then ever_meman=1;
		if rivasyr[i] then ever_rivas=1;
		if donepyr[i] then ever_donep=1;
		if galanyr[i] then ever_galan=1;
		if comboyr[i] then ever_combo=1; ***** CONFIRM WITH DOUG THAT COMBO SHOULD BE CONSIDERED WITHIN YEARS AND NOT ACROSS YEARS;
		if acheiyr[i] then ever_achei=1;
		if adrxyr[i] then ever_adrx=1;
	end;
	
	* Average possession days and claims - only using average from 2008-2016;
	avgpdays=mean(of pdays_2008-pdays_2016);
	avgclms=mean(of clms_2008-clms_2016);
	
	keep bene_id rxinit rxinit_spec
	meman2006-meman2016 donep2006-donep2016 galan2006-galan2016 rivas2006-rivas2016 
	achei2006-achei2016 combo2006-combo2016 adrx2006-adrx2016
	clms_2006-clms_2016 pdays_2006-pdays_2016 moleculesnum2006-moleculesnum2016
	ever_: avgpdays avgclms firstuse firstuse_spec in_adrx in_pdays;
	
	* Since Part D data does not start until 2006 and we have incomplete data in 2006 and 2007, then using those years 
		as a wash out period. Essentially saying that if they have a drug use (defined as 1 claim with>=7 day supply) in that period, we are not sure
		if it is their initial one and will only start counting after January 2008;
	format rxinit mmddyy10.;
	if year(firstuse)>=2008 then do;
		rxinit=firstuse;
		rxinit_spec=firstuse_spec;
	end;
	
run;
%mend;

%adrx;

proc freq data=addrugs.adrxinc_0616;
	table in_adrx*in_pdays / missing;
run;

proc univariate data=addrugs.adrxinc_0616 noprint outtable=univariate; run;
proc means data=addrugs.adrxinc_0616 noprint; output out=means; run;
proc print data=univariate; run;
proc print data=means; run;
	
options obs=100;
proc print data=addrugs.adrx_0616_long; run;
proc print data=addrugs.adrxinc_0616; run;
proc print data=addrugs.adrxinc_0616; where rxinit ne . and adrx2006=1; run;
	
