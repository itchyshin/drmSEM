# VALIDATION LEDGER — drmSEM

Status of each claim drmSEM makes. Update when a claim moves between states.

**Status legend**
- **validated** — checked end-to-end against a known data-generating process or
  closed-form result.
- **kernel-validated** — the underlying logic/arithmetic passes pure-logic tests
  that do not require the drmTMB engine; the engine-integration path is not yet
  exercised at runtime.
- **experimental** — implemented and reasoned about, but the operating
  characteristics (e.g. calibration) are not yet established.
- **pending** — code written, runtime evidence not yet collected.

Environment: the dev container has no R; all R/ source files are reviewed and
parse-checked by inspection, and the pure-logic kernel suite passes in CI (which
compiles drmTMB). drmTMB-integration tests cannot run in this lane (no
compiler/network); they run in CI and the Codex cloud env (`CLOUD.md`). Claims
past V-21 are recorded in the dated narrative sections below (the 2026-06-04
table is a snapshot, not the full list).

| # | Claim | Status (2026-06-04) | Evidence |
| --- | --- | --- | --- |
| V-1 | Fixed-effect predictor extraction drops RE bars and structured/smooth markers, keeps `mi(x)`, removes intercepts | validated (kernel) | `test-utils.R`: predictor-extraction test PASS |
| V-2 | Topological sort orders a DAG and detects cycles (cycles are an error) | validated (kernel) | `test-utils.R`: toposort test PASS |
| V-3 | Ancestors + simple-path enumeration correct | validated (kernel) | `test-utils.R`: ancestors/paths test PASS |
| V-4 | Coefficient names map back to predictor variables | validated (kernel) | `test-utils.R`: `drm_coef_variable` test PASS |
| V-5 | Inverse links (`identity`, `log`, `logit`, `tanh`) correct | validated (kernel) | `test-effect-kernels.R`: inverse-link test PASS |
| V-6 | Family samplers recover target moments, incl. zero-inflation lowering the mean | validated (kernel) | `test-effect-kernels.R`: sampler-moment test PASS |
| V-7 | **Distribution-mediated effect** appears only when a mediator's `sigma` depends on x and a downstream nonlinearity exists; ~0 when scale constant | validated (live fit: mechanism + decomposition) | `test-effect-kernels.R` contrast = 0.99 vs ~0 PASS (kernel); **V-41** (`test-recovery.R`, drmTMB-gated, CI-green) — on a real `drm_sem()` fit the distribution-mediated channel is non-zero, the additive identity `indirect = mean + distribution` closes, and it is reproducible; **V-37** pins the closed-form *magnitude* engine-free through the production `drm_decomp_legs()` path. Optional follow-up: a tight *live-fit* magnitude check vs the closed form computed from the fitted params. |
| V-8 | Fisher's C combines p-values with `2k` df: `C = -2*sum(log p)` | validated (kernel) | `test-dsep-kernels.R`: Fisher's C test PASS |
| V-9 | Basis set excludes adjacent pairs, respects causal order, applies the **any-component** adjacency rule | kernel-validated; drmTMB-integration pending | `test-dsep-kernels.R`: basis-set test PASS (incl. `habitat -> zi(abund)` adjacency) |
| V-10 | **d-separation** LRT-of-augmented-node flags a true omitted edge (`size -> survival`, `p < 0.05`) | kernel-validated; drmTMB-integration pending | `test-integration.R`: d-sep test WRITTEN, gated, not yet run |
| V-11 | `drm_sem` builds a valid DAG with component-labelled edges (`zi ~ habitat`, `sigma ~ temp`) and topo order `size, abundance, survival` | pending | `test-integration.R`: edge/topo test WRITTEN, gated, not yet run |
| V-12 | `paths()` returns a component-labelled coefficient table including `zi` | pending | `test-integration.R`: paths test WRITTEN, gated, not yet run |
| V-13 | Effect API runs and total decomposes into direct + indirect (incl. `distribution_mediated` row) | pending | `test-integration.R`: effect test WRITTEN, gated, not yet run |
| V-14 | Total ≈ direct + indirect within Monte-Carlo CI on the canonical SEM | pending | planned recovery check (`04-validation-plan.md`) |
| V-15 | Gaussian-mean analytic cross-check: simulated mean-mediated = product of path coefficients on identity-link chain | pending | planned recovery check |
| V-16 | d-sep passes a true non-edge (low false-positive rate) | pending | planned recovery check |
| V-17 | Fisher's C calibration (Type-I / power) under the any-component augmentation | validated for OQ-6 grid | `inst/calibration/generate.R` produced `inst/calibration/calibration-results.rds` on live `drmTMB` 0.1.3.9000 (`17b1321`); all five `cal$acceptance` checks pass; `vignettes/calibration.Rmd` renders from the cache |
| V-18 | `model.matrix()` contrast coding matches drmTMB's internal fixed-effect coding | pending | needs live drmTMB fit (OQ-2); isolated in `drm_fixed_design` |
| V-19 | Exact family-sampler parameterizations match drmTMB (nbinom2 `size`, beta_binomial trials, lognormal scale) | pending | needs live drmTMB fit (OQ-1) |
| V-20 | drmTMB adapter shapes (`bf()$entries`, `coef`/`fixef`/`vcov` `dpar:term`, `logLik`, `is_converged`, `predict_parameters`) | pending | written against drmTMB 0.1.3.9000 source; runtime confirmation pending |
| V-21 | `standardize()` scaling math: `sd_x` = `estimate * sd(predictor)` (factor SD=1, sign preserved); `latent` additionally divides by the SD of the target component's fitted linear predictor `eta = X %*% b`; link-scale labels (`identity` mu, `log` sigma) | validated (kernel) | `test-standardize.R`: 13 value-level assertions PASS on a fake `drm_sem` (no engine); single-predictor mean/sigma paths standardize to +1 |

## 2026-06-04 — Independent kernel re-verification

A second harness (`/tmp/harness.R`, base R only, no testthat) sourced
`R/simulate_effects.R` directly and reproduced V-5, V-6, and V-7 outside the
testthat suite, as a cross-check that the headline mechanism is not a test
artifact:

- Inverse links (V-5) and Gaussian/Poisson/zero-inflation sampler moments (V-6)
  reproduced.
- **Distribution-mediated mechanism (V-7) reproduced independently:** with
  mediator scale constant in x, distribution- and mean-mediated contrasts agree
  (0.71 vs 0.65, diff 0.058 ≈ 0); with `sigma(M)` rising in x, the
  distribution-mediated path adds **+0.99** over the mean path (1.64 vs 0.65).

Caveat (does **not** close OQ-1/V-19): the harness's `nbinom2` moment check used
the *assumed* `size = 1/sigma` parameterization, so it confirms internal
self-consistency only, not agreement with drmTMB's actual family parameterization.
That still needs a live drmTMB fit in the cloud env.

## 2026-06-04 — CI run 26981892600: integration tests ran against live drmTMB

PR #1, head `0720609`, R-CMD-check on ubuntu/macOS/windows: **all green**.
Dependencies were a **cache hit** (drmTMB precompiled), so the fast (~90s) jobs
are real, not skipped. Ubuntu test summary: **`[ FAIL 0 | WARN 3 | SKIP 0 | PASS
39 ]`** — `SKIP 0` confirms the drmTMB-gated `test-integration.R` actually fitted
nodes (`size`, `abundance`, `survival`) with a live drmTMB and passed.

Promotions (runtime-confirmed against drmTMB 0.1.3.9000):
- V-11 (drm_sem builds a component-labelled DAG, topo `size, abundance, survival`) → **validated**.
- V-12 (`paths()` component-labelled table incl. `zi`) → **validated**.
- V-13 (effect API runs; total decomposes incl. `distribution_mediated`) → **validated** (now also asserts finiteness).
- V-10 (d-sep flags the omitted `size -> survival` edge, p < 0.05; Fisher's C finite) → **validated**.
- V-20 (adapter shapes: `bf()$entries`, `coef`/`vcov` `dpar:term`, `logLik`, `predict_parameters`) → **validated**.
- V-18 / OQ-2 (`model.matrix` contrast coding vs drmTMB) → **substantially resolved**: factor predictor `habitat` round-tripped through edges/paths/effects without error. Keep open until a factor-heavy `sigma`/`zi` design is checked explicitly.

Still open: V-19 / OQ-1 (exact family-sampler parameterizations) — sampling is
drmSEM's own code, not exercised by drmTMB; needs the moment-recovery check.

New caveat (OQ-7): 3 warnings `NaNs produced` from `TMB::sdreport` when fitting
the canonical DGP nodes → NaN standard errors on at least one node. Hardened
`drm_draw_beta()` to fall back to the point estimate for any component whose
vcov block is non-finite, and strengthened the effect tests to assert finite
estimates so NaN effects can no longer pass silently.

## 2026-06-04 — Recovery suite added (test-recovery.R)

Added closed-form recovery tests (drmTMB-gated; run in CI):
- V-15: on an identity-link Gaussian chain x->m->y, the simulated mean-mediated
  effect equals the product of *fitted* path coefficients times the contrast
  width sd(x), deterministically (draw = FALSE). Status: validated pending the
  CI run on this commit.
- V-14: on x->m->y with a direct x->y edge, direct = b_xy*s, indirect =
  b_xm*b_my*s, total = (b_xy + b_xm*b_my)*s, and total = direct + indirect.
  Status: validated pending CI.
- V-16: d-separation specificity is checked as a rejection RATE over 8 seeds
  (a single null p-value is ~Uniform and fragile); expect <= 3/8 rejections.
  Status: validated pending CI. Partially addresses V-17 calibration.

## 2026-06-04 — OQ-1 resolved: family-sampler parameterizations

V-19 → validated pending CI on this commit. `test-oq1-samplers.R` fits
intercept-only models for gaussian, poisson, nbinom2, beta, lognormal, and Gamma
and asserts that `drm_sample_family()` at the fitted response-scale (mu, sigma)
recovers the data mean and variance. Fix: nbinom2/truncated_nbinom2 `size =
1/sigma^2`; beta `phi = 1/sigma^2` (were `1/sigma` and `sigma`). lognormal/Gamma
already correct. See DECISIONS D-7. Pre-push numeric check: nbinom2 var 21.5 vs
21.6; beta var 0.0296 vs 0.0301.

## 2026-06-04 — Green end-to-end: V-17 calibration, plotting, vignettes

CI run 26984153215 (head 21eff43), ubuntu/macOS/windows all success,
`[ FAIL 0 | WARN 3 | SKIP 0 | PASS 83 ]` (the 3 warnings are the tracked OQ-7
sdreport NaN on the small integration DGP, not failures).

- V-14 / V-15 / V-16 (recovery: total=direct+indirect, Gaussian analytic
  cross-check, d-sep specificity) → **validated**.
- V-17 (d-separation Type-I rate near nominal and power high) → **experimental**
  (NOT validated). The only evidence is a 20-rep smoke test in
  `test-calibration.R` at a single n=250 / single effect size / single Gaussian
  chain, asserting only Type-I < 0.25 and power > 0.70 — it would pass at a badly
  inflated Type-I (0.24 ≫ nominal 0.05) and cannot establish "near nominal". The
  any-component augmentation's calibration is OQ-6; `paper.md` and
  `03-dsep.md` correctly label the test experimental. Do NOT write "Type-I near
  nominal" until a real grid study (multiple n, effect sizes, families,
  multi-component augmentation) lands. (Corrected 2026-06-06 after inference
  review B-1; prior wording over-claimed.)
- V-19 / OQ-1 (family-sampler parameterizations for gaussian, poisson, nbinom2,
  beta, lognormal, Gamma) → **validated** against live drmTMB.
- New: `plot.drm_effect()` forest plot validated (`test-plotting.R` + live render
  in `vignettes/effect-decomposition.Rmd`); `vignettes/comparison.Rmd` builds.

Still open: OQ-7 (sdreport NaN root cause; mitigated, tracked in DRMTMB_ISSUES.md);
`plot.drm_sem` standardized-coefficient edge labels + ns dashing (D-8, roadmap).

## 2026-06-05 — Phylogenetic Phase 1 complete (PR #6)

CI run 27006262081 (ubuntu/macOS/windows green) validates, against live
drmTMB + ape: a phylo SEM builds and fits; `paths()` strips the phylo()
term to the fixed-effect DAG; `total_effects()` propagates; and -- after the
OQ-13 fix -- `dsep()` augment-refits a phylo node (the `tree` resolves via
the captured `fit_env`), so the claim returns status 'ok' with a finite
p-value and Fisher's C is finite. d-separation/Fisher's C now work
end-to-end for phylogenetic SEMs. Marker no-leak is kernel-verified
(test-utils.R). Phase 1 = DONE.

## 2026-06-05 — Parallel batch validated (PR #6, run 27007984275/...311 green)

All three OS R-CMD-check jobs + the pkgdown build are green on live drmTMB. Newly
validated end-to-end:
- **Phase 2 model comparison**: compare()/best()/average() fit a drm_model_set of
  candidate DAGs and rank by Fisher's C + CICc (test-model-set.R engine test).
- **zero_one_beta / student samplers** (test-oq1-samplers.R) — validated for the
  CONTINUOUS part only: `zero_one_beta`'s beta core (phi = 1/sigma^2; degrades to a
  plain beta when zoi/coi absent) and `student`'s mean. The zoi/coi inflation
  mapping and student's `nu`/variance are NOT asserted (TODO(live-drmTMB) in the
  test). `zero_one_beta` is in `drm_supported_sampler_families()`; `tweedie` is
  not (it has no realized-value sampler and falls back to mean).
- **Distributional phylogenetic SEM** (test-phylo-distributional.R): a phylo node
  with sigma ~ x yields a finite distribution-mediated effect under shared ancestry.
- **pkgdown site builds** with the new model-comparison reference + overview/paper.

Three bugs were fixed to get here (all CI-surfaced):
1. test-model-set.R: DAG factories defined after the test that used them; and
   expect_silent on cli-emitting print methods. (test-only)
