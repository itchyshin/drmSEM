# 11 — Validation matrix (simulation-based correctness map)

This is the coverage map for drmSEM's machinery: for each piece of functionality,
the **known-answer data-generating process** that exercises it, the **validation
tier**, and the **evidence** (a `V-` number in `../memory/VALIDATION_LEDGER.md`).
It exists so "is everything correct?" has a concrete, auditable answer and so the
remaining gaps are explicit rather than implied.

## Tiers

- **kernel** — closed-form / hand-built-engine recovery that runs **without
  drmTMB** (pure-R). Pins the *algorithm* (the propagation map, the decomposition
  arithmetic, the graph logic, the standardization math) against an exact answer.
- **live-fit (CI)** — recovery on a **real `drm_sem()` fit**, drmTMB-gated, run in
  CI. Pins the *pipeline* (the drmTMB adapter, family samplers, predict, the
  effect engine end-to-end) against a fitted-coefficient / simulated ground truth.
- **calibration** — a compute-heavy, many-replicate study (Type-I / power /
  interval coverage / selection rate). The full grid runs in the live (Codex)
  lane and is cached; CI runs a bounded smoke version. (Wave 2; see below.)

The guiding rule for live-fit recovery: assert against quantities the **engine
itself produces** — fitted coefficients from `paths()`, or a Monte-Carlo ground
truth from `drmTMB::simulate()` on the same fit — rather than a hand-derived
closed form whose drmTMB parameterization we cannot independently verify. This
keeps the tests robust to engine-internal conventions.

## Coverage matrix

| Machinery | Known-answer DGP | Tier | Evidence |
| --- | --- | --- | --- |
| Predictor/edge extraction, toposort, ancestors, simple paths | hand graphs | kernel | V-1..V-4 |
| Inverse links, family samplers (basic) | analytic | kernel | V-5, V-6 |
| **Distribution-mediated mechanism** (channel real iff `x→sigma(M)` + downstream curvature) | hand engine + lognormal | kernel + **live-fit** | V-7 (kernel + V-41 live, V-37 magnitude) |
| Fisher's C arithmetic, basis-set under any-component rule | hand graphs | kernel | V-8, V-9 |
| Effect engine integration (effects finite, total=direct+indirect on a live DAG) | canonical 3-node | live-fit | V-10..V-14 |
| Mean-mediated = fitted-coef product (identity Gaussian) | linear chain | live-fit | V-15 |
| d-separation specificity (detects an omitted true arrow) | omitted arrow | live-fit | V-13 / integration |
| Calibration: Fisher's C Type-I / power (OQ-6 grid) | mean / distributional / cross-link grid | calibration | V-17 (OQ-6 grid only) |
| Sampler parameterizations (default dpars; nbinom2/beta/Gamma; lognormal meanlog) | drmTMB introspection + simulate comparison | live-fit | V-19 / OQ-1 |
| Analytic effect identities (a·b·w; sigma-path invisibility; lognormal gap; natural vs controlled; functionals) | closed forms | kernel | V-26..V-30 |
| Composite constructs + reliability + standardize | hand data | kernel (+live) | V-31 (+ structural grid) |
| Path attribution (per-mediator, per-component, natural/recanting) | hand engines | kernel | V-32..V-35 |
| **Effect decomposition pairing** (additive identity, lognormal gap + sign, linear-zero, chain, reproducibility) through the shipped `drm_decomp_legs()` | hand engines + live | kernel + **live-fit** | V-36..V-41 |
| **Outcome functionals on the effect API** (OQ-11): `quantile` recovers a sigma-path tail effect; functional decomposition legs non-degenerate + close | hand engines (gaussian/poisson) | kernel | **V-74, V-75** |
| Feedback equilibrium = reduced form `(I−B)⁻¹Γ`; non-convergence flagged | linear 2-cycle | kernel | V-42, V-43 |
| **Nonlinear feedback** fixed point (self-consistency + independent solve) | saturating 2-cycle | kernel | **V-73** |
| Standardization `sigma_E` (logit π²/3 etc.) | fakefit | kernel (+live) | V-44 (+ V-65/66) |
| **Effect decomposition across the family×link grid** (closure, sign, magnitude) | gaussian/poisson/nbinom2/beta/beta_binomial/Gamma/lognormal (logit via `beta()`; drmTMB has no plain `binomial`) | **live-fit** | **V-45..V-54** |
| **Sampler moments vs `drmTMB::simulate()`** + outcome functionals (`p_zero`/`var`/`p_gt`) | per-family moments; Poisson zero-prob | **live-fit** | **V-55..V-64** |
| **Structural recovery on live fits** (standardization sigma_E pipeline; composite as predictor + response; feedback `total_effects` vs fitted-B reduced form; natural NDE/NIE nonlinear) | per-area | **live-fit** | **V-65..V-72** |
| Interop round-trip (lavaan / DOT) | hand graphs | kernel | `test-interop.R` |
| Phylogenetic covariance + phylo d-sep | fixed-grid trees | kernel (+live) | `test-phylo*` |

(V-numbers V-45..V-73 are the **recovery-grid campaign**; exact per-test mappings
are listed in `VALIDATION_LEDGER.md`.)

## The recovery-grid campaign (this wave)

New live-fit recovery files, drmTMB-gated, authored to assert *numerical*
recovery (not just finiteness) across the surface:

- `test-recovery-families.R` (V-45..V-54) — the effect decomposition across the
  family×link grid: mean-mediated = fitted-coef product; total = direct +
  indirect closure; `distribution_mediated` sign/magnitude (the V-7 magnitude
  follow-up, from fitted params).
- `test-recovery-samplers.R` (V-55..V-64) — `drm_sample_family()` mean/variance
  vs `drmTMB::simulate()` for gaussian, poisson, nbinom2, beta, Gamma, and
  lognormal, plus outcome-functional recovery (`p_zero` = Poisson zero-prob
  change, `var`, `p_gt`). Tweedie, zero_one_beta boundary inflation, student
  `nu`, and beta_binomial trials remain separate sampler-extension work.
- `test-recovery-structural.R` (V-65..V-72) — standardization `sigma_E` on a live
  GLM fit; composite as predictor **and** response; feedback `total_effects`
  equilibrium vs the reduced form from the **fitted** B; natural NDE/NIE on an
  identified nonlinear case.
- `test-feedback.R` (V-73) — nonlinear feedback fixed point.

## Wave 2 — calibration & coverage (the compute-heavy layer)

Not in this wave; the harness mirrors the OQ-6 calibration pattern
(`inst/calibration/generate.R` + `vignettes/calibration.Rmd`, cached `.rds`):

- **Effect-CI coverage** — do `uncertainty = "parametric"` intervals cover the
  true effect at the nominal rate across DGPs? (Currently unmeasured — the single
  biggest open correctness property.)
- **d-separation Type-I / power** beyond the OQ-6 grid.
- **Model-selection recovery rate** — does `compare()` / `best()` select the true
  DAG, and at what rate?

These need many replicates, so the full grid runs in the live (Codex) lane and is
cached; CI runs a bounded smoke. **The wave-2 spec — DGPs, estimands, true values,
metrics, acceptance criteria, and output schema — is `12-coverage-calibration.md`**
(C-1 coverage, C-2 d-sep Type-I/power, C-3 model-selection recovery, C-4 the
sampler-dispersion close-out). Tracked alongside the live-engine items in
`../memory/CODEX_HANDOFF.md`.
