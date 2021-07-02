/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 12/18/2018;

* PURPOSE: Make a version of Table 1 - no longer requiring survival except for a few rows;

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
%partABlib(types=bsf)
%let maxyear=2016;

***** Table 1 - characteristics of ADrx use and users, across diagnosis groups;
* Using long version to identify those who are still using x months after initiation;
* Of those that survive 10 months, using in month 12-10;
* Of those that survive 36 months, using in months 10-36;
* Of those that survive 48 months, using in months 36-48;

%macro prev;
data analytical_table1_prev;
	merge addrugs.analytical&maxyear (in=a) exp.ffsptd_samp_monthly_fix (in=b keep=bene_id ffsptd:) addrugs.analytical_stillusing&maxyear (in=c);
	by bene_id;
	
	array insamp [2006:&maxyear.] insamp2006-insamp&maxyear.;

* identifying column scenarios;
			* table1
			scen1-ADRD+
			scen2-AD
			scen3-ADRD
			scen4-NADD (all)
			scen5-NADD - AD added 365 days later
			scen6-NADD - no AD added within 365
			scen7-Symptoms (all)
			scen8-Symptoms - AD added 365 days later
			scen9-Symptoms - no AD added within 365
			scen10-drug use, no dx
			scen11-AD without any prior dementia symptoms or non-AD symptoms
			scen12-NADD and Symptoms (all - no AD ever)
			scen13-NADD and symptoms - AD added 365 days after first
			scen14-NADD and symptoms - no AD added within 365 after first;
	
	ADRDplus_inc_yr=year(ADRDplus_inc);
	AD_inc_yr=year(AD_inc);
	NADD_inc_yr=year(NADD_inc);
	symp_inc_yr=year(symp_inc);
	ADRD_inc_yr=year(ADRD_inc);
	dem_inc_yr=year(dem_inc);
	nadd_symp_inc=min(NADD_inc,symp_inc);
	nadd_symp_inc_yr=year(nadd_symp_inc);
	dem_symp_inc=min(dem_inc,symp_inc);
	dem_symp_inc_yr=year(dem_symp_inc);
	
	format nadd_symp_inc scen_inc1-scen_inc14 birth_date death_date mmddyy10.;
	
	* table 1 -scenarios 1- 14;
	if ADRDplus_inc_yr>=2008 then do;
		if insamp[ADRDplus_inc_yr] then do; 
			scen1=1;
			scen_inc1=ADRDplus_inc;
			scenyr1=ADRDplus_inc_yr;
			any6moRXuse1=use6moPostADRDplus;
		end;
	end;
	if AD_inc_yr>=2008 then do;
		if insamp[AD_inc_yr] then do;
			scen2=1;
			scen_inc2=AD_inc;
			scenyr2=AD_inc_yr;
			any6moRXuse2=use6moPostAD;
		end;
	end;
	if NADD_inc_yr>=2008 then do; * has never gotten AD;
		if insamp[NADD_inc_yr] then do;
			scen4=1;
			scen_inc4=NADD_inc;
			scenyr4=NADD_inc_yr;
			any6moRXuse4=use6moPostDem;
		end;
	end;
	if symp_inc_yr>=2008 and NADD_inc_yr=. and AD_inc_yr=. then do; * symptoms but have never gotten AD or NADD;
		if insamp[symp_inc_yr] then do;
			scen7=1;
			scen_inc7=symp_inc;
			scenyr7=symp_inc_yr;
			any6moRXuse7=use6moPostSymp;
		end;
	end;
	if ADRD_inc_yr>=2008 then do;
		if insamp[ADRD_inc_yr] then do;
			scen3=1;
			scen_inc3=ADRD_inc;
			scenyr3=ADRD_inc_yr;
			any6moRXuse3=use6moPostADRD;
		end;
	end;
	if dem_inc_yr>=2008 and dem_inc<AD_inc<=(dem_inc+365) then do; * NADD, AD added after 1 year;
		if insamp[dem_inc_yr] then do;
			scen5=1;
			scen_inc5=dem_inc;
			scenyr5=dem_inc_yr;
			any6moRXuse5=use6moPostDem;
		end;
	end;
	else if dem_inc_yr>=2008 and (AD_inc=. or AD_inc>dem_inc+365) then do; * NADD, no AD added after 1 year - may have gotten AD at another point after 1 year;
		if insamp[dem_inc_yr] then do;
			scen6=1;
			scen_inc6=dem_inc;
			scenyr6=dem_inc_yr;
			any6moRXuse6=use6moPostDem;
		end;
	end;
	if symp_inc_yr>=2008 and symp_inc<AD_inc<=(symp_inc+365) then do; * Symptom, AD added after 1 year;
		if insamp[symp_inc_yr] then do;
			scen8=1;
			scen_inc8=symp_inc;
			scenyr8=symp_inc_yr;
			any6moRXuse8=use6moPostSymp;
		end;
	end;
	else if symp_inc_yr>=2008 and (AD_inc=. or AD_inc>symp_inc+365) then do; * Symptom, no prior AD and no AD added after 1 year;
		if insamp[symp_inc_yr] then do;
			scen9=1;
			scen_inc9=symp_inc;
			scenyr9=symp_inc_yr;
			any6moRXuse9=use6moPostSymp;
		end;
	end;
	* For scenario 10, using year of first drug use & requiring at least a year of in samp - a little different from Doug;
	if ADRDplus_inc=. and firstuse ne . then do; 
		if insamp[year(firstuse)] then do;
			scen10=1;
			scen_inc10=.;
			scenyr10=year(firstuse);
		end;
	end;
	* AD and never any prior non-AD dementia or symptoms;
	if AD_inc_yr>=2008 and (dem_inc=. or dem_inc>=AD_inc) and (symp_inc=. or symp_inc>=AD_inc) then do;
		if insamp[AD_inc_yr] then do;
			scen11=1;
			scen_inc11=AD_inc;
			scenyr11=AD_inc_yr;
			any6moRXuse11=use6moPostAD;
		end;
	end;
	* NADD or symptoms but have never gotten AD;
	if dem_symp_inc_yr>=2008 and AD_inc_yr=. then do; * NADD or symptoms but have never gotten AD or NADD;
		if insamp[dem_symp_inc_yr] then do;
			scen12=1;
			scen_inc12=dem_symp_inc;
			scenyr12=dem_symp_inc_yr;
			if dem_inc=. or .<symp_inc<=dem_inc then any6moRXuse12=use6moPostSymp;
			if symp_inc=. or .<dem_inc<=symp_inc then any6moRXuse12=use6moPostDem;
		end;
	end;
	* NADD or symptoms but got AD within 365 days;
	if dem_symp_inc_yr>=2008 and dem_symp_inc<AD_inc<=dem_symp_inc+365 then do; 
		if insamp[dem_symp_inc_yr] then do;
			scen13=1;
			scen_inc13=dem_symp_inc;
			scenyr13=dem_symp_inc_yr;
			if dem_inc=. or .<symp_inc<=dem_inc then any6moRXuse13=use6moPostSymp;
			if symp_inc=. or .<nadd_inc<=symp_inc then any6moRXuse13=use6moPostDem;
		end;
	end;
	* NADD or symptoms but have not gotten AD within 365 days;
	else if dem_symp_inc_yr>=2008 and (AD_inc=. or AD_inc>(dem_symp_inc+365)) then do; 
		if insamp[dem_symp_inc_yr] then do;
			scen14=1;
			scen_inc14=dem_symp_inc;
			scenyr14=dem_symp_inc_yr;
			if dem_inc=. or .<symp_inc<=dem_inc then any6moRXuse14=use6moPostSymp;
			if symp_inc=. or .<dem_inc<=symp_inc then any6moRXuse14=use6moPostDem;
		end;
	end;
	
	array scen [*] scen1-scen14;
	array scenyr [*] scenyr1-scenyr14;
	array sceninc [*] scen_inc1-scen_inc14;
	array adrx2008_ [*] adrx2008_1-adrx2008_14;
	array adrx2009_ [*] adrx2009_1-adrx2009_14;
	array adrx2010_ [*] adrx2010_1-adrx2010_14;
	array adrx2011_ [*] adrx2011_1-adrx2011_14;
	array adrx2012_ [*] adrx2012_1-adrx2012_14;
	array adrx2013_ [*] adrx2013_1-adrx2013_14;
	array adrx2014_ [*] adrx2014_1-adrx2014_14;
	array adrx2015_ [*] adrx2015_1-adrx2015_14;
	array adrx&maxyear._ [*] adrx&maxyear._1-adrx&maxyear._14;
	array dx2008initpre [*] dx2008initpre1-dx2008initpre14; 
	array dx2009initpre [*] dx2009initpre1-dx2009initpre14;
	array dx2010initpre [*] dx2010initpre1-dx2010initpre14;
	array dx2011initpre [*] dx2011initpre1-dx2011initpre14;
	array dx2012initpre [*] dx2012initpre1-dx2012initpre14;
	array dx2013initpre [*] dx2013initpre1-dx2013initpre14;
	array dx2014initpre [*] dx2014initpre1-dx2014initpre14;
	array dx2015initpre [*] dx2015initpre1-dx2015initpre14;
	array dx&maxyear.initpre [*] dx&maxyear.initpre1-dx&maxyear.initpre14;
	array dx2008init6mo [*] dx2008init6mo1-dx2008init6mo14; 
	array dx2009init6mo [*] dx2009init6mo1-dx2009init6mo14;
	array dx2010init6mo [*] dx2010init6mo1-dx2010init6mo14;
	array dx2011init6mo [*] dx2011init6mo1-dx2011init6mo14;
	array dx2012init6mo [*] dx2012init6mo1-dx2012init6mo14;
	array dx2013init6mo [*] dx2013init6mo1-dx2013init6mo14;
	array dx2014init6mo [*] dx2014init6mo1-dx2014init6mo14;
	array dx2015init6mo [*] dx2015init6mo1-dx2015init6mo14;
	array dx&maxyear.init6mo [*] dx&maxyear.init6mo1-dx&maxyear.init6mo14;
	array dx2008any6mo [*] dx2008any6mo1-dx2008any6mo14; 
	array dx2009any6mo [*] dx2009any6mo1-dx2009any6mo14;
	array dx2010any6mo [*] dx2010any6mo1-dx2010any6mo14;
	array dx2011any6mo [*] dx2011any6mo1-dx2011any6mo14;
	array dx2012any6mo [*] dx2012any6mo1-dx2012any6mo14;
	array dx2013any6mo [*] dx2013any6mo1-dx2013any6mo14;
	array dx2014any6mo [*] dx2014any6mo1-dx2014any6mo14;
	array dx2015any6mo [*] dx2015any6mo1-dx2015any6mo14;
	array dx&maxyear.any6mo [*] dx&maxyear.any6mo1-dx&maxyear.any6mo14;
	array any6moRXuse [*] any6moRXuse1-any6moRXuse14;
	

	
	%do yr=2008 %to &maxyear.;
		if insamp&yr. then do i=1 to 14;
			if .<sceninc[i]<=mdy(12,31,&yr) then do;
				adrx&yr._[i]=0;
				if adrx&yr=1 then adrx&yr._[i]=1;
			end;
		end;
	%end;
	
