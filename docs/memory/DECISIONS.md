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

## [2026-06-06] D-12 — rho12 is a residual-correlation component, not a y1->y2 path; covariance edges are a distinct class

**Decision.** `rho12` ("rho one-two") is the **residual correlation between two
responses in a bivariate model**, not a causal path from response 1 to response 2.
A bivariate Gaussian node has components `mu1`, `mu2`, `sigma1`, `sigma2`, `rho12`
with `[y1,y2] ~ MVN([mu1,mu2], Omega)`, `Omega = [[s1^2, rho12*s1*s2],
[rho12*s1*s2, s2^2]]`. drmSEM separates **three distinct edge classes**:

1. **Directed causal/distributional path** (solid arrow) — `y1 -> y2`,
   `x -> mu/sigma/zi(y)`, and `x -> rho12(y1,y2)`. A predictor that *changes* the
   residual correlation IS a legitimate directed path **into** the `rho12`
   component, and is what drmSEM 0.1 already extracts from a bivariate drmTMB fit
   via `drm_psem()`. Contributes to causal paths and indirect effects.
2. **Residual covariance edge** (double-headed arc), `rho12`: `eps_y1 <-> eps_y2`,
   within-observation. NOT a causal arrow.
3. **Higher-level random-effect covariance edge** (double-headed arc):
   `u_id,y1 <-> u_id,y2`, `u_phylo,y1 <-> u_phylo,y2`, `u_site,mu <-> u_site,sigma`,
   between-unit. Surfaced via a `corpairs()`-type accessor.

Classes (2) and (3) are **covariance allowances**: double-headed arcs that
contribute to **neither** directed paths, **nor** mediation/indirect effects, and
that are **distinct from each other** (residual within-observation correlation vs
random-effect between-unit correlation — different biological questions, never
collapsed). First-class bivariate support — a `drm_pair()` node, `covariances()` /
`rho12()` / `corpairs()` accessors, double-headed-arc plotting, and d-sep
covariance-awareness (drop the `y1 _||_ y2 | predictors` basis-set claim when a
covariance edge is declared) — is **deferred to a post-0.1 version**.

**Rationale.** Treating `rho12` as a `y1 -> y2` arrow would invent a direction the
model never asserted and would feed a spurious indirect effect into the path
algebra. A residual correlation is a covariance, exactly like a residual
covariance in classical SEM (Shipley): bidirected, effect-free, but
d-separation-relevant. Spec in `07-bivariate-covariance-edges.md`.

## D-13 — Unified effect-API surface (OQ-12), additive with deprecated aliases

The three effect functions now share one vocabulary (`R/effects_api.R`):
`uncertainty = c("parametric","none","bootstrap")` (→ `draw`), `nsim` (→ `n_sim`),
`population = c("conditional","marginal")`, plus `method = c("gcomp","simulate")`
(→ `mediation`) on `total_effects()` and `target`/`threshold` extended to
`direct_effects()`. `drm_effect_controls()` and `drm_resolve_mediation()` do the
mapping; **no simulation kernel changed**.

**Choices.**
- *Additive, not breaking.* The old `mediation`/`draw`/`n_sim` stay as deprecated
  aliases (a plain `cli_warn`, every call, so the deprecation is reliably
  testable); when both an old and new form are supplied the new one wins with a
  warning. `B` keeps its name (it is the uncertainty-replicate count, a distinct
  loop from the inner `nsim` realizations — collapsing them would change kernel
  behaviour, which OQ-12 forbids).
- *No `method` on `indirect_effects()`.* The controlled decomposition is built
  from both the mean and distribution legs, and the natural split is always
  distribution-mediated; there is no single mean/distribution choice to expose.
  The shared `uncertainty`/`nsim`/`population` controls do apply.
- *Honest "not yet" errors.* `uncertainty = "bootstrap"` (OQ-10) and
  `population = "marginal"` (OQ-9) abort early with a pointer to the open
  question, rather than silently falling back. These aborts fire in
  `drm_effect_controls()` before `drm_require_drmTMB()`, so they are reachable
  (and tested) without a live engine.
- *`target` on `direct_effects()`.* Reuses `drm_functional_contrast()` with an
  empty active set (controlled direct effect on a functional); partially advances
  OQ-11. `target` on `indirect_effects()` stays open (decomposition-on-a-functional
  semantics unsettled).

Validation: pure-R unit tests for the normalizers in `test-effect-api.R`; new-vs-
old parity and early-abort behaviour are CI-gated in the same file. Vignettes and
the 02-effect-calculus design doc were migrated to the new vocabulary.

## D-14 — Covariance-edge grammar ships as a pure-R layer (OQ-14), engine parts deferred

OQ-14 (first-class bivariate covariance edges) is split: the **graph grammar and
d-separation semantics** are pure-R and ship now (`R/covariances.R`); everything
that needs a **live bivariate drmTMB fit** stays on the roadmap.

