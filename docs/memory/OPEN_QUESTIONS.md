# OPEN QUESTIONS — drmSEM

Tracked unknowns and unresolved design choices. Resolve into `DECISIONS.md` or a
`VALIDATION_LEDGER.md` entry when answered. Format: `OQ-n — title`.

## OQ-1 — Exact drmTMB family-sampler parameterizations

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
