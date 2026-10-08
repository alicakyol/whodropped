*! whodropped 1.0.0  28aug2026  Ali C. Akyol
*! Which variables cost you observations?

program define whodropped, rclass
    version 14.0

    syntax [varlist(numeric ts fv default=none)] [if] [in]              ///
        [aweight fweight pweight iweight]                                ///
        [ ,                                                              ///
            SORT                                                         ///
            MINimum(integer 0)                                           ///
            GENerate(name)                                               ///
            REASon(name)                                                 ///
            SAVing(string)                                               ///
            DETail                                                       ///
            noHEADer                                                     ///
        ]

    * -----------------------------------------------------------------
    * 0.  Check new variable names up front, before doing any work
    * -----------------------------------------------------------------
    if "`generate'" != "" confirm new variable `generate'
    if "`reason'"   != "" confirm new variable `reason'

    if `"`saving'"' != "" {
        gettoken sfile srest : saving, parse(",")
        local sfile = trim(`"`sfile'"')
        if strpos(lower(`"`srest'"'), "replace") local sreplace "replace"
        if `"`sfile'"' == "" {
            di as err "option {bf:saving()} requires a filename"
            exit 198
        }
    }

    * -----------------------------------------------------------------
    * 1.  Work out which variables to check
    * -----------------------------------------------------------------
    local inferred 0
    local terms "`varlist'"

    if "`terms'" == "" {
        if "`e(cmd)'" == "" {
            di as err "no varlist specified and no estimation results in memory"
            di as err `"{p 4 4 2}Specify a varlist, or run {bf:whodropped} immediately after an estimation command.{p_end}"'
            exit 301
        }
        local inferred 1

        if "`e(depvar)'" != "" local terms `terms' `e(depvar)'

        capture local cn : colnames e(b)
        if _rc == 0 {
            foreach c of local cn {
                if "`c'" != "_cons" local terms `terms' `c'
            }
        }
        if "`e(absvars)'"  != "" local terms `terms' `e(absvars)'
        if "`e(clustvar)'" != "" local terms `terms' `e(clustvar)'
    }

    * Expand interactions, strip factor-variable notation, keep ts operators,
    * and drop duplicates while preserving order.
    local comps
    foreach t of local terms {
        local parts : subinstr local t "#" " ", all
        foreach p of local parts {
            whodropped_clean "`p'"
            local c "`r(clean)'"
            if "`c'" == "" continue
            local isdup : list c in comps
            if !`isdup' local comps `comps' `c'
        }
    }

    if "`comps'" == "" {
        di as err "no variables to check"
        exit 198
    }

    * -----------------------------------------------------------------
    * 2.  Baseline sample: if / in / weights, nothing else
    * -----------------------------------------------------------------
    marksample touse, novarlist

    qui count if `touse'
    local Nbase = r(N)
    if `Nbase' == 0 {
        di as err "no observations in the baseline sample"
        exit 2000
    }

    * -----------------------------------------------------------------
    * 3.  One missing-value indicator per variable
    * -----------------------------------------------------------------
    tempvar nmiss
    qui gen int `nmiss' = 0 if `touse'

    local k 0
    foreach c of local comps {
        local ++k
        local name`k' "`c'"

        tempvar m`k'
        qui gen byte `m`k'' = 0 if `touse'

        * String variables (a string cluster variable, say) cannot go
        * through tsrevar, but missing() still works on them.
        local rv ""
        capture confirm string variable `c'
        if _rc == 0 {
            local rv "`c'"
        }
        else {
            capture tsrevar `c'
            if _rc {
                di as err "could not evaluate {bf:`c'}"
                di as err `"{p 4 4 2}Time-series operators require the data to be {bf:tsset} or {bf:xtset}.{p_end}"'
                exit _rc
            }
            local rv "`r(varlist)'"
        }

        foreach z of local rv {
            qui replace `m`k'' = 1 if missing(`z') & `touse'
        }
        qui replace `nmiss' = `nmiss' + `m`k'' if `touse'
    }
    local K = `k'

    * -----------------------------------------------------------------
    * 4.  Per-variable counts
    * -----------------------------------------------------------------
    forvalues i = 1/`K' {
        qui count if `touse' & `m`i'' == 1
        local miss`i' = r(N)
        qui count if `touse' & `m`i'' == 1 & `nmiss' == 1
        local only`i' = r(N)
    }

    * Display / waterfall order
    local order
    if "`sort'" != "" {
        local pool
        forvalues i = 1/`K' {
            local pool `pool' `i'
        }
        while "`pool'" != "" {
            local best     = 0
            local bestonly = -1
            local bestmiss = -1
            foreach i of local pool {
                if (`only`i'' > `bestonly') |                             ///
                   (`only`i'' == `bestonly' & `miss`i'' > `bestmiss') {
                    local best     = `i'
                    local bestonly = `only`i''
                    local bestmiss = `miss`i''
                }
            }
            local order `order' `best'
            local pool : list pool - best
        }
    }
    else {
        forvalues i = 1/`K' {
            local order `order' `i'
        }
    }

    * -----------------------------------------------------------------
    * 5.  Waterfall: impose the variables one at a time, in order
    * -----------------------------------------------------------------
    tempvar alive
    qui gen byte `alive' = 1 if `touse'
    local rem = `Nbase'

    foreach i of local order {
        local prev = `rem'
        qui replace `alive' = 0 if `m`i'' == 1 & `touse'
        qui count if `touse' & `alive' == 1
        local rem = r(N)
        local seq`i'  = `prev' - `rem'
        local left`i' = `rem'
    }

    qui count if `touse' & `nmiss' == 0
    local Ncomp = r(N)
    local Nlost = `Nbase' - `Ncomp'

    * Estimation sample, if there is one to compare against
    local Nesamp = .
    if "`e(cmd)'" != "" {
        capture qui count if e(sample)
        if _rc == 0 local Nesamp = r(N)
    }

    * Panel units, for -detail-
    local pvar : char _dta[_TSpanel]
    local Ubase = .
    local Ucomp = .
    if "`detail'" != "" & "`pvar'" != "" {
        tempvar ug
        qui egen `ug' = group(`pvar') if `touse'
        qui su `ug', meanonly
        local Ubase = cond(r(N) == 0, 0, r(max))
        drop `ug'
        qui egen `ug' = group(`pvar') if `touse' & `nmiss' == 0
        qui su `ug', meanonly
        local Ucomp = cond(r(N) == 0, 0, r(max))
    }

    * -----------------------------------------------------------------
    * 6.  Report
    * -----------------------------------------------------------------
    if "`header'" == "" {
        di ""
        di as txt "whodropped" _col(14) "observations lost to missing values"
        if `inferred' {
            di as txt "{p 4 4 2}Variables taken from the last estimation " ///
                      "results ({bf:`e(cmd)'}). Pass the same {bf:if}/{bf:in} " ///
                      "you used there, or the baseline below will be too wide.{p_end}"
        }
        di ""
        local s1 = cond(`K' == 1, "", "s")
        di as txt "    Baseline sample"          _col(52) as res %14.0fc `Nbase'
        di as txt "    Complete cases on `K' variable`s1'"                 ///
                                                  _col(52) as res %14.0fc `Ncomp'
        di as txt "    Lost to missing values"   _col(52) as res %14.0fc `Nlost' ///
           as txt "   (" %4.1f 100*`Nlost'/`Nbase' "%)"
        if "`detail'" != "" & "`pvar'" != "" {
            di as txt "    Panel units (`pvar')" _col(52) as res %14.0fc `Ucomp' ///
               as txt " of " as res %1.0fc `Ubase'
        }
    }

    di ""
    di as txt "    Variable" _col(30) %10s "Missing" _col(41) %7s "% base" ///
        _col(49) %11s "Only this" _col(61) %10s "Seq. loss" _col(72) %11s "Remaining"
    di as txt "    {hline 79}"

    local hidden 0
    foreach i of local order {
        if `miss`i'' < `minimum' {
            local ++hidden
            continue
        }
        di as res "    " %-24s abbrev("`name`i''", 24)                     ///
            as txt _col(30) %10.0fc `miss`i''                              ///
                   _col(41) %7.1f  100*`miss`i''/`Nbase'                   ///
                   _col(49) %11.0fc `only`i''                              ///
                   _col(61) %10.0fc `seq`i''                               ///
                   _col(72) %11.0fc `left`i''
    }
    di as txt "    {hline 79}"

    if `hidden' > 0 {
        local s2 = cond(`hidden' == 1, "", "s")
        di as txt "    (`hidden' variable`s2' with fewer than `minimum' missing not shown)"
    }

    di as txt "{p 4 4 2}{it:Missing} is the univariate count. {it:Only this} " ///
              "counts observations that this variable alone kills, so it is what " ///
              "you would get back by dropping it. {it:Seq. loss} is the marginal " ///
              "cost of adding the variable in the order shown.{p_end}"

    * The single most expensive exclusive variable
    local topi = 0
    local topn = 0
    forvalues i = 1/`K' {
        if `only`i'' > `topn' {
            local topn = `only`i''
            local topi = `i'
        }
    }
    if `topi' > 0 & `Nlost' > 0 {
        local topstr = trim(string(`topn', "%14.0fc"))
        local toppct = trim(string(100*`topn'/`Nlost', "%4.1f"))
        di ""
        di as txt "{p 4 4 2}Dropping {bf:`name`topi''} would recover " ///
                  "{res:`topstr'}{txt} observations, `toppct'% of the loss.{p_end}"
    }

    * Reconciliation against the estimation sample
    if `Nesamp' < . {
        local gap = `Ncomp' - `Nesamp'
        di ""
        di as txt "    Estimation sample e(sample)"     _col(52) as res %14.0fc `Nesamp'
        di as txt "    Unexplained"                     _col(52) as res %14.0fc `gap'
        if `gap' > 0 {
            di as txt "{p 4 4 2}The unexplained gap is not missing values: look at " ///
                      "{bf:if}/{bf:in} restrictions, zero or negative weights, " ///
                      "singleton groups dropped by the estimator, collinear " ///
                      "observations, or a subpopulation.{p_end}"
        }
        if `gap' < 0 {
            di as txt "{p 4 4 2}The estimation sample is larger than the complete-case " ///
                      "count, so the variables checked here are not the ones the " ///
                      "estimator used. Specify the varlist explicitly.{p_end}"
        }
    }
    di ""

    * -----------------------------------------------------------------
    * 7.  Optional new variables
    * -----------------------------------------------------------------
    if "`generate'" != "" {
        qui gen byte `generate' = (`nmiss' > 0) if `touse'
        label variable `generate' "1 = dropped from the complete-case sample"
    }

    if "`reason'" != "" {
        qui gen strL `reason' = "" if `touse'
        forvalues i = 1/`K' {
            qui replace `reason' = `reason' +                              ///
                cond(`reason' == "", "", "; ") + "`name`i''"               ///
                if `m`i'' == 1 & `touse'
        }
        qui compress `reason'
        label variable `reason' "variables missing for this observation"
    }

    * -----------------------------------------------------------------
    * 8.  Saved results
    * -----------------------------------------------------------------
    tempname T
    matrix `T' = J(`K', 5, .)
    matrix colnames `T' = missing pctbase onlythis seqloss remaining

    local rnames
    local r 0
    foreach i of local order {
        local ++r
        matrix `T'[`r', 1] = `miss`i''
        matrix `T'[`r', 2] = 100*`miss`i''/`Nbase'
        matrix `T'[`r', 3] = `only`i''
        matrix `T'[`r', 4] = `seq`i''
        matrix `T'[`r', 5] = `left`i''
        local safe = substr(subinstr("`name`i''", ".", "_", .), 1, 32)
        local rnames `rnames' `safe'
    }
    matrix rownames `T' = `rnames'

    if `"`sfile'"' != "" {
        preserve
        tempname pf
        tempfile tf
        postfile `pf' str64 variable double(missing pctbase onlythis seqloss remaining) ///
            using "`tf'", replace
        foreach i of local order {
            post `pf' ("`name`i''") (`miss`i'') (100*`miss`i''/`Nbase') ///
                      (`only`i'') (`seq`i'') (`left`i'')
        }
        postclose `pf'
        qui use "`tf'", clear
        label data "whodropped results"
        if "`sreplace'" != "" {
            qui save `"`sfile'"', replace
        }
        else {
            qui save `"`sfile'"'
        }
        restore
        di as txt "    (results saved to " as res `"`sfile'"' as txt ")"
    }

    return matrix table   = `T'
    return local  varlist "`comps'"
    return scalar K          = `K'
    return scalar N_baseline = `Nbase'
    return scalar N_complete = `Ncomp'
    return scalar N_dropped  = `Nlost'
    if `Nesamp' < . {
        return scalar N_esample = `Nesamp'
        return scalar N_gap     = `Ncomp' - `Nesamp'
    }
