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
| V-19 | Exact family-sampler parameterizations match drmTMB for common families (nbinom2 `size`, beta precision, Gamma shape, lognormal meanlog/sdlog) | validated for V-57..V-60; family extensions remain | `test-recovery-samplers.R` now asserts V-57..V-60 against `drmTMB::simulate()`; closeout found nbinom2/beta/Gamma keep `1/sigma^2`, default fitted dpars must be carried into prediction engines, and lognormal uses `mu = meanlog`, `sigma = sdlog` |
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
- **V-74 / OQ-11 — Quantile functional** (`test-effect-kernels.R`): for a gaussian
  `Y` with `mu = 10 + 2x`, `sigma = 1 + 3x`, `drm_functional_contrast(target =
  "quantile")` recovers the closed-form `prob`-quantile contrast `2 + qnorm(p)*3`
  — the median (`p=0.5`) moves by the mean slope only, the upper tail (`p=0.9`)
  also by the sigma slope. Validates the new `quantile`/`prob` path. **Kernel.**
- **V-75 / OQ-11 — Functional decomposition non-degeneracy** (`test-effect-kernels.R`):
  for `X→M→Y` (no direct path; `M` gaussian, `Y` Poisson `mu=exp(M)`),
  `drm_decomp_legs(target = "p_zero")` gives `cde ≈ 0`, a non-zero
  `tot_dist − tot_mean` (the Jensen gap), and an exact close
  `indirect = mean_mediated + distribution_mediated`. Guards the fix that the
  legs honour `mediation` (mean vs distribution) for a non-mean target instead of
  always simulating the mediator. **Kernel.**
- **V-76 / OQ-11 — Analytic outcome functionals** (`test-effect-kernels.R`):
  `drm_analytic_functional()` returns the closed-form `var`/`p_gt`/`p_zero`/
  `quantile` for gaussian (`sigma^2`, `pnorm`, `0`, `qnorm`) and poisson (`mu`,
  `ppois`, `dpois(0)`, `qpois`), and `NULL` for the dispersion families (OQ-1).
  `drm_functional_contrast_analytic()` recovers the Poisson `p_zero` contrast
  `exp(-mu_hi) - exp(-mu_lo)` to machine precision (the simulated kernel hits it
  only to ~0.03), confirming the no-Monte-Carlo-noise property. **Kernel.**

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
- V-46 poisson / V-47 nbinom2 / V-51 Gamma / V-52 lognormal (identity meanlog):
  decomposition
  closes, sign correct, mean-mediated finite and strictly positive. (A
  `predict_parameters()` do-contrast *magnitude* match was attempted but the
  recompute proved fragile across the log-link families, so for all four it is
  **not** asserted — closure + sign + finite-positive mean-mediated are the
  robust, parameterization-free recovery signal.)
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
- V-55 gaussian / V-56 poisson: `drm_sample_family()` mean **and** variance match
  `drmTMB::simulate()` — **validated**.
- V-57 nbinom2 / V-58 beta / V-59 Gamma / V-60 lognormal: **validated** against
  `drmTMB::simulate()` after the 2026-06-07 closeout. nbinom2, beta, and Gamma
  keep the D-7 `1/sigma^2` mapping; the earlier variance failures came from the
  prediction engine omitting fitted default dpars such as `sigma` when no explicit
  `sigma ~ ...` formula was declared. lognormal now uses drmTMB's current
  parameterization (`mu = meanlog`, identity link; `sigma = sdlog`) and propagates
  `exp(mu + sigma^2 / 2)` under mean mediation. The tests are real assertions, not
  skip-on-mismatch records.
- V-61 binomial: skipped (`drmTMB` has no plain `binomial()` family).
- V-62 p_zero (Poisson) recovers `exp(-mu_hi) - exp(-mu_lo)`; V-63 `var` matches a
  large-n empirical from the fit; V-64 p_gt matches the exact Poisson tail —
  **validated** (these route through Poisson, whose sampler matches).

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

## 2026-06-08 — C-3 model-selection recovery: CBIC validated, CICc scoped

`inst/validation/validation-results.rds` now carries a regenerated C-3
model-selection block from the current source checkout, with C-1 coverage
retained from the previous cache because the full coverage rerun exceeded the
live-lane wall-time budget. The C-3 grid used `R = 300`, `n = 300, 1000`, and the
same seed scheme as `inst/validation/generate.R`.

- **CBIC (`C + k log(n)`) passed the C-3 recovery gate:** truth selection was
  `0.9267` at `n = 300` and `0.9733` at `n = 1000`; mean truth weight was
  `0.8169` and `0.8830`; the missing-edge rival was never selected.
- **CICc is now scoped as support / AIC-like ranking, not a consistent true-DAG
  selector:** truth selection stayed at `0.6100` and `0.5733`, with zero
  missing-edge selections. This matches the design decision that over-fitted but
  harmless rivals can retain CICc support.

Status: C-3 true-DAG recovery is **validated for CBIC** on this grid; CBIC is now
the default comparison criterion. CICc remains available explicitly and is
**not** the recovery claim.

## 2026-06-11 — Maturity hardening: interval honesty, path-effects live fit, CRAN hygiene

Blocked-maturity review closed three local gaps and reduced one release-hygiene
gap.

