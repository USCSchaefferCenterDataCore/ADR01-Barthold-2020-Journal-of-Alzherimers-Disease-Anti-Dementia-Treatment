/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 9/3/2019;

* PURPOSE: Merge PartD to Cost information;

* INPUT: ADdrugs_0615;
* OUTPUT: adrx_2007_2016;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname exp "../../data/explore";
%partDlib(types=pde);

/*********************************************************************************************
- Merge to original part D claims by PDE to get:
	- benefit phase (bn, bnftphas - 2012 only)
	- totalcst
	- lics_amt
	- ptpayamt
- Drop claims with lics_amt
- Check if totalcst is different from ptpayamt amoung the phases
- Limit to benefit phase II
- Average, standardizing to 30 day supply
*********************************************************************************************/

proc sort data=addrugs.ADdrugs_0616 out=adrx; by bene_id pde_id; run;
	
data rxcost;
	merge adrx (in=a) 
				pde.opt1pde2006 (in=_06 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2007 (in=_07 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2008 (in=_08 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2009 (in=_09 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bn rename=bn=bnftphas)
				pde.opt1pde2010 (in=_10 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2011 (in=_11 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2012 (in=_12 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt gapdscnt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2013 (in=_13 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt gapdscnt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2014 (in=_14 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt gapdscnt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2015 (in=_13 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt gapdscnt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas)
				pde.opt1pde2016 (in=_14 keep=bene_id pde_id drcvstcd gdcboopt gdcaoopt gapdscnt lics_amt plro_amt cpp_amt npp_amt ptpayamt totalcst bnftphas);
	by bene_id pde_id;
	if a;
	found=(sum(of _06-_14));
run;

* checking the difference between all the amounts and the total cost;
data check;
	set rxcost;
	if found=1;
	costck=sum(ptpayamt,lics_amt,plro_amt,cpp_amt,npp_amt,gapdscnt);
	year=year(srvc_dt);
	match=0;
	if round(costck,0.01)=round(totalcst,0.01) then match=1;
run;

proc freq data=check;
	table year*match / missing;
run;

proc print data=check (obs=100);
	where match=0;
run;
				
proc freq data=rxcost;
	table found drcvstcd;
run;

data rxcost1;
	set rxcost;
	* drop lics amt;
	achei=max(donep,galan,rivas);
	year=year(srvc_dt);
	if achei then do;
		achei_dayssply=dayssply;
		achei_oop=ptpayamt;
		achei_total=totalcst;
	end;
	if donep then do;
		donep_dayssply=dayssply;
		donep_oop=ptpayamt;
		donep_total=totalcst;
	end;
	if meman then do;
		meman_dayssply=dayssply;
		meman_oop=ptpayamt;
		meman_total=totalcst;
	end;
	if rivas then do;
		rivas_dayssply=dayssply;
		rivas_oop=ptpayamt;
		rivas_total=totalcst;
	end;
	if galan then do;
		galan_dayssply=dayssply;
		galan_oop=ptpayamt;
		galan_total=totalcst;
	end;
run;

proc means data=rxcost1 noprint nway;
	class year;
	output out=plancost_yr sum(achei_dayssply achei_oop achei_total donep_dayssply donep_oop donep_total
	meman_dayssply meman_oop meman_total rivas_dayssply rivas_oop rivas_total galan_dayssply galan_oop galan_total)=;
run;

data plancost_yr1;
	set plancost_yr;
	
	* standardize to 30 days;
	achei_oop30=(achei_oop/achei_dayssply)*30;
	donep_oop30=(donep_oop/donep_dayssply)*30;
	galan_oop30=(galan_oop/galan_dayssply)*30;
	meman_oop30=(meman_oop/meman_dayssply)*30;
	rivas_oop30=(rivas_oop/rivas_dayssply)*30;
	achei_total30=(achei_total/achei_dayssply)*30;
	donep_total30=(donep_total/donep_dayssply)*30;
	galan_total30=(galan_total/galan_dayssply)*30;
	meman_total30=(meman_total/meman_dayssply)*30;
	rivas_total30=(rivas_total/rivas_dayssply)*30;
run;

ods excel file="./output/adrx_cost2016.xlsx";
proc print data=plancost_yr1; run;
ods excel close;
	
	
