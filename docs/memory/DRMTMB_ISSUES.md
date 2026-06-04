# drmTMB upstream issues — to file from drmSEM work

This session's GitHub access is scoped to `itchyshin/drmSEM` only, so issues
cannot be filed on `itchyshin/drmTMB` from here. Collect genuine engine problems
here; file them on drmTMB (or widen this session's repo scope) later. Only list
things that are actually drmTMB's to fix — not drmSEM bugs.

## Status: none confirmed yet

Every CI failure so far has been a drmSEM bug (sampler parameterization,
`drmTMB::poisson`/`Gamma` vs `stats::`, Gamma link), not drmTMB.

### Candidate (needs confirmation, do NOT file yet) — OQ-7
`TMB::sdreport()` emits `NaNs produced` (NaN standard errors) when fitting the
small canonical integration DGP (`size -> abundance -> survival`, n=300). This is
most likely a weakly-identified/boundary fit on a small fixture, not an engine
bug. Before filing: reproduce on a clean, well-conditioned single-node fit and
confirm the Hessian is genuinely non-PD where it should not be. If confirmed, the
ask would be a clearer warning (which parameter) and/or a more robust
`sdreport` fallback.
