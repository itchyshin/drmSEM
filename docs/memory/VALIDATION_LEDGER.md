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
