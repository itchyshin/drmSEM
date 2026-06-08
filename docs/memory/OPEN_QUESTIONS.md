# OPEN QUESTIONS — drmSEM

Tracked unknowns and unresolved design choices. Resolve into `DECISIONS.md` or a
`VALIDATION_LEDGER.md` entry when answered. Format: `OQ-n — title`.

## OQ-1 — Exact drmTMB family-sampler parameterizations  [RESOLVED 2026-06-07 for V-57..V-60; family extensions remain below]

**Closeout (2026-06-07).** The live single-row probe and promoted
`test-recovery-samplers.R` assertions close the reported sampler-variance bug for
the common families:

- nbinom2, beta, and Gamma still use drmTMB's SD-like `sigma` with native
  dispersion `1/sigma^2` (`size`, `phi`, and `shape`, respectively).
- The aggregate V-57..V-59 failures were caused by drmSEM's prediction engine
  omitting fitted default dpars such as `sigma` when the user did not declare an
  explicit `sigma ~ ...` formula, forcing `drm_sample_family()` to fall back to
  `sigma = 1`.
- lognormal was genuinely mis-parameterized: current drmTMB exposes `mu` as
  `meanlog` with identity link and `sigma` as `sdlog`. drmSEM now samples with
  `rlnorm(meanlog = mu, sdlog = sigma)` and propagates the expected response
  `exp(mu + sigma^2 / 2)` under mean mediation.

V-57..V-60 now assert mean and variance against `drmTMB::simulate()` rather than
skipping on mismatch. `inst/validation/sampler-dispersion-probe.R` remains as a
drift diagnostic.

**Resolution (2026-06-04, refined above).** drmTMB's response-scale `sigma` is an
SD-like scale; count and proportion dispersions go as `1/sigma^2`. From
intercept-only fits (probe log, CI run 26982805627): nbinom2 `sigma=0.715` with
true `size=2` gives `size = 1/sigma^2 = 1.96`; beta `sigma=0.374` with data
precision ~7 gives `phi = 1/sigma^2 = 7.15`. Fixed `drm_sample_family()` (`size =
1/sigma^2`; beta `phi = 1/sigma^2`). Gamma `shape = 1/sigma^2` remains correct.
The lognormal part was corrected on 2026-06-07 as described above.
beta_binomial sampling is still unimplemented (mediator falls back to its mean);
tracked separately. Original notes below.

`drm_sample_family()` must draw from each family with the *same* parameterization
drmTMB uses, or distribution-mediated effects will be biased. Unconfirmed against
a live fit:

- **nbinom2**: resolved for V-57 (`size = 1/sigma^2`; `var = mu + mu^2/size`).
- **beta_binomial**: where do the number of **trials** come from for prediction
  (from the `cbind(alive, dead)` row totals?), and how are the two shape/overdispersion
  parameters parameterized?
- **lognormal**: resolved for V-60 (`mu = meanlog`, `sigma = sdlog`).

Remaining family-extension work is zero_one_beta boundary inflation, tweedie,
student `nu`, and beta_binomial trials/overdispersion.

## OQ-2 — Does model.matrix() contrast coding match drmTMB's internal coding?

`drm_fixed_design()` rebuilds each component's design matrix with standard
`model.matrix()` contrasts and aligns columns to the stored `dpar:term`
coefficient names. If drmTMB uses non-default contrasts or a different factor
expansion, the rebuilt `eta = X %*% beta` will be wrong even though the
coefficients are right. Blocks V-18. Resolve by comparing a rebuilt design matrix
against drmTMB's own on a factor-heavy fit. (See D-6.)

## OQ-3 — Node-name vs response-variable matching for cbind() responses

A node is matched by its identifiers: node name, response label, and response
vars. For `cbind(alive, dead)`, the response vars are `alive` and `dead` and the
label is the deparsed `cbind(alive, dead)`. We prefer matching downstream
references by **node name** (`survival`), but matching on the bare `alive`/`dead`
columns also resolves. Edge cases to pin down: a downstream formula that uses
`alive` directly; collisions between a column name and a node name; multivariate
responses sharing a column. Documented as a known edge in `01-semantics.md`.

## OQ-4 — Standardization scale conventions  [RESOLVED 2026-06-06, see D-15]

**Resolution (conventions finalized + documented, `docs/design/08-standardization.md`,
`?standardize`):** report on the **link scale only** (no back-transform); **factor
predictors keep SD = 1** (raw per-contrast effect, lavaan `std.nox` convention —
existing behaviour, now documented); **`latent` is per-component** so `sigma`/`zi`
paths standardize on their own link scale (the correct and only latent-scale
standardization for a non-`mu` component). Two refinements remain open and need a
live-fit cross-check before changing behaviour/tests: (1) add the theoretical-
variance term `sigma_E` (e.g. `pi^2/3` for logit) to the `latent` divisor for
non-identity-link **mu** paths — current `sd(eta)` mildly over-standardizes GLM
mean paths (Grace et al. 2019 / piecewiseSEM `latent.linear`); (2) a Gelman (2008)
2-SD opt-in for continuous-vs-factor comparability as an explicit argument.
Original questions below.

**Update 2026-06-07 — refinement (1) shipped for constant-variance links.** The
`latent` divisor of a **mu** path now adds the theoretical link variance
`sigma_E^2` for the links where it is a constant — logit `pi^2/3`, probit `1`,
cloglog `pi^2/6` (`drm_link_latent_var()` / `drm_latent_divisor()` in
`R/standardize.R`), closed-form validated by **V-44** (no engine). Still open:
the **log-link** families' *mean-dependent* (observation-level) latent variance,
the Gelman 2-SD opt-in, and an optional live-GLM-fit confirmation of the full
pipeline (a Codex nice-to-have; the math is already closed-form locked).

`standardize()` offers `sd_x` (multiply by predictor SD) and `latent` (also
divide by the SD of the component's fitted linear predictor, after Grace &
Bollen). Open:

- For **factor** predictors `sd_x` uses SD = 1 (no rescaling); is that the
  convention we want, or should we report per-contrast standardized effects?
- The `latent` denominator uses the linear-predictor SD per `(node, component)`;
  confirm this is the intended latent-scale standardization for non-`mu`
  components (e.g. standardizing a `sigma` or `zi` path).
- Should standardized effects be reported on the link scale only, or also
  back-transformed?

## OQ-5 — Expose path-specific effects beyond a mediator set?  [PARTIAL 2026-06-06, see D-17/D-19]

**Partial.** `path_effects(object, from, to, through=)` ships the **per-mediator**
decomposition (D-17, V-32): `inclusion(Mj) = T({Mj}) - direct` and
`exclusion(Mj) = T(all) - T(all \ Mj)`, plus `total_indirect` and an explicit
`interaction_remainder` that is ~0 only in the additive case and is never forced
to sum. Pure active-set toggling, no new kernel; kernel-verified in
`test-path-effects.R` (additive P-1, nonlinear-non-additive P-2, sequential P-3).
Honest scope: model-based attribution, not nonparametric path-specific
identification (recanting-witness criterion). `path_effects(by = "component")`
ships the **per-component** split — `mean_channel` + `sigma_channel`/`zi_channel`/...
(each via `drm_freeze_engine()`, freezing that component at its x0 value) + a
`component_remainder` for the non-separable part — kernel-verified against the
lognormal closed forms (V-34). **Still open:** the cross-world natural variant with
a recanting-witness guard; the `identified` flag is kernel-verified (V-35).
**Still open:** `NA` handling for unconfirmed-sampler families and a live-fit
integration test (real-family sampler accuracy) before broad promotion.
Original note below.

`indirect_effects(..., through = )` routes through a *set* of mediator nodes. We
do not currently decompose by individual *path* (e.g. separating
`X -> M1 -> Y` from `X -> M2 -> Y` when both exist), nor by the specific
*component* a distribution-mediated effect flows through. Question: is set-level
routing sufficient for the target audience, or do we need per-path / per-component
effect attribution? This interacts with how distribution-mediated effects are
attributed when a mediator has several non-mean components.

## OQ-6 — Fisher's C calibration under the any-component augmentation  [RESOLVED 2026-06-06]

The any-component d-separation test augments every component of Y with X, so the
LRT df can be larger than the mean-only case, and the independence-claim
p-values may not be uniform under the null in finite samples.

