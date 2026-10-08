*------------------------------------------------------------------
* whodropped — worked example
*
* Builds a small synthetic firm-year panel with realistic missingness
* and shows what the command reports. Run it top to bottom; no data
* required.
*------------------------------------------------------------------

clear all
set seed 20260828

* ---- a firm-year panel ------------------------------------------
set obs 2000
gen long gvkey = _n
expand 12
bysort gvkey: gen int fyear = 2012 + _n - 1
xtset gvkey fyear

gen double size     = rnormal(7, 1.5)
gen double leverage = runiform()*0.6
gen double roa      = 0.05 + 0.02*rnormal() + 0.01*(size - 7)
gen byte   industry = 1 + int(runiform()*12)

* ---- missingness with structure ---------------------------------
* R&D: missing for most firms in most years (the classic sample killer),
* but its missingness overlaps heavily with the segment variable.
gen double rd = runiform() if runiform() < 0.35
replace rd = . if industry <= 4

* Segment disclosure: missing for the same firms as R&D, plus a few more.
gen double segments = runiform() if !missing(rd) | runiform() < 0.05

* Institutional ownership: missing only in the early years — a
* different kind of problem, and one that is exclusively its own.
gen double instown = runiform() if fyear >= 2015

* Analyst coverage: missing almost at random, small.
gen double coverage = runiform() if runiform() < 0.97

* A few missing outcomes.
replace roa = . if runiform() < 0.01

* ---- 1. plan a specification before estimating -------------------
whodropped roa size leverage rd segments instown coverage, sort

* Note the contrast: rd is missing far more often than instown, but
* almost none of that loss is exclusive — segments is missing for the
* same observations. Dropping instown recovers observations; dropping
* rd on its own recovers very few.

* ---- 2. after an estimation, with no varlist ---------------------
regress roa size leverage instown coverage i.industry
whodropped

* ---- 3. pass the same if restriction the estimation used ---------
regress roa size leverage instown if fyear >= 2015
whodropped if fyear >= 2015

* ---- 4. time-series operators are handled ------------------------
regress roa L.size L.leverage instown
whodropped, sort

* ---- 5. is the attrition systematic? -----------------------------
whodropped roa size leverage rd instown, generate(lost) reason(why)
tabulate fyear lost, row nofreq
tabulate why if lost, sort

* ---- 6. saved results --------------------------------------------
whodropped roa size leverage rd instown, sort
matrix list r(table)
display "baseline: " r(N_baseline) "   complete: " r(N_complete)

drop lost why
