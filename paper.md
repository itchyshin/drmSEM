---
title: "drmSEM: distributional piecewise structural equation modelling for ecology and evolution"
tags:
  - R
  - structural equation modelling
  - ecology
  - phylogenetics
  - distributional regression
authors:
  - name: Shinichi Nakagawa
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Affiliation placeholder
    index: 1
date: 5 June 2026
bibliography: paper.bib
---

# Summary

`drmSEM` is an R package for **distributional piecewise structural equation
modelling (SEM)**. A structural path in `drmSEM` need not target the *mean* of a
response: it can target any modelled component of that response's distribution —
its scale (`sigma`), shape (`nu`), zero-inflation probability (`zi`), hurdle
probability (`hu`), random-effect scale (`sd(group)`), or the residual
correlation between the two responses of a bivariate node (`rho12`). This lets
ecologists and evolutionary biologists state and test
hypotheses such as "warmer sites make body size *more variable*" or "habitat
raises the *probability of absence*, not the mean count" as first-class causal
claims rather than as nuisance terms.

The package is a thin **layer** over the `drmTMB` fitting **engine** [@drmTMB]:
`drmSEM` never fits its own likelihoods. Each endogenous node is exactly one
`drmTMB` distributional regression fit, the system is *piecewise* in the
tradition of `piecewiseSEM` [@Lefcheck2016], and the directed graph must be
acyclic. On top of that engine, `drmSEM` supplies component-labelled path
tables, an any-component d-separation test combined by Fisher's C
[@Shipley2009], a simulation-based effect calculus that decomposes total effects
into direct, mean-mediated, and *distribution-mediated* parts, and a first phase
of phylogenetic distributional SEM. Effects are computed by Monte-Carlo
intervention over the fitted DAG, following the counterfactual mediation
framework of @Pearl2001 and @Imai2010, never by multiplying coefficients.

# Statement of need

Ecological and evolutionary SEM today forces a choice between paradigms, none of
which addresses distributional structure as a causal target. `lavaan`
[@Rosseel2012] performs covariance-structure, latent-variable, largely Gaussian
SEM. `piecewiseSEM` [@Lefcheck2016] estimates each structural equation locally
and tests the model with d-separation, but its paths act only on the mean.
`glmmTMB` [@Brooks2017] fits rich distributional generalized linear mixed models
— means, dispersion, zero-inflation — but it is a single-response fitting engine,
not an SEM. `dsem` [@dsem] targets dynamic, time-series structural models.
In the phylogenetic comparative setting, `phylopath` [@vanderBijl2018] does
confirmatory path analysis under phylogenetic covariance, and `phylosem`
[@phylosem] fits joint phylogenetic SEM; both, however, concern relationships
among trait *means*.

The gap is the intersection: a **distributional, hierarchical, and
phylogenetic** SEM in which a path can target scale, shape, zero-inflation,
hurdle probability, random-effect scale, or residual correlation, and in which
the consequences of such a path can be propagated to a downstream response.
`drmSEM` fills that gap. Because each node is a full distributional regression,
"X is irrelevant to Y" becomes a statement about Y's *whole conditional
distribution*, and an indirect effect can flow through a mediator's variance or
zero probability — a channel that mean-only tools either report as zero or
silently fold into the mean.

# Functionality

**Component-labelled paths.** A `drmSEM` edge is the tuple
`(from, to, component, link, term)`. The `component` is the distributional
parameter of the target node that the predictor acts on. `paths()` returns one
row per fitted fixed-effect coefficient across all nodes, each tagged with its
component and link, so a `temp -> sigma(size)` claim about *spread* is never
reported, plotted, or aggregated as a mean effect.

**Any-component d-separation and Fisher's C.** A missing arrow `X -> Y` asserts
that `X` predicts *none* of Y's modelled components. `basis_set()` enumerates the
implied independence claims; `dsep()` tests each by refitting Y's node with `X`
added to *every* component sub-formula and comparing to the base node with a
likelihood-ratio test (`df` equal to the number of added coefficients).
`fisher_c()` combines the claim p-values into Fisher's C [@Shipley2009] on `2k`
degrees of freedom. The any-component definition is a deliberate, novel research
choice; its OQ-6 calibration grid (mean-only, distributional, and cross-link
DGPs; `n` from 100 to 1000; 200 replicates per cell) met the pre-specified
Type-I, augmented-component-count, Fisher-uniformity, and power criteria. Broader
Fisher's C and d-separation settings remain claim-scoped until separately tested.

**Simulation-based direct, indirect, and total effects.** Coefficient products
are valid only on a single linear identity-link scale; `drmSEM` paths cross links
and flow through non-mean components, where products have no response-scale
meaning. Effects are therefore computed by counterfactual Monte-Carlo
propagation [@Pearl2001; @Imai2010] over the fitted DAG in topological order,
with random effects held at zero. A mediator passes either its expected mean
(mean mediation) or a **realized draw** from its fitted family (distribution
mediation). `indirect_effects()` reports `total_path`, `direct`, `indirect`,
`mean_mediated`, and `distribution_mediated`, where the
distribution-mediated row isolates exactly the contribution that no
coefficient-product method can express. By default `direct` is a **controlled
direct effect** (mediators held at their observed values) and the total/indirect
split is simulation-based; these coincide with the natural direct and indirect
effects only under linearity with no exposure-mediator interaction. For the cases
where they diverge, `indirect_effects(effect = "natural")` additionally returns
the cross-world **natural** decomposition — `natural_direct`, `natural_indirect`,
and `mediated_interaction` — in the mediation-analysis tradition of @Pearl2001
and @Imai2010, validated against the linear-Gaussian recovery case. Effects are
reported on the response scale of the target, and `total_effects(target = ...)`
reports the same distribution-mediated effects on outcome **functionals** beyond
the mean — `Pr(Y > t)`, `Pr(Y = 0)`, and the variance of `Y` — the headline
estimands of distributional SEM, also recovery-tested (e.g. the `p_zero` effect
recovers the Poisson zero-probability change).

**Phylogenetic distributional SEM (Phase 1).** `drmTMB` exports structured-effect
markers (`phylo()`, `animal()`, `relmat()`, `spatial()`). `drmSEM` recognizes
these markers and excludes them from the causal edge set, so a node may carry a
phylogenetic random effect today while `paths()`, `dsep()`, `fisher_c()`, and the
effect engine operate on the fixed-effect DAG. This covers the `phylopath` niche
[@vanderBijl2018] within a distributional engine. Building on this, `drmSEM` also
ships phylopath-style confirmatory model comparison — `drm_dag()` and
`drm_model_set()` define a candidate set, `compare()` ranks the candidates by a
small-sample-corrected information criterion (CICc) built on Fisher's C, and
`best()` / `average()` return the top model and CICc-weighted model-averaged
paths — and `drm_phylo_cov()`, which constructs the phylogenetic relatedness
matrix under a fixed evolutionary model (Brownian motion, Pagel's lambda or
kappa, or Ornstein-Uhlenbeck) for a node to consume via `relmat()`. Jointly
estimating that evolutionary parameter, a phylogenetic-covariance-aware model
comparison, and phylogenetic paths into distributional components are on the
roadmap.

**Built on `drmTMB`.** Every assumption about the engine's return shapes is
isolated in a single adapter, so `drmSEM` re-uses, rather than re-implements,
`drmTMB`'s likelihoods, link functions, and family samplers.

A short, illustrative usage sketch (not executed here):

```r
library(drmSEM)

sem <- drm_sem(
  size      = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
                       family = stats::gaussian()),
  abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
                       family = drmTMB::nbinom2()),
  survival  = drm_node(drmTMB::bf(survival ~ abundance + size),
                       family = drmTMB::nbinom2()),
  data = dat
)

paths(sem)        # component-labelled path table
fisher_c(sem)     # any-component d-separation goodness-of-fit
indirect_effects(sem, from = "temp", to = "survival")  # incl. distribution-mediated
```

# Scope

`drmSEM` is honest about its boundaries. The current release is
**observed-variable, piecewise, and DAG-only**: one `drmTMB` fit per endogenous
node, no cycles, and no latent variables. A path can already target a bivariate
node's residual correlation (`rho12`, the residual coupling `eps_y1 <-> eps_y2`,
not a directed `y1 -> y2` path). The bivariate covariance-edge *grammar* and
d-separation *awareness* ship as a pure-R layer: `covary()` declares a residual
(`rho12`) or higher-level (`corpair`) random-effect covariance edge,
`covariances()` reports those edges separately from `paths()`, and d-separation
drops the `y1 _||_ y2` claim for a declared pair. Only the joint bivariate *fit*
— a `drm_pair()` node, fitted-correlation read-back (`corpairs()`), and
double-headed-arc rendering — remains on the roadmap, alongside latent-variable
and full joint (single-likelihood) multivariate SEM. None of the roadmap items
are in the current scope, and `drmSEM` never introduces new likelihoods of its
own.

# Acknowledgements

We thank the developers of `drmTMB`, and the `piecewiseSEM`, `phylopath`, and
`phylosem` communities whose conventions `drmSEM` builds on.

# References