**Shipped.** `covary(y1, y2, level=)` declares a residual (`rho12`) or
higher-level (`corpair`) edge; `drm_sem()`/`drm_psem()` take `covariances=` and
store validated edges in a `$covariances` slot; `covariances(sem)` reports them
(residual vs higher-level via a `class` column) separately from directed-only
`paths()`; `basis_set()`/`dsep()` drop the `y1 _||_ y2` claim for declared pairs.

**Choices.**
- *Separate slot, never `$edges`.* Covariance edges are allowances, not paths, so
  they live in `$covariances` and cannot leak into `paths()` or the effect
  algebra. A directed `x -> rho12` path is unaffected — it stays a normal
  component-labelled edge in `$edges` (the class-1 vs class-2/3 split of D-12).
- *Declaration over introspection.* `covary()` records the declared
  `level`/`structure` and validates only that both responses resolve to distinct
  nodes. The deep level-compatibility rule (both nodes actually share the
  grouping + a compatible covariance structure) needs to read the fitted RE
  blocks, so it is deferred with the other engine-dependent pieces.
- *Back-compatible.* `drm_covariance_pairs()` treats a missing `$covariances`
  slot as "no edges", so objects built before this slot (and the hand-rolled
  test objects) are unaffected; `basis_set()` is unchanged when no edge is
  declared.
- *Unordered keying.* Covariance pairs are matched on the unordered
  `pmin/pmax` key, so `covary("a","b")` and `covary("b","a")` are the same edge
  and drop the same claim regardless of topological order.

Deferred to the Codex lane (need a live bivariate fit): `drm_pair()` joint
fitting, `rho12(fit)`/`corpairs(fit)` read-back accessors, double-headed-arc
plotting, and deep RE-block level-compatibility validation.

Validation: `test-covariances.R` (pure-R) — covary() construction + validation,
drm_build_covariances() node resolution / labelling / de-dup, covariances()
accessor, and basis_set() dropping the y1 _||_ y2 claim for residual and
higher-level edges. See V-25.

## D-15 — Standardization conventions finalized (OQ-4); non-breaking, documented

The 0.2 "standardization conventions finalized and documented" item. Decisions
(full rationale + citations in `docs/design/08-standardization.md`):

- **Link scale only** is the reporting scale; standardized coefficients are not
  back-transformed (no constant response-scale counterpart under a nonlinear
  link). Response-scale/functional interpretation is the effect engine's job.
- **Factor predictors keep SD = 1** (raw per-contrast effect) — lavaan `std.nox`
  / piecewiseSEM convention. This is the existing behaviour, so **no code change**
  and **no broken tests**; it is now documented rather than implicit. SD-rescaling
  a 0/1 dummy by `sqrt(p(1-p))` was rejected as data-dependent and non-comparable.
- **`latent` is per-component**: `sigma`/`zi`/`sd(*)` paths standardize by the SD
  of their own linear predictor (no marginal outcome SD exists for a non-`mu`
  component). This per-component latent standardization is drmSEM's distinct
  contribution (no other tool standardizes distributional-component paths).

**Deferred (tracked under OQ-4, need a live-fit cross-check before changing
behaviour/tests):** (1) add the distribution-specific theoretical-variance term
`sigma_E` (e.g. `pi^2/3` for logit) to the `latent` divisor for non-identity-link
**mu** paths — current `sd(eta)` mildly over-standardizes GLM mean paths (Grace
et al. 2019 / piecewiseSEM `latent.linear`); (2) a Gelman (2008) 2-SD opt-in for
continuous-vs-factor comparability, as an explicit argument, not a default.

Chose documentation + a non-breaking default over a blind code change because
this lane cannot run R to verify a new standardization denominator against a
fit; the refinements are specified precisely for the engine lane. Recorded the
`sd(eta)`-omits-`sigma_E` finding as a known limitation in `?standardize` and the
design doc rather than silently leaving it undocumented.

## D-16 — 0.3 starts with composite (formative) constructs; reflective deferred

The 0.3 "latent variables" milestone is split. **Composite constructs ship now**
(`R/composite.R`): `drm_composite()` materializes a deterministic weighted-sum
(`fixed`) or first-PC (`pca`) index of observed indicators as a column before
fitting, so it is an ordinary observed variable to the rest of the engine — no
joint likelihood, no drmTMB change. `loadings()` reports the measurement loadings
separately from `paths()`, mirroring the `covariances()` pattern (D-14).

**Choices.**
- *Pre-fit materialization.* The construct column is built before node fitting
  (`drm_apply_composites()` in `drm_sem()`); `drm_psem()` only records the spec
  (the column must already be in the fitted data). The score is recomputed from
  the fitting data via the stored loadings so the reported loadings and the
  materialized column are always consistent.
- *Not a node.* A composite is a derived column, not a fitted node, so it never
  appears in `object$records`/`order`; d-separation therefore generates no
  `indicator _||_ construct` claim (nothing to special-case). Loadings are kept
  out of `$edges`/`paths()`.
