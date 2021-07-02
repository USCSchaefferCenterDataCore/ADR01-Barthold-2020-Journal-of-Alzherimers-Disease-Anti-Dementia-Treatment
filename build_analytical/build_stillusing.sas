/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 11/6/2018;

* PURPOSE: Figure 1 and Table 1 of AD Drug Use descriptive analysis;

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
%let method=any;
%let maxyear=2016;
%partABlib(types=bsf)

***** Characteristics of ADrx use and users, across diagnosis groups;
* Using long version to identify those who are still using x months after initiation;
* Of those that survive 24 months, using in month 12-24;
* Of those that survive 36 months, using in months 24-36;
* Of those that survive 48 months, using in months 36-48;

data table1_stillusing_long;
	set addrugs.analytical_long&maxyear.;
	by bene_id;
	array inc [*] ADRDplus_inc ADRD_inc AD_inc dem_inc symp_inc;
	array use6moPostDX [*] use6moPostADRDPlus use6moPostADRD use6moPostAD use6moPostDem use6moPostSymp;
	if first.bene_id then do;
		stillusing12_24=0;
		stillusing24_36=0;
		stillusing36_48=0;
		do i=1 to dim(use6moPostDX);
			use6moPostDX[i]=0;
		end;
	end;
	retain stillusing12_24 stillusing24_36 stillusing36_48 use6moPost:;
	if addrug then do;
		if stillusing12_24=0 and intnx('year',firstuse,1,'s')<=date<intnx('year',firstuse,2,'s') then stillusing12_24=1;
		if stillusing24_36=0 and intnx('year',firstuse,2,'s')<=date<intnx('year',firstuse,3,'s') then stillusing24_36=1;
		if stillusing36_48=0 and intnx('year',firstuse,3,'s')<=date<intnx('year',firstuse,4,'s') then stillusing36_48=1;
		do i=1 to dim(inc);
			if inc[i] ne . and inc[i]<=date<intnx('month',inc[i],6,'s') and use6moPostDX[i]=0 then use6moPostDX[i]=1;
		end;
	end;
	keep bene_id stillusing: use6moPost: firstuse ADRDplus_inc ADRD_inc AD_inc NADD_inc dem_inc symp_inc
	addrug date;
run;

data addrugs.analytical_stillusing&maxyear.;
	set table1_stillusing_long;
	by bene_id;
 	keep bene_id stillusing: use6moPost:;
 	if last.bene_id;
run;
