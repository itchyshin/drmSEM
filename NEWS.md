# drmSEM 0.2.0.9000 (development version)

## Interop (graph interchange)

* **Graph interchange, not a fitting bridge.** A new pure-R interop layer
  (`R/interop.R`) translates a drmSEM component-labelled graph *to and from* the
  neighbouring ecosystems' text formats. drmSEM still never fits its own
  likelihoods, and lavaan/brms *fitting* interop stays out of the 0.x scope.
* `as_lavaan(sem)` (and `as_lavaan(dag)`) emits a **lavaan model-syntax string**:
  one `y ~ x1 + x2` regression per endogenous node (the mean structure) and one
  `y1 ~~ y2` line per declared covariance edge (`covariances()`).
* **Honesty:** lavaan syntax cannot express a distributional-component path (an
  arrow into `sigma`, `zi`, `nu`, `hu`, `sd(group)`, `rho12`). `as_lavaan()`
  therefore **collapses to the mean structure** and reports every dropped non-`mu`
  path — both as a `dropped` attribute and via a one-time `cli` message. A non-mean
  path is **never** silently misrepresented as a lavaan mean regression.
* `from_lavaan(syntax)` parses lavaan syntax back into a drmSEM graph skeleton:
  `~` regressions become per-response node formulas in a `drm_dag()`, and `~~`
  lines become `covary()` declarations. Reflective measurement (`=~`) lines are
  **ignored with a warning** (reflective measurement needs a joint likelihood,
  out of 0.x scope). Pure string parsing — nothing is evaluated or fitted, so
  `from_lavaan(as_lavaan(sem))` round-trips the directed mean structure and the
  covariance edges.
* `as_dot(sem)` (and `as_dot(dag)`) exports the component-labelled DAG as a
  **Graphviz DOT** string: one labelled edge per typed edge, with non-mean paths
  dashed/greyed. Unlike lavaan, DOT keeps **every** component path.

## Feedback / cyclic motifs (0.5.0, grammar + equilibrium engine)

* `drm_cycle("y1", "y2")` declares a **feedback motif**; `drm_sem()` / `drm_psem()`
  gain a `feedback =` argument that accepts it. Cycles remain a hard error
  **unless declared** — a declared motif is condensed into one topological layer,
  so the DAG check still rejects every *undeclared* cycle. `cycles(sem)` lists the
  declared motifs.
* **Honest fitting.** Node-wise ML of a declared cycle is inconsistent under
  simultaneity, so `drm_sem()` **warns**: consistent estimation (IV/2SLS or a
  joint likelihood) is an engine capability, not something drmSEM fakes.
* **d-separation** drops independence claims among a motif's nodes (DAG
  d-separation does not hold across a cycle; full sigma-separation is deferred).
* **Equilibrium total effects (0.5.x).** `total_effects()` now reports the
  **equilibrium** response of a feedback SEM, iterating the mean-propagation map
  to its fixed point (the `mediation` column reads `"equilibrium"`); if the
  feedback diverges (no stable equilibrium, spectral radius `>= 1`) the estimate
  is `NA` with a warning — never a fabricated number. `direct_effects()` (the
  controlled direct effect, which does not traverse the cycle) also works. The
  mean/distribution **decomposition** through a cycle is out of scope, so
  `indirect_effects()` / `path_effects()` refuse a feedback SEM and point to
  `total_effects()`. The internal `propagate_fixedpoint()` carries a
  spectral-radius / max-iter stability guard; closed-form tests confirm it
  recovers the linear reduced form `(I − B)⁻¹ Γ` (V-42) and that the equilibrium
  total effect equals the reduced-form total effect of the exposure (V-43).
  Design: `docs/design/10-cyclic-feedback.md`.

## Effect decomposition: paired Monte-Carlo and honest framing

* **Bug fix (intervals).** `indirect_effects()` now computes the
  controlled-direct, mean-mediated, and distribution-mediated legs from **one
  shared coefficient draw per replicate** (`drm_decomp_legs()`), mirroring the
  natural-effect branch. Previously the three legs were drawn independently, so
  with the default `seed = NULL` the `mean_mediated` / `distribution_mediated`
  **intervals** subtracted unrelated parameter draws and were inflated (not a
  valid paired contrast). Point estimates are unchanged; the reported intervals
  are now common-random-numbers (paired) contrasts that isolate the propagation
  mode.
* **New asserted tests** lock the *shipped* decomposition path (not only the
  kernels): the additive identity `indirect = mean_mediated +
  distribution_mediated` (V-36), the lognormal Jensen-gap closed form and its
  sign flip through `drm_decomp_legs()` (V-37), the linear-outcome zero (V-38), a
  two-mediator chain (V-39), seed reproducibility (V-40), and an end-to-end
  live-fit check that the distribution-mediated channel is real and the
  decomposition closes (V-41).
* **Honest framing.** Documentation now describes `distribution_mediated` as a
  **Jensen-gap / interventional-mediation** term — non-zero only when a higher
  moment of the mediator responds to the exposure **and** the outcome is curved
  in that mediator — identified under the usual mediation assumptions plus a
  correctly specified mediator *distribution*. The novelty is positioned as
  *implementational* (a mediator's `sigma`/`zi`/shape as a first-class causal
  target), with the estimand credited to the interventional/distributional
  mediation literature (Pearl; Imai et al.; VanderWeele 2015; Vansteelandt &
  Daniel 2017).

## Bivariate nodes (0.4, grammar layer)

* `drm_pair()` declares a **bivariate (joint two-response) node** — two response
  formulas, two families, an optional `rho12 ~ x` residual-correlation model (a
  directed path *into* the `rho12` component), and an auto-detected higher-level
  `corpair` edge where the two responses share a grouping level. It is the
  bivariate counterpart of `drm_node()`.
* `drm_expand_pair()` bridges a pair onto the shipped covariance-edge grammar
  (two `drm_node()` sub-nodes + `covary()` edges), so the residual (`rho12`) and
  higher-level (`corpair`) arcs flow through `covariances()` / `basis_set()` /
  `dsep()` unchanged — the documented hook point for the 0.4 joint fit.
* `rho12()` and `corpairs()` accessors report the declared residual and
  higher-level correlation edges (of a `drm_pair` or a `drm_sem`), kept separate
  from `paths()`. **The `estimate` is `NA`:** drmSEM never fits its own
  likelihoods, so reading a *fitted* correlation back needs a live bivariate
  `drmTMB` fit (the 0.4 engine deliverable). The declaration is never a
  fabricated estimate. See `docs/design/07-bivariate-covariance-edges.md`.
* `plot(sem)` now draws **covariance edges as double-headed arcs** — solid grey
  for a residual `rho12`, dashed grey for a higher-level `corpair` — so the three
  edge classes (directed path, residual covariance, higher-level covariance) are
  visually distinct. A new `show = c("all", "paths")` argument toggles the arcs
  off (`"paths"` draws the directed structural edges only).
* New vignette **"Bivariate nodes: two responses, one correlation (`drm_pair`)"**
  walks an animal-personality example (activity & boldness) through `drm_pair()`,
  `print()`, `rho12()`, `corpairs()`, and `drm_expand_pair()`, motivating the
  difference between a directed `activity -> boldness` path and the residual
  `rho12` / higher-level `corpair` covariance arcs. It is emphatic that the
  correlation **estimates are `NA` by construction** — declaring a bivariate node
  is not fitting one, and the joint bivariate `drmTMB` fit is the 0.4 engine step.
  See `docs/design/07-bivariate-covariance-edges.md`.

## Path-specific effects (OQ-5)

* `path_effects(effect = "natural")` reports each mediator's cross-world **natural
  indirect effect**, with an `identified` column flagged `FALSE` under a
  **recanting witness** (another mediator that is a descendant of `from` and an
  ancestor of this one), after Avin, Shpitser & Pearl (2005). The detection is
  pure graph logic; the cross-world computation reuses the validated
  `drm_natural_target` kernel.

## Latent constructs (0.3)

* `drm_composite()` now reports **reliability** (Cronbach's alpha, an
  internal-consistency measure for reflective indicator sets — unclamped, `NA`
  for a single indicator) and accepts `standardize = TRUE` (mean-0 / sd-1 score).
  A new `summary.drm_composite()` shows the loadings table, first-PC variance, and
  reliability. A composite may now be used as a **response** (a node modelling the
  construct), not only a predictor.
* New vignette **"Latent constructs: composites and reliability"** walks through
  formative vs reflective-flavoured (PCA) constructs, construct quality, and
  construct-as-response; reflective *measurement-model* SEM stays out of scope
  (needs a joint likelihood → 0.4), documented in `docs/design/09-latent-variables.md`.

## Calibration (OQ-6)

* The live-drmTMB lane generated `inst/calibration/calibration-results.rds`
  (`drmTMB` 0.1.3.9000, Git SHA `17b1321`, 14,400 calibration replicates). All
  five pre-specified acceptance checks pass, so V-17 is promoted to validated
  for the OQ-6 mean-only / distributional / cross-link calibration grid only;
  broader Fisher's C / d-sep settings remain claim-scoped until separately
  tested.

# drmSEM 0.2.0

Second release. Post-0.1 work: a unified effect-API surface, first-class
covariance-edge and composite-construct grammars, per-mediator and per-component
path attribution, finalized standardization conventions, and a scaffolded
Fisher's C calibration study. The any-component d-separation calibration remains
**experimental** until its (compute-heavy) study is run; everything else is
CI-validated against a live drmTMB or kernel-validated by closed-form tests.

