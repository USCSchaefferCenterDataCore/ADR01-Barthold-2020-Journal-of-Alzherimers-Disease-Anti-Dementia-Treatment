/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 5/8/2018;

* PURPOSE:  Making analytical data sets, one that is benefiiary level and one that is date level;

* INPUT: statins.dementia_dxdate_2002_2014, ad_dxprv_specrate_any, adrd_dxprv_specrate_any, 
				 symp_dxprv_specrate_any;
* OUTPUT: analysis;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname exp "../../data/adrd_inc_explore";
libname demdx "../../data/dementiadx";
%partABlib(types=bsf);
%let maxyear=2016;
%let method=any;

* Need the following measures:
	* incident ADRD+ dx, incident ADRD dx, incident AD dx, incident NADD dx, incident dementia symptoms dx;
data addrugs.adrd_0216_&method._long;
	merge demdx.adrd_dxdate_2002_&maxyear. (in=a keep=bene_id demdx_dt dxtypes rename=(demdx_dt=date)) 
				addrugs.adrd_dxprv_specrate_&method (in=b rename=(demdx_dt=date spec=adrdspec spec_geria=adrdspec_geria spec_neuro=adrdspec_neuro spec_neuropsych=adrdspec_neuropsych spec_psych=adrdspec_psych) 
				keep=bene_id demdx_dt spec spec_geria spec_psych spec_neuro spec_neuropsych)
				addrugs.ad_dxprv_specrate_&method (in=c rename=(demdx_dt=date spec=adspec spec_geria=adspec_geria spec_neuro=adspec_neuro spec_neuropsych=adspec_neuropsych spec_psych=adspec_psych) 
				keep=bene_id demdx_dt spec spec_geria spec_psych spec_neuro spec_neuropsych)
				addrugs.symp_dxprv_specrate_&method (in=d rename=(demdx_dt=date spec=sympspec spec_geria=sympspec_geria spec_neuro=sympspec_neuro spec_neuropsych=sympspec_neuropsych spec_psych=sympspec_psych) 
				keep=bene_id demdx_dt spec spec_geria spec_psych spec_neuro spec_neuropsych)
				exp.dem_symptoms2002_&maxyear. (in=e drop=year)
			  addrugs.ADrx_0616_long (in=a rename=(srvc_dt=date) where=(dayssply>=7)) ;
	by bene_id date;
	
	adrd_d=a;
	adrd_s=b;
	ad_s=c;
	symp_s=d;
	symp_d=e;
	
	format AD_inc ADRD_inc ADRDplus_inc NADD_inc symp_inc dem_inc mmddyy10.;
	
	if first.bene_id then do;
		
		AD=.;
		NADD=.;
		ADRD=.;
		ADRDplus=.;
		symp=.;
		dem=.;
		
		AD_inc=.;
		ADRD_inc=.;
		ADRDplus_inc=.;
		NADD_inc=.;
		symp_inc=.;
		dem_inc=.;
		
		AD_inc_spec=.;
		AD_inc_spec_geria=.;
		AD_inc_spec_neuro=.;
		AD_inc_spec_neuropsych=.;
		AD_inc_spec_psych=.;
		
		ADRD_inc_spec=.;
		ADRD_inc_spec_geria=.;
		ADRD_inc_spec_neuro=.;
		ADRD_inc_spec_neuropsych=.;
		ADRD_inc_spec_psych=.;
		
		ADRDplus_inc_spec=.;
		ADRDplus_inc_spec_geria=.;
		ADRDplus_inc_spec_neuro=.;
		ADRDplus_inc_spec_neuropsych=.;
		ADRDplus_inc_spec_psych=.;
	end;
	retain AD NADD ADRD ADRDplus symp dem
				 AD_inc ADRD_inc ADRDplus_inc NADD_inc symp_inc dem_inc
				 AD_inc_spec ADRD_inc_spec ADRDplus_inc_spec
				 AD_inc_spec_geria AD_inc_spec_neuro AD_inc_spec_neuropsych AD_inc_spec_psych
				 ADRD_inc_spec_geria ADRD_inc_spec_neuro ADRD_inc_spec_neuropsych ADRD_inc_spec_psych
				 ADRDPLUS_inc_spec_geria ADRDPLUS_inc_spec_neuro ADRDPLUS_inc_spec_neuropsych ADRDPLUS_inc_spec_psych;
	
	if find(dxtypes,"A") and AD=. then do;
			AD=1;
			AD_inc=date;
			AD_inc_spec=adspec;
			AD_inc_spec_geria=adspec_geria;
			AD_inc_spec_neuro=adspec_neuro;
			AD_inc_spec_neuropsych=adspec_neuropsych;
			AD_inc_spec_psych=adspec_psych;
	end;
		
	if compress(dxtypes,,"l") ne "" and ADRD=. then do;
			ADRD=1;
			ADRD_inc=date;
			ADRD_inc_spec=adrdspec;
			ADRD_inc_spec_geria=adrdspec_geria;
			ADRD_inc_spec_neuro=adrdspec_neuro;
			ADRD_inc_spec_neuropsych=adrdspec_neuropsych;
			ADRD_inc_spec_psych=adrdspec_psych;
	end;
	
	if (compress(dxtypes,,"l") ne "" or symptom or find(dxtypes,"m")) and ADRDplus=. then do;
			ADRDplus=1;
			ADRDplus_inc=date;
			ADRDplus_inc_spec=max(adrdspec,sympspec);
			ADRDplus_inc_spec_geria=max(adrdspec_geria,sympspec_geria);
			ADRDplus_inc_spec_neuro=max(adrdspec_neuro,sympspec_neuro);
			ADRDplus_inc_spec_neuropsych=max(adrdspec_neuropsych,sympspec_neuropsych);
			ADRDplus_inc_spec_psych=max(adrdspec_psych,sympspec_psych);
	end;
	
	if (symptom or find(dxtypes,"m")) and symp=. then do;
			symp=1;
			symp_inc=date;
			symp_inc_spec=sympspec;
			symp_inc_spec_geria=sympspec_geria;
			symp_inc_spec_neuro=sympspec_neuro;
			symp_inc_spec_neuropsych=sympspec_neuropsych;
			symp_inc_spec_psych=sympspec_psych;
	end;
	
	if compress(dxtypes,'A','l') ne "" and dem=. then do;
		dem=1;
		dem_inc=date;
	end;
	
	if last.bene_id then do;
		flag=1;
		* if ADRD and never got AD, then considering an NADD;
		if ADRD=1 and AD ne 1 then do;
			NADD=1;
			NADD_inc=ADRD_inc;
			NADD_inc_spec=adrdspec;
		end;
	end;
	
		keep bene_id date AD: ADRD: ADRDplus: NADD: symp: flag dem dem_inc dxtypes addrug
		any_prscrbr_spec dayssply donep galan meman rivas gcdf gcdf_desc npi other: primary: pde_id 
		prscrbid firstuse firstuse_spec;
run;

* Checks;
proc print data=addrugs.adrd_0216_&method._long;
	where flag=1 and (min(symp_inc,NADD_inc,AD_inc)<adrdplus_inc or min(AD_inc,NADD_inc)<ADRD_inc);
run;

data addrugs.analytical_long&maxyear.;
	merge addrugs.adrd_0216_&method._long (in=a) exp.ffsptd_samp_0416 (in=b);
	by bene_id;
	if a;
run;

proc contents data=addrugs.analytical_long&maxyear.; run;

* Create beneficiary level version;
data addrugs.analytical&maxyear.;
	merge addrugs.ADrxinc_0616 (in=a)
				addrugs.adrd_0216_&method._long (in=b drop=adrx2006-adrx2016 firstuse firstuse_spec where=(flag=1))
				exp.ffsptd_samp_0416 (in=c);
	by bene_id;
	adrx=a;
	addx=b;
	samp=c;
	drop flag;
run;

proc freq data=addrugs.analytical&maxyear. noprint;
	table adrx*addx*samp / out=analytical_match;
run;

proc contents data=addrugs.analytical&maxyear.; run;

proc print data=analytical_match; run;
