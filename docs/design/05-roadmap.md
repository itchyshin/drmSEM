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

## Missing data — PARTIAL (row-alignment policy and graph-derived imputation shipped 0.5.x)

Previously absent from this roadmap entirely, which is how drmSEM reached 0.5.0
with no missing-data policy at all. See `13-missing-data.md`.

- **Shipped:** `drm_sem(na_action = )` (`"warn"` / `"common"` / `"fail"`), so a
  piecewise SEM describes one sample rather than several silently; `nobs`
  reporting through `attr(x, "alignment_issues")`, `print()` and `check_sem()`;
  a `"n_mismatch"` d-separation status so an invalid likelihood ratio cannot
  enter Fisher's C.
- **Shipped:** `drm_sem(impute = "auto")` — each incomplete **endogenous**
  parent's imputation model is derived from its own node formula and family and
  handed to the engine as `mi()` + `impute_model()`. Reported by `imputation()`.
- **Open, engine-dependent:** drmTMB 0.7.0 (#1086) accepts **two independent
  Gaussian** `mi()` terms. `k > 2` and non-Gaussian `k = 2` still abort.
  Issue 1 (per-family C++ `has_mi`, not a whitelist edit) is still open.
  See `../memory/DRMTMB_ISSUES.md`. Capability stays `partial`.
- **Open, drmSEM-side:** incomplete **exogenous** predictors have no node model
  in the graph, so the graph cannot specify their imputation model; they remain
  governed by `na_action`.
- **Won't do:** full-information Bayesian imputation inside a joint model. That
  requires drmSEM to fit its own likelihood, which the charter forbids.

## m-separation (IMPLEMENTED 2026-08-26 — `14-m-separation.md`)

Reaches the latent problem from the side the charter allows: m-separation is a **graph**
operation, so it needs no joint likelihood. Changes only which independence claims are
generated — the any-component LRT (D-2) and `fisher_c()` are untouched.

- **Wired.** `latent =` on `drm_sem()` / `drm_psem()` builds the implied MAG;
  `basis_set()` / `dsep()` condition on Richardson & Spirtes Corollary 5.3
  anteriors (`S = ∅`). Pairwise ⇒ global is licensed under a compositional
  graphoid (Sadeghi & Lauritzen 2014 Thm 3; Lauritzen & Sadeghi 2018 Thm 4).
- **v1 is marginalised latents only.** A *conditioned* (selection) latent is
  structurally unrepresentable (no selection argument). Treating one as
  marginalised would produce silently WRONG independence claims.
- **Acceptance.** V-117 reproduces the S&D Fig 1 DAG (I) Cor. 5.3 claim set,
  including the collider trap `A _||_ Y | {}` (not `| {X}`). V-118 / V-119 are
  the DGP where DAG d-sep is wrong and MAG m-sep is right.
- **Still out of scope:** selection / conditioned latents; parent-based Shipley
  & Douma separators.
- **Honest positioning:** this is parity with `because`, not differentiation —
  drmSEM's distinguishing feature is the non-mean component path, which
  m-separation does not extend.

## 0.3 — Latent variables

- Allow a node to load on a latent construct (composite or reflective), bridging
  toward lavaan-style measurement while staying likelihood-based per node. Out of
  scope until the observed-variable core is validated.

## 0.4 — Joint multivariate SEM (joint-FIT milestone) — PARTIAL (grammar + declaration shipped 0.2.x; joint fit engine-dependent, deferred)

- Optionally fit correlated endogenous responses as one joint drmTMB model
  (`rho12` becomes a first-class structural target rather than a per-node
  residual correlation), moving beyond the strictly piecewise assumption.
- This is the joint-*fit* milestone for bivariate covariance edges (OQ-14,
  D-14): `drm_pair()` joint bivariate fitting and `rho12()` / `corpairs()`
  read-back from a live fit. The covariance-edge *grammar* + d-separation-
  *awareness* layer landed in 0.2.0 (`R/covariances.R`); the bivariate-node
  *declaration* grammar — `drm_pair()`, `drm_expand_pair()`, and the `rho12()` /
  `corpairs()` accessors returning the declared edges with an `NA` (engine-hook)
  estimate — landed in 0.2.x (`R/pair.R`); and double-headed / dashed-arc
  plotting shipped in 0.2.x (`plot.drm_sem(show=)`). Only the engine-dependent
  joint *fit* and the fitted-correlation read-back (a non-`NA` estimate) remain
  here.

## 0.5 — Cyclic / feedback graphs (RELEASED, 0.5.0)

- Lift the DAG-only restriction for specific feedback motifs with a defined
  estimand and propagation rule. Cycles remain an error until this lands.
- Design of record: `10-cyclic-feedback.md` — declared feedback motifs, the
  reduced-form / fixed-point equilibrium estimand, sigma-separation, and the
  staged plan (pure-R fixed-point propagation now; consistent IV/joint estimation
  is the engine part).
- Shipped (0.5.0 pure-R grammar + equilibrium engine, `R/feedback.R`):
  `drm_cycle()` / `feedback =` declaration, relaxed toposort (cycles stay an error
  unless declared), `cycles()` accessor, basis-set suppression among motif nodes,
  and the internal `propagate_fixedpoint()` (stability-guarded,
  non-convergence-reporting, recovers `(I − B)⁻¹ Γ`).
- Shipped (0.5.x equilibrium effects): `total_effects()` reports the equilibrium
  total effect of a feedback SEM (`mediation = "equilibrium"`, `target = "mean"`,
  `NA` on divergence); `direct_effects()` (the controlled direct effect) works;
  `indirect_effects()` / `path_effects()` refuse a feedback SEM (the
  mean/distribution decomposition through a cycle is undefined). Remaining: full
  sigma-separation, distributional feedback equilibria, and consistent estimation
  (IV/2SLS or a joint likelihood) — the engine part.

## Interop and distribution

- **Graph-interchange layer — SHIPPED** (pure-R, `R/interop.R`): `as_lavaan()`
  exports a drmSEM graph as lavaan model syntax (mean structure `~` + covariance
  `~~`, with every non-`mu` distributional-component path *dropped-with-notice*,
  never misrepresented as a mean regression); `from_lavaan()` parses lavaan
  syntax back into a `drm_dag()` + `covary()` skeleton (reflective `=~`
  measurement ignored-with-warning); `as_dot()` exports the component-labelled
  DAG as Graphviz DOT (every component path kept). Round-trip
  `from_lavaan(as_lavaan(sem))` recovers the directed mean structure and the
  covariance edges. This is graph interchange, not new engines: brms/lavaan
  *FITTING* interop stays out of scope (drmSEM never fits its own likelihoods),
  and arbitrary brms/glmmTMB/lme4 adapters stay out of scope.
- CRAN submission once the engine surface is stable and integration tests run on
  all platforms (the Grace track in `CLOUD.md`).

## Phylogenetic distributional SEM

See `06-phylogenetic-sem.md` for the staged phylogenetic roadmap (Phase 1 phylo
nodes, Phase 2 model comparison, and Phase 3 fixed-grid evolutionary covariance
via `drm_phylo_cov()` all ship today). **Correction (2026-07-19):** Phase 4
(distributional phylogenetic paths) also ships today — it was framed above as
future work, but `test-phylo-distributional.R` shows it already passes via
generic composition; see the status correction at the top of
`06-phylogenetic-sem.md`. Effect-theory refinements (natural effects, marginal
effects, bootstrap, outcome functionals) are OQ-8..12 in
`../memory/OPEN_QUESTIONS.md`.

## Non-goals (kept off the roadmap deliberately)

- drmSEM fitting its own likelihoods — never; drmTMB is the engine.
- Arbitrary model-backend adapters.
- Replacing lavaan for classical covariance-structure SEM.
