# 05 — Roadmap

Staged plan for drmSEM. Each stage ships only with the Definition of Done
(implementation, tests, roxygen docs, a worked example, ledger evidence, an
AGENT_LOG entry, review). Scope boundaries from the charter hold: observed-
variable, piecewise, DAG-only, drmTMB as the only engine.

## 0.1 — Core + effects (CURRENT)

The first usable release. Status: code complete and kernel-validated;
drmTMB-integration runtime pending (see `04-validation-plan.md`).

- Graph grammar: `drm_node()`, `drm_sem()` (declarative), `drm_psem()` (core),
  component-labelled typed edges, DAG/cycle enforcement. (`R/edges.R`,
  `R/drm_sem.R`, `R/extractors.R`)
- d-separation under the any-component rule: `basis_set()`, `dsep()`,
  `fisher_c()`. (`R/dsep.R`)
- Simulation effect engine: `direct_effects()`, `total_effects()`,
  `indirect_effects()` with the direct / mean-mediated / distribution-mediated
  decomposition. (`R/effects.R`, `R/simulate_effects.R`)
- `paths()`, `standardize()`, `check_sem()`, `plot()`.
- Canonical `size -> abundance -> survival` example and vignette.
- Exit criterion: Tier-2 integration tests pass in the cloud env; ledger flips
  distribution-mediated effects and d-sep from "kernel-validated" to "validated".

## 0.2 — Inference hardening

- Fisher's C calibration study (Type-I / power under the any-component
  augmentation); document the operating characteristics.
- Analytic effect cross-checks promoted from "planned" to asserted tests
  (Gaussian-mean product identity; distribution-mediated -> 0 when scale fixed).
- Standardization scale conventions finalized and documented (`sd_x` vs
  `latent`), including factor predictors.

## 0.3 — Latent variables

- Allow a node to load on a latent construct (composite or reflective), bridging
  toward lavaan-style measurement while staying likelihood-based per node. Out of
  scope until the observed-variable core is validated.

## 0.4 — Joint multivariate SEM

- Optionally fit correlated endogenous responses as one joint drmTMB model
  (`rho12` becomes a first-class structural target rather than a per-node
  residual correlation), moving beyond the strictly piecewise assumption.

## 0.5 — Cyclic / feedback graphs

- Lift the DAG-only restriction for specific feedback motifs with a defined
  estimand and propagation rule. Cycles remain an error until this lands.

## Interop and distribution

- brms / lavaan interop: import or export drmSEM graphs to/from neighbouring
  ecosystems for users who live there. (Arbitrary brms/glmmTMB/lme4 adapters stay
  out of scope; this is graph interchange, not new engines.)
- CRAN submission once the engine surface is stable and integration tests run on
  all platforms (the Grace track in `CLOUD.md`).

## Non-goals (kept off the roadmap deliberately)

- drmSEM fitting its own likelihoods — never; drmTMB is the engine.
- Arbitrary model-backend adapters.
- Replacing lavaan for classical covariance-structure SEM.
