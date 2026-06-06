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

---

## Maintainer charter (2026-06-06) — the reason drmSEM exists

> Recorded verbatim from the maintainer as the project's statement of intent.
> This is the vision/charter; shipped-vs-roadmap status is tracked in
> `VALIDATION_LEDGER.md` and `OPEN_QUESTIONS.md`, the API specifics in
> `docs/design/` (esp. `02-effect-calculus.md`, `07-bivariate-covariance-edges.md`).

drmSEM is not a clone of lavaan, piecewiseSEM, phylopath, or phylosem. It is a new
framework for distributional, multilevel, piecewise structural equation modelling
using drmTMB as the fitting engine.

**Central idea:** paths may target different components of a response
distribution, not only the conditional mean:

```
X -> mu(Y)        effect on expected Y
X -> sigma(Y)     effect on residual scale / heterogeneity
X -> zi(Y)        effect on structural-zero probability
X -> hu(Y)        effect on hurdle probability
X -> nu(Y)        effect on tail heaviness / shape
X -> sd(group)    effect on group-level variation
X -> rho12(Y1,Y2) effect on residual coupling between two responses
```

drmSEM is therefore not "SEM with GLMMs" — it is **distributional SEM**.

### Core theoretical rule
Do NOT define indirect effects by multiplying coefficients except in the special
linear-Gaussian, identity-link case. Coefficient products fail here because paths
may be on different link scales and target different distributional components
(a `sigma(M)` coefficient is not a mean effect; a `zi(M)` coefficient is not an
abundance effect; a `rho12` coefficient is not a causal arrow). The effect
calculus must be model-implied counterfactual prediction (simulation / numerical
g-computation).

### Effects are endpoint-specific
There is no single universal "total effect." Always ask **total effect on what?**
Endpoints include mean(Y), variance(Y), sd(Y), median(Y), an upper quantile,
Pr(Y=0), Pr(Y>threshold), Pr(Y<extinction threshold), or the whole predictive
distribution. The default endpoint may be mean(Y) but the mean is never implied to
be the only relevant endpoint. A distributional pathway `X -> sigma(M) -> Y` can
move mean(Y), variance(Y), tail risk, or threshold probability, because for
nonlinear downstream models `E[f(M)] != f(E[M])`. Separate **mechanism** (what
component did X affect?) from **endpoint** (what feature of Y are we summarizing?).

### Simulation = counterfactual prediction
Simulation means estimating model-implied counterfactual contrasts, not vague
fake data. For `X -> M -> Y`, the indirect effect compares predicted Y with M
generated as if X=x1 vs as if X=x0 (X held at x0); the total effect compares Y
under X=x1 (all downstream mediators at x1) vs X=x0. Speed tiers:
(1) deterministic g-computation, (2) parameter simulation from vcov,
(3) mediator-distribution simulation, (4) parametric bootstrap,
(5) nonparametric bootstrap. Default fast and practical (g-comp + parametric
uncertainty, nsim ~500; nsim=100 exploratory, >=1000 for final inference);
bootstrap refitting optional, not default.

### paths() vs effects() are different
`paths()` reports local, component-specific, often link-scale model coefficients
(`X -> mu(M)`, `X -> sigma(M)`, `M -> mu(Y)`, `X -> zi(Y)`). `effects()` reports
scientific contrasts (effect of X on mean(Y), on sd(Y), on Pr(Y>t), on the whole
distribution). Do not conflate them. Target the distinction explicitly:
`paths(sem)`, `direct_effects(sem, target=)`, `indirect_effects(sem, target=)`,
`total_effects(sem, target=c("mean","variance","probability"), threshold=)`,
`effect_profile(sem, targets=c("mean","sd","p_gt"))`.

### Bivariate models, rho12, corpairs
`rho12` is NOT a causal path — it is the residual correlation between two responses
(`eps_Y1 <-> eps_Y2`), drawn as a double-headed residual association, never
`Y1 -> Y2`. Keep three edge classes separate: (1) directed causal/distributional
paths (`X -> mu(Y)`, `M -> mu(Y)`, incl. `X -> rho12`); (2) residual covariance
edges (`eps_Y1 <-> eps_Y2`, label rho12); (3) higher-level random-effect
covariance edges (`u_id,Y1 <-> u_id,Y2`, `u_phylo,Y1 <-> u_phylo,Y2`,
`u_site,mu <-> u_site,sigma`) via a `corpairs()`-style accessor. API:
`paths()` returns directed paths only; `covariances()` returns residual +
random-effect correlations; `plot(sem, show="all")` draws each class distinctly.
(See `07-bivariate-covariance-edges.md`, D-12, OQ-14.)

### Phylogenetic position
Eventually reproduce the useful phylopath-style workflow (model sets, fit/compare/
best/average competing DAGs, plot, phylogenetic structure). The distinctive
contribution is **phylogenetic distributional SEM**: phylogeny included while paths
target mu/sigma/zi/hu/sd()/rho12. Do NOT claim full phylosem replacement in 0.1.

### Version 0.1 scope
INCLUDE: observed-variable SEM; one drmTMB model per endogenous node;
component-labelled paths (mu/sigma/zi/hu/nu, and sd()/rho12 where available); DAG
extraction; path tables; covariance tables; basic d-separation; Fisher's C; direct
effects; simulation-based indirect & total effects; plotting; validation examples.
EXCLUDE for now: latent variables; full joint SEM likelihood; arbitrary cyclic
models; automatic full multivariate SEM; new TMB likelihoods; unvalidated drmTMB
surfaces; coefficient-product mediation as the general method (allowed only as the
linear-Gaussian shortcut / a validation check / educational comparison).

### Design principle for all agents
When unsure, preserve the distinction among: (1) local coefficient,
(2) distributional component, (3) causal path, (4) residual covariance,
(5) higher-level covariance, (6) endpoint-specific effect. Do not collapse them
into one generic "path coefficient." The central scientific promise: **estimate
how predictors and mediators change entire response distributions, not only
expected values, while preserving SEM-style direct/indirect/total decomposition.**
