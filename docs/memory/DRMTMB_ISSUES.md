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

## ✉ Message to drmTMB — 2026-08-09 (from the `because`-package gap audit)

Context: the `because` package (von Hardenberg, Quintero Vallejo & Gonzalez-Voyer,
RSTB-2025-0491, under review) is a joint-Bayesian causal-inference ecosystem
overlapping drmSEM's territory. Auditing drmSEM against it surfaced nine engine-side
asks. **No drmTMB bug is claimed here** — all nine are scope/ergonomics/evidence asks.

Headline finding, worth stating plainly: **drmTMB's missing-data support is not a gap,
it is a mature subsystem that drmSEM cannot currently reach.** Missing-*response*
masking across 15–18 families at ledger gate G3, plus a joint-likelihood (FIML-like)
missing-*predictor* mechanism (`mi()` / `impute_model()` / `imputed()`) over 12
predictor families. Explicitly not multiple imputation, not Bayesian, MNAR fails loud.
That is a *better* architectural fit for drmSEM than `because`'s approach, because it
is per-fit and therefore piecewise-compatible.

Priority order for a drmTMB imputation lane: **2 + 5 together**, then 1, with 4 and 6
riding alongside. Items 7–9 are separate asks, not part of that lane.

1. **Widen the response-family gate for `missing = "model"`.**
   `drm_missing_predictor_families()` (`R/drmTMB.R:325-327`) accepts a modelled missing
   predictor only when the *response* family is gaussian, poisson, binomial, nbinom2 or
   beta. Every drmSEM node is one drmTMB fit and drmSEM imposes no family whitelist, so
   a SEM loses `mi()` the moment any node uses Gamma, lognormal, student, tweedie,
   beta_binomial, cumulative_logit or a zero-inflated family. The 12-family *predictor*
   catalogue is already implemented; the restriction is on the response side.
   *Ask:* extend family by family — Gamma, lognormal, student, beta_binomial,
   zi_poisson/zi_nbinom2. *Acceptance:* known-DGP recovery test + ledger row each.

2. **Allow more than one `mi()` term per fit.** ← highest priority
   Exactly one modelled missing predictor is supported. A SEM node routinely has several
   parents (`y ~ m1 + m2 + x`) and real comparative data has NAs in several columns.
   One-at-a-time forces drmSEM to drop rows — reintroducing the complete-case bias the
   feature exists to remove — or to refuse.
   *Ask:* k ≥ 2 simultaneous `mi()` terms, at minimum Gaussian response with independent
   predictor models. *Acceptance:* two-missing-predictor recovery test under MCAR and
   MAR; confirm sentinel-invariance still holds.

3. **Reuse a mediator's own node model as its predictor model** *(SEM-specific)*.
   In `x → m → y`, `m` is a response in its own node and a predictor in node `y`. When
   `m` is incomplete, `impute_model()` asks for a predictor model for `m` — but that
   model already exists: it is node `m`. Today the two are specified and estimated
   independently, so a SEM would impute `m` from a model contradicting the one it just
   fitted for `m`.
   *Ask:* discussion, not a fixed API. (a) `impute_model()` accepts a fitted `drmTMB`
   object; (b) a documented recipe for building the predictor model from an existing
   fit's formula + family, caveating that estimates are not shared; (c) declare (a) out
   of scope and document (b). Even (c) is valuable — it makes the boundary explicit.

4. **Populate or fail loud on `imputed()` standard errors for non-Gaussian routes.**
   `std_error` is `NA` for every finite-state/quadrature route; only the Gaussian route
   populates it via `sdreport()`. drmSEM draws parametric uncertainty per node and
   already has machinery for this failure mode (`attr(x, "uncertainty_issues")`). Silent
   `NA` SEs are the shape of bug that yields confident-looking effect intervals with a
   missing uncertainty component.
   *Ask:* populate them, or emit a structured machine-readable warning. *Acceptance:* a
   downstream consumer can distinguish "no uncertainty available" from "uncertainty is
   zero" without string-matching a message.

5. **Ledger coverage for the missing-*predictor* subsystem.** ← pair with 2
   The ledger tracks 18 `missing_response` rows at G3 but has **no rows at all** for
   missing-predictor capability, despite 12 implemented predictor families and a
   user-facing extractor. That subsystem sits outside the G0–G5 discipline the rest of
   the package holds itself to — and item 2 is about to extend it.
   *Ask:* a `missing_predictor` axis, one row per gated (response × predictor) cell at
   its honest evidence tier.

6. **G4 interval evidence for missing-response masking.**
   All 18 masking rows sit at G3 (point recovery); none has reached G4 (finite CI at a
   known-DGP point) or G5, and the rows say so. drmSEM builds *interval* claims — effect
   CIs, Fisher's C — on each node's covariance, so every drmSEM interval computed on a
   masked node inherits that gap.
   *Ask:* raise gaussian, poisson, nbinom2, binomial to G4.
   *Until then:* drmSEM documents a masked node feeding an effect interval as a known
   limitation rather than discovering it silently.

7. **Distributional sub-models for `cumulative_logit`.** ← most drmSEM-shaped ask
   `cumulative_logit()` declares `dpars = c("mu")` (`R/family.R:329`) and the fitter
   rejects any non-`mu` formula (`R/drmTMB.R:6029`); cutpoints are free scalars, not the
   output of a linear predictor. drmSEM exists because a path may target a NON-mean
   component — so for ordinal nodes that capability is structurally unavailable: an
   ordinal node can be mediator or outcome, but nothing can ever have a path *into* its
   scale. The family docs already flag scale/discrimination formulas as "planned".
   *Ask:* expose a scale (discrimination) sub-model, i.e. a second `dpar`.
   *Acceptance:* `bf(y ~ x, disc ~ z)` fits with a known-DGP recovery test; drmSEM then
   labels the `disc` edge through existing component machinery with **no drmSEM change**.

8. **A fitted multinomial (baseline-category logit) response family.**
   `categorical()` exists only as a predictor-model family for imputation — no fitted TMB
   likelihood, no `model_type`, no `predict()`/`simulate()` path for an unordered
   categorical *response*. Unordered categorical outcomes (habitat choice, morph,
   behavioural state) are common in the audience. Acknowledged as substantial work, and
   drmSEM has no partial route to fake it. Lowest priority of this list.

9. **Estimable spatial range / Matérn; implement or remove `mesh=`.**
   `drm_spatial_coords_precision()` (`R/drmTMB.R:11956-11988`) builds
   `exp(-dist / median(dist))` — a fixed exponential kernel whose range is a heuristic,
   not an estimated parameter; no Matérn, no anisotropy. `spatial(mesh=)` is in the
   signature but aborts as unimplemented (`R/drmTMB.R:11641`). Consequence: `relmat(K=)`,
   which accepts any matrix, is **strictly more flexible for spatial work than
   `spatial()` itself**. (drmSEM will document `relmat(K=)` as the preferred spatial
   route.) Caveat: `relmat` is not wired for Student `mu` or zi-Poisson `zi`, where
   `spatial()` is the only route.

**Two corrections to earlier drmSEM assumptions, recorded so they are not re-derived:**
- `simulate.drmTMB` (`R/methods.R:2800`) covers **all 18 fitted families**, including
  `rtweedie_compound()` and an ordinal category draw. drmSEM's
  `drm_supported_sampler_families()` lists only ten and its comment wrongly claims
  tweedie has no sampler. **That is a drmSEM-side staleness, not an engine gap** — no ask.
- `categorical()` is **not** a fitted response family (see item 8). An earlier drmSEM
  audit note treating it as one was wrong.