- **Effect-interval honesty:** the canonical integration DGP was bisected node by
  node. `size` (Gaussian `mu + sigma`) and `abundance` (`nbinom2` with `zi`)
  converged and returned finite fixed-effect covariance matrices; `survival`
  (`beta_binomial`) emitted `TMB::sdreport()` `NaNs produced`, did not converge,
  and `vcov()` reported no positive-definite Hessian. **Platform-dependent, as of
  2026-08-14:** that covariance failure reproduces on macOS and Linux but NOT on
  Windows, where the same node is still flagged `not_converged` yet returns a
  usable covariance. Non-convergence is the portable finding; the covariance
  failure is an optimizer outcome and must not be asserted cross-platform (it
  turned CI red twice before this was understood). Effect calls now warn and
  attach `attr(x, "uncertainty_issues")` with node/component/issue rows
  (`not_converged`, `vcov_unavailable`, `vcov_nonfinite`, etc.) instead of
  silently treating those components as point estimates. Non-finite effect draws
  are counted in `attr(x, "value_issues")`, summaries return `NA` when all draws
  are unusable, and log-link inverse links are clamped below floating-point
  overflow. Evidence: `test-effect-kernels.R` and `test-integration.R` assert the
  diagnostics and finite-effect behavior.
- **Wave-2 validation status:** `inst/validation/validation-results.rds` was
  re-read, not regenerated. C-1 effect-interval coverage passed for direct,
  indirect, and total effects at `n = 300` and `n = 1000` (coverage range
  `0.9433` to `0.9633`, all inside the stored nominal +/- 2 SE bands). C-3 CBIC
  remains validated on the cached grid (`0.9267` and `0.9733` truth selection;
  missing-edge rate `0`); CICc remains explicitly scoped as support, not the
  true-DAG recovery claim. Cache provenance remains mixed: C-1 retained from the
  previous cache, C-3 regenerated from source version `0.5.0`.
- **OQ-5 live wrapper evidence:** `path_effects()` now has a live `drmTMB`
  integration test for both `by = "mediator"` and `by = "component"` on a fitted
  Gaussian mediator with `sigma ~ x` feeding a log-link Poisson outcome. This
  closes the live-fit wrapper evidence gap for the supported sampler families;
  unconfirmed-sampler `NA` policy remains separate.
- **CRAN hygiene:** `Authors@R` now includes the copyright-holder role (`cph`) and
  package-site URLs use the non-redirecting trailing slash. Remaining CRAN
  blocker is external/dependency policy: `DESCRIPTION` still needs `Remotes:` for
  GitHub-only `drmTMB` and `symbolizer`, so CRAN submission waits until those
  dependencies are CRAN-acceptable or the dependency strategy changes.

## 2026-08-14 — Missing data: row alignment (S5) and graph-derived imputation (S6)

Two claims, in dependency order. Design record: `docs/design/13-missing-data.md`.
Suite went 745 -> 793 passing, 0 failing, 3 skips throughout.

### S5 — row alignment (correctness fix, no V-number: it is a defect closure)

drmSEM had no missing-data policy anywhere in `R/`. Nodes could be fitted on
different samples silently, and `drm_fixed_design()` built its design with
`model.matrix()` under `na.action = na.omit`, returning fewer rows than requested.

**The dangerous half was not the error.** When `nrow(newdata)` was an exact
multiple of the complete-case count (300 against 150), R recycled **silently**
into a scrambled design matrix — a wrong number with no condition raised. A test
asserting only "does not error" would have passed against that bug, so
`test-missing-data.R` asserts the recycling case explicitly: 300 rows in, 300
rows out, 150 NA.

Status: **validated** for the tested cases — 9 tests / 25 assertions covering all
three `na_action` values, the unmodelled-column case (columns no node models must
not cost rows), `check_sem()`'s `nobs` column, the effect engine completing where
it previously raised a raw subscript error, and the d-separation `"n_mismatch"`
guard firing on a claim whose augmented refit changed the sample size.

### S6 — imputation models derived from the graph

- **V-77 (load-bearing).** The auto-derived fit is **numerically identical** to
  the hand-written `impute = list(m = impute_model(m ~ x))` fit, to all printed
  digits (`-0.00026406 / 0.6432292 / 0.2455947` both ways). Following the house
  rule, this compares a public output against quantities recomputed from the same
  fit rather than against a hand formula, so a wrong derivation cannot hide
  behind good-looking recovery. **Validated.**
- **V-78.** Bias reduction under **outcome-dependent** missingness, replicated
  across four seeds (n = 600, ~313 complete rows). Single-seed illustration:

  | | intercept | `m` (truth 0.60) | `x` (truth 0.30) |
  |---|---|---|---|
  | complete-case | −0.194 | 0.513 | 0.274 |
  | graph-derived | 0.000 | 0.643 | 0.246 |

  **Scope of the claim, stated narrowly:** "recovers the intercept and reduces
  mediator-coefficient bias under outcome-dependent missingness" — *not* "beats
  complete-case". It is slightly **worse** on `x`, which is reported rather than
  buried. Also note an MCAR fixture would show nothing at all (complete-case is
  already unbiased there); the first pre-run test used MCAR and returned
  0.656/0.263 against complete-case 0.656/0.263, i.e. plumbing evidence only.
  **Validated for the MAR-on-outcome Gaussian chain**, not generalized.
