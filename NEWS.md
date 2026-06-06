# drmSEM 0.0.0.9000 (development)

First development version of **drmSEM** — a distributional piecewise structural
equation modelling layer built on the [`drmTMB`](https://github.com/itchyshin/drmTMB)
fitting engine. drmSEM does not fit its own likelihoods; each endogenous node is
one `drmTMB` fit and the system is piecewise over a DAG.

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
