/*********************************************************************************************/
title1 'Diabetes & AD';

* Author: PF;
* Purpose: Looking at the difference between insulin start and date of diabetes dx - expecting
	a bimodal;
* Input: diabetes_samp;
* Output: insulin_output;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
libname demdx "../../data/dementiadx";
%partABlib(types=bsf);

%let maxyr=2016;

***** Building CCW to get comordities - using ATF, AMI, Hypertension, AD, ADRD, CKD, COPD, hyperlipidemia;
%macro cc;
%do year=2002 %to &maxyr.;
data bsfcc&year;
	set bsf.bsfcc&year;
	by bene_id;
	if first.bene_id;
run;
%end;

data demdx.cc_0216;
	merge 
	%do year=2002 %to &maxyr.;
	bsfcc&year (rename=(alzhe=alzhe&year alzhdmte=alzhdmte&year amie=amie&year anemia_ever=anemia_ever&year
	asthma_ever=asthma_ever&year atrialfe=atrialfe&year catarcte=catarcte&year chfe=chfe&year
	chrnkdne=chrnkdne&year cncendme=cncendme&year cncrbrse=cncrbrse&year cncrclre=cncrclre&year cncrlnge=cncrlnge&year
	cncrprse=cncrprse&year copde=copde&year deprssne=deprssne&year diabtese=diabtese&year glaucmae=glaucmae&year
	hipfrace=hipfrace&year hyperl_ever=hyperl_ever&year hyperp_ever=hyperp_ever&year hypert_ever=hypert_ever&year 
	hypoth_ever=hypoth_ever&year ischmche=ischmche&year osteopre=osteopre&year ra_oa_e=ra_oa_e&year 
	strktiae=strktiae&year)
	keep=bene_id alzhe alzhdmte amie anemia_ever asthma_ever atrialfe catarcte chfe chrnkdne cncendme
	cncrbrse cncrclre cncrlnge cncrprse copde deprssne diabtese glaucmae hipfrace
	hyperl_ever hyperp_ever hypert_ever hypoth_ever ischmche osteopre ra_oa_e
	strktiae)
	%end;;
	by bene_id;
	alzhe=min(of alzhe2002-alzhe&maxyr.);
	alzhdmte=min(of alzhdmte2002-alzhdmte&maxyr.);
	amie=min(of amie2002-amie&maxyr.);
	anemia_ever=min(of anemia_ever2002-anemia_ever&maxyr.);
	asthma_ever=min(of asthma_ever2002-asthma_ever&maxyr.);
	atrialfe=min(of atrialfe2002-atrialfe&maxyr.);
	catarcte=min(of catarcte2002-catarcte&maxyr.);
	chfe=min(of chfe2002-chfe&maxyr.);
	chrnkdne=min(of chrnkdne2002-chrnkdne&maxyr.);
	cncendme=min(of cncendme2002-cncendme&maxyr.);
	cncrbrse=min(of cncrbrse2002-cncrbrse&maxyr.);
	cncrclre=min(of cncrclre2002-cncrclre&maxyr.);
	cncrlnge=min(of cncrlnge2002-cncrlnge&maxyr.);
	cncrprse=min(of cncrprse2002-cncrprse&maxyr.);
	copde=min(of copde2002-copde&maxyr.);	
	deprssne=min(of deprssne2002-deprssne&maxyr.);
	diabtese=min(of diabtese2002-diabtese&maxyr.);
	glaucmae=min(of glaucmae2002-glaucmae&maxyr.);
	hipfrace=min(of hipfrace2002-hipfrace&maxyr.);
	hyperl_ever=min(of hyperl_ever2002-hyperl_ever&maxyr.);
	hyperp_ever=min(of hyperp_ever2002-hyperp_ever&maxyr.);
	hypert_ever=min(of hypert_ever2002-hypert_ever&maxyr.);
	hypoth_ever=min(of hypoth_ever2002-hypoth_ever&maxyr.);
	ischmche=min(of ischmche2002-ischmche&maxyr.);
	osteopre=min(of osteopre2002-osteopre&maxyr.);
	ra_oa_e=min(of ra_oa_e2002-ra_oa_e&maxyr.);
	strktiae=min(of strktiae2002-strktiae&maxyr.);
	format alzhe alzhdmte amie anemia_ever asthma_ever atrialfe catarcte chfe chrnkdne cncendme
	cncrbrse cncrclre cncrlnge cncrprse copde deprssne diabtese glaucmae hipfrace
	hyperl_ever hyperp_ever hypert_ever hypoth_ever ischmche osteopre ra_oa_e
	strktiae mmddyy10.;
		keep bene_id alzhe alzhdmte amie anemia_ever asthma_ever atrialfe catarcte chfe chrnkdne cncendme
		cncrbrse cncrclre cncrlnge cncrprse copde deprssne diabtese glaucmae hipfrace
		hyperl_ever hyperp_ever hypert_ever hypoth_ever ischmche osteopre ra_oa_e
		strktiae ;
run;
%mend;

%cc;