- **V-79.** Two incomplete parents abort with the engine's one-`mi()`-per-fit
  limit named. **Validated.**
- **V-80.** drmSEM's response allow-list is locked to
  `drmTMB:::drm_missing_predictor_families()` by an anti-drift test, mirroring
  drmTMB's own `test-missing-data-capability-gate.R`, so loosening one without
  the other fails here rather than deep inside the engine. **Validated.**
- **V-81.** `mi()` coefficient names resolve to the correct node. Pre-fix,
  `"mi(mass)"` starts with `"m"`, so a SEM with a node named `m` resolved the
  `mass` path onto it. **Validated** (unit-level).

**Not claimed.** Generality beyond a Gaussian chain: blocked by drmTMB Issues 1
and 2. Cross-node uncertainty propagation: does not exist by construction — the
downstream node re-estimates the parent's model rather than sharing its
estimates, so this is a principled imputation, never FIML across the SEM.

## 2026-08-14 — S1b: un-staling the realized-value sampler list

The stale vector at `R/diagnostics.R` claimed ten families and asserted "tweedie
… has no realized-value sampler". Both halves were wrong, and the second was
wrong about the ENGINE rather than about drmSEM: `simulate.drmTMB` draws
`rtweedie_compound(n, mu, phi = sigma^2, power = nu)`, so the `sigma`-to-phi
mapping the comment named as the blocker was answered in the engine's own source.

**The important structural point:** that vector is ADVISORY — its only consumer
is `check_sem()`'s `sampler` column. The load-bearing list is the `switch()` in
`drm_sample_family()`. Widening the vector alone would have made `check_sem()`
report `TRUE` for a family that still mean-falls-back, i.e. converted a visible
limitation into an invisible wrong number.

- **V-82 tweedie.** Mean and variance match `drmTMB::simulate()`. **Validated.**
- **V-83 skew_normal.** Same. **Validated.**
- **V-84 binomial / V-85 beta_binomial.** Same, and these were a **units bug**
  rather than a missing feature: `mu` is a probability while the response is a
  count, so the previous mean fallback returned a value on (0,1) to a downstream
  node fitted on counts. `drm_family_expected_mean()` had the identical defect,
  so `mediation = "mean"` was affected too. Both now use the fitted `trials`.
  **Validated**, conditional on `trials` being recoverable; V-84b asserts that
  without it drmSEM warns rather than returning a probability.
- **V-86 anti-drift lock.** Every family named in
  `drm_supported_sampler_families()` is asserted to actually draw, and an
  unnamed family to warn. This is what stops the vector going stale again.
  **Validated** (15 assertions).

**Not restated, deliberately.** The new branches call drmTMB's own generators
(`rtweedie_compound`, `rskew_normal_public`, `drm_beta_shapes`) rather than
reimplementing them, so a parameterization cannot drift between the packages.
The tests confirm the wiring, which is the part that can break.

**Still mean-fallback, declared not hidden:** `cumulative_logit` (needs an
engine-level decision about a non-numeric mediator value), the bivariate
families, `zero_one_beta` zoi/coi inflation, and student `nu`. Also unaddressed:
`hu` is documented in `drm_sample_family()`'s roxygen but never read, so a
`hurdle_nbinom2` mediator's hurdle zeros are absent while `nbinom2` reports as
fully supported — drmTMB folds zi/hurdle into `model_type` while drmSEM keys on
the family NAME, so the list cannot express the distinction at all.

Suite: 818 pass / 0 fail / 3 skip / 10 warn (was 793 / 0 / 3 / 10).

## 2026-08-15 — A2: ordinal evidence, spatial relabel, and two pinned limitations

drmSEM imposes **no family whitelist** (verified across `R/drm_node.R`, `R/drm_sem.R`,
`R/edges.R`, `R/extractors.R`), and `cumulative_logit` has had its link label at
`R/edges.R:42` all along. So an ordinal node has worked end-to-end for some time —
and nothing tested it. Untested capability is worse than absent capability, because
the surface advertises it while nothing holds it up.

**A prior claim was half wrong and is corrected here.** The roadmap note said ordinal
*and* spatial "carry no retained evidence". Spatial did:
`tests/testthat/test-phylo-cov.R:199-243` already live-fits `relmat(1 | species, K = K)`
and asserts marker stripping. The real defect was **findability** — that evidence sits
under a phylogenetic label, so anyone asking "does drmSEM do spatial?" greps for
`spatial`, finds only drmTMB's weaker marker, and concludes no.

### Ordinal — `tests/testthat/test-ordinal.R` (8 tests / 28 assertions, 0 skips)

Fixture: `x -> m -> y`, gaussian mediator into a 4-category `cumulative_logit`
outcome, n = 800, **seed fixed at 101**. Fit takes ~0.7 s.

- **V-87.** `paths()` labels the edge `component = mu`, `link = logit`, and the
  cutpoints never appear as an edge source or coefficient term. **Validated.**
- **V-88.** Latent-scale recovery: `x→m` **0.5009** against true 0.500; `m→y`
  **0.9330** against true 0.900. **Validated.**
  *Note:* the earlier audit's 0.518 / 0.875 figures are **not** reproducible without
  their seed (an independent run gave 0.4877) and are superseded by these.
