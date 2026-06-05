# 00 — Charter: what DRMSEM is

**DRMSEM** is the project/paper name; **drmSEM** is the R package. It adds a
*distributional piecewise structural equation modelling* layer on top of the
`drmTMB` fitting engine (github `itchyshin/drmTMB`).

## Purpose first

Ecological and evolutionary hypotheses are not only about means. "Warmer sites
make body size *more variable*", "habitat raises the *probability of absence*
(zero-inflation), not the mean count", "denser populations reduce *among-site
heterogeneity* in survival" — these are claims about `sigma`, `zi`, and
`sd(site)`, not about `mu`. drmSEM lets a structural path target *any modelled
distributional component* of a node, and keeps that distinction explicit
everywhere: in the graph, the path table, the d-separation test, and the effect
decomposition.

## Engine vs layer (the central split)

- **drmTMB = the fitting ENGINE.** It fits one distributional regression
  (mean, scale, shape, zero-inflation, etc.) per response.
- **drmSEM = the graph / SEM / d-separation / path / effect-decomposition
  LAYER.** It never fits its own likelihoods. Each endogenous node is exactly
  **one drmTMB fit**; the SEM is *piecewise* (a graph of separately fitted
  local models, in the tradition of piecewiseSEM).

Every assumption about drmTMB's return shapes is isolated in the adapter
`R/extractors.R`. No other file touches a drmTMB object directly.

## Distinctive feature: component-labelled paths

A drmSEM edge is the tuple `(from, to, component, link, term)`. The `component`
is the distributional parameter of `to` that `from` targets:

`mu` (mean), `sigma` (residual scale), `nu` (shape), `zi` (zero-inflation
probability), `hu` (hurdle probability), `sd(group)` (random-effect scale),
`rho12` (bivariate residual correlation).

A path to `sigma` is **not** a path to the mean. A path to `zi` is **not** a
path to the conditional mean. A path to `sd(site)` is a path to among-site
heterogeneity. These terms are fixed vocabulary; do not let them drift.

## Niche vs other tools

| Tool | What it is | Relation to drmSEM |
| --- | --- | --- |
| **lavaan** | Classical covariance-structure / latent-variable SEM | Different paradigm; drmSEM is observed-variable and likelihood-based per node. |
| **piecewiseSEM** | Local-estimation SEM with d-separation | Closest cousin. There, distributional parameters are side features; here they are *first-class* path targets. |
| **glmmTMB** | A fitting engine for GLMMs | An engine, not an SEM layer. drmTMB plays the analogous engine role for drmSEM. |
| **dsem** | Dynamic, time-series structural equation models | Temporal/state-space focus; drmSEM is cross-sectional, hierarchical, distributional. |

drmSEM = **observed-variable, hierarchical, distributional, ecological/
evolutionary SEM on drmTMB.**

## Scope for 0.x

**In scope (0.x):**
- Observed-variable, piecewise SEM; one drmTMB fit per endogenous node.
- Component-labelled paths over `mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`,
  `rho12`.
- DAGs only.
- d-separation under the any-component rule; Fisher's C.
- Simulation-based direct, mean-mediated, and distribution-mediated effects.
- Both interfaces: `drm_psem()` (assemble fitted nodes) and `drm_sem()` +
  `drm_node()` (declarative, fits then delegates).

**Out of scope (0.x):**
- Latent variables.
- New likelihoods (drmSEM never fits its own).
- Full joint multivariate SEM (the model is piecewise, not a single joint fit).
- Cyclic / feedback graphs — **cycles are an error**.
- Arbitrary brms / glmmTMB / lme4 adapters or unsupported drmTMB surfaces.

## Canonical example (used throughout the docs)

`size -> abundance -> survival`:

```r
drm_sem(
  size = drm_node(
    drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
    family = stats::gaussian()),
  abundance = drm_node(
    drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
    family = drmTMB::nbinom2()),
  survival = drm_node(
    drmTMB::bf(cbind(alive, dead) ~ abundance + size),
    family = drmTMB::beta_binomial()),
  data = dat)
```

Here `temp` reaches `size` through both `mu` and `sigma`; `habitat` reaches
`abundance` only through `zi`; and the `size -> abundance -> survival` chain
carries both a mean-mediated and a potential distribution-mediated effect.
