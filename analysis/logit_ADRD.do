clear all
set more off
capture log close

/* Logit Regression Analysis for AD Drug Use */

use "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/ad_drug_use/analytical_logit_spec2016",replace

ds 

drop if zip==""
drop if foundspec==0

// Limit to ADRD only - change monthssincedx to ADRD_inc and drop dx dummies

gen ADRD_inc=min(AD_inc,dem_inc)

drop if ADRD_inc==. | year(ADRD_inc)>year

gen agesq=age^2
gen eoy=mdy(12,31,year)
gen monthssincedx=(eoy-ADRD_inc)/(365/12)

sum monthssincedx 

global yvar7 "adrx71"
global yvar90 "adrx902"
global yvar180 "adrx1802"
global yvar270 "adrx2702"
global xvar1 "female age agesq race_db race_dh race_da dx_dad dx_dnadd spec"
global xvar2 "female age agesq race_db race_dh race_da dx_dad dx_dnadd i.hcc4 dual lis i.year i.phyvis4 cc* monthssincedx spec"

codebook bene_id

////////////////////////// Dependent Variable - Drug Use 7 days, 1 claim //////////////////////
// 1. ADRX Drug use - 7 days, 1 claim 
logit $yvar7 $xvar1, or vce(cluster zip)
	matrix logit1=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(1) modify
	putexcel A1="1. 7 days 1 claim, basic, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit1),names nformat(number_d2) left
	putexcel C3="OR"
	
// 2. ADRX Drug use - 7 days, 1 claim, addl covariates
logit $yvar7 $xvar2, or vce(cluster zip)
	matrix logit2=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(2) modify
	putexcel A1="2. 7 days 1 claim,addl covariates, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit2),names nformat(number_d2) left
	putexcel C3="OR"

// 3. ADRX Drug use - 90 days, 2 claims
logit $yvar90 $xvar1, or vce(cluster zip)
	matrix logit3=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(3) modify
	putexcel A1="3. 90 days 2 claims, basic, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit3),names nformat(number_d2) left
	putexcel C3="OR"

// 4. ADRX Drug Use - 90 days, 2 claims, addl covariates
logit $yvar90 $xvar2, or vce(cluster zip) 
	matrix logit4=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(4) modify
	putexcel A1="4. 90 days 2 claims,addl covariates, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit4),names nformat(number_d2) left
	putexcel C3="OR"

// 5. ADRX Drug Use - 180 days, 2 claims
logit $yvar180 $xvar1, or vce(cluster zip) 
	matrix logit5=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(5) modify
	putexcel A1="5. 180 days 2 claims, basic, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit5),names nformat(number_d2) left
	putexcel C3="OR"
	
// 6. ADRX Drug Use - 180 days, 2 claims, addl covariates
logit $yvar180 $xvar2, or vce(cluster zip) 
	matrix logit6=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(6) modify
	putexcel A1="6. 180 days 2 claims, addl covariates, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit6),names nformat(number_d2) left
	putexcel C3="OR"
	
// 7. ADRX Drug Use - 270 days, 2 claims
logit $yvar270 $xvar1, or vce(cluster zip) 
	matrix logit7=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(7) modify
	putexcel A1="7. 270 days 2 claims, basic, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit7),names nformat(number_d2) left
	putexcel C3="OR"
	
// 8. ADRX Drug Use - 270 days, 2 claims, addl covariates
logit $yvar270 $xvar2, or vce(cluster zip) 
	matrix logit8=r(table)'
	putexcel set "./output/logit_ADRD.xlsx",sheet(8) modify
	putexcel A1="8. 270 days 2 claims, addl covariates, add spec", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit8),names nformat(number_d2) left
	putexcel C3="OR"