**Scaffolded (2026-06-06).** The study is fully designed (DGP ladder: mean-only /
distributional `zi`-`sigma` / cross-link; `n` in {100,250,500,1000}; reps;
Type-I + uniformity + power; the centrepiece diagnostic is empirical Type-I
**stratified by augmented-component count** `q`). The precomputed vignette
(`vignettes/calibration.Rmd`, never fits) and the live-drmTMB regeneration script
(`inst/calibration/generate.R`, produces
`inst/calibration/calibration-results.rds`) are in place; the cache must be
generated in the Codex/live-drmTMB lane (outside the CI budget). The 20-rep
`test-calibration.R` remains the fast smoke check only.

**Acceptance criteria for V-17 (explicit 2026-06-06).** Promote only if all five
pass in `cal$acceptance`: (1) every family x n x beta cell has at least 95% ok
finite claim p-values; (2) every beta=0 family x n Type-I estimate lies inside
the 99% binomial Monte-Carlo band around alpha; (3) every beta=0 family x
augmented-component-count (`claim_df`) Type-I estimate lies inside the same band;
(4) null Fisher's C p-values have KS p >= 0.01 and median p in [0.40, 0.60]; and
(5) power is high and ordered: beta=0.8 gives power >= 0.80 in every family x n
cell, beta=0.5 gives power >= 0.70 for n >= 250, and power is nondecreasing aside
from at most 0.05 Monte-Carlo jitter.

**Resolution.** Codex generated the cache on 2026-06-06 with live `drmTMB`
0.1.3.9000 at Git SHA `17b1321` and `drmSEM` 0.2.0.9000 at git SHA `c951d31`.
The full grid (3 DGP families x 4 sample sizes x 6 omitted-edge strengths x 200
reps = 14,400 replicates) completed with all finite ok claims. All five C1-C5 checks in
`cal$acceptance` passed: Type-I by family/n stayed in the 99% binomial
Monte-Carlo band (range 0.025-0.080), Type-I by family/claim_df passed
(`claim_df=1`: 0.0525 and 0.05625; `claim_df=2`: 0.045), null Fisher's C
p-values were uniform enough (KS p = 0.631, median p = 0.499), and power was 1.0
for beta=0.8 in every cell and beta=0.5 for n>=250. V-17 is validated for this
OQ-6 grid; do not generalize beyond these DGP families without a new calibration
study.

## OQ-7 — `TMB::sdreport` returns NaN standard errors on the canonical test DGP

CI run 26981892600 fit the integration DGP and drmTMB warned `NaNs produced`
from `TMB::sdreport` for the `size -> abundance -> survival` nodes (3 warnings,
one per `make_sem()`), i.e. a non-positive-definite Hessian / NaN SEs on at least
one node. Tests still passed. Mitigated (not root-caused): `drm_draw_beta()` now
falls back to the point estimate for non-finite vcov blocks, and the effect tests
assert finite estimates. Open: WHICH node/parameter is unidentified — likely the
`sigma ~ temp` Gaussian scale or the `beta_binomial` overdispersion at n=300 —
and whether a better-conditioned DGP (larger n, gentler scale slope) removes the
warning. Needs a live drmTMB session to bisect by node. Until then the canonical
example inherits NaN SEs, so Monte-Carlo effect intervals there collapse to point
estimates.

## OQ-8 — Natural (cross-world) vs controlled direct/indirect effects  [PARTIAL 2026-06-05]

**Implemented:** `indirect_effects(..., effect = "natural")` returns natural
direct / natural indirect / total + `mediated_interaction`, validated on the
identity-link linear-Gaussian recovery (cross-world kernel verified in
`test-effect-kernels.R`). The Pearl/Imai natural effects use cross-world
counterfactuals: `NDE = E[Y(x1,M(x0))] - E[Y(x0,M(x0))]`, `NIE =
E[Y(x0,M(x1))] - E[Y(x0,M(x0))]`, holding the mediator at its predicted
`M(x0)`/`M(x1)` distribution; `indirect_effects(effect = "controlled")` keeps the
prior split (mediators at observed values, `indirect = total - direct`). See
`02-effect-calculus.md`. OPEN: general cross-world identification under arbitrary
links / interactions, an integration test on a live nonlinear fit, CIs, and
harmonizing with the `method`/`uncertainty` surface (OQ-12).