- *Honest limitations, documented:* indicators are leaves (intervene on the
  construct, not an indicator); loadings are not yet drawn as measurement arcs.
- *Reflective deferred.* A reflective latent needs a joint measurement likelihood
  drmTMB does not fit piecewise → 0.4 / lavaan interop, not 0.3. A pre-fit
  factor-score plug-in would just be a composite with external weights that
  ignores score uncertainty, so it is not advertised as reflective SEM.

Validation: `test-composite.R` (pure-R) — construction (fixed + pca, sign/prop_var),
scoring, validation errors, `drm_build_composites`/`drm_apply_composites`, and the
`loadings()` accessor. See V-31.

## D-17 — OQ-5 ships per-mediator attribution first; per-component/natural deferred

`path_effects()` decomposes the indirect effect by mediator using only active-set
toggling of the existing engine (`R/path_effects.R`, kernel `drm_path_contrasts`):
`inclusion(Mj) = T({Mj}) - direct`, `exclusion(Mj) = T(all) - T(all \ Mj)`.

**Choices.**
- *Two estimands, both reported.* Inclusion and exclusion answer different
  questions and only coincide when additive; we report both rather than inventing
  one "canonical" per-mediator number.
- *Honesty remainder, never force-sum.* Every call emits `total_indirect` and
  `interaction_remainder = total_indirect - sum(inclusion)`; ~0 in the additive
  case, non-zero otherwise. The per-mediator effects are never rescaled to sum.
- *Model-based, not identified.* Labelled as attribution-by-construction, not a
  nonparametric path-specific effect (which needs the recanting-witness criterion,
  Avin-Shpitser-Pearl 2005). No "validated" wording until a live-fit integration
  test exists.
- *Pure-R testable.* The kernel takes engines, so it is unit-tested with hand-
  built engines + mean mediation + draw=FALSE for deterministic closed forms
  (`test-path-effects.R`: P-1 additive, P-2 nonlinear, P-3 sequential).
- *Deferred (OQ-5 follow-up):* per-component (mu/sigma/zi) attribution needs a
  one-argument `freeze` plumbing change to `drm_propagate` (hold one component at
  its x0 value); the cross-world natural variant needs a recanting-witness guard;
  unconfirmed-sampler families must return NA. These are riskier and wait for a
  careful pass (and a live fit).

Validation: V-32.

Later updates: per-component attribution landed in V-34, and the natural
per-mediator variant with a recanting-witness guard landed in D-19/V-35. The
live-fit integration test remains the promotion gate for broad OQ-5 claims.

## D-18 — V-17 calibration promotion uses explicit C1-C5 cache criteria

The Fisher's C / any-component d-separation calibration claim is promoted only
from the cached OQ-6 study, not from the 20-rep smoke test. The generator stores
the decision in `cal$acceptance`, and the vignette, validation ledger, and OQ-6
record all read the same cache-backed criteria.

**Criteria.** C1 requires at least 95% ok finite d-separation claims in every
family x n x beta cell. C2 requires every beta=0 family x n Type-I estimate to
fall inside the 99% binomial Monte-Carlo band around alpha. C3 repeats that
Type-I check stratified by augmented-component count (`claim_df`). C4 requires
null Fisher's C p-values to pass a coarse uniformity check (KS p >= 0.01 and
median p in [0.40, 0.60]). C5 requires high and ordered power: beta=0.8 power
>= 0.80 in every family x n cell, beta=0.5 power >= 0.70 for n>=250, and power
nondecreasing aside from at most 0.05 Monte-Carlo jitter.

**Scope.** Passing C1-C5 validates V-17 for the OQ-6 grid only: mean-only,
distributional, and cross-link Gaussian chains with n in {100,250,500,1000}.
It does not certify every possible drmSEM graph, family, or multi-component
configuration. New DGP families need their own cache or an explicit ledger note.

## D-19 — OQ-5 natural per-mediator variant reports identification status

`path_effects(effect = "natural")` reports each mediator's cross-world natural
indirect effect by reusing the existing `drm_natural_target` kernel. The result
adds an `identified` column: `FALSE` when another mediator is both a descendant
of the exposure and an ancestor of the target mediator (the recanting-witness
criterion of Avin, Shpitser & Pearl 2005), otherwise `TRUE`.

**Choices.**
- *Keep controlled as the default.* The controlled per-mediator attribution is
  the model-based default; the natural rows are opt-in because they carry a
  stronger cross-world identification interpretation.
- *Report, do not suppress.* Non-identified natural rows are returned with
  `identified = FALSE` rather than being dropped, so users can see which mediator
  route fails the graph criterion.
- *Pure graph guard.* `drm_recanting_witness()` uses the fitted drmSEM graph
  only; it does not inspect fitted coefficients or likelihoods. That keeps the
  identification flag testable without a live engine.

Validation: V-35. Remaining OQ-5 work is the live-fit integration test for real
family sampler accuracy and `NA` handling for unconfirmed-sampler families.
