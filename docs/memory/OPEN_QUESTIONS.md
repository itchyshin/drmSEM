# OPEN QUESTIONS — drmSEM

Tracked unknowns and unresolved design choices. Resolve into `DECISIONS.md` or a
`VALIDATION_LEDGER.md` entry when answered. Format: `OQ-n — title`.

## OQ-1 — Exact drmTMB family-sampler parameterizations  [RESOLVED 2026-06-04, see D-7]

**Resolution.** drmTMB's response-scale `sigma` is an SD-like scale; count and
proportion dispersions go as `1/sigma^2`. From intercept-only fits (probe log,
CI run 26982805627): nbinom2 `sigma=0.715` with true `size=2` gives `size =
1/sigma^2 = 1.96`; beta `sigma=0.374` with data precision ~7 gives `phi =
1/sigma^2 = 7.15`. Fixed `drm_sample_family()` (`size = 1/sigma^2`; beta `phi =
1/sigma^2`). lognormal (`meanlog = log(mu)` via the log mu-link) and Gamma
(`shape = 1/sigma^2`) were already correct. Verified numerically (nbinom2 var
21.5 vs 21.6; beta var 0.0296 vs 0.0301) and asserted in `test-oq1-samplers.R`.
beta_binomial sampling is still unimplemented (mediator falls back to its mean);
tracked separately. Original notes below.

`drm_sample_family()` must draw from each family with the *same* parameterization
drmTMB uses, or distribution-mediated effects will be biased. Unconfirmed against
a live fit:

- **nbinom2**: is the dispersion the `size` (theta) of `rnbinom(mu, size)`, and
  does drmTMB expose it on the same scale? (`nbinom2` mean-variance: `var = mu +
  mu^2/size`.)
- **beta_binomial**: where do the number of **trials** come from for prediction
  (from the `cbind(alive, dead)` row totals?), and how are the two shape/overdispersion
  parameters parameterized?
- **lognormal**: is `sigma` the `sdlog` (log-scale SD) and `mu` the meanlog, or
  is `mu` already on the response scale?

Blocks V-19. Resolve by inspecting `predict_parameters()` output and the family
definitions on a real drmTMB fit.

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

## OQ-4 — Standardization scale conventions

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

## OQ-5 — Expose path-specific effects beyond a mediator set?

`indirect_effects(..., through = )` routes through a *set* of mediator nodes. We
do not currently decompose by individual *path* (e.g. separating
`X -> M1 -> Y` from `X -> M2 -> Y` when both exist), nor by the specific
*component* a distribution-mediated effect flows through. Question: is set-level
routing sufficient for the target audience, or do we need per-path / per-component
effect attribution? This interacts with how distribution-mediated effects are
attributed when a mediator has several non-mean components.

## OQ-6 — Fisher's C calibration under the any-component augmentation

The any-component d-separation test augments every component of Y with X, so the
LRT df can be larger than the mean-only case, and the independence-claim
p-values may not be uniform under the null in finite samples. We have not
established the Type-I rate or power of Fisher's C under this scheme. Blocks
V-17. Resolve by a simulation study before promoting d-sep to "validated".

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

## OQ-11 — Outcome functionals beyond the mean  [PARTIAL 2026-06-05]

**Implemented:** `total_effects(..., target = c("mean","p_gt","p_zero","var"),
threshold=)` simulates the outcome and reports the effect on that functional of
the outcome distribution (Poisson `p_zero` kernel-verified in
`test-effect-kernels.R`). Distribution-mediated effects are most compelling on
functionals other than the mean — `Pr(Y > t)`, `Pr(Y = 0)`, `Var(Y)`, quantiles
— since a path that moves only `sigma`/`zi` may leave `E[Y]` nearly unchanged
while sharply changing a tail or zero probability, and the simulation engine
already produces realized outcome draws. OPEN: extend `target` to
`direct_effects`/`indirect_effects`, add more functionals (quantiles) and
analytic (non-simulated) functionals, and decide the default reporting scale and
CI construction. This is the headline for Phase 4 (distributional phylogenetic
SEM, see `06-phylogenetic-sem.md`).

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
bidirected-edge rule). Remaining open items (all need a **live bivariate drmTMB
fit**, so they stay in the Codex lane):

- `drm_pair()` bivariate node type (fits two responses jointly; `covary()` is the
  declaration primitive it will emit).
- `rho12(fit)` / `corpairs(fit)` accessors that read the *fitted* residual /
  random-effect correlations back from a live bivariate fit.
- Double-headed / dashed covariance arcs in `plot(sem, show = "all")` (needs
  rendering to validate).
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
