# 04 — Validation plan

This document states how every drmSEM claim is checked, what currently passes,
and what is still pending. It is the narrative companion to
`docs/memory/VALIDATION_LEDGER.md` (the dated table). AGENTS.md rule 1: no public
effect type, estimand, or d-separation rule ships without a simulation test that
recovers a known data-generating process.

Two test tiers exist:

1. **Pure-logic kernel tests** — run anywhere, no engine. They isolate the graph
   grammar, the simulation kernels, and the d-separation arithmetic from drmTMB.
2. **drmTMB-integration tests** — fit real nodes and exercise the public API end
   to end. Gated by `skip_if_not_installed("drmTMB")`; run in the Codex cloud
   environment (see `CLOUD.md`).

## Tier 1 — pure-logic kernel tests (the pure-logic kernel suite PASSES locally, R 4.3.3)

`tests/testthat/test-utils.R`:
- Fixed-effect predictor extraction drops random-effect bars `(g | h)` and
  structured/smooth markers (`phylo`, `mi`, `s`, ...), keeps `mi(x)` as `x`,
  removes intercepts. PASS.
- Topological sort orders a DAG and flags a 2-cycle as non-acyclic. PASS.
- Ancestors and simple-path enumeration on a small DAG. PASS.
- Coefficient names map back to predictor variables (`habitatB` -> `habitat`).
  PASS.

`tests/testthat/test-dsep-kernels.R`:
- Fisher's C combines p-values with `2k` df and the right `C`. PASS.
- Basis set excludes adjacent pairs and respects causal order, including the
  any-component rule: `habitat -> zi(abund)` makes the pair adjacent, so no
  claim is generated. PASS.

`tests/testthat/test-effect-kernels.R`:
- Inverse links (`identity`, `log`, `logit`, `tanh`) are correct. PASS.
- Family samplers recover target moments: gaussian mean/SD, poisson mean, and a
  zero-inflated poisson mean strictly below the un-inflated mean. PASS.
- **The distribution-mediated mechanism.** A chain x -> M (gaussian, with `mu`
  and `sigma` depending on x) -> Y (`mu = exp(0.5*M)`): the distribution-mediated
  contrast equals the mean contrast (~0 extra) when M's `sigma` is constant, and
  adds a positive effect (> 0.1, ~0.99 in the design) when `sigma` rises with x.
  This is the load-bearing test for the package's key novelty. PASS.

`tests/testthat/test-effect-api.R`:
- The unified effect-API normalizers (OQ-12): `uncertainty` / `nsim` /
  `population` / `method` mapping, new-vs-old-argument parity, and the
  honest early-abort errors for `bootstrap` / `marginal`. PASS.

`tests/testthat/test-covariances.R`:
- Covariance-edge grammar (OQ-14): `covary()` construction + validation,
  `drm_build_covariances()` node resolution / labelling / de-dup, the
  `covariances()` accessor, and `basis_set()` dropping the `y1 _||_ y2` claim
  for residual and higher-level edges. PASS.

`tests/testthat/test-analytic-effects.R`:
- Analytic effect cross-checks (Gaussian-mean product identity; distribution-
  mediated channel vanishing when scale is held fixed) plus the natural /
  functional effect kernels. PASS.

The pure-logic kernel suite (including `test-composite.R` and `test-path-effects.R`,
which carry the OQ-5 / composite V-31..V-35; `test-pair.R` for the `drm_pair()`
declaration grammar; `test-feedback.R` for `drm_cycle()`, the fixed-point recovery
V-42, and the equilibrium total effect V-43; `test-interop.R` for the lavaan / DOT
graph-interchange layer; and the decomposition-pairing V-36..V-41 in
`test-analytic-effects.R`) passes in CI, and all 22 R/ source files parse clean.

## Tier 2 — drmTMB-integration tests (WRITTEN, runtime PENDING)

> **[Update 2026-06-07] Largely superseded.** Tiers 2-3 below predate the
> V-26..V-73 campaign and describe shipped, CI-running recovery as "planned /
> pending." The authoritative, current coverage map is
> `11-validation-matrix.md` (kernel + live-fit recovery, V-1..V-73), the wave-2
> spec is `12-coverage-calibration.md`, and per-claim status lives in
> `../memory/VALIDATION_LEDGER.md`. In particular the family-sampler
> parameterization (listed as an "open item" below) has since been exercised,
> fixed where needed, and asserted against `drmTMB::simulate()` for V-57..V-60.
> Read those three documents for live state; the prose below is retained as
> historical plan.

`tests/testthat/test-integration.R` builds the canonical
`size -> abundance -> survival` SEM from a known DGP (`helper-dgp.R`,
`simulate_drmsem_dgp()`) and checks:

- **Edge recovery / topo order.** `drm_sem` builds a valid DAG with
  `order = c("size","abundance","survival")` and recovers the `zi ~ habitat`
  and `sigma ~ temp` edges with the correct component labels.
- **Path table.** `paths()` returns a component-labelled coefficient table that
  includes a `zi` row.
- **d-sep flags an omitted edge.** A model that deliberately drops the true
  `size -> survival` arrow yields a `size _||_ survival` claim with `p < 0.05`,
  and `fisher_c()` returns a finite statistic.
- **Effect decomposition.** `direct_effects()` and `indirect_effects()` run; the
  indirect result carries `total_path`, `direct`, `indirect`, and
  `distribution_mediated` rows.

These cannot run in the dev container: the network allowlist blocks
CRAN/Posit/r-universe (`host_not_allowed`), so TMB and drmTMB cannot be installed
or compiled here. Status: **PENDING runtime validation** in the cloud env.

## Planned recovery checks (to be asserted as the suite matures)

- **d-sep passes a true non-edge.** A pair with genuinely no relationship should
  yield p well above 0.05 (low false-positive rate), complementing the
  omitted-edge detection above.
- **total ≈ direct + indirect within Monte-Carlo CI.** Confirm the decomposition
  closes on the canonical SEM, accounting for MC error at the chosen `B`/`n_sim`.
- **Gaussian-mean analytic cross-check.** On an all-Gaussian identity-link chain,
  the simulated mean-mediated effect should match the closed-form product of path
  coefficients (the one regime where products are valid), validating the
  simulator against theory.
- **Distribution-mediated vanishes when sigma is held fixed.** The integration
  analogue of the kernel test: refit/replace the mediator so its scale does not
  depend on the upstream predictor and confirm `distribution_mediated -> 0`.

## Open validation items

- Calibration of Fisher's C under the any-component augmentation (Type-I rate).
- Confirming the `model.matrix()` contrast-coding assumption against live drmTMB
  fixed-effect coding (`R/extractors.R`, `drm_fixed_design`).
- Confirming the exact family-sampler parameterizations against drmTMB's
  internal definitions (nbinom2 `size`, beta_binomial trials, lognormal scale).

See `docs/memory/OPEN_QUESTIONS.md` for the full list.
