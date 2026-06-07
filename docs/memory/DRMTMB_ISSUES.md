# drmTMB upstream issues — to file from drmSEM work

This session's GitHub access is scoped to `itchyshin/drmSEM` only, so issues
cannot be filed on `itchyshin/drmTMB` from here. Collect genuine engine problems
here; file them on drmTMB (or widen this session's repo scope) later. Only list
things that are actually drmTMB's to fix — not drmSEM bugs.

## ✉ Message to drmTMB — 2026-06-07 (from the drmSEM 0.5.0 cut)

drmSEM just cut **0.5.0** (the cyclic/feedback-graph milestone). **No new
confirmed drmTMB bug.** Coordination items and ergonomics asks surfaced by the
0.5 work, in priority order:

1. **CRAN timeline — the release blocker for drmSEM.** drmSEM cannot be submitted
   to CRAN until drmTMB is on CRAN (CRAN forbids `Remotes:`). drmSEM already keeps
   drmTMB in `Suggests` behind `requireNamespace()` guards and is otherwise
   CRAN-clean. **What is the drmTMB CRAN ETA?** That sequencing gates drmSEM's
   own submission.
2. **OQ-1 sampler parameterization — RESOLVED drmSEM-side, not a drmTMB bug.**
   The per-family `sigma`↔dispersion mapping was reverse-engineered against
   `stats::simulate(fit)` (drmSEM PR #35; var ratios ~0.99–1.02). Two
   *ergonomics* asks that would let drmSEM stop reverse-engineering it:
   - Document/expose the exact **response-scale `sigma`↔dispersion convention**
     per family (nbinom2 `size`, beta `phi`, Gamma `shape`; lognormal: is the
     response `mu` = E[Y], i.e. `meanlog = log(mu) − sigma²/2`?).
   - `predict_parameters()` does **not** reliably name its columns `mu`/`sigma`
     (the drmSEM probe must request each dpar and take the named-or-last-numeric
     column). A **stable named-column contract** would remove that fragility.
3. **OQ-9 marginal effects — needs an API.** For population-averaged effects
   through a random-effect scale, drmSEM needs drmTMB to **expose the fitted RE
   variance components** and a way to **draw/integrate them on the response
   scale**.
4. **OQ-14 joint bivariate fit — needs an engine hook.** A joint bivariate fit
   estimating `rho12`, plus an extractor to read the fitted correlation back
   (drmSEM hook name `drm_fit_rho12()`), would let drmSEM replace its placeholder
   `estimate = NA` with a real value.
5. **OQ-7 `sdreport` NaN — still a candidate, do NOT file yet** (see below).

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