- **V-89.** `dsep()` tests the single claim `x ⫫ y | {m}` with `status = "ok"`
  (LR 2.4e-06, p = 0.999) and Fisher's C is finite — the true DAG is not rejected,
  and the claim is genuinely tested rather than skipped for want of a sampler.
  **Validated.**
- **V-89b.** Effects decompose through an ordinal outcome and `total_path = direct +
  indirect` closes to 1e-8, recomputed from the same object. **Validated.**

### Two pinned LIMITATIONS — deliberately not fixed

Both are silent-wrong-answer shaped, which is this lane's whole subject. They are
pinned so the suite makes them loud, rather than a user discovering them.

- **V-90 — `mu` is the LATENT linear predictor, not `E[category]`.** Measured range
  **(−3.218, 3.160)** against categories 1–4. An effect reported with
  `target = "mean"` on an ordinal node is therefore a latent-scale effect, and
  **nothing warns**. Recovery in V-88 is stated on the latent scale for this reason.
- **V-91 — a non-mean target degenerates to exactly zero.** `target = "p_gt"` returns
  `estimate == 0` for **every** quantity, with `NA` intervals: `cumulative_logit` has
  no realized-value sampler, so propagation falls back to a deterministic mean and
  both scenarios collapse. The sampler warning does fire (asserted), but a reader who
  sees only the number sees a confident "no effect".
  **Returning `NA` instead would be a semantics change and is GATED, not done here.**
- **V-92 — an ordinal node cannot be distributional.** `cumulative_logit` declares
  `dpars = "mu"` only and the fitter rejects any second formula, so no causal path can
  ever target an ordinal node's scale. This is the one family class where drmSEM's
  headline capability is structurally unavailable. Engine-side ask, already recorded
  as `DRMTMB_ISSUES.md` item 7.

### Spatial — `tests/testthat/test-spatial.R` (2 tests / 11 assertions, 0 skips)

