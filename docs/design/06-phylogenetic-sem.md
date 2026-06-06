# 06 — Phylogenetic distributional SEM

drmSEM should cover the **phylopath** niche directly and part of the **phylosem**
niche, but its unique contribution is **phylogenetic _distributional_ SEM**: shared
ancestry enters each node, while direct/indirect/total effects are estimated for
changes in means *and* in variances, zero-inflation, overdispersion,
random-effect scale, and residual coupling — not trait means alone.

Positioning sentence (paper/package):

> Existing phylogenetic SEM tools focus primarily on causal relationships among
> trait means under phylogenetic covariance; drmSEM extends this to distributional
> SEM, where shared ancestry can be incorporated while direct and indirect effects
> are estimated for changes in means, variances, zero probabilities, and other
> response-distribution components.

## The landscape

- **phylopath** — confirmatory phylogenetic path analysis: a model set of DAGs,
  compared under phylogenetic covariance via the d-separation / Fisher's C
  tradition; `define_model_set()`, `phylo_path()`, `best()`, `average()`,
  `plot()`; ranking by C, CICc, ΔCICc, weights. Mean-only.
- **phylosem** — TMB-based *joint* phylogenetic SEM + comparative methods: a
  Brownian-motion base with optional OU / Pagel's-λ / -κ / -δ transformations,
  trait imputation, recursive/cyclic links,
  coercion to `sem`/`phylopath`/`phylobase`. Broader engine, mean/trait focus.
- **drmSEM** — *piecewise distributional* SEM on the drmTMB engine: each
  endogenous node is one drmTMB fit; phylogeny enters as a structured random
  effect; paths may target any distributional component.

## Phase 1 — phylogenetic correction inside piecewise SEM (**already supported**)

drmTMB already exports the structured-effect markers `phylo()`, `phylo_interaction()`,
`animal()`, `relmat()`, `spatial()`. And drmSEM's edge extraction already treats
those as markers: `drmsem_marker_funs()` in `R/utils.R` lists `phylo`,
`phylo_interaction`, `spatial`, `animal`, `relmat`, so `drm_strip_markers()` drops
them from the fixed-effect predictor set. **Consequence:** a node may carry a
phylogenetic random effect *today*, and drmSEM correctly excludes it from the
causal edge set while `paths()`, `dsep()`, `fisher_c()`, and the effect engine
operate on the fixed-effect DAG:

```r
sem <- drm_sem(
  y1 = drm_node(bf(y1 ~ x + phylo(1 | species, tree = tree)), family = gaussian()),
  y2 = drm_node(bf(y2 ~ y1 + x + phylo(1 | species, tree = tree)), family = gaussian()),
  data = dat
)
paths(sem); dsep(sem); fisher_c(sem); indirect_effects(sem, from = "x", to = "y2")
```

**drmTMB phylo constraints (confirmed via API recon):** `tree` is an `ape`
"phylo" object (not a matrix; use `relmat(K=/Q=)` for a precomputed matrix)
and **must be ultrametric** (rescale a raw `ape::rtree()` with
`ape::compute.brlen(tree, "Grafen")`); every `species` level must be a tip
label. drmTMB phylo is a first slice: intercept-only `phylo(1|species)` for
Gaussian and Poisson/NB2 q=1 means — no non-Gaussian phylo *slopes* or slope
correlations yet. `ape` is a test/vignette Suggests, gated on
`requireNamespace("ape")`.

**Phase-1 d-sep refit (RESOLVED, OQ-13):** `dsep()` augment-refits a structured
node by evaluating the refit in the SEM's specification environment
(`object$fit_env`), so the `tree` (and any `animal()/relmat()` object) resolves
and the `phylo()` term is preserved in the augmented model. Phylo d-separation
claims therefore return `status="ok"` with a real LRT p-value and contribute to
Fisher's C — d-separation goodness-of-fit is complete for phylo SEMs. (Earlier
this failed: the tree was not resolvable in the refit, claims returned
`status="refit_failed"` and dropped out of Fisher's C; drmSEM degraded gracefully
without crashing. That limitation is closed.) Validated end-to-end on live drmTMB
in `tests/testthat/test-phylo.R` (asserts `status == "ok"` + finite p-value).

**Phase-1 status:** complete end-to-end — build / `paths()` / `dsep()` /
`fisher_c()` / effects on a live phylo node, a drmTMB-gated integration test, and
a worked vignette (`vignettes/phylogenetic-sem.Rmd`). Effects are conditional
(RE = 0); a path into `sd(species)` needs the marginal option from OQ-9 (see
`02-effect-calculus.md`).

## Phase 2 — phylopath-compatible model comparison

A confirmatory model-set + selection layer over the piecewise core:

```r
models <- drm_model_set(
  direct   = drm_dag(fitness ~ temp + size),
  mediated = drm_dag(size ~ temp, fitness ~ size + temp),
  full     = drm_dag(size ~ temp, abundance ~ size + temp, fitness ~ abundance + size))
fit <- phylo_drm_path(models, data = dat, tree = tree, species = "species",
                      family = list(size = gaussian(), abundance = nbinom2(),
                                    fitness = gaussian()))
summary(fit); best(fit); average(fit); plot(best(fit))
```

Mirrors `define_model_set()`/`phylo_path()`/`best()`/`average()` but with drmTMB
families and component-labelled paths. Selection by Fisher's C, CICc, ΔCICc,
weights — reusing the existing `dsep()`/`fisher_c()` machinery per model.

## Phase 3 — evolutionary covariance models (**implemented, short term**)

`drm_phylo_cov(tree, model = c("BM","lambda","OU","kappa"), ...)` constructs/
transforms the phylogenetic covariance matrix on a fixed λ/OU/κ grid *before* it
enters the structured-effect layer, returning a relatedness matrix to feed a node
via the `relmat()` marker:

```r
K <- drm_phylo_cov(tree, "lambda", lambda = 0.7)   # or "BM" / "OU" (alpha) / "kappa"
sem <- drm_sem(
  y = drm_node(bf(y ~ x + relmat(1 | species, K = K)), family = gaussian()),
  data = dat)
```

The four models all start from the Brownian-motion covariance `C = ape::vcv(tree)`:

- **BM** — `C` unchanged.
- **Pagel's λ** — scale off-diagonals by λ, keep the diagonal: `λ=1`→BM, `λ=0`→star
  phylogeny. Pure matrix transform (`phylo_transform_lambda`).
- **OU** — Martins & Hansen (1997) exponential-decay *correlation*
  `exp(-α · d_ij)` over patristic distance `d_ij = C_ii + C_jj − 2C_ij`: `α→0`
  strong-inertia (all-ones, singular), large `α`→identity. Pure matrix transform
  (`phylo_transform_ou`).
- **Pagel's κ** — raises branch lengths to the power κ before `vcv` (genuinely
  tree-structured, ape-only): `κ=1`→BM.

`standardize = TRUE` (default) returns a correlation-style relatedness matrix
(unit diagonal), the natural input to `relmat()`. The λ/OU/standardise transforms
are pure base R and unit-tested without ape (`test-phylo-cov.R`); the ape (κ, real
tree) and drmTMB (`relmat` node) paths are gated and validated in CI.

**Long term:** estimate λ/OU/κ jointly — a larger engine problem that belongs in
drmTMB, not drmSEM (file upstream if needed).

## Phase 4 — distributional phylogenetic SEM (the novel contribution)

Phylogenetic paths into **distributional** components, e.g.
`temp → sigma(size)` with `sigma ~ temp + phylo(1|species)`, and indirect effects
that flow through a mediator's scale/zero-inflation/shape under shared ancestry:

```r
indirect_effects(sem, from = "temp", through = "sigma(size)", to = "fitness",
                 method = "simulate")
```

This is genuinely new: phylogenetic distributional SEM, reported as effects on
expected fitness, Pr(fitness > t), variance of fitness, zero probability, etc.
(outcome functionals from OQ-11).

## Feature comparison

| Feature | phylopath | phylosem | drmSEM target |
| --- | --- | --- | --- |
| Compare causal DAGs | yes | yes | yes (Phase 2) |
| Phylogenetic correction | yes | yes | **yes (Phase 1, now)** |
| Best / averaged model | yes | yes | Phase 2 |
| Plot fitted DAGs | yes | yes | yes |
| BM covariance | yes | yes | Phase 1/3 |
| OU / λ / κ | limited | yes | **yes (Phase 3, fixed grid)** |
| Missing-trait imputation | no | yes | later |
| Cyclic / non-recursive | no | yes | later (maybe not core) |
| Non-Gaussian responses | some | some | **yes (drmTMB)** |
| Paths to zi / hu | no | no | **yes** |
| Paths to residual sigma | no | no | **yes** |
| Paths to `sd(group)` | no | no | **yes** |
| Simulation distributional indirect effects | no | no | **yes** |
| Full latent-variable SEM | no | limited | not v0.x |

## Honest non-goals (do not promise phylosem parity at first)

Full joint phylogenetic SEM likelihood; automatic multi-trait imputation; joint
multivariate phylogenetic covariance across all traits; cyclic/non-recursive
structures; OU/λ/κ estimated jointly across the whole SEM; phylogenetic factor
analysis / ordination. These require a joint engine, not a piecewise one.