## OQ-9 — Marginal (population-averaged) effects through random-effect scale

The effect engine currently propagates with random effects held at zero, so
reported direct/indirect/total effects are **conditional** (RE = 0), not the
marginal mean `E_b[g^{-1}(eta+b)]`. This means a causal path *into* a
random-effect scale — e.g. `X -> sd(group)` or a path into `sd(species)` under a
phylogenetic node — cannot be expressed as an effect on the response, because
integrating it out requires marginalizing over the RE distribution. Open: add a
`marginal = TRUE` / `population = c("conditional","marginal")` option that
integrates over the fitted RE distribution (needs drmTMB to expose the RE
variance components and a way to draw/integrate them on the response scale).
Until then, `sd(group)` paths appear in `paths()` but have no entry in the effect
decomposition, and this is documented as a conditional-effects limitation (see
`02-effect-calculus.md`, `06-phylogenetic-sem.md`). Needs a live drmTMB session
to confirm the ranef variance API.

## OQ-10 — Bootstrap uncertainty (speed Tier 5)

Add `uncertainty = "bootstrap"` (parametric/nonparametric, refit per replicate)
as an alternative to the current `MVN(coef, vcov)` coefficient draw for effect
CIs.

## OQ-11 — Outcome functionals beyond the mean  [PARTIAL 2026-06-07 — extended to the whole effect API + quantiles]

**Update 2026-06-07.** `target` now rides the **whole effect surface**:
`direct_effects()`, `total_effects()`, **and `indirect_effects()`** take
`target = c("mean","p_gt","p_zero","var","quantile")` with `threshold=` (for
`p_gt`) and **`prob=`** (for the new `quantile` functional). For
`indirect_effects(effect = "controlled")` every leg reports the contrast on the
functional and the mean-/distribution-mediated split still closes
(`indirect = mean_mediated + distribution_mediated`). A real bug was fixed in the
process: `drm_functional_target()` hardcoded `"distribution"` mediator
propagation, so the mean- vs distribution-mediated legs were identical for a
non-mean target (the split collapsed); it now honours the passed `mediation`,
making the decomposition non-degenerate. Kernel-verified in
`test-effect-kernels.R` (quantile recovers a sigma-path tail effect; the
functional legs are non-degenerate and close) and `test-recovery-samplers.R`
(V-62..V-64 live-fit `p_zero`/`var`/`p_gt`). `effect = "natural"` stays mean-only
(cross-world functional contrast is open, see OQ-8); a feedback SEM stays
mean-only (equilibrium response).

**Update 2026-06-07 (b).** **Analytic (non-simulated) functionals** now ship:
`direct_effects()` / `total_effects()` take `functional = c("simulate",
"analytic")`; `"analytic"` returns a closed-form functional of the predicted
params (no MC noise) for **gaussian** and **poisson** (`var`/`p_gt`/`p_zero`/
`quantile`), requires mean mediation, and aborts for other families (their
`sigma`↔dispersion scale is OQ-1). Kernel-verified exact in `test-effect-kernels.R`
(V-76). **Still open:** closed forms for the dispersion families once OQ-1 is
settled, the natural/cross-world functional variant, and a live-fit functional
recovery beyond V-62..V-64. Original note below.

**Update 2026-06-08 — multiple quantiles in one call.** `direct_effects()` /
`total_effects()` now accept a **vector `prob`** with `target = "quantile"`,
returning a quantile *curve*: one row per probability with an added `prob`
column, all sharing a single seed so the curve is internally coherent. A scalar
`prob` keeps the historical one-row schema unchanged. `prob` is validated
(`drm_check_prob()`): a vector is rejected for non-quantile targets and for the
decomposing `indirect_effects()` (one row per quantity), and probabilities must
lie strictly in (0, 1). `plot.drm_effect()` labels each curve row by its
probability. Tested in `test-effect-api.R` (validation paths run without an
engine; the live curve is `skip_if_not_installed`).

