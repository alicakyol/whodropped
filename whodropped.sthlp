{smcl}
{* *! version 1.0.0  28aug2026}{...}
{viewerjumpto "Syntax" "whodropped##syntax"}{...}
{viewerjumpto "Description" "whodropped##description"}{...}
{viewerjumpto "Options" "whodropped##options"}{...}
{viewerjumpto "Reading the table" "whodropped##reading"}{...}
{viewerjumpto "Examples" "whodropped##examples"}{...}
{viewerjumpto "Stored results" "whodropped##results"}{...}
{viewerjumpto "Author" "whodropped##author"}{...}

{title:Title}

{phang}
{bf:whodropped} {hline 2} Which variables cost you observations?


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:whodropped}
{varlist}
{ifin}
{weight}
[{cmd:,} {it:options}]

{p 4 4 2}
If {varlist} is omitted, {cmd:whodropped} takes the variables from the
estimation results in memory, so it can be run immediately after a
regression.

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt sort}}order the table by exclusive loss instead of by
the order the variables were given{p_end}
{synopt:{opt min:imum(#)}}suppress rows with fewer than {it:#} missing
values{p_end}
{synopt:{opt det:ail}}also report panel units, if the data are
{helpb xtset}{p_end}
{synopt:{opt nohead:er}}suppress the summary block above the table{p_end}

{syntab:Saving}
{synopt:{opt gen:erate(newvar)}}create an indicator equal to 1 for
observations dropped from the complete-case sample{p_end}
{synopt:{opt reas:on(newvar)}}create a string variable listing the
variables that are missing for each observation{p_end}
{synopt:{opt sav:ing(filename[, replace])}}save the table as a Stata
dataset{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}{cmd:aweight}s, {cmd:fweight}s, {cmd:pweight}s and
{cmd:iweight}s are allowed; observations with zero or missing weight are
excluded from the baseline, as they would be in estimation.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:whodropped} answers a question that comes up in every empirical
project: the regression reports 118,904 observations, the dataset has
148,332, and it is not obvious which variables are responsible.

{pstd}
For each variable, {cmd:whodropped} reports how many observations it is
missing for, how many observations it {it:alone} is responsible for
losing, and the marginal cost of imposing it on top of the variables
before it. When it is run after an estimation command, it also
reconciles the complete-case count against {cmd:e(sample)}, so that
losses which are {it:not} due to missing values -- an {cmd:if}
restriction, zero weights, singleton groups dropped by
{helpb reghdfe}, collinearity -- show up as a separate residual rather
than being silently attributed to the data.

{pstd}
Factor-variable and time-series notation is understood. Interactions are
decomposed into their components, factor-variable prefixes are stripped
({cmd:i.industry} is reported as {cmd:industry}), and time-series
operators are kept, since {cmd:L.roa} and {cmd:roa} are missing for
different observations.

{pstd}
The baseline sample is every observation that satisfies the {cmd:if},
{cmd:in} and weight conditions given to {cmd:whodropped} itself --
nothing else. When running after an estimation command that used an
{cmd:if} restriction, pass the same restriction, or the baseline will be
wider than the one you meant and the residual gap will absorb the
difference.


{marker options}{...}
{title:Options}

{phang}
{opt sort} orders the table by the number of observations each variable
exclusively costs, largest first. The sequential column is recomputed in
the displayed order, so the waterfall always matches the table.

{phang}
{opt minimum(#)} suppresses rows for variables missing fewer than
{it:#} times. The suppressed variables still count toward the
complete-case sample; only the display is affected.

{phang}
{opt detail} additionally reports the number of panel units surviving,
if the data are {helpb xtset} or {helpb tsset} with a panel variable.

{phang}
{opt noheader} suppresses the summary block printed above the table.

{phang}
{opt generate(newvar)} creates a {cmd:byte} variable equal to 1 for
observations in the baseline that are excluded from the complete-case
sample and 0 otherwise. Useful for checking whether attrition is random:
{cmd:logit dropped x1 x2}.

{phang}
{opt reason(newvar)} creates a string variable listing, for each
observation, the variables that are missing for it. Useful with
{helpb list} or {helpb tabulate} to see whether the losses cluster in
particular years, industries, or sources.

{phang}
{opt saving(filename[, replace])} saves the table as a Stata dataset
with one row per variable.


{marker reading}{...}
{title:Reading the table}

{phang2}{bf:Missing} is the univariate count: how many baseline
observations this variable is missing for, ignoring every other
variable.

{phang2}{bf:Only this} counts observations that this variable alone
kills -- every other variable in the list is present. This is the number
you would recover by dropping the variable from the specification, and
it is usually the number worth acting on. A variable can be missing for
40,000 observations and be responsible for none of them exclusively, in
which case dropping it buys nothing.

{phang2}{bf:Seq. loss} is the marginal cost of imposing the variable on
top of the ones above it, and {bf:Remaining} is what survives at that
point. The two columns depend on the order of the variables; {opt sort}
changes both.


{marker examples}{...}
{title:Examples}

{pstd}After a regression, with no varlist:{p_end}
{phang2}{cmd:. regress roa size leverage rd_intensity institutional_own}{p_end}
{phang2}{cmd:. whodropped}{p_end}

{pstd}With the same {cmd:if} restriction the estimation used:{p_end}
{phang2}{cmd:. regress roa size leverage if year >= 2000}{p_end}
{phang2}{cmd:. whodropped if year >= 2000}{p_end}

{pstd}Before running anything, to plan a specification:{p_end}
{phang2}{cmd:. whodropped roa size leverage rd_intensity, sort}{p_end}

{pstd}With factor variables, time-series operators, and absorbed
effects:{p_end}
{phang2}{cmd:. xtset gvkey fyear}{p_end}
{phang2}{cmd:. reghdfe roa L.size c.leverage#c.size i.industry, absorb(gvkey fyear)}{p_end}
{phang2}{cmd:. whodropped, sort detail}{p_end}

{pstd}Checking whether the attrition is systematic:{p_end}
{phang2}{cmd:. whodropped roa size leverage, generate(lost) reason(why)}{p_end}
{phang2}{cmd:. tabulate fyear lost, row}{p_end}
{phang2}{cmd:. tabulate why if lost, sort}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:whodropped} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_baseline)}}observations satisfying {cmd:if}, {cmd:in} and weights{p_end}
{synopt:{cmd:r(N_complete)}}observations with no missing values on any variable{p_end}
{synopt:{cmd:r(N_dropped)}}difference between the two{p_end}
{synopt:{cmd:r(N_esample)}}observations in {cmd:e(sample)}, if available{p_end}
{synopt:{cmd:r(N_gap)}}complete cases minus {cmd:e(sample)}{p_end}
{synopt:{cmd:r(K)}}number of variables checked{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables checked, after cleaning{p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}one row per variable, columns {cmd:missing},
{cmd:pctbase}, {cmd:onlythis}, {cmd:seqloss}, {cmd:remaining}{p_end}
{p2colreset}{...}

{title:Also see}

{psee}
Manual: {manhelp misstable D}, {manhelp mark P}

{psee}
Online: {helpb misstable}, {helpb mark}, {helpb tsset}, {helpb xtset}
{p_end}