* initpre - initiated prior index dx;
	* init6mo - initiated between 0-6 months after index dx, no prior drug use;
	* any6mo - any use between 0-6 months after index;
	do i=1 to 9,11 to 14;
		
			array ffsptd2008 [*] ffsptd2008_1-ffsptd2008_12 ffsptd2009_1-ffsptd2009_12;
			array drop2008 [*] drop2008_scen1-drop2008_scen14;
			if scenyr[i]=2008 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2008[mo] ne "Y" then drop2008[i]=1;
				end;
				
				if drop2008[i] ne 1 then do;
					*initpre;
					dx2008initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2008initpre[i]=1;
					
					* init6mo;
					if firstuse=. or firstuse>=sceninc[i] then dx2008init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2008init6mo[i]=1; 
					
					* any use in 6 month;
					dx2008any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2008any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2009 [*] ffsptd2009_1-ffsptd2009_12 ffsptd2010_1-ffsptd2010_12;
			array drop2009 [*] drop2009_scen1-drop2009_scen14;
			if scenyr[i]=2009 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2009[mo] ne "Y" then drop2009[i]=1;
				end;
				
				if drop2009[i] ne 1 then do;
					*initpre;
					dx2009initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2009initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2009init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2009init6mo[i]=1;
					
					* any use in 6 month;
					dx2009any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2009any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2010 [*] ffsptd2010_1-ffsptd2010_12 ffsptd2011_1-ffsptd2011_12;
			array drop2010 [*] drop2010_scen1-drop2010_scen14;
			if scenyr[i]=2010 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2010[mo] ne "Y" then drop2009[i]=1;
				end;
				
				if drop2010[i] ne 1 then do;
					*initpre;
					dx2010initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2010initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2010init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2010init6mo[i]=1;
					
					* any use in 6 month;
					dx2010any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2010any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2011 [*] ffsptd2011_1-ffsptd2011_12 ffsptd2012_1-ffsptd2012_12;
			array drop2011 [*] drop2011_scen1-drop2011_scen14;
			if scenyr[i]=2011 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2011[mo] ne "Y" then drop2011[i]=1;
				end;
				
				if drop2011[i] ne 1 then do;
					*initpre;
					dx2011initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2011initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2011init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2011init6mo[i]=1;
					
					* any use in 6 month;
					dx2011any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2011any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2012 [*] ffsptd2012_1-ffsptd2012_12 ffsptd2013_1-ffsptd2013_12;
			array drop2012 [*] drop2012_scen1-drop2012_scen14;
			if scenyr[i]=2012 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2012[mo] ne "Y" then drop2012[i]=1;
				end;
				
				if drop2012[i] ne 1 then do;
					*initpre;
					dx2012initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2012initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2012init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2012init6mo[i]=1;
					
					* any use in 6 month;
					dx2012any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2012any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2013 [*] ffsptd2013_1-ffsptd2013_12 ffsptd2014_1-ffsptd2014_12;
			array drop2013 [*] drop2013_scen1-drop2013_scen14;
			if scenyr[i]=2013 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2013[mo] ne "Y" then drop2013[i]=1;
				end;
				if drop2013[i] ne 1 then do;
					*initpre;
					dx2013initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2013initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2013init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2013init6mo[i]=1;

					* any use in 6 month;
					dx2013any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2013any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2014 [*] ffsptd2014_1-ffsptd2014_12 ffsptd2015_1-ffsptd2015_12;
			array drop2014 [*] drop2014_scen1-drop2014_scen14;
			if scenyr[i]=2014 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2014[mo] ne "Y" then drop2014[i]=1;
				end;
				
				if drop2014[i] ne 1 then do;
					*initpre;
					dx2014initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2014initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2014init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2014init6mo[i]=1;
					
					* any use in 6 month;
					dx2014any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2014any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd2015 [*] ffsptd2015_1-ffsptd2015_12 ffsptd&maxyear._1-ffsptd&maxyear._12;
			array drop2015 [*] drop2015_scen1-drop2015_scen14;
			if scenyr[i]=2015 then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd2015[mo] ne "Y" then drop2015[i]=1;
				end;
				if drop2015[i] ne 1 then do;
					*initpre;
					dx2015initpre[i]=0;
					if .<firstuse<sceninc[i] then dx2015initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx2015init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=rxinit<intnx('month',sceninc[i],6,'s') then dx2015init6mo[i]=1;

					* any use in 6 month;
					dx2015any6mo[i]=0;
					if any6moRXuse[i]=1 then dx2015any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
			
			array ffsptd&maxyear. [*] $ ffsptd&maxyear._1-ffsptd&maxyear._12 ffsptd2017_1-ffsptd2017_12;
			array drop&maxyear. [*] drop&maxyear._scen1-drop&maxyear._scen14;
			if scenyr[i]=&maxyear. then do;
				mostart=month(sceninc[i]);
				moend=mostart+6;
				do mo=mostart to moend;
					if ffsptd&maxyear.[mo] ne 'Y' then drop&maxyear.[i]=1;
				end;
				if drop&maxyear.[i] ne 1 then do;
					*initpre;
					dx&maxyear.initpre[i]=0;
					if .<firstuse<sceninc[i] then dx&maxyear.initpre[i]=1;
									
					* init60;
					if firstuse=. or firstuse>=sceninc[i] then dx&maxyear.init6mo[i]=0; * clearing out those with prior drug use;
					if sceninc[i]<=firstuse<intnx('month',sceninc[i],6,'s') then dx&maxyear.init6mo[i]=1;
					
					* any use in 6 month;
					dx&maxyear.any6mo[i]=0;
					if any6moRXuse[i]=1 then dx&maxyear.any6mo[i]=1;
				end;
			end;
			else do;
				mostart=.;
				moend=.;
			end;
		
	end;
	
