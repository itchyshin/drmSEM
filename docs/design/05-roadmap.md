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

## 0.2 — Inference hardening + grammars (RELEASED, 0.2.0)

Shipped in 0.2.0:
- OQ-12 — unified effect-API surface (`method` / `uncertainty` / `nsim` /
  `population` shared across the effect functions; old args deprecated aliases).
- OQ-14 / D-14 — bivariate covariance-edge *grammar* (`covary()`,
  `covariances()`, covariance-aware d-separation). Joint bivariate *fit* → 0.4.
- OQ-5 — per-mediator (`inclusion`/`exclusion`) and per-component
  (`mean`/`sigma`/`zi`) path attribution (`path_effects()`).
- Composite (formative) constructs (`drm_composite()` / `loadings()`) — the 0.3
  first increment landed early.
- Analytic effect cross-checks promoted to asserted tests (V-26..V-34).
- Standardization scale conventions finalized and documented (OQ-4).

Post-0.2.0 live-drmTMB lane (issue #13): the Fisher's C calibration study
(Type-I / power) generated the live-drmTMB cache and passed all five OQ-6
acceptance checks. V-17 is validated for the tested OQ-6 grid; broader d-sep
and Fisher's C settings remain claim-scoped until separately calibrated.
Remaining live-engine work: the standardization `sigma_E` refinement, V-7
live-fit analytic-effect tier flip, and OQ-14 joint fit.

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
  covariance-edge *grammar* + d-separation-*awareness* layer landed in 0.2.0
  (`R/covariances.R`), and the bivariate-node *declaration* grammar —
  `drm_pair()`, `drm_expand_pair()`, and the `rho12()` / `corpairs()` accessors
  returning the declared edges with an `NA` (engine-hook) estimate — landed in
  0.2.x (`R/pair.R`). Only the engine-dependent joint fit / read-back / render
  pieces remain here.

## 0.5 — Cyclic / feedback graphs

- Lift the DAG-only restriction for specific feedback motifs with a defined
  estimand and propagation rule. Cycles remain an error until this lands.
- Design of record: `10-cyclic-feedback.md` — declared feedback motifs, the
  reduced-form / fixed-point equilibrium estimand, sigma-separation, and the
  staged plan (pure-R fixed-point propagation now; consistent IV/joint estimation
  is the engine part).

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