2. drm_node(): auto-wrapping a stored plain formula used drmTMB::bf(formula), but
   bf() is NSE -> captured the symbol. Fixed with do.call(bf, list(formula)).
   (latent bug; first exercised by Phase 2.)
3. pkgdown workflow: pak dependency self-conflict from listing
   github::itchyshin/drmTMB alongside local::.+Remotes. Dropped the redundant entry.

## 2026-06-05 — Phase 3 evolutionary covariance (`drm_phylo_cov`)

`drm_phylo_cov(tree, model = c("BM","lambda","OU","kappa"), ...)` builds a
phylogenetic relatedness matrix to feed a node via `relmat(1 | species, K = K)`,
on a FIXED λ/OU/κ grid (joint estimation remains roadmap; see OQ — Phase 4).
Evidence tiers:
- **Pure-matrix transforms** (`phylo_transform_lambda`, `phylo_transform_ou`,
  `phylo_to_corr`) and input validation: **verified locally** (base-R Rscript,
  cli-shimmed source) and in `tests/testthat/test-phylo-cov.R` pure-logic tests —
  λ=1 identity, λ=0 star, off-diagonal scaling, OU monotone decay + α-limits
  (all-ones / identity), PSD, unit-diagonal standardisation, 2/sqrt(9) corr check.
- **ape path** (`ape::vcv`, κ branch-length transform, real-tree builder):
  **CI-gated** (`skip_if_not_installed("ape")`).
- **drmTMB integration** (`relmat()` node from `drm_phylo_cov()` → valid SEM with
  the marker stripped from `paths()`): **CI-gated** (`skip_if_not_installed` ape +
  drmTMB).
Closes the Phase 3 (short-term) roadmap item.

## 2026-06-05 — Closeout doc/man hygiene (audit-driven)

Systems audit (Rose) punch-list addressed: (1) committed `man/*.Rd` brought
current — hand-wrote the 5 Phase-2 topics (`drm_dag`, `drm_model_set`, `compare`,
`best`, `average`) + `drm_phylo_cov`; whole `man/` passes `tools::checkRd()` with
no broken links. (2) `drm_phylo_cov` exported in NAMESPACE + listed in
`_pkgdown.yml` reference. (3) `zero_one_beta` added to
`drm_supported_sampler_families()`. (4) Phase 2/3 reclassified shipped (not
roadmap) across vignettes/paper/overview/design-doc; OQ-13 marked resolved in
`DRMTMB_ISSUES.md` + `OPEN_QUESTIONS.md`; sampler claims downgraded to
continuous-part-only above. (5) `NEWS.md` updated (model comparison, phylo
covariance, effect plot; `standardize()` claim corrected to link-scale only).
OQ-9 (marginal RE effects) and OQ-11 (outcome functionals) defined.

**Release note:** `NAMESPACE` + `man/` are also regenerated by CI's
`roxygen2::roxygenise()` before R-CMD-check/pkgdown, so the source of truth is the
roxygen blocks in `R/`. The hand-written `.Rd` match that output (verified via
`checkRd`); re-run `roxygen2::roxygenise()` on a roxygen-equipped machine before
tagging a release to confirm byte-parity.

## 2026-06-06 — PR #4 effect engine reconciled into the phylo branch

PR #4 (`effects-counterfactual-theory`) was not docs-only: it carried a more
advanced effect engine than the phylo branch had. Reconciled fully (per the
release plan) — `R/effects.R` and `tests/testthat/test-effect-kernels.R` were
identical to main on the phylo branch, so #4's versions were taken wholesale;
`R/simulate_effects.R` was merged (#4's natural/functional helpers +
`drm_functional_target`/`drm_functional_contrast`/`drm_natural_target`/
`drm_outcome_functional`, with the phylo branch's `zero_one_beta`/`tweedie`
samplers re-injected). Newly available + kernel-validated locally
(`test-effect-kernels.R`, base-R harness, no engine):

- **V-22 / OQ-8 — Natural (cross-world) effects** via
  `indirect_effects(effect = "natural")`: on an identity-link chain x->m->y with a
  direct x->y edge, `natural_direct = c`, `natural_indirect = a*b`,
  `total = c + a*b`, and `natural_indirect = 0` with no x->m path. **PARTIAL** —
  validated only on the linear-Gaussian recovery; general cross-world
  identification under arbitrary links/interactions + CIs remain open (OQ-8).
- **V-23 / OQ-11 — Outcome functionals** via
  `total_effects(target = c("p_gt","p_zero","var"), threshold=)`: the `p_zero`
  effect recovers the Poisson zero-probability change `exp(-mu_hi) - exp(-mu_lo)`.
  **PARTIAL** — first functionals validated; more functionals / reporting-scale /
  CI construction remain open (OQ-11).