## Documentation

* New vignette **"Covariance edges, composites, and path attribution"** walks
  through `covary()`/`covariances()`, `drm_composite()`/`loadings()`, and
  `path_effects()`. Every exported function now carries an example.

## Path-specific effects (OQ-5, per-mediator)

* `path_effects(object, from, to, through=)` decomposes the indirect effect into
  a per-mediator contribution: an **inclusion** effect (`T({Mj}) - direct`, only
  `Mj` responds) and an **exclusion** effect (`T(all) - T(all \\ Mj)`, `Mj`'s
  marginal given the rest), plus `total_indirect` and an explicit
  `interaction_remainder`. The pieces sum to the total only in the additive case;
  the remainder is reported, never forced to zero. Model-based attribution, not a
  nonparametric path-specific identification claim. The cross-world natural
  variant is the OQ-5 follow-up.
* `path_effects(by = "component")` splits each mediator's effect into a
  `mean_channel` and one channel per non-mean component (`sigma_channel`,
  `zi_channel`, ... -- the drop when that component is frozen at its reference
  value), plus a `component_remainder` for the part that does not separate cleanly
  under a nonlinear outcome.

## Composite latent constructs (0.3, first increment)

* `drm_composite(name, indicators, weights, method = c("fixed", "pca"))` declares
  a **composite (formative) construct** — a weighted sum or first-PC index of
  observed indicator columns. It is materialized as an ordinary column *before*
  fitting, so a node formula can use it as a predictor or response with no engine
  change.
* `drm_sem()` / `drm_psem()` gain a `composites =` argument; `loadings(sem)`
  reports the indicator-to-construct loadings, kept separate from `paths()`.
* Reflective (measurement-model) latent variables remain out of scope (they need
  a joint likelihood); see `docs/design/09-latent-variables.md`.

## Inference hardening (towards 0.2)

* **Analytic effect cross-checks** are now asserted tests (`test-analytic-effects.R`,
  pure-R, no engine): the Gaussian identity-link mean-mediated effect equals the
  coefficient product `a*b*w`; a non-mean (`sigma`) path contributes *exactly*
  nothing to the mean channel and the distribution-mediated effect goes to zero
  when the outcome is linear in the mediator; the distribution-mediated effect
  matches the lognormal closed form (and flips sign) across a downstream
  nonlinearity; natural and controlled effects diverge under an exposure-mediator
  interaction by the predicted amount; and the Poisson `Pr(Y>0)` and Gaussian
  `Var(Y)` outcome-functional effects match their closed forms.
* **Standardization conventions finalized and documented** (OQ-4; see
  `docs/design/08-standardization.md` and `?standardize`): standardized
  coefficients are reported on the link scale only; factor predictors keep SD = 1
  (raw per-contrast effect, lavaan `std.nox` convention); the `latent` divisor is
  per-component, so `sigma`/`zi` paths standardize on their own link scale. A
  Gelman 2-SD opt-in for continuous-vs-factor comparability and a theoretical-
  variance term for GLM mean paths are noted as tracked refinements.
## Covariance edges: rho12 and corpair (OQ-14, grammar layer)

* `covary(y1, y2, level = )` declares a **covariance edge** between two responses
  — a residual correlation (`rho12`, within-observation, `level = NULL`) or a
  higher-level random-effect correlation (`corpair`, between-unit, a grouping
  `level`). Covariance edges are double-headed arcs: they carry no direction and
  no mediated effect.
* `drm_sem()` / `drm_psem()` gain a `covariances =` argument that takes `covary()`
  declarations and validates them against the node records.
* `covariances(sem)` reports residual and higher-level edges **separately**, kept
  out of `paths()` (which stays directed-only, including any `x -> rho12` path).
