/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 12/17/2019;

* PURPOSE: Create a table for anyone with a diagnosis or drug use;

* INPUT: adrd_inc_2001_2016, adrx_inc_2007_2016;
* OUTPUT: analysis;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname demdx "../../data/dementiadx";
libname exp "../../data/adrd_inc_explore";
libname bene "&datalib.Clean_Data/BeneStatus";
libname bsfab "/disk/aging/medicare/data/20pct/bsf/2002";
libname aht "../../data/aht/base";
%let method=any;
%partABlib(types=bsf)
%let maxyear=2016;

***** Table 1 - characteristics of ADrx use and users, across diagnosis groups;
* Using long version to identify those who are still using x months after initiation;
* Of those that survive 10 months, using in month 12-10;
* Of those that survive 36 months, using in months 10-36;
* Of those that survive 48 months, using in months 36-48;

* Getting dual/lis information;
%macro duallis;

%do year=2006 %to &maxyr.;
data duallis&year;
	set bene.bene_status_year&year. (keep=bene_id anylis anydual_full anydual_restrict);
	lis&year.=(anylis='Y');
	dual&year.=(anydual_full='Y' or anydual_restrict='Y');
	keep bene_id lis&year. dual&year.;
run;
%end;

data duallis;
	merge %do year=2006 %to &maxyr.;
	duallis&year.
	%end;;
	by bene_id;
run;
%mend;

%duallis;

* Specialist use;
data spec;
	set addrugs.adrd_dxprv_specrate_any addrugs.symp_dxprv_specrate_any;
	by bene_id demdx_dt;
	keep bene_id spec year;
run;

proc means data=spec noprint;
	class bene_id;
	output out=bene_firstspec max(spec)=;
run;

data samptable;
	merge 
	addrugs.analytical&maxyear (in=a) 
	demdx.cc_0216 (in=b keep=bene_id copde asthma_ever chrnkdne hypert_ever chfe glaucmae amie atrialfe ischmche)
	duallis (in=c)
	aht.phy_0616 (in=d)
	bene_firstspec (in=e)
	addrugs.samp_geoses (in=f keep=bene_id hcc:);
	by bene_id;
	
	if a;
	cc=b;
	geo=f;
	ses=c;
	phy=d;
	specinfo=e;
	
	array insamp [2006:&maxyear.] insamp2006-insamp&maxyear.;

* just using scen1-ADRD+, scen10-drug use, no dx;
	
	ADRDplus_inc_yr=year(ADRDplus_inc);
	
	format birth_date death_date mmddyy10.;
	
	* table 1 -scenarios 1- 14;
	if ADRDplus_inc_yr>=2008 then do;
		if insamp[ADRDplus_inc_yr] then do; 
			scen1=1;
			incyr=ADRDplus_inc_yr;
		end;
	end;
	* For scenario 10, using year of first drug use & requiring at least a year of in samp - a little different from Doug;
	if ADRDplus_inc=. and firstuse ne . then do; 
		if insamp[year(firstuse)] then do;
			scen10=1;
			incyr=year(firstuse);
		end;
	end;
	
	if scen1 or scen10;
	
	* Ever had a diagnoses;
	ever_AD=(AD_inc ne .);
	ever_dem=(dem_inc ne .);
	ever_symp=(symp_inc ne .);
	never_dx=(ADRDplus_inc=.);
	
	* Patient characteristics;
	array age_beg [2006:&maxyear] age_beg2006-age_beg&maxyear;
	age=age_beg[incyr];
	female=(sex='2');
	race_dw=(race_bg='1');
	race_db=(race_bg='2');
	race_da=(race_bg='4');
	race_dh=(race_bg='5');
	
	* SES;
	array hccyr [2007:&maxyear.] hcc2007-hcc&maxyear.;
	array phyyr [2006:&maxyear.] phyvis_2006-phyvis_&maxyear.;
	array dualyr [2006:&maxyear.] dual2006-dual&maxyear.;
	array lisyr [2006:&maxyear.] lis2006-lis&maxyear.;
	
	phyvis=phyyr[incyr];
	dual=dualyr[incyr];
	lis=lisyr[incyr];
	
	if incyr>=2007 then hcc=hccyr[incyr];
	else hcc=hccyr[2007];

	* Drug use;
	if ever_adrx=. then ever_adrx=0;
	if ever_achei=. then ever_achei=0;
	if ever_combo=. then ever_combo=0;
	if ever_donep=. then ever_donep=0;
	if ever_galan=. then ever_galan=0;
	if ever_meman=. then ever_meman=0;
	if ever_rivas=. then ever_rivas=0;
	
	*Variables that are already built: spec;
		
	* CC;
	cc_copd=(copde ne .);
	cc_asthma=(asthma_ever ne .);
	cc_ckd=(chrnkdne ne .);
	cc_hypert=(hypert_ever ne .);
	cc_chfe=(chfe ne .);
	cc_glaucma=(glaucmae ne .);
	cc_ami=(amie ne .);
	cc_afib=(atrialfe ne .);
	cc_ischmch=(ischmche ne .);
	
run;

proc freq data=samptable;
	table incyr cc specinfo ses phy geo;
run;

* Missing HCC for 412 people - will fill in an average;
proc means data=samptable noprint;
	var hcc:;
	output out=mean_hcc mean()= / autoname;
run;

proc print data=mean_hcc; run;
	
data samptable1;
	merge samptable mean_hcc;
	array mean_hcc [2007:&maxyear.] hcc2007_mean hcc2008_mean hcc2009_mean hcc2010_mean hcc2011_mean hcc2012_mean 
	hcc2013_mean hcc2014_mean hcc2015_mean hcc&maxyear._mean;
	array avg_hcc [2007:&maxyear.] avg_hcc2007-avg_hcc&maxyear.;
	if _n_=1 then do yr=2007 to &maxyear.;
		avg_hcc[yr]=mean_hcc[yr];
	end;
	retain avg_hcc2007-avg_hcc&maxyear.;
	if hcc=. then fillhcc=0;
	if hcc=. and incyr>2006 then do; 
		fillhcc=1; 
		hcc=avg_hcc[incyr]; 
	end;
	if hcc=. and incyr=2006 then do; 
		fillhcc=1;
		hcc=avg_hcc2007; 
	end;
	drop hcc_mean: avg_hcc:;
run;

proc freq data=samptable1;
	table fillhcc;
run;

proc print data=samptable1 (obs=100);
	where geo=0;
	var bene_id incyr hcc:;
run;

proc means data=samptable1 noprint;
	where specinfo ne .;
	var age female race_d: cc: spec hcc phyvis ever: never_dx dual lis;
	output out=sample_stats sum()= mean()= std()= / autoname;
run;

ods excel file="/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/programs/ad_drug_use/output/sample_stats.xlsx";
proc print data=sample_stats; run;
ods excel close;


	