end


* ---------------------------------------------------------------------
* whodropped_clean: strip factor-variable and level prefixes from one
* term component, keep any time-series operator, return the remainder.
*
*   i.industry      -> industry
*   1b.industry     -> industry
*   c.size          -> size
*   L2.roa          -> L2.roa
*   c.L.roa         -> L.roa
*   ib(2).rating    -> rating
* ---------------------------------------------------------------------
program define whodropped_clean, rclass
    version 14.0
    args comp

    local comp = trim(`"`comp'"')
    if "`comp'" == "" | "`comp'" == "_cons" {
        return local clean ""
        exit
    }

    local pieces : subinstr local comp "." " ", all
    local np : word count `pieces'

    if `np' == 1 {
        return local clean "`comp'"
        exit
    }

    * The variable name is always the last piece.
    local var : word `np' of `pieces'

    * Walk backwards collecting time-series operators that sit directly
    * in front of the variable name; anything before those is factor
    * notation and gets dropped.
    local tspart ""
    local j = `np' - 1
    local keepgoing 1
    while `j' >= 1 & `keepgoing' {
        local pj : word `j' of `pieces'
        if regexm("`pj'", "^[LFDSlfds][LFDSlfds0-9()/, ]*$") {
            local tspart "`pj'.`tspart'"
            local --j
        }
        else {
            local keepgoing 0
        }
    }

    return local clean "`tspart'`var'"
end