**Implemented (2026-06-05):** `total_effects(..., target = c("mean","p_gt","p_zero","var"),
threshold=)` simulates the outcome and reports the effect on that functional of
the outcome distribution (Poisson `p_zero` kernel-verified in
`test-effect-kernels.R`). Distribution-mediated effects are most compelling on
functionals other than the mean — `Pr(Y > t)`, `Pr(Y = 0)`, `Var(Y)`, quantiles
— since a path that moves only `sigma`/`zi` may leave `E[Y]` nearly unchanged
while sharply changing a tail or zero probability, and the simulation engine
already produces realized outcome draws. This is the headline for Phase 4
(distributional phylogenetic SEM, see `06-phylogenetic-sem.md`).

## OQ-12 — Effect API harmonization  [RESOLVED 2026-06-06, see D-13]

**Resolution.** The unified surface ships in `R/effects_api.R`:
`direct_effects()`, `total_effects()`, and `indirect_effects()` share
`uncertainty = c("parametric","none","bootstrap")`, `nsim`, and `population =
c("conditional","marginal")`; `total_effects()` adds `method =
c("gcomp","simulate")`; `target` is now on `direct_effects()` as well as
`total_effects()`. `drm_effect_controls()` / `drm_resolve_mediation()` map these
onto the unchanged engine knobs (`mediation`/`draw`/`B`/`n_sim`). The old
`mediation`/`draw`/`n_sim` remain as **deprecated aliases** (warn, new arg wins).
Not-yet-implemented choices abort early with an OQ pointer: `uncertainty =
"bootstrap"` (OQ-10) and `population = "marginal"` (OQ-9). The pure-R
normalizers are unit-tested in `test-effect-api.R` (no drmTMB), and new-vs-old
parity + early-abort are CI-gated in the same file. `indirect_effects()`
intentionally has no `method` (it needs both legs). Original note below.

Surface `indirect_effects(..., method = c("gcomp","simulate"), uncertainty =
c("none","parametric","bootstrap"), nsim, population, target)` mapping onto the
existing `mediation`/`draw`/`B`/`n_sim` engine without changing the kernels, so
the effect-function argument surface is unified across `direct_effects()`,
`indirect_effects()`, and `total_effects()`.

## OQ-13 — d-separation augment-refit of a structured (phylo/animal/relmat) node  [RESOLVED 2026-06-05, see D-entry / VALIDATION_LEDGER]

**Resolution.** `dsep()` could not augment-refit a node carrying a structured
term because the `tree`/pedigree object was not resolvable in the refit (claims
returned `status="refit_failed"` and dropped out of Fisher's C). Fixed
drmSEM-side: `drm_sem()`/`drm_psem()` capture the specification environment
(`fit_env = parent.frame()`); `dsep()` passes it to `drm_refit_augmented(...,
env = object$fit_env)`, which builds the augmented formula and refits via
`do.call(..., envir = env)`, so the tree resolves and the `phylo()` term is
preserved. Phylo d-sep claims now return `status="ok"` with a real LRT p-value
and contribute to Fisher's C. Validated on live drmTMB (CI run 27006262081
green; asserted in `tests/testthat/test-phylo.R`). No drmTMB change required
(see `DRMTMB_ISSUES.md`).

## OQ-14 — First-class bivariate covariance edges (rho12 / corpairs) + d-sep awareness  [PARTIAL 2026-06-06, see D-14]

First-class support for bivariate models and their covariance edges, deferred to
post-0.1 (see D-12, `07-bivariate-covariance-edges.md`). drmSEM 0.1 already
extracts `x -> rho12` as a directed-path component from a bivariate drmTMB fit
given to `drm_psem()`, but the covariance-edge machinery does not exist.

**PARTIAL (pure-R grammar layer shipped, `R/covariances.R`, kernel-validated in
`test-covariances.R`):** `covary(y1, y2, level=)` declares a residual (`rho12`)
or higher-level (`corpair`) covariance edge; `drm_sem()`/`drm_psem()` take a
`covariances =` argument and store the validated edges in a `$covariances` slot
(never in `$edges`); `covariances(sem)` reports residual vs higher-level edges
separately, kept out of directed-only `paths()`; and `basis_set()`/`dsep()` drop
the `y1 _||_ y2` independence claim for any declared covariance pair (Shipley's
bidirected-edge rule).