* `basis_set()` / `dsep()` are now **covariance-aware**: a declared `rho12` /
  `corpair` edge between `y1` and `y2` drops the `y1 _||_ y2 | predictors`
  independence claim (Shipley's bidirected-edge rule).
* This is the pure-R grammar/d-separation layer. `drm_pair()` (joint bivariate
  fitting), `rho12()` / `corpairs()` accessors that read a live fit, and
  double-headed-arc plotting need a bivariate `drmTMB` fit and remain on the
  roadmap (OQ-14).

## Unified effect-API surface (OQ-12)

* `direct_effects()`, `total_effects()`, and `indirect_effects()` now share one
  argument vocabulary: `uncertainty = c("parametric", "none", "bootstrap")`,
  `nsim` (inner distributional realizations), and `population = c("conditional",
  "marginal")`. `total_effects()` selects mediation with `method = c("gcomp",
  "simulate")`.
* The previous `mediation`, `draw`, and `n_sim` arguments are **deprecated
  aliases** — they still work but emit a deprecation warning, and the new
  argument wins when both are supplied. `B` (the number of uncertainty
  replicates) is unchanged. No simulation kernel changed.
* Not-yet-implemented choices fail fast with a pointer to the tracking question:
  `uncertainty = "bootstrap"` (refit bootstrap, OQ-10) and `population =
  "marginal"` (marginalizing over the random-effect distribution, OQ-9).
* `direct_effects()` gains `target` / `threshold`, so a controlled direct effect
  can be read on an outcome functional (`p_gt`, `p_zero`, `var`) as well as the
  mean, matching `total_effects()`.

# drmSEM 0.1.0

First public release of **drmSEM** — a distributional piecewise structural
equation modelling layer built on the [`drmTMB`](https://github.com/itchyshin/drmTMB)
fitting engine. drmSEM does not fit its own likelihoods; each endogenous node is
one `drmTMB` fit and the system is piecewise over a DAG. Causal paths can target
any distributional component (mean, scale, zero-inflation, shape, random-effect
scale, residual correlation), and effects are estimated by Monte-Carlo
counterfactual propagation rather than coefficient products.

## Building a SEM

* `drm_node()` specifies one endogenous node (a `drmTMB` formula + family).
* `drm_sem()` assembles a SEM declaratively, fitting each node, and `drm_psem()`
  assembles one from already-fitted `drmTMB` objects. Both return the same object.

## Component-labelled paths

* `paths()` returns one row per fitted coefficient, labelled by the
  distributional component it targets (`mu`, `sigma`, `nu`, `zi`, `hu`, `sd(*)`,
  `rho12`). A path to `sigma` or `zi` is never reported as a mean effect.
* `plot()` draws the DAG with edges styled by component.

## d-separation (any modelled component)

* `basis_set()`, `dsep()`, and `fisher_c()` test missing arrows. A missing arrow
  asserts X has no effect on *any* modelled component of Y, via a likelihood-ratio
  test of Y's node augmented with X on every component sub-model. Fisher's C
  combines the claim p-values (`C = -2*sum(log p)`, `2k` df).

## Simulation-based effects

* `direct_effects()`, `indirect_effects()`, and `total_effects()` propagate a
  do-style intervention through the fitted DAG by Monte-Carlo, on the response
  scale. Coefficient products are never used across non-Gaussian or cross-link
  paths.
* The indirect decomposition reports `mean_mediated` and `distribution_mediated`
  parts, so effects flowing through a mediator's scale, zero-inflation, or shape
  are visible rather than collapsed into a mean effect.
* `indirect_effects(effect = "natural")` adds the cross-world natural
  decomposition — `natural_direct`, `natural_indirect`, and
  `mediated_interaction` (Pearl; Imai, Keele & Yamamoto) — alongside the default
  controlled-direct / simulation-indirect split, validated on the linear-Gaussian
  recovery case.
* `total_effects(target = c("p_gt", "p_zero", "var"))` reports
  distribution-mediated effects on outcome functionals beyond the mean — `Pr(Y >
  threshold)`, `Pr(Y = 0)`, and `Var(Y)` — with the `p_zero` effect recovery-tested
  against the Poisson zero-probability change.
* `standardize()` reports standardized path coefficients on the component's link
  scale.

## Model comparison (confirmatory model sets)

* `drm_dag()` captures one unfitted candidate causal model (a set of node
  formulas), and `drm_model_set()` collects named candidates into a comparison
  set — drmSEM's analogues of `phylopath::define_model_set()`.
* `compare()` fits every candidate with `drm_sem()`, runs the any-component
  d-separation test, and ranks the candidates by CICc (a small-sample-corrected
  information criterion built on Fisher's C), reporting delta-CICc and Akaike
  weights.
* `best()` returns the lowest-CICc fitted SEM; `average()` returns CICc-weighted
  (conditional) model-averaged standardized path coefficients.

## Phylogenetic covariance

* `drm_phylo_cov()` builds a phylogenetic relatedness matrix from an `ape` tree
  under a fixed evolutionary model (`"BM"`, `"lambda"`, `"OU"`, `"kappa"`),
  ready to feed a node via `relmat(1 | species, K = K)`. The evolutionary
  parameter is fixed by the caller (a grid), not jointly estimated.
* `dsep()` augment-refits phylogenetic nodes correctly, evaluating each refit in
  the SEM's captured fitting environment so structured-effect objects (the tree
  / relatedness matrix) resolve.

## Plots

* `plot.drm_effect()` draws an effect (forest) plot for an effect decomposition.

## Diagnostics

* `check_sem()` reports unsupported surfaces, convergence, and sampler coverage.

## Status

Early and experimental; APIs may change before a stable release. Kernel logic is
validated by tests that run without the engine; the full `drmTMB`-integration
path is validated in CI where `drmTMB` is compiled. See the validation ledger in
`docs/memory/VALIDATION_LEDGER.md`.
