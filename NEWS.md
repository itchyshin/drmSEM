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
* `standardize()` reports effects on link and response scales.

## Diagnostics

* `check_sem()` reports unsupported surfaces, convergence, and sampler coverage.

## Status

Early and experimental; APIs may change before a stable release. Kernel logic is
validated by tests that run without the engine; the full `drmTMB`-integration
path is validated in CI where `drmTMB` is compiled. See the validation ledger in
`docs/memory/VALIDATION_LEDGER.md`.
