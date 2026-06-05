# PROJECT MEMORY — drmSEM / DRMSEM

Durable scientific memory. Read this before working on drmSEM. It states what the
project *is* and the invariants no agent may break. Details live in the design
docs (`docs/design/`); this is the stable core.

## What DRMSEM means

**DRMSEM** is the project/paper name; **drmSEM** is the R package. It is a
*distributional piecewise structural equation modelling* layer: observed-variable,
hierarchical, distributional SEM for ecology and evolution, built on top of the
`drmTMB` fitting engine.

## The engine/layer split (central)

- **drmTMB = the fitting ENGINE** (github `itchyshin/drmTMB`). It fits one
  distributional regression — mean, scale, shape, zero-inflation, etc. — per
  response.
- **drmSEM = the graph / SEM / d-separation / path / effect-decomposition
  LAYER.** It **never fits its own likelihoods.** Each endogenous node is exactly
  **one drmTMB fit**; the SEM is *piecewise*.
- Every assumption about drmTMB's return shapes is isolated in the adapter
  `R/extractors.R`. No other file touches a drmTMB object directly.

## The component vocabulary (do not let it drift)

A drmSEM edge is a tuple `(from, to, component, link, term)`. The `component` is
the distributional parameter of `to` that `from` targets:

`mu` (mean), `sigma` (residual scale), `nu` (shape), `zi` (zero-inflation
probability), `hu` (hurdle probability), `sd(group)` (random-effect scale),
`rho12` (bivariate residual correlation).

A path to `sigma` is **not** a path to the mean. A path to `zi` is **not** a path
to the conditional mean. A path to `sd(site)` is a path to among-site
heterogeneity. These are component-labelled paths; keep the labels explicit in
code, prose, plots, and output.

## The effect taxonomy (key novelty)

- **Direct**: `X -> mu(Y)`.
- **Mean-mediated**: `X -> mu(M1) -> mu(M2) -> mu(Y)`.
- **Distribution-mediated**: `X -> sigma(M) -> distribution(M) -> mu(Y)` — an
  indirect effect flowing through a mediator's *scale / zero-inflation / shape*,
  visible only when realized mediator draws propagate through a downstream
  nonlinearity. It has no coefficient-product analogue and motivates the whole
  simulation engine.

Effects are computed by Monte-Carlo do()-style propagation over the fitted DAG in
topological order, **never** by multiplying coefficients on non-Gaussian or
cross-link paths.

## Canonical example (use throughout)

`size -> abundance -> survival`:

```r
drm_sem(
  size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
                  family = stats::gaussian()),
  abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
                       family = drmTMB::nbinom2()),
  survival = drm_node(drmTMB::bf(cbind(alive, dead) ~ abundance + size),
                      family = drmTMB::beta_binomial()),
  data = dat)
```

`temp` reaches `size` through both `mu` and `sigma`; `habitat` reaches
`abundance` only through `zi`; the chain carries mean-mediated and potential
distribution-mediated effects.

## Invariants agents must not break

1. drmSEM never fits its own likelihoods. One drmTMB fit per endogenous node;
   the SEM stays piecewise.
2. All drmTMB-shape assumptions stay in `R/extractors.R`.
3. Never call a non-mean path a mean effect. Component labels are load-bearing.
4. DAGs only. Cycles are an **error**, not a warning.
5. Effects are simulation-based for non-Gaussian / cross-link paths; no
   coefficient-product mediation there.
6. d-separation uses the any-component definition: a missing arrow X → Y means X
   affects *no* modelled component of Y.
7. Out of scope for 0.x: latent variables, new likelihoods, full joint
   multivariate SEM, cyclic/feedback graphs, arbitrary brms/glmmTMB/lme4 adapters.
8. Semantics changes update the relevant design doc; validated/experimental
   claims update `VALIDATION_LEDGER.md`; durable choices go in `DECISIONS.md`.

## Public API (exact names)

`drm_node`, `drm_sem`, `drm_psem`, `paths`, `basis_set`, `dsep`, `fisher_c`,
`direct_effects`, `total_effects`, `indirect_effects`, `standardize`,
`check_sem`, `plot`.
