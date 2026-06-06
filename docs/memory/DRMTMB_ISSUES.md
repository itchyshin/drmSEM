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

### RESOLVED drmSEM-side (no drmTMB change needed) — structured-effect object not resolvable on refit
When drmSEM refits a node for d-separation (adds one predictor and re-fits via
`drmTMB::drm_formula()` + `drmTMB::drmTMB()`), a `phylo(1|species, tree=phy)`
term failed because `phy` (the ape tree) was not resolvable in the refit. CI:
PR #6 run 26998231239 -> `status="refit_failed"` for the augmented phylo-node
refit.

**Resolution (OQ-13, drmSEM-side):** the latter horn of the question held —
re-fitting a structured node needs the structured object in the evaluation
environment. drmSEM now captures the SEM's specification environment at build
time (`drm_sem()`/`drm_psem()` store `fit_env = parent.frame()`) and evaluates
the augment-refit there (`drm_refit_augmented(..., env = object$fit_env)` via
`do.call(..., envir = env)`). The `tree` resolves, the `phylo()` term is
preserved, and phylo d-sep claims now return `status="ok"` with a real LRT
p-value (CI run 27006262081 green; asserted in `tests/testthat/test-phylo.R`).
**No drmTMB change is required** — nothing to file upstream. (A future
convenience would be drmTMB storing the resolved phylo covariance on the fitted
object so a refit need not keep the tree in scope, but it is not necessary.)
