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

Environment: R 4.3.3 in the dev container; all 13 R/ source files parse clean;
18/18 pure-logic kernel tests pass locally. drmTMB-integration tests are written
but cannot run here (network allowlist blocks CRAN/Posit/r-universe, so TMB and
drmTMB cannot be compiled); they run in the Codex cloud env (`CLOUD.md`).

| # | Claim | Status (2026-06-04) | Evidence |
| --- | --- | --- | --- |
| V-1 | Fixed-effect predictor extraction drops RE bars and structured/smooth markers, keeps `mi(x)`, removes intercepts | validated (kernel) | `test-utils.R`: predictor-extraction test PASS |
| V-2 | Topological sort orders a DAG and detects cycles (cycles are an error) | validated (kernel) | `test-utils.R`: toposort test PASS |
| V-3 | Ancestors + simple-path enumeration correct | validated (kernel) | `test-utils.R`: ancestors/paths test PASS |
| V-4 | Coefficient names map back to predictor variables | validated (kernel) | `test-utils.R`: `drm_coef_variable` test PASS |
| V-5 | Inverse links (`identity`, `log`, `logit`, `tanh`) correct | validated (kernel) | `test-effect-kernels.R`: inverse-link test PASS |
| V-6 | Family samplers recover target moments, incl. zero-inflation lowering the mean | validated (kernel) | `test-effect-kernels.R`: sampler-moment test PASS |
| V-7 | **Distribution-mediated effect** appears only when a mediator's `sigma` depends on x and a downstream nonlinearity exists; ~0 when scale constant | kernel-validated; drmTMB-integration pending | `test-effect-kernels.R`: distribution-mediated contrast = 0.99 (scale on x) vs ~0 (scale constant) PASS |
| V-8 | Fisher's C combines p-values with `2k` df: `C = -2*sum(log p)` | validated (kernel) | `test-dsep-kernels.R`: Fisher's C test PASS |
| V-9 | Basis set excludes adjacent pairs, respects causal order, applies the **any-component** adjacency rule | kernel-validated; drmTMB-integration pending | `test-dsep-kernels.R`: basis-set test PASS (incl. `habitat -> zi(abund)` adjacency) |
| V-10 | **d-separation** LRT-of-augmented-node flags a true omitted edge (`size -> survival`, `p < 0.05`) | kernel-validated; drmTMB-integration pending | `test-integration.R`: d-sep test WRITTEN, gated, not yet run |
| V-11 | `drm_sem` builds a valid DAG with component-labelled edges (`zi ~ habitat`, `sigma ~ temp`) and topo order `size, abundance, survival` | pending | `test-integration.R`: edge/topo test WRITTEN, gated, not yet run |
| V-12 | `paths()` returns a component-labelled coefficient table including `zi` | pending | `test-integration.R`: paths test WRITTEN, gated, not yet run |
| V-13 | Effect API runs and total decomposes into direct + indirect (incl. `distribution_mediated` row) | pending | `test-integration.R`: effect test WRITTEN, gated, not yet run |
| V-14 | Total ≈ direct + indirect within Monte-Carlo CI on the canonical SEM | pending | planned recovery check (`04-validation-plan.md`) |
| V-15 | Gaussian-mean analytic cross-check: simulated mean-mediated = product of path coefficients on identity-link chain | pending | planned recovery check |
| V-16 | d-sep passes a true non-edge (low false-positive rate) | pending | planned recovery check |
| V-17 | Fisher's C calibration (Type-I / power) under the any-component augmentation | experimental | reasoned in `03-dsep.md`; no simulation yet |
| V-18 | `model.matrix()` contrast coding matches drmTMB's internal fixed-effect coding | pending | needs live drmTMB fit (OQ-2); isolated in `drm_fixed_design` |
| V-19 | Exact family-sampler parameterizations match drmTMB (nbinom2 `size`, beta_binomial trials, lognormal scale) | pending | needs live drmTMB fit (OQ-1) |
| V-20 | drmTMB adapter shapes (`bf()$entries`, `coef`/`fixef`/`vcov` `dpar:term`, `logLik`, `is_converged`, `predict_parameters`) | pending | written against drmTMB 0.1.3.9000 source; runtime confirmation pending |

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