**Update 2026-06-07 — the declaration grammar, accessors, and plotting now ship
(`R/pair.R`, `test-pair.R`; `R/plotting.R`, `test-plotting.R`):** `drm_pair()`
declares a bivariate node (two response formulas + families, optional `rho12 ~ x`,
auto-detected `corpair` level), `drm_expand_pair()` bridges it onto `covary()`,
the `rho12()` / `corpairs()` accessors report the declared edges (with
`estimate = NA` by construction), and `plot(sem, show = "all")` draws
double-headed (residual) / dashed (higher-level) covariance arcs. Remaining open
items now need only a **live bivariate drmTMB fit** (the Codex lane):

- The joint bivariate *fit* itself (estimating `rho12` in one drmTMB model);
  `drm_pair()` is the declaration primitive it consumes.
- `rho12(fit)` / `corpairs(fit)` returning a *fitted* (non-`NA`) correlation read
  back from a live bivariate fit.
- Deep level-compatibility validation (both nodes actually share the declared
  grouping + a compatible covariance structure) — needs RE-block introspection.

Original open items below:

- A `drm_pair()` bivariate node type returning two response sub-nodes (e.g.
  `activity`, `boldness`) plus the extra covariance structure
  (`rho12(activity, boldness)`, `corpair(id: activity, boldness)`).
- A `covariances(sem)` accessor that separates **residual** (`rho12`,
  `eps_y1 <-> eps_y2`) and **higher-level** (`corpair`, `u_*,y1 <-> u_*,y2`)
  correlations from directed `paths()` (which stays directed-only); plus
  `rho12(fit)` / `corpairs(fit)` accessors that **query the fitted object** and
  expose only correlations actually present (no assumed empty blocks).
- Double-headed-arc plotting in `plot(sem, show="all")`: solid arrows (directed),
  double-headed arcs (residual `rho12`), dashed arcs (higher-level `corpair`).
- The **level-compatibility rule**: estimate/report a higher-level correlation
  only among random effects sharing the same level + grouping index + compatible
  covariance structure (OK: `id-y1<->id-y2`, `species-phylo-y1<->species-phylo-y2`,
  `site-mu<->site-sigma`; NOT generally OK: `site<->species`, `phylo<->spatial`,
  unrelated cross-model blocks).
- Making `basis_set()` / `dsep()` **covariance-aware**: skip the
  `y1 _||_ y2 | predictors` independence claim whenever a residual or RE
  covariance edge between `y1` and `y2` is declared (the model explicitly allowed
  them to remain associated). Directed edges (incl. `x -> rho12`) still enter the
  path algebra; covariance edges are allowances the d-sep machinery must respect.

Needs a **live bivariate drmTMB fit** to validate (cannot be tested in the dev
container).

## OQ-15 — Composite-construct follow-ups (0.3)

The 0.3 first increment ships composite (formative) constructs (`drm_composite()`,
`loadings()`, `composites=` on `drm_sem()`/`drm_psem()`; D-16, V-31). Open items:

- **Indicator interventions.** A composite is frozen in the data, so the effect
  engine cannot propagate an intervention on an *indicator* through the construct
  (intervene on the construct instead). Propagating from indicators needs
  `drm_build_scenarios()` to re-derive the construct column. Needs a live fit to
  validate end-to-end.
- **Measurement arcs in `plot()` — SHIPPED 2026-06-07.** `plot.drm_sem(show =
  "all")` now draws each composite's indicators pointing into the construct as
  steel-blue measurement edges, with indicators as distinctly-filled nodes and a
  legend row, visually distinct from structural paths and covariance arcs
  (`R/plotting.R`; tested in `test-plotting.R` via the legend helper + a
  null-device render). Aesthetic layout of indicator nodes is best confirmed on a
  live render.
- **Reflective constructs** (a latent common cause with a measurement model) need
  a joint likelihood drmTMB does not fit piecewise — deferred to 0.4 / lavaan
  interop, not 0.3 (D-16).
- **Standardized loadings / construct reliability — SHIPPED 2026-06-07.**
  `loadings()` now adds a `std_loading` column (each indicator's correlation with
  the construct score, valid for fixed and PCA composites; `NA` when data is
  unavailable), and a new `reliability()` accessor reports per-construct `alpha`
  (Cronbach), `ave` (mean squared standardized loading), and `prop_var`. Both
  documented honestly as reflective-measurement diagnostics (a formative composite
  is defined by its weights regardless). Pure-R, tested in `test-composite.R`.