Regression check: `test-dsep-kernels` (incl. the new p==0 Fisher's-C floor),
`test-effect-kernels` (incl. the natural + functional kernels), and
`test-standardize` all pass under the base-R harness after the merge; all `R/`
parse clean. Engine-path validation (natural effects + functionals on a live
nonlinear drmTMB fit) is CI/roadmap (OQ-8/OQ-11). Migrated #4's design/memory
content too: D-10/D-11, OQ-8/OQ-10/OQ-12, the 02-effect-calculus essay, and the
05-roadmap phylo pointer.

- **V-24 / OQ-12 — Unified effect-API surface.** `drm_effect_controls()` and
  `drm_resolve_mediation()` (pure R, no drmTMB) map `uncertainty`/`nsim`/
  `population`/`method` onto the engine knobs: defaults (`draw=TRUE`, `n_sim=50`),
  `uncertainty` none/parametric → `draw` FALSE/TRUE, `nsim`→`n_sim` (integer),
  `method` gcomp/simulate → mediation mean/distribution. Deprecated
  `mediation`/`draw`/`n_sim` warn and are overridden by the new args.
  `uncertainty="bootstrap"`→OQ-10 abort; `population="marginal"`→OQ-9 abort.
  **DONE (pure-R, unit-tested in `test-effect-api.R`).** Engine-path parity
  (new surface == deprecated aliases, identical estimates under a fixed seed) and
  `direct_effects(target="p_zero")` finiteness are CI-gated in the same file.

- **V-25 / OQ-14 — Covariance-edge grammar + d-sep awareness (pure R).**
  `covary()` builds residual/higher-level declarations and rejects malformed ones;
  `drm_build_covariances()` resolves responses to nodes, labels edges
  (`rho12(a, b)` / `corpair(id: a, b)`), de-duplicates unordered pairs, and errors
  on unknown / self-referential responses; `covariances()` returns a classed table
  separating residual vs higher-level; `basis_set()` drops the `y1 _||_ y2` claim
  for a declared residual OR higher-level edge and is unchanged when none is
  declared (missing `$covariances` slot ⇒ no-op). **DONE (pure-R, unit-tested in
  `test-covariances.R`).** Engine-dependent OQ-14 remainder (`drm_pair()` joint
  fit, `rho12()`/`corpairs()` read-back, arc plotting, deep level-compat) is
  Codex-lane / roadmap.

## 2026-06-06 — V-26..V-30: analytic effect cross-checks asserted (0.2)

The 0.2 "analytic effect cross-checks" item: promoted the effect-engine identities
from planned/kernel-only to ASSERTED pure-R tests in `test-analytic-effects.R`
(no drmTMB; hand-built engine harness as in `test-effect-kernels.R`). Derivations
checked by the math-consistency pass (Noether).

- **V-26 — Gaussian mean-mediated = a*b*w.** Bare product (a*b*w), the
  controlled-direct / mean-mediated split closing on a chain with a direct edge,
  and two parallel mediators summing to a1*b1 + a2*b2. Deterministic mean channel,
  tolerance 1e-8. **validated (kernel).**
- **V-27 — a non-mean (sigma) path is invisible to the mean channel.** (a) the
  mean channel is *bit-identical* with and without a sigma~x path (exact, the
  falsifiable core); (b) the distribution-mediated effect -> 0 when the outcome is
  linear in the mediator (MC, tol 0.02, seeded). **validated (kernel).**
- **V-28 — distribution-mediated effect across a downstream nonlinearity** matches
  the lognormal closed form `exp(k*mu + 0.5 k^2 sigma^2)` and flips sign with the
  sigma slope (MC, tol 0.06, seeded). **validated (kernel).**
- **V-29 — natural vs controlled under an x:M interaction.** NDE/NIE/mediated-
  interaction recover their closed forms (`w*(c+d*a*x0)`, `a*w*(b+d*x0)`,
  `d*a*w^2`) and the controlled direct effect differs from the natural direct,
  tolerance 1e-8. **validated (kernel).**
- **V-30 — outcome functionals.** Poisson `Pr(Y>0)` effect = `exp(-mu_lo) -
  exp(-mu_hi)`; a pure-sigma path moves `Var(Y)` on the closed form
  `exp(2 eta_hi) - exp(2 eta_lo)` with zero mean effect, and constant sigma gives a
  zero Var contrast (MC, tol 0.03/0.15, seeded). **validated (kernel).**
- Plus a standalone `drm_nominal_link` table assertion (pure-R link labels).

These discharge the 0.2 analytic-cross-check item. The remaining 0.2 items
(flipping V-7/V-10/d-sep to "validated" on live-fit analytic identities) need
the live-drmTMB lane.

## 2026-06-06 — V-17 OQ-6 calibration cache generated in live drmTMB lane

Codex ran `Rscript inst/calibration/generate.R` on branch
`codex/live-drmtmb-closeout` after installing the current checkout and updating
`drmTMB` from GitHub. Provenance: `drmTMB` 0.1.3.9000 at Git SHA `17b1321`,
`drmSEM` 0.2.0.9000, R 4.5.2, drmSEM git SHA `c951d31`; final runtime
14.5 minutes. The script wrote
`inst/calibration/calibration-results.rds` and `vignettes/calibration.Rmd`
rendered from the source-tree cache.

The full OQ-6 grid completed: 3 DGP families (`mean_only`, `distributional`,
`cross_link`) x 4 sample sizes (`100,250,500,1000`) x 6 omitted-edge strengths
(`0,0.1,0.2,0.3,0.5,0.8`) x 200 reps = 14,400 replicates. All five acceptance
criteria passed:
- C1 usable claim rate: every family x n x beta cell had >= 95% ok finite
  p-values; no failing cells.
- C2 Type-I by family/n: every beta=0 cell was inside the 99% binomial
  Monte-Carlo band around alpha=0.05 (observed range 0.025-0.080; band
  0.015-0.095).
- C3 Type-I by augmented-component count: `cross_link`, claim_df=1, Type-I
  0.0525; `mean_only`, claim_df=1, Type-I 0.05625; `distributional`,
  claim_df=2, Type-I 0.045; all inside the 99% band.
- C4 Fisher's C null uniformity: n=2400 null p-values, KS p=0.631, median
  p=0.499.
- C5 power: beta=0.8 power was 1.0 in every family x n cell; beta=0.5 power was
  1.0 for n>=250; monotonicity check passed.

V-17 is therefore **validated for this OQ-6 calibration grid**. Keep the claim
scoped to these DGP families and sample sizes; new families or more complex
component structures need their own calibration evidence.

## 2026-06-06 — V-31: composite constructs (0.3, pure R)

- **V-31 — `drm_composite()` + materialization + `loadings()`.** `drm_composite()`
  builds `fixed` (weighted-sum) and `pca` (sign-fixed PC1, prop_var) specs and
  rejects malformed declarations; `drm_score_composite()` recomputes the column
  (raw %*% weights for fixed; scaled %*% loadings for pca); `drm_build_composites()`
  normalizes/dedups; `drm_apply_composites()` materializes columns and guards
  name collisions; `loadings()` reports indicator loadings (empty when none).
  **validated (kernel)** — `test-composite.R`, no drmTMB. The engine path
  (`drm_sem(composites=)` fitting a node on a materialized construct) is CI-gated.

## 2026-06-06 — V-32: per-mediator path-specific attribution (OQ-5, pure R)

- **V-32 — `path_effects()` per-mediator decomposition.** Kernel
  `drm_path_contrasts()` computes inclusion/exclusion/total/remainder by active-set
  toggling. Closed-form deterministic checks (`test-path-effects.R`, mean
  mediation, draw=FALSE): P-1 parallel-additive (inclusion = a*b, inclusion =
  exclusion, remainder = 0); P-2 downstream nonlinearity (remainder =
  (e^{ka1}-1)(e^{ka2}-1) > 0, inclusion != exclusion); P-3 sequential M1->M2->Y
  (inclusion = 0 each, exclusion = total each, remainder = total); single-mediator
  degenerate case. **validated (kernel)** — no drmTMB. Later V-34 and V-35 cover
  the per-component and natural follow-ups; a live-fit integration test is the
  missing evidence before broad OQ-5 promotion.

## 2026-06-06 — V-33: per-mediator mean/distributional channel split (OQ-5)

- **V-33 — `path_effects(by = "component")`.** Splits each mediator's indirect
  effect into a mean channel (`T_mean({Mj}) - direct`, deterministic) and a
  distributional channel (`T_dist({Mj}) - T_mean({Mj})`); the two partition the
  inclusion effect exactly (no remainder). Kernel-verified in `test-path-effects.R`
  (by-component): mean channel exact (1e-8); distributional channel matches the
  lognormal closed form (MC, tol 0.06, seeded); flat-scale negative control ~0.
  **validated (kernel).** The finer sigma-vs-zi split is covered by V-34 and the
  natural variant by V-35; a live-fit integration test remains open (OQ-5).

## 2026-06-06 — V-34: per-component (sigma/zi) path attribution via freeze (OQ-5)

- **V-34 — `path_effects(by = "component")` per-component split.** `drm_freeze_engine()`
  wraps a mediator's predict to hold one component at its x0 value;
  `drm_component_contrasts()` attributes the distribution-mediated effect to each
  non-mean component (`PCE(c) = T_dist(full) - T_dist(c frozen)`), with a
  `component_remainder` for the non-separable part. Kernel-verified in
  `test-path-effects.R` (seeded, common random numbers): mean channel exact (1e-8);
  sigma channel = `exp(ka+0.5k^2 s1^2) - exp(ka+0.5k^2 s0^2)` (MC, tol 0.06);
  component_remainder = `(e^{ka}-1)(e^{0.5k^2 s0^2}-1)`; flat-scale sigma channel = 0
  exactly. **validated (kernel)** — no drmTMB. Real-family sampler accuracy and a
  live-fit integration test remain OQ-5 (Codex).

## 2026-06-06 — V-35: natural per-mediator path attribution guard (OQ-5)

- **V-35 — `path_effects(effect = "natural")` identification flag.** The
  per-mediator natural variant reuses `drm_natural_target()` and reports an
  `identified` column. `drm_recanting_witness()` is kernel-verified in
  `test-path-effects.R`: parallel mediators are identified, while a sequential
  mediator route with another mediator that is both a descendant of the exposure
  and an ancestor of the target mediator is flagged `identified = FALSE`.
  **validated (kernel)** — pure graph logic, no drmTMB. Live-fit integration and
  unconfirmed-sampler `NA` handling remain OQ-5.

## 2026-06-06 — V-36..V-42: effect-decomposition pairing + feedback equilibrium

- **V-36 — decomposition additive identity (production path).** `drm_decomp_legs()`
  (the shipped helper `indirect_effects()` calls) is exercised directly:
  `indirect = mean_mediated + distribution_mediated` holds exactly on the shared
  per-replicate legs. `test-analytic-effects.R`. **validated (kernel)** — no drmTMB.
- **V-37 — distribution-mediated lognormal Jensen gap + sign flip.** Through
  `drm_decomp_legs()`, `distribution_mediated` matches the closed form
  `exp(k a x + ½k²σ(x)²) − exp(k a x)` differenced across the contrast, and flips
  sign when `sigma(M)` decreases with `x`. `test-analytic-effects.R`.
  **validated (kernel).**
- **V-38 — distribution-mediated linear-outcome zero (production path).**
  `distribution_mediated ≈ 0` when the outcome is linear in `M` even though
  `sigma(M)` depends on `x` (no Jensen gap). `test-analytic-effects.R`.
  **validated (kernel).**
- **V-39 — multi-mediator chain mean propagation.** Through `drm_decomp_legs()`,
  `mean_mediated` recovers `a·c·b` for `x → M1 → M2 → Y` and the distribution
  channel is ~0 (linear Gaussian). `test-analytic-effects.R`. **validated (kernel).**
- **V-40 — decomposition reproducibility / seed plumbing.** Same seed yields
  identical legs (the shared-draw pairing is deterministic given the seed).
  `test-analytic-effects.R`. **validated (kernel).**
- **V-41 — `indirect_effects()` distribution-mediated, live fit.** End-to-end on a
  real `drm_sem()` fit (mediator with `x → sigma(M)` feeding a lognormal outcome):
  `distribution_mediated > 0`, the additive identity closes, and the result is
  reproducible under a fixed seed. `test-recovery.R` (drmTMB-gated).
  **validated (integration).**
- **V-42 — feedback fixed-point equilibrium recovery.** `propagate_fixedpoint()`
  recovers the linear reduced form `(I − B)⁻¹ Γ` for a 2-cycle, and flags
  non-convergence when `ρ(B) ≥ 1`. `test-feedback.R`. **validated (kernel)** —
  pure-R, no drmTMB.

(Note: V-31..V-35 above are the OQ-5 / composite claims; the decomposition tests
were renumbered from a draft V-31..V-36 to V-36..V-41 to avoid that collision,
and the feedback recovery is V-42.)

## 2026-06-06 — V-43: equilibrium total effect for a feedback SEM (0.5.x)

- **V-43 — `drm_equilibrium_contrast()` / `total_effects()` equilibrium.** For a
  declared feedback motif, `total_effects()` routes through the fixed-point
  propagator and reports the system's equilibrium response. The kernel test
  confirms the equilibrium contrast of an exogenous `x` equals the reduced-form
  total-effect column `((I − B)^{-1} Γ)[, x]` for a linear 2-cycle, and that a
  diverging system (`ρ(B) ≥ 1`) is flagged non-convergent (effect `NA`, never a
  number). `test-feedback.R` (kernel) + the drmTMB-gated end-to-end check that
  `total_effects()` returns `mediation = "equilibrium"` with a finite estimate on
  a stable reciprocal fit. **validated (kernel + integration).**

## 2026-06-07 — V-44: GLM mean-path latent standardization sigma_E (OQ-4)

- **V-44 — `latent` divisor adds the theoretical link variance for mu paths.**
  `drm_link_latent_var()` returns the constant latent-scale error variance
  (logit π²/3, probit 1, cloglog π²/6; 0 for identity/log), and
  `drm_latent_divisor()` makes the `latent` divisor of a non-identity-link **mu**
  path `sqrt(Var(eta) + σ_E²)`. Closed-form test (`test-standardize.R`, fakefit,
  no engine): a logit mean path standardizes by `sqrt(Var(eta) + π²/3)`, strictly
  below the old `sd(eta)`-only value; identity-link mu and non-mu components are
  unchanged. **validated (kernel).** Remaining (deferred): the mean-dependent
  observation-level latent variance for log-link families, and an optional
  live-GLM-fit confirmation of the full pipeline (Codex).

## 2026-06-07 — V-45..V-73: simulation-based recovery-grid campaign (wave 1)

Live-fit numerical-recovery grid (drmTMB-gated, runs in CI) + one kernel test.
Validated on a real fit unless noted; assertions prefer fitted-coefficient /
`drmTMB::simulate()` ground truth over hand-derived closed forms. See
`docs/design/11-validation-matrix.md`.

**Effect decomposition across the family×link grid — `test-recovery-families.R`:**
- V-45 gaussian (identity): mean-mediated == product of fitted `paths()` coefs ×
  contrast width; CDE ~ 0; distribution_mediated ~ 0; both identities close.
- V-46 poisson / V-47 nbinom2 (log): decomposition closes, sign correct,
  mean-mediated matches a do-contrast recomputed from the same fit via
  `predict_parameters()` (parameterization-free).
- V-51 Gamma / V-52 lognormal (log): decomposition closes, sign correct,
  mean-mediated finite and strictly positive. (The `predict_parameters()`
  do-contrast magnitude match is **not** asserted for these two log-link families
  — the recompute proved fragile; closure + sign are the robust recovery signal.)
- V-48 beta / V-49 beta_binomial / V-50 beta (logit): closure + sign. (V-48 is a
  `drmTMB::beta()` (0,1) proportion node — `drmTMB` has no plain `binomial()`
  family; the logit-link mean-recovery leg uses `beta()`; V-49 is the
  `beta_binomial()` cbind() count node.)
- V-53 `x→sigma(M)`→lognormal outcome (the V-7 follow-up on a live fit):
  distribution_mediated > 0, closure holds, and the fitted-parameter Jensen gap is
  positive. (The tight **magnitude** match proved parameterization-fragile and is
  not asserted; sign + closure + a positive fitted gap are the robust signal.)
  V-54 same on a Gamma outcome (sign + closure).

**Sampler moments vs `drmTMB::simulate()` + outcome functionals — `test-recovery-samplers.R`:**
- V-55..V-61: `drm_sample_family()` mean+variance match `drmTMB::simulate()` at the
  fit's params for gaussian / poisson / nbinom2 (`size=1/sigma^2`) / beta
  (`phi=1/sigma^2`) / Gamma / lognormal / binomial.
- V-62 p_zero (Poisson) recovers `exp(-mu_hi) - exp(-mu_lo)`; V-63 `var` matches a
  large-n empirical from the fit; V-64 p_gt matches the exact Poisson tail.

**Structural recovery on live fits — `test-recovery-structural.R`:**
- V-65 latent standardization on a live **logit-link** GLM (a `drmTMB::beta()`
  node on a (0,1) response; `drmTMB` has no plain `binomial()`) ==
  `b·sd(x)/sqrt(Var(eta)+π²/3)` from fitted coefs (OQ-4 `sigma_E` pipeline
  end-to-end); V-66 Gaussian identity == `sd_x/sd(eta)` (no `sigma_E`).
- V-67 composite used as BOTH predictor and response fits; `loadings()` + effect
  flow. V-68 Cronbach alpha on a live composite == `drm_cronbach_alpha()` closed
  form.
- V-69 feedback `total_effects` (equilibrium) == fitted `((I−B)⁻¹Γ)` entry; V-70 a
  divergent declared system (`ρ(B)≥1`) reports NA, not a number.
- V-71 natural NDE+NIE+mediated_interaction sum to total_path (nonlinear,
  single mediator; `mi≈0`); V-72 adding `x:M` moves mediated_interaction off zero.

**Kernel — `test-feedback.R`:** V-73 `propagate_fixedpoint()` solves a NONLINEAR
2-cycle fixed point (saturating coupling), validated by self-consistency +
an independent Gauss-Seidel solve (no closed form).

**Still flagged for the live lane (NOT asserted here):** tweedie realized-value
sampler (mean-fallback only), zero_one_beta zoi/coi inflation, and student `nu`
remain unconfirmed against `drmTMB::simulate()` (as in `test-oq1-samplers.R`); the
V-53 lognormal-mu / mediator-sigma response-scale parameterization is buffered by
a generous tolerance and worth a live sanity check.
