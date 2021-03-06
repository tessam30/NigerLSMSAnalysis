/*-------------------------------------------------------------------------------
# Name:		02_hhinfrastructure
# Purpose:	Process household data and create hh infrastrucutre variables
# Author:	Tim Essam, Ph.D.
# Created:	15/11/2013
# Modified: 	07/23/2014
# Owner:	USAID GeoCenter | OakStream Systems, LLC
# License:	MIT License
# Ado(s):	polychoric (For mixed variable factor anlaysis) 
# Required: copylables, attachlabels, 00_SetupFoldersGlobals.do
# Links: http://www.ats.ucla.edu/stat/stata/faq/efa_categorical.htm
#-------------------------------------------------------------------------------
*/
clear
capture log close
log using "$pathlog/infrastructure", replace
set more off

/* Call-in module with hh infrastructure variables 
# ecvmamen_p1 - Dwelling characteristics (pp. 33 from Basic Info Doc) #
*/
use "$pathin/ecvmamen_p1_en.dta", clear

* Generate HH dwelling dummies *
g byte own = inlist(ms06q03, 1, 2, 3, 4)
la var own "HH owns property"

g byte ownTitle = inlist(ms06q03, 1, 3)
la var ownTitle "HH owns property with title"

g byte brickHome = inlist(ms06q10, 2, 6)
la var brickHome "Dwelling primarily made of brick"

g byte roof = inlist(ms06q11, 1, 2, 3)
la var roof "Roof primarily metal/tile/concrete"

g byte dfloor =  ms06q12==1
la var dfloor "Dirt floor"

* Generate water variables *
g byte waterConnect = ms06q13==1
la var waterConnect "Dwelling connected to SEEN water network"

ren  ms06q18a waterSource
g byte waterRunning =  inlist(waterSource, 11, 12, 13, 14) & ms06q19<=500
la var waterRunning "Water is from tap within 500 meters of dwelling"

g waterDist = 0
replace waterDist = 1 if ms06q19<1
replace waterDist = 2 if ms06q19>=1 & ms06q19<=500
replace waterDist = 3 if ms06q19>500 & ms06q19<=1000
replace waterDist = 4 if ms06q19>1000
la var waterDist "dist to h20: 1=in dwelling, 2=less than 500m, 3=500-1,000m, 4=1km or more" 
la define h20 1 "h20 in dwelling" 2 "h20 less than 500m" 3 "h20 b/tw 500-1000m" 4 "h20 more than 1km"
la values waterDist h20 

g waterTime = ms06q20a + ms06q20bm
recode waterTime (.=0)
la var waterTime "Total time required to get water"

* Should we include neighbor's tap and neighborhood fountain in this var?
g byte waterSafe = inlist(waterSource, 11, 12, 13, 14, 18, 19, 20, 21) & ms06q19<=1000
la var waterSafe "Water from tap or protected source & within 1KM"

* Generate electricity vars *
g byte elecMeter = ms06q23==1 if inlist(ms06q25, 0, 99999, .)!=1
recode elecMeter (.=0)
la var elecMeter "HH has electricity meter"

g byte electricity = inlist(ms06q26, 1, 2)
la var electricity "HH has electricity"

ren ms06q43a cooking

g byte toilet= inlist(ms06q45, 1, 2, 3)
la var toilet "HH has flush toilet or latrine"

/* NOTES: Create Infrastructure indices *Rural, Urban, National*
 Keeping only first factor to simplify;
 Use polychoric correlation matrix because of binary variables
 http://www.ats.ucla.edu/stat/stata/faq/efa_categorical.htm
*/

polychoric waterRunning elecMeter dfloor toilet waterDist roof brickHome [aweight=hhweight] if urbrur == 2
matrix C = r(R)
global N = r(N)
factormat C, n($N) pcf factor(2)
rotate, varimax
greigen
predict infraindex if urbrur==2
la var infraindex "infrastructure index for rural hh"
alpha waterRunning elecMeter dfloor toilet waterDist roof brickHome  if urbrur == 2

polychoric waterRunning elecMeter dfloor toilet waterDist roof brickHome [aweight=hhweight] if urbrur == 1
matrix C = r(R)
global N = r(N)
factormat C, n($N) pcf factor(2)
rotate, varimax
greigen
predict infraindex_urb if urbrur == 1
la var infraindex_urb "infrastructure index for urban hh"
alpha waterRunning elecMeter dfloor toilet waterDist roof brickHome if urbrur == 1

polychoric waterRunning elecMeter dfloor toilet waterDist roof brickHome [aweight=hhweight]
matrix C = r(R)
global N = r(N)
factormat C, n($N) pcf factor(2)
rotate, varimax
greigen
predict infraindex_ntl
la var infraindex_ntl "infrastructure index for all hh"
alpha waterRunning elecMeter dfloor toilet waterDist roof brickHome

twoway (kdensity infraindex_ntl) (kdensity infraindex) (kdensity infraindex_urb)

/* Extra code
qui factor waterRunning elecMeter dfloor toilet waterDist roof brickHome if urbrur ==2 [aweight=hhweight], pcf
predict infraindex1 if urbrur==2
la var infraindex1 "infrastructure index for rural hh"

qui factor waterRunning elecMeter dfloor toilet waterDist roof brickHome if urbrur ==1 [aweight=hhweight], pcf
predict infraindex_urbr if urbrur==1
la var infraindex_urb "infrastructure index for urban hh"

qui factor waterRunning elecMeter dfloor toilet waterDist roof brickHome [aweight=hhweight], pcf
predict infraindex_natl
la var infraindex_natl "infrastructure index for all Niger"
*/

* Check distribution of variables
tabstat own-toilet [aw=hhweight], stats(mean median min max sd) col(stat)
compress

* Keep all new data and essential survey info
ds(ms1* ms0* as0*), not
keep `r(varlist)'

sort hid
compress
save "$pathout/hhinfra.dta", replace

log2html "$pathlog/infrastructure", replace
