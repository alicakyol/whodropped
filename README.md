[README.md](https://github.com/user-attachments/files/33186520/README.md)
# whodropped

**Which variables cost you observations?**

The regression reports 118,904 observations. The dataset has 148,332. Which
variables ate the difference, and which one would you get most of it back from?

`whodropped` answers that. For every variable in a specification it reports the
univariate missing count, the number of observations that variable **alone** is
responsible for losing, and the marginal cost of imposing it on top of the
others. Run after an estimation command, it also reconciles the complete-case
count against `e(sample)`, so losses that are *not* about missing data — an `if`
restriction, zero weights, singleton groups dropped by `reghdfe`, collinearity —
appear as a separate residual instead of being quietly blamed on the data.

## Install

```stata
net install whodropped, from("https://raw.githubusercontent.com/alicakyol/whodropped/main") replace
```

Or, once it is on SSC:

```stata
ssc install whodropped
```

## Use

```stata
. regress roa size leverage rd_intensity institutional_own i.industry
. whodropped, sort
```

```
whodropped   observations lost to missing values

    Baseline sample                                        148,332
    Complete cases on 5 variables                          118,904
    Lost to missing values                                  29,428   (19.8%)

    Variable                    Missing  % base    Only this  Seq. loss    Remaining
    -------------------------------------------------------------------------------
    institutional_own            18,204    12.3       17,442     18,204      130,128
    rd_intensity                 24,110    16.3        1,986     11,224      118,904
    leverage                      1,204     0.8            0          0      118,904
    size                            962     0.6            0          0      118,904
    industry                          0     0.0            0          0      118,904
    -------------------------------------------------------------------------------

Dropping institutional_own would recover 17,442 observations, 59.3% of the loss.

    Estimation sample e(sample)                            117,455
    Unexplained                                              1,449
```

The `Only this` column is the one to act on. `rd_intensity` is missing more often
than `institutional_own`, but almost all of that loss is shared — the same
observations are already gone for other reasons — so dropping it buys you
2,000 observations, not 24,000.

## Options

| Option | Effect |
|---|---|
| `sort` | order by exclusive loss, largest first (the waterfall is recomputed to match) |
| `minimum(#)` | hide rows with fewer than `#` missing |
| `detail` | also report surviving panel units, if `xtset` |
| `generate(newvar)` | flag observations dropped from the complete-case sample |
| `reason(newvar)` | string variable listing which variables are missing per observation |
| `saving(file[, replace])` | save the table as a dataset |
| `noheader` | suppress the summary block |

Factor-variable and time-series notation is understood: interactions are
decomposed into components, `i.` / `c.` / `ib2.` prefixes are stripped, and
time-series operators are kept (`L.roa` and `roa` are missing for different
observations, so they get separate rows).

## Checking whether attrition is systematic

```stata
. whodropped roa size leverage rd_intensity, generate(lost) reason(why)
. tabulate fyear lost, row nofreq
. tabulate why if lost, sort
. logit lost size leverage        // is what you lost different from what you kept?
```

## A note on the baseline

The baseline is every observation satisfying the `if`, `in` and weight conditions
given to `whodropped` **itself** — nothing else. If the estimation used an `if`,
pass the same one, or the baseline will be wider than you meant and the residual
gap will absorb the difference.

## Stored results

`r(N_baseline)`, `r(N_complete)`, `r(N_dropped)`, `r(N_esample)`, `r(N_gap)`,
`r(K)`, `r(varlist)`, and `r(table)` (one row per variable).

## Files

- `whodropped.ado` — the command
- `whodropped.sthlp` — help file
- `whodropped_example.do` — worked example on synthetic data, no data required
- `whodropped.pkg`, `stata.toc` — for `net install`

Requires Stata 14 or later. Bug reports and suggestions welcome.