run;
%mend;

%prev;

proc print data=analytical_table1_prev (obs=100);
	where adrx&maxyear.=1 and insamp&maxyear.=1;
run;

%macro means(var);
proc means data=analytical_table1_prev noprint nway;
	output out=table1_&var. 
	sum(&var.1-&var.14)=sum1-sum14 mean(&var.1-&var.14)=mean1-mean14 std(&var.1-&var.14)=std1-std14;
run;
%mend;

%means(adrx2008_);
%means(adrx2009_);
%means(adrx2010_);
%means(adrx2011_);
%means(adrx2012_);
%means(adrx2013_);
%means(adrx2014_);
%means(adrx2015_);
%means(adrx&maxyear._);
%means(dx2008initpre);
%means(dx2009initpre);
%means(dx2010initpre);
%means(dx2011initpre);
%means(dx2012initpre);
%means(dx2013initpre);
%means(dx2014initpre);
%means(dx2015initpre);
%means(dx&maxyear.initpre);
%means(dx2008init6mo);
%means(dx2009init6mo);
%means(dx2010init6mo);
%means(dx2011init6mo);
%means(dx2012init6mo);
%means(dx2013init6mo);
%means(dx2014init6mo);
%means(dx2015init6mo);
%means(dx&maxyear.init6mo);
%means(dx2008any6mo);
%means(dx2009any6mo);
%means(dx2010any6mo);
%means(dx2011any6mo);
%means(dx2012any6mo);
%means(dx2013any6mo);
%means(dx2014any6mo);
%means(dx2015any6mo);
%means(dx&maxyear.any6mo);

