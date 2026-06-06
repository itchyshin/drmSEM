# 05 — Roadmap

Staged plan for drmSEM. Each stage ships only with the Definition of Done
(implementation, tests, roxygen docs, a worked example, ledger evidence, an
AGENT_LOG entry, review). Scope boundaries from the charter hold: observed-
variable, piecewise, DAG-only, drmTMB as the only engine.

## 0.1 — Core + effects (RELEASED, 0.1.0)

The first public release, tagged 0.1.0. Status: code complete and kernel-
validated; drmTMB-integration runtime was validated in CI where `drmTMB` is
compiled (see `04-validation-plan.md`).

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

## 0.1.x dev (CURRENT)

Post-0.1.0 development on the `0.1.0.9000` line:
- OQ-12 — unified effect-API surface (`method` / `uncertainty` / `nsim` /
  `population` shared across the effect functions, old args kept as deprecated
  aliases; `R/effects_api.R`).
- OQ-14 / D-14 — bivariate covariance-edge *grammar* as a pure-R layer:
  `covary()` declaration, `covariances()` accessor (separate from `paths()`),
  and covariance-aware d-separation (dropping the `y1 _||_ y2` claim).
  (`R/covariances.R`). The joint bivariate *fit* stays in 0.4 (below).

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

## 0.4 — Joint multivariate SEM (joint-FIT milestone)

- Optionally fit correlated endogenous responses as one joint drmTMB model
  (`rho12` becomes a first-class structural target rather than a per-node
  residual correlation), moving beyond the strictly piecewise assumption.
- This is the joint-*fit* milestone for bivariate covariance edges (OQ-14,
  D-14): `drm_pair()` joint bivariate fitting, `rho12()` / `corpairs()`
  read-back from a live fit, and double-headed / dashed-arc plotting. The
  covariance-edge *grammar* + d-separation-*awareness* layer already landed in
  0.1.x (`R/covariances.R`); only the engine-dependent fit/read-back/render
  pieces remain here.

## 0.5 — Cyclic / feedback graphs

- Lift the DAG-only restriction for specific feedback motifs with a defined
  estimand and propagation rule. Cycles remain an error until this lands.

## Interop and distribution

- brms / lavaan interop: import or export drmSEM graphs to/from neighbouring
  ecosystems for users who live there. (Arbitrary brms/glmmTMB/lme4 adapters stay
  out of scope; this is graph interchange, not new engines.)
- CRAN submission once the engine surface is stable and integration tests run on
  all platforms (the Grace track in `CLOUD.md`).

## Phylogenetic distributional SEM

See `06-phylogenetic-sem.md` for the staged phylogenetic roadmap (Phase 1 phylo
nodes, Phase 2 model comparison, and Phase 3 fixed-grid evolutionary covariance
via `drm_phylo_cov()` all ship today; Phase 4 adds distributional phylogenetic
paths). Effect-theory refinements (natural effects, marginal effects, bootstrap,
outcome functionals) are OQ-8..12 in `../memory/OPEN_QUESTIONS.md`.

## Non-goals (kept off the roadmap deliberately)

- drmSEM fitting its own likelihoods — never; drmTMB is the engine.
- Arbitrary model-backend adapters.
- Replacing lavaan for classical covariance-structure SEM.
