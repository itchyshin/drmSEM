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

**Implemented:** `indirect_effects(..., effect = "natural")` returns NDE/NIE/
total + `mediated_interaction`, cross-world kernel verified in
`test-effect-kernels.R`. Remaining: an integration test on a live nonlinear fit,
and harmonizing with the `method`/`uncertainty` surface (OQ-12).

`indirect_effects()` currently splits total into a CONTROLLED direct effect
(mediators at observed values) and `indirect = total - direct`. The Pearl/Imai
natural effects use cross-world counterfactuals: `NDE = E[Y(x1,M(x0))] -
E[Y(x0,M(x0))]`, `NIE = E[Y(x0,M(x1))] - E[Y(x0,M(x0))]`. Implement an
`effect = c("controlled","natural")` option that holds the mediator at its
predicted `M(x0)`/`M(x1)` distribution. See `02-effect-calculus.md`.

## OQ-9 — Marginal vs conditional effects over random effects

Effects hold RE = 0 (conditional / typical-group), not the marginal mean
`E_b[g^{-1}(eta+b)]`. Add `population = c("conditional","marginal")` that
integrates over the fitted RE distribution. Required before a path into
`sd(group)` can be given a response-scale marginal effect.

## OQ-10 — Bootstrap uncertainty (speed Tier 5)

Add `uncertainty = "bootstrap"` (parametric/nonparametric, refit per replicate)
alongside the current `MVN(coef, vcov)` parameter draws.

## OQ-11 — Outcome functionals beyond the mean  [PARTIAL 2026-06-05]

**Implemented:** `total_effects(..., target = c("mean","p_gt","p_zero","var"),
threshold=)` simulates the outcome and reports the effect on that functional
(Poisson p_zero kernel-verified in `test-effect-kernels.R`). Remaining: extend to
`direct_effects`/`indirect_effects` and add analytic (non-simulated) functionals.

Report effects on `Pr(Y>t)`, `Var(Y)`, `Pr(Y=0)`, not only the response-scale
mean of `to`. Add `target = c("mean","prob","var","p_zero", ...)`.

## OQ-12 — Effect API harmonization

Surface `indirect_effects(..., method = c("gcomp","simulate"), uncertainty =
c("none","parametric","bootstrap"), nsim, population, target)` mapping onto the
existing `mediation`/`draw`/`B`/`n_sim` engine without changing the kernels.

## OQ-13 — Phylogenetic mode (Phase 1) test + dsep refit fidelity

A phylo node works today (markers are stripped from causal edges), but needs: a
drmTMB-gated integration test fitting `phylo(1|species, tree=)` nodes; a worked
vignette; and confirmation that `drm_refit_augmented()` (d-sep) preserves the
`phylo()` structured term when augmenting a node. See `06-phylogenetic-sem.md`.