- **V-93/V-94.** A distance-kernel `relmat(1 | site, K = exp(-d/range))` node forms a
  valid SEM with `site`/`K`/`relmat` stripped from `paths()`, and `dsep()` +
  `indirect_effects()` both run over it (the augmented refit resolves `K` from the
  SEM's environment — the same OQ-13 path a phylo node uses). **Validated.**

Recorded substantively: `relmat(K = <any PSD matrix>)` is **strictly more flexible for
spatial work** than drmTMB's own `spatial()` marker, whose only implemented kernel is
a fixed exponential with a heuristic, non-estimated range and whose `mesh=` argument
aborts as unimplemented. Documenting `spatial()` as the spatial route would mislead.

Suite: 856 pass / 0 fail / 3 skip / 10 warn (was 817).

## 2026-08-15 — A4: the nominal link table

`drm_nominal_link()` (`R/edges.R`) labels each (family, component) pair for display in
`paths()` and for `standardize()`. It never alters a drmTMB computation, but a wrong
label misinforms the reader silently.

`skew_normal`, `biv_gaussian`, `biv_lognormal` and `biv_student` were reaching the
`"identity"` fallback rather than being named. For those four `"identity"` is the
CORRECT label, so **no output changes** — which is precisely why it survived
unnoticed. A right answer for the wrong reason is invisible until a family arrives
for which the fallback is wrong.

- **V-95.** All 18 family labels asserted explicitly, plus a lock that every family in
  `drm_supported_sampler_families()` appears in the table — so admitting a sampler
  without a link label now fails a test instead of printing a fallback. **Validated.**
- **V-96.** Component-driven links (`sigma`/`nu`/`sd_*` → log, `zi`/`hu`/`zoi`/`coi` →
  logit, `rho12` → tanh) override the family, and the fallback still answers for a
  genuinely unknown family. **Validated.**

`tests/testthat/test-nominal-link.R`, 2 tests / 28 assertions. Pure lookup — no engine,
deterministic on every platform, deliberately so: this lane's Windows CI failure came
from testing a mechanism against a live optimizer instead of where it is deterministic.

Suite: 884 pass / 0 fail / 3 skip / 10 warn (was 856).

## 2026-08-15 — A3: check_sem() coverage

`check_sem()` is exported and documented and had, until today, exactly **one**
assertion anywhere in the suite — the `nobs` column, added with the row-alignment
work. Its convergence, covariance and sampler columns, its `print` method, and every
warning branch were untested. The capability surface said so in as many words:
*"existence and a plausible-looking implementation are not evidence it reports
correctly."*

`tests/testthat/test-diagnostics.R`, 8 tests / 26 assertions, 0 skips.

**Split by determinism, deliberately.** Row content is checked against a live SEM;
every warning branch is checked against a **hand-built** `drm_diagnostics` object.
Asking a live optimizer to produce a non-converged node on demand is precisely the
test that passes on macOS and fails on Windows — this lane paid for that lesson
earlier the same day.

- **V-97.** Live SEM: column set, **topological** row order (not argument order),
  `nobs`, `converged`, `vcov_available`, `sampler`, and the `exogenous` attribute.
  **Validated.**
- **V-98 / V-98b.** `print()` warns on non-convergence, and treats `NA` convergence
  as not-converged — silence about convergence is not evidence of it. **Validated.**
- **V-99.** Warns on a missing covariance **and** the message names the `se = TRUE`
  remedy: a diagnostic that does not say what to do next is half a diagnostic.
  **Validated.**
- **V-100.** A missing sampler `inform`s rather than `warn`s. Asserted in both
  directions, because mean fallback is a documented degradation and escalating it to
  a warning would be wrong. **Validated.**
- **V-101 / V-101b.** Warns on mismatched `nobs` and names `na_action`; does **not**
  fire on equal counts, nor when an engine declines to report `nobs` (an unknown must
  not be manufactured into a mismatch). **Validated.**
- **V-102.** A healthy object emits none of the problem messages and returns its input
  invisibly. Note the cli header is itself a message, so "no messages at all" is the
  wrong bar — the bar is that no *problem* message fires.

Suite: 910 pass / 0 fail / 3 skip / 10 warn (was 884).

## 2026-08-15 — A5: the hurdle gap, PINNED not fixed

A defect recorded as a test rather than closed, because closing it is a semantics
change. `tests/testthat/test-hurdle-gap.R`, 3 tests / 8 assertions.

**Mechanism, verified live against drmTMB 0.6.0.** A hurdle node has
`model_type = "hurdle_nbinom2"` but `family$family = "truncated_nbinom2"`. drmSEM
keys on the family NAME (`drm_family_name()` -> `fit$family$family`), and
`truncated_nbinom2` **is** in `drm_supported_sampler_families()`. So:

1. `check_sem()` reports `sampler = TRUE` for a hurdle mediator;
2. `drm_sample_family()` draws a plain truncated NB2 and never consults `hu`;
3. the hurdle zeros silently do not appear in the propagated distribution.

drmSEM tells the user the mediator is fully supported, then propagates a
distribution missing its entire zero component.

- **V-103.** `hu = 0.9` produces **bit-identical** draws to no `hu` at all
  (`expect_identical`), while `zi = 0.9` correctly yields >80% zeros. The contrast is
  the point: `zi` is honoured, so `hu`'s silence is a defect and not a documented
  scope boundary. **Gap confirmed.**
- **V-104 / V-104b.** A live hurdle fit is asserted to present `model_type =
  hurdle_nbinom2` while `drm_family_name()` returns `truncated_nbinom2`, and that
  name is on the supported list. `hu` **is** a modelled component of the fit — the
  information is there; drmSEM simply never routes it to the sampler. **Confirmed.**

Also corrected: `drm_sample_family()`'s roxygen listed `hu` among the parameters it
accepts. Nothing in the body ever read it — documentation ahead of code. The false
promise is removed and replaced with a statement of the gap.

**Why this is GATED rather than fixed.** The family name cannot express the
distinction, so the fix means keying on `model_type` instead. That changes what a
mediator propagates — a semantics change, and this lane's gate list stops at exactly
that line. Not a drmTMB ask: the engine exposes everything needed.

Suite: 918 pass / 0 fail / 3 skip / 10 warn (was 910).

## 2026-08-15 — A6 (added arc): drm_psem() had no test at all

Not in the original A1–A5 list. Added because it is the same defect class the lane
exists to close — a capability the surface advertises with nothing checking it — and
because adding tests is ungated. Declared as an addition rather than slipped in.

`drm_psem()` is one of the package's two documented interfaces, named in `DESCRIPTION`
and the charter, exported and documented, and **referenced by zero tests**. Every SEM
in the suite was built through `drm_sem()`, so the shared internals (`new_drm_sem()`)
were heavily exercised while `drm_psem`'s own path — input validation and the default
`data` branch — was not.

`tests/testthat/test-psem.R`, 4 tests / 21 assertions, 0 skips.

- **V-105.** The two interfaces are documented as producing the same object, so the
  assertion is against a `drm_sem()` built from the same data rather than against a
  hand-written expectation: same topological order, same node set, same path table,
  and the **coefficients agree to 1e-6**. Shape alone would not have caught a wrong
  assembly. **Validated.**
- **V-105b.** The assembled object carries the downstream surface — `dsep()`,
  `fisher_c()`, `indirect_effects()` (closing additively), `check_sem()` with correct
  `nobs`. **Validated.** Also pinned: a **saturated** DAG (`y ~ m + x`) yields an
  **empty basis set** and warns "fully saturated". That is correct — every pair is
  connected, so there is nothing to test — but "dsep returned nothing" is easy to
  misread as breakage, so both the empty result and the warning are asserted.
- **V-106.** Non-`drmTMB` input is rejected, and the message names `drm_sem()`. A
  `drm_node()` spec is the obvious mistake, since it is exactly what the *other*
  interface wants; an error that does not say where to go next is half an error.
  **Validated.**
- **V-107.** The default-`data` branch — `drm_psem(data = NULL)` reaching into fit 1
  via `drm_fit_data()` — had no coverage anywhere. Asserted to recover the right frame
  and to agree with the explicit-data form to 1e-10. If it had silently produced an
  empty or wrong frame, every downstream scenario would have been built on it.
  **Validated.**

One warning was leaked and then fixed rather than suppressed: the saturated-basis-set
warning pushed the suite's WARN count 10 -> 11. Wrapping it in `expect_warning()`
restores the count **and** strengthens the test, which is the better of the two ways
to make a warning go away.

Suite: 939 pass / 0 fail / 3 skip / 10 warn (was 918).

## 2026-08-15 — A7: the hurdle gap FIXED (was pinned as A5)

A5 pinned this as a defect and gated the fix as a semantics change. Approved and done.

**What was wrong.** drmTMB folds the hurdle into `model_type` (`hurdle_nbinom2`) while
leaving `family$family` at `truncated_nbinom2`. drmSEM keyed its sampler on the family
NAME, so a hurdle mediator reported `sampler = TRUE`, was drawn as a plain truncated
NB2, and lost its **entire zero component** silently.

**The fix is deliberately narrow.** `drm_effective_family()` prefers `model_type` only
for model_types on an explicit allow-list, `drm_model_type_samplers()` (currently just
`hurdle_nbinom2`). Keying on `model_type` wholesale would have routed `zi_poisson`,
`zi_nbinom2` and friends — handled correctly today by the base family plus generic `zi`
post-processing — to the mean fallback, i.e. fixed one silent degradation by creating
several. V-104 asserts that non-regression explicitly.

Parameterization is **borrowed, not restated**: the branch calls the engine's own
`drm_nbinom2_size()` and `truncated_nbinom2_p0()`, matching `simulate.drmTMB`'s hurdle
branch term for term. `drm_family_expected_mean()` gained the matching mean,
`(1 - hu) * mu / (1 - p0)` — the non-zero part is zero-truncated, so plain `mu`
understates it.

- **V-103.** The BASE family still ignores `hu`, asserted bit-identically. The hurdle is
  reached through `model_type`, never by smuggling a parameter into `truncated_nbinom2`.
- **V-104 / V-104b.** Routing resolves `hurdle_nbinom2` to its own sampler and leaves
  `zi_*` and plain `truncated_nbinom2` untouched; `hu = 0.6` now produces ~60% zeros and
  the non-zero part is genuinely zero-truncated. Without `hu` the branch refuses to draw
  and warns rather than guessing.
- **V-108.** Moments against `drmTMB::simulate()` on a live hurdle fit: **zero fraction
  0.4444 vs 0.4446**, mean within 0.4%, variance within 2.7%. The zero fraction is the
  claim — pre-fix drmSEM produced essentially none.
- **V-108b.** `check_sem()` reports the node as sampled, now for the right reason: the
  column is computed from the effective family, not the bare name.

`test-hurdle-gap.R` renamed to `test-hurdle.R`, rewritten from pinning a defect to
guarding a fix. The history is kept in the file header because it explains the shape.

Suite: 948 pass / 0 fail / 3 skip / 10 warn (was 939).

## 2026-08-15 — A8: the vignette-tangling guard (and a false claim corrected)

A1 fixed the tangling defect. This closes the second half — making it *stay* fixed —
and corrects a claim made in between.

**The false claim.** `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_: false` was landed and
announced as "CI now runs the vignette code-tangling step, so A1 is guarded". **It
does not.** The variable is set and visibly propagated into the job environment, yet
`checking running R code from vignettes` appears on **no** platform: the step list runs
straight from `checking package vignettes` to `checking re-building of vignette
outputs`. The lane had announced a guard that did not exist — the same defect class it
was created to close.

**The real guard.** `tools/check-vignette-tangling.R` purls all 13 vignettes and fails
if any emits a call into the fitting engine, wired in as its own workflow step so it
cannot be silently skipped the way the check step was.

Two-sided verification, which is the standard `FLAGGED-TERMS.tsv` set here:
- **Fails on a regression.** Reverting one header (`{r formative-sem, eval =
  has_engine}` → `{r formative-sem}`) gives exit 1, naming `latent-variables.Rmd` and
  printing the offending `drm_sem(` line.
- **Passes clean, and demonstrably RUNS in CI.** `OK: all 13 vignettes tangle to
  engine-free code` appears in the ubuntu, windows *and* macos logs of run `7daebc1`.
  That last check is precisely what the first attempt lacked: green CI was mistaken for
  a green *step*.

The env var is retained with a comment recording that it was measured not to work, so
it is not re-added later in the belief that it is the guard.

Recorded because it nearly shipped: an attempt to muffle knitr's expected stderr with
`capture.output()` swallowed `purl()`'s side effect, produced no file, and left a guard
that could not fire while looking tidier. Reverted; stderr is redirected at the call
site. Cleverness that breaks a guard is worse than noise.

## 2026-08-15 — S3: scale-aware d-separation (detection; correction deliberately NOT done)

**The defect, demonstrated before anything was written.** A d-separation claim is
tested on the flattened data frame, one row per observation. When the claim's variable
varies at a coarser scale — a species-level trait repeated down to individuals — the
likelihood ratio sees one row per individual while the variable carries only as much
information as there are groups.

Measured on a 12-species × 40-individual fixture where `trait` is species-level and `z`
is species-structured but **independent of trait**, so `trait ⊥ z | {y}` is TRUE:

| model | p-value for a TRUE independence |
|---|---|
| flattened (as drmSEM tested it) | **0.004** — rejects |
| with `(1 \| sp)` on node `z` | **≫ 0.05** — correct |

Fisher's C inherited the false rejection (C p = 0.004), so the entire model was
condemned on the strength of a chance group-level correlation credited with 480 rows of
evidence instead of 12 groups'.

**Direction matters and is stated in the warning:** this **rejects TRUE independences**.
A reader who assumes the usual "underpowered test misses things" has the error backwards.

**Why this REPORTS rather than CORRECTS.** The remedy is to give both the base and the
augmented fit the grouping term. Adding it only to the augmented fit compares two
different random-effect structures, which is not a valid likelihood ratio — so a silent
fix is not available. Correcting it automatically would change what is tested, i.e. the
estimand. drmSEM therefore makes the mis-scaled claim loud and names the remedy. That
scope line is deliberate, not an omission.

- **V-109 / V-109b.** The claim is detected; `dsep()` gains `n_effective` (12) and
  `scale_group` (`sp`) columns and warns. The warning names the grouping, the honest
  sample size, the remedy `(1 | group)`, and the direction of the error — "this p-value
  is untrustworthy" is not actionable without them. **Validated.**
- **V-110 / V-110b.** No false alarms: a node that already models `(1 | sp)` is silent
  with `n_effective` `NA` and its true independence is no longer rejected; plain
  row-scale data is never flagged. **Validated.**
- **V-111 / V-111b.** The detector is exact: a variable that varies within groups yields
  nothing; a grouping with one level per row (a row id) is excluded, since otherwise
  every variable would report a spurious "scale"; a non-column is not an error; and a
  grouping the node already models via a bar term is not re-reported. **Validated.**

`tests/testthat/test-scale.R`, 6 tests / 21 assertions, 0 skips.

Still open at the time (design, not defect): evaluating each claim at its own
scale rather than reporting the mismatch, and skipping claims between variables
in orthogonal hierarchies. Both change which claims are tested and were gated.
**C-membership is now D-21 / V-109c** (2026-08-26): `wrong_scale` p-values do
not enter Fisher's C. Auto-refit of both sides remains out of scope.
Orthogonal-hierarchy skipping remains OQ-17.

Suite: 969 pass / 0 fail / 3 skip / 10 warn (was 948).

## 2026-08-26 — S3 grouping: wrong_scale excluded from Fisher's C (D-21)

Detection shipped 2026-08-15 (V-109). The flattened LRT on the 12×40 fixture
rejected a TRUE independence (p = 0.004) and Fisher's C inherited that
rejection. Auto-refitting both sides with `(1 | sp)` would test a different
SEM than `paths()`. D-21 therefore marks the claim `wrong_scale` and drops
its p-value from C. `model_set()` / CICc inherit C on the remaining `"ok"`
claims (Q3).

- **V-109c.** On the V-109 fixture, `trait _||_ z` has `status = "wrong_scale"`;
  `fisher_c()$n_claims` equals the count of `"ok"` claims; C does **not**
  reject the true independence (`p` is not `< 0.05`; typically `k = 0` and
  `p = NA`). Detection columns and the warning stay. **Validated.**
- V-109 / V-109b (detection + warning text) and V-110 / V-110b (no false
  alarms when the node already models `(1 | sp)`, or on row-scale data)
  remain in force.

`tests/testthat/test-scale.R`. The any-component LRT (D-2) is unchanged.

Suite: **1032 pass / 0 fail / 3 skip / 10 warn** (was 1026). Warning/skip
counts held. The +6 assertions are V-109c.

## 2026-08-15 — S2 (partial): DAG → MAG conversion, sourced then implemented

The gate that blocked this slice was **sourcing**, not authorisation. Discharged by
three independent readings of the primary sources, adversarial review of each, and
synthesis of only what they agreed on. Richardson & Spirtes obtained via UW TR 375
(Project Euclid paywalled — citations by section/theorem, not page).

**Implemented** (`R/mag.R`): adjacency by inducing path (R&S §4.2.3 / Thm 4.2(ii)),
orientation by ancestry (§4.2.1), edge types per Prop. 4.13.

- **V-112.** Shipley & Douma Fig 1 DAG (I), `A → X ← L → Y → B` with `L` marginalised,
  reproduces the **printed** MAG `A → X ↔ Y → B` exactly. **Validated.**
- **V-113.** Their DAG (III) reproduces the printed saturated MAG — complete on
  `{A,X,Y,B}`, six edges, with `X → B` and `A → B` added and *oriented*. **Validated.**
- **V-114.** The latent-chain trap: `A → u → B` with `u` latent gives `A → B`, not
  `A ↔ B`. Ancestors must be read in the ORIGINAL DAG; deleting latents first yields a
  valid MAG that is the wrong one, with nothing downstream to catch it. **Validated.**
- **V-115b.** A name-collision guard, added because it actually happened — see below.

**NOT implemented, and why:** the basis set. Cor. 5.3 proves each pairwise claim
(conditioning on **anteriors**, not the parents Shipley & Douma use), but pairwise ⇒
global was never located, and that is exactly what a basis set needs. Nothing here is
wired into `basis_set()` or `dsep()`. Selection/conditioned latents: explicit NO.

**Two things the process caught that the code would not have.**

1. **S&D's published orientation rules are defective in general** — they drop R&S's
   `∪ S` and mis-cite Lemma 3.9 (which is about *reading* an ancestral graph, not
   constructing one). They coincide with R&S only when `S = ∅`. The marginalised-only
   restriction is therefore justified **by the source**, not by caution.
2. **A silent name collision.** The first draft named its path helper
   `drm_simple_paths()` — already defined in `R/utils.R`, directed, and used by
   `path_effects()`. R redefines without a word; collation decided the winner; the MAG
   code silently received the DIRECTED version and returned a graph missing most of its
   edges. Nothing errored. **The printed acceptance example is what caught it** — a test
   asserting only "returns a data frame" would have passed. V-115b now pins the two
   apart.

`tests/testthat/test-mag.R`, 6 tests / 13 assertions, pure graph logic, no engine.

Suite: 982 pass / 0 fail / 3 skip / 10 warn (was 969).

---

## 2026-08-15 — V-116: `average(method = "latent")`, the argument nobody checked was forwarded

The last unblocked gap named in `capability-status.md`: `average(method = "latent")` was
implemented but no test exercised that branch.

**The gap was narrower than it looked, and worse in shape.** `standardize()`'s own latent
scaling is already validated, including live — V-44 (the theoretical link-variance term
for logit/probit/cloglog) and V-65 (a live logit-link GLM). So the untested surface was
never the latent standardization. It was `average.drm_compare()` **forwarding** `method`
to `standardize()` and weighting the values it gets back (`R/model_set.R:592,610`).

That is the silent-wrong-answer shape, not a missing-feature shape. Had the forwarding
broken, `average(cmp, method = "latent")` would still have returned a well-formed
`drm_average` with the right columns, the right paths, and the right `weight_sum` — and
`"sd_x"` numbers inside it. Nothing in the package or the suite would have objected.

- **V-116.** The CBIC-weighted mean is rebuilt by hand from `attr(cmp, "fits")` using
  `standardize(fit, method = "latent")` and `cmp$weight`, keyed exactly as
  `average.drm_compare()` keys it (`from \r to \r component`), and asserted equal to
  `average(cmp, method = "latent")$std.estimate`. Two supporting assertions: the `"latent"`
  and `"sd_x"` results must actually **differ** (the latent divisor is `sd(eta)` for the
  fixture's identity- and log-link nodes, so equality would mean the argument was dropped),
  and the path-key set and `weight_sum` must **agree** across methods, since which paths
  exist and how much model weight carries each are properties of the graph, not of the
  standardization. **Validated.**

**Seen red before it was believed.** With `method` hard-coded to `"sd_x"` inside
`average.drm_compare()`, the block fails 2 assertions (the reconstruction and the
differ-check); reverted, it passes. A test never observed failing is not evidence — this
is the same discipline V-115b was added under.

**What V-116 does NOT establish.** It checks *forwarding and weighted-averaging
arithmetic*, not that latent standardization is the right scaling for model averaging —
that convention is D-15 / OQ-4, and the log-link families' mean-dependent latent variance
remains deferred there. Conditional (not full) averaging is unchanged and untested here.

`tests/testthat/test-model-set.R`, 1 test / 5 assertions, live fit. The `mediated`
candidate is saturated for its two nodes, so `compare()` emits the documented empty-basis-set
notice; it is consumed in this test rather than left to inflate the suite's warning count.

Suite: 987 pass / 0 fail / 3 skip / 10 warn (was 982). Warning count held, which is the
point of consuming that notice rather than letting it drift the tracked figure.

---

## 2026-08-26 — MAG basis set wired (V-117 / V-118 / V-119)

The 2026-08-15 conversion (`drm_dag_to_mag()`, V-112–V-115b) stopped at graph
construction. Completeness (pairwise ⇒ global) was located in Sadeghi &
Lauritzen (2014) Theorem 3 and Lauritzen & Sadeghi (2018) Theorem 4. The
wire landed on `claude/lane-mag-wire` under D-20: Cor. 5.3 anterior
conditioning, `S = ∅`, compositional-graphoid license. d-sep LRT machinery
unchanged (D-2).

- **V-117.** Shipley & Douma Fig 1 DAG (I), `A → X ← L → Y → B` with `L`
  marginalised: MAG adjacency is `A → X ↔ Y → B`; anteriors of `{A,Y}`
  exclude the bidirected spouse `X`; `basis_set()` emits
  `A _||_ Y | {}`, `A _||_ B | {Y}`, `X _||_ B | {A, Y}` and **not**
  `A _||_ Y | {X}`. Homoscedastic Gaussian stays silent; a `sigma` or
  non-Gaussian node fires the compositionality `cli_inform()`.
  `tests/testthat/test-mag-basis.R`. **Validated.**
- **V-118.** A latent common-cause DGP (`L → x`, `L → y`): DAG `basis_set()`
  claims `x _||_ y`; declaring `latent = "L"` drops that false claim and
  never names `L` in the MAG basis. `tests/testthat/test-mag-dsep.R`.
  **Validated.**
- **V-119.** Live `dsep()`: the DAG rejects the false `x _||_ y` claim
  (`p < 0.05`, Fisher's C rejects); the MAG omits it from Fisher's C.
  Same file. **Validated.**

The 2026-08-15 note "NOT implemented, and why: the basis set" is discharged
for marginalised latents. Selection / conditioned latents and parent-based
S&D separators remain out of scope. Residual compositionality gap: OQ-16.

Suite: **1026 pass / 0 fail / 3 skip / 10 warn** (was 987). Warning count
held. Skips unchanged (ape-missing guard + 2 symbolizer).