%macro results;
data table1_prev;
	format row
		%do i=1 %to 14;
			sum&i mean&i
		%end;;
	set table1_adrx2008_ (in=a1) 
			table1_adrx2009_ (in=a2)
			table1_adrx2010_ (in=a3)
			table1_adrx2011_ (in=a4)
			table1_adrx2012_ (in=a5) 
			table1_adrx2013_ (in=a6)
			table1_adrx2014_ (in=a7) 
			table1_adrx2015_ (in=a8)
			table1_adrx&maxyear._ (in=a9)
			table1_dx2008initpre (in=a10)
			table1_dx2009initpre (in=a11)
			table1_dx2010initpre (in=a12)
			table1_dx2011initpre (in=a13)
			table1_dx2012initpre (in=a14)
			table1_dx2013initpre (in=a15)
			table1_dx2014initpre (in=a16)
			table1_dx2015initpre (in=a17)
			table1_dx&maxyear.initpre (in=a18)
			table1_dx2008init6mo (in=a19)
			table1_dx2009init6mo (in=a20)
			table1_dx2010init6mo (in=a21)
			table1_dx2011init6mo (in=a22)
			table1_dx2012init6mo (in=a23)
			table1_dx2013init6mo (in=a24)
			table1_dx2014init6mo (in=a25)
			table1_dx2015init6mo (in=a26)
			table1_dx&maxyear.init6mo (in=a27)
			table1_dx2008any6mo (in=a28)
			table1_dx2009any6mo (in=a29)
			table1_dx2010any6mo (in=a30)
			table1_dx2011any6mo (in=a31)
			table1_dx2012any6mo (in=a32)
			table1_dx2013any6mo (in=a33)
			table1_dx2014any6mo (in=a34)
			table1_dx2015any6mo (in=a35)
			table1_dx&maxyear.any6mo (in=a36);
	length row $15.;
	if a1 then row="adrx2008";
	if a2 then row="adrx2009";
	if a3 then row="adrx2010";
	if a4 then row="adrx2011";
	if a5 then row="adrx2012";
	if a6 then row="adrx2013";
	if a7 then row="adrx2014";
	if a8 then row="adrx2015";
	if a9 then row="adrx&maxyear.";
	if a10 then row="dx2008initpre";
	if a11 then row="dx2009initpre";
	if a12 then row="dx2010initpre";
	if a13 then row="dx2011initpre";
	if a14 then row="dx2012initpre";
	if a15 then row="dx2013initpre";
	if a16 then row="dx2014initpre";
	if a17 then row="dx2015initpre";
	if a18 then row="dx&maxyear.initpre";
	if a19 then row="dx2008init6mo";
	if a20 then row="dx2009init6mo";
	if a21 then row="dx2010init6mo";
	if a22 then row="dx2011init6mo";
	if a23 then row="dx2012init6mo";
	if a24 then row="dx2013init6mo";
	if a25 then row="dx2014init6mo";
	if a26 then row="dx2015init6mo";
	if a27 then row="dx&maxyear.init6mo";
	if a28 then row="dx2008any6mo";
	if a29 then row="dx2009any6mo";
	if a30 then row="dx2010any6mo";
	if a31 then row="dx2011any6mo";
	if a32 then row="dx2012any6mo";
	if a33 then row="dx2013any6mo";
	if a34 then row="dx2014any6mo";
	if a35 then row="dx2015any6mo";
	if a36 then row="dx&maxyear.any6mo";
run;
%mend;

%results;

ods excel file="./output/prev_inc&maxyear..xlsx";
proc print data=table1_prev; run;
ods excel close;

