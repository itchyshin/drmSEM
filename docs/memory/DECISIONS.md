# DECISIONS — drmSEM

Dated log of durable choices and their rationale. Append, do not rewrite. Newest
last within a date is fine. Format: `[YYYY-MM-DD] D-n — title`.

---

## [2026-06-04] D-1 — Interface = BOTH (`drm_psem` core, `drm_sem` wrapper)

**Decision.** Two entry points over one shared object:
- `drm_psem(..., data = NULL)` is the **core**: it accepts already-fitted
  `drmTMB` objects, named one per node.
- `drm_sem(<name> = drm_node(bf(...), family = ...), ..., data = )` is the
  **declarative wrapper**: it fits each node with drmTMB, then delegates to the
  same core object.

**Rationale.** Power users who already have fitted models assemble a SEM with no
refitting; new users get a single declarative call. Both produce the identical
`drm_sem` object, so all downstream methods (`paths`, `dsep`, effects) have one
implementation. `drm_node()` is the per-node spec (`formula`, `family`, ...).

## [2026-06-04] D-2 — d-separation = ANY MODELLED COMPONENT

**Decision.** A missing arrow X → Y asserts X has no effect on **any** modelled
distributional component of Y. Tested by refitting Y's node with X added to
**every** modelled component sub-formula (`mu`, `sigma`, `zi`, ...) and a
likelihood-ratio test vs the base node: `df` = number of added terms,
`LR = 2*(ll_aug - ll_base)`. Fisher's C = `-2*sum(log p)` on `2k` df.

**Rationale.** drmSEM models whole conditional distributions, not just means, so
"X is irrelevant to Y" must be a statement about the whole distribution. This is
drmSEM's **definition** of a missing arrow, not a borrowed standard, and is an
open research choice (calibration study pending). Adjacency is correspondingly
any-component: an arrow into `zi(Y)` alone still makes X adjacent to Y.
Documented in `docs/design/03-dsep.md`. Code: `R/dsep.R`, `R/extractors.R`.

## [2026-06-04] D-3 — Effects = SIMULATION, never coefficient products

**Decision.** Direct/indirect/total effects use Monte-Carlo do()-style
propagation over the fitted DAG in topological order. Each node turns predictors
into response-scale parameters (own linear predictor + inverse link, **random
effects held at 0**), then passes downstream either its mean (mean-mediated) or a
realized family draw (distribution-mediated). Coefficient uncertainty comes from
MVN draws from each node's `vcov`. Coefficient products are **rejected** for
non-Gaussian / cross-link paths.

**Rationale.** The product-of-coefficients identity is exact only on a single
linear identity-link scale. drmSEM paths cross links and flow through non-mean
components, where products have no response-scale meaning. Simulation is also the
only way to express the **distribution-mediated** effect at all. Documented in
`docs/design/02-effect-calculus.md`. Code: `R/effects.R`,
`R/simulate_effects.R`.

## [2026-06-04] D-4 — Naming: drmSEM (package) / DRMSEM (project & paper)

**Decision.** The R package is **drmSEM**; the project and paper are **DRMSEM**.
Companion to `drmTMB` (lower-case engine). Keep the casing consistent in code,
docs, and citations.

## [2026-06-04] D-5 — igraph used for plotting layout only

**Decision.** `plot.drm_sem()` uses `igraph` solely to compute a layered DAG
layout (`layout_with_sugiyama`) and draw edges. drmSEM does not depend on igraph
for any graph *logic* — topological sort, ancestors, simple paths, and basis-set
construction are pure base R in `R/utils.R` / `R/dsep.R`.

**Rationale.** Keeps the core graph machinery dependency-light and testable
without igraph; confines igraph to an optional plotting nicety.

## [2026-06-04] D-6 — model.matrix() contrast-coding assumption for design rebuild

**Decision.** When drmSEM rebuilds a fixed-effect design matrix for effect
propagation and standardization (`drm_fixed_design` in `R/extractors.R`), it
assumes drmTMB codes fixed effects with standard `model.matrix()` contrasts, then
aligns/zero-fills columns to the fitted coefficient names (`dpar:term`).

**Rationale.** drmSEM never re-solves the model; it only needs a design matrix
consistent with the stored coefficients. The assumption is isolated in the
adapter so a single fix suffices if drmTMB's coding differs. Confirming this
against a live drmTMB fit is an open question (OQ).

## [2026-06-04] D-7 — drmTMB `sigma` is SD-like; dispersions are 1/sigma^2

**Decision.** In `drm_sample_family()`, map drmTMB's response-scale `sigma` to
each family's native dispersion as: nbinom2 / truncated_nbinom2 `size = 1/sigma^2`
(var = mu + mu^2*sigma^2); beta precision `phi = 1/sigma^2` (shape1 = mu*phi,
shape2 = (1-mu)*phi); Gamma `shape = 1/sigma^2` (sigma is the CV); lognormal
`meanlog = log(mu)`, `sdlog = sigma` (mu uses the log link, so the engine's mu is
exp(meanlog)); gaussian/student `sigma` is the SD.

**Rationale.** Confirmed against live drmTMB intercept-only fits (OQ-1, CI run
26982805627): predict_parameters reported nbinom2 `sigma=0.715` for a true
`size=2` (1/0.715^2=1.96) and beta `sigma=0.374` for precision ~7 (1/0.374^2=7.15).
The earlier `size = 1/sigma` / beta `phi = sigma` were wrong and biased
distribution-mediated effects through count/proportion mediators. Asserted by
`test-oq1-samplers.R` (sampler moments vs data moments). Resolves OQ-1.

## [2026-06-04] D-8 — Plotting: igraph DAG + ggplot2 effect forest plot

**Decision.** Two plot surfaces, both with optional dependencies gated at call
time: (1) `plot.drm_sem()` keeps the component-styled DAG on `igraph`
(`layout_with_sugiyama`, matching dsem); to gain on peers it should later add
standardized-coefficient edge labels and dash non-significant edges
(piecewiseSEM `ns_dashed` / dsem `value_and_stars` idiom). (2) New
`plot.drm_effect()` draws the direct / mean-mediated / distribution-mediated /
indirect / total decomposition as a horizontal forest plot (point + MC interval,
zero reference line), gated on `ggplot2` (Suggests), with the distribution-
mediated channel coloured separately. Do NOT add DiagrammeR / ggdag / ggraph /
tidySEM as dependencies — borrow their conventions in vignette recipes only.

**Rationale.** Landscape scan (Jason): piecewiseSEM (`plot.psem`, DiagrammeR),
dsem (`plot.dsem`, igraph/ggraph), and lavaan/semPaths all plot the path diagram
but NONE plots the effect decomposition — that is left as a table. The only
precedent is `mediation::plot.mediate` (a forest plot). So the effect-
decomposition forest plot is drmSEM's distinctive visual, and the
distribution-mediated row is the part no other tool can show.

## [2026-06-04] D-9 — Gamma `sigma` is the coefficient of variation (link = log)

**Decision.** drmTMB Gamma requires `Gamma(link = "log")`; its `sigma` is the
coefficient of variation, so `drm_sample_family()` uses `shape = 1/sigma^2`
(var = mu^2 * sigma^2), which was already correct. Tests fit Gamma with
`stats::Gamma(link = "log")`.

**Rationale.** Confirmed verbatim by drmTMB's own error in CI run 26983569684:
"The implemented Gamma contract is log(mu) = X_mu beta_mu and log(sigma) =
X_sigma beta_sigma, where sigma is the coefficient of variation." Completes D-7.

## [2026-06-05] D-10 — Effects are counterfactual contrasts, not coefficient products

**Decision.** drmSEM defines direct/indirect/total effects as model-implied
counterfactual contrasts of predicted response distributions, estimated by
Monte-Carlo g-computation over the fitted DAG (Pearl 2001; Robins & Greenland
1992; Imai, Keele & Yamamoto 2010). The product-of-coefficients identity is only
the linear-Gaussian, identity-link, mean-only special case and is used solely as
a validation check (recovery test V-15). Current `total_path` is exact
g-computation; the `direct`/`indirect` split is currently controlled (CDE
baseline) with the natural NDE/NIE split now IMPLEMENTED via
`indirect_effects(effect = "natural")` (OQ-8 PARTIAL), validated on the
linear-Gaussian recovery case. Documented in `02-effect-calculus.md`.

**Rationale.** Across mixed links and non-mean components, `a*b` has no
response-scale meaning, and `E[f(M)] != f(E[M])` means a path on a mediator's
sigma/zi/nu can carry a real indirect effect with zero mu path — the
distribution-mediated channel, expressible only by simulation.

## [2026-06-05] D-11 — Phylogenetic scope = distributional, piecewise, on drmTMB structured effects

**Decision.** drmSEM targets phylogenetic *distributional* SEM, piecewise, with
shared ancestry entering each node via drmTMB's `phylo()`/`animal()`/`relmat()`/
`spatial()` structured effects (which drmSEM already strips from causal edges).
It covers the phylopath niche (Phases 1-2) and part of phylosem (Phase 3), but
does NOT promise a joint phylogenetic SEM likelihood, multi-trait imputation,
cyclic structures, or joint OU/lambda/kappa estimation in 0.x (we ship a FIXED
grid via `drm_phylo_cov()`, shipped in Phase 3). Roadmap in
`06-phylogenetic-sem.md`.
