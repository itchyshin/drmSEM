# 08 — Standardized path coefficients

How `standardize()` rescales component-labelled path coefficients, and the
conventions finalized for 0.2 (OQ-4). Code: `R/standardize.R`. If these
conventions change, this file changes.

## What `standardize()` does

`paths()` returns one fitted coefficient per (node, component, term) on that
component's link scale. `standardize()` adds a `std.estimate` column under one of
two scalings, **both reported on the link scale**:

- **`sd_x`** — multiply the coefficient by the SD of its predictor:
  `b * sd(x)`. The link-scale change in the component per one-SD change in the
  predictor (a "x-standardized" coefficient).
- **`latent`** — additionally divide by the SD of that component's fitted linear
  predictor: `b * sd(x) / sd(eta_component)`, where
  `eta_component = X_component %*% b_component`. This is the latent-scale
  standardization of Grace & Bollen (2005), generalized **per component** so a
  `sigma` or `zi` path is standardized on its own link scale.

## The three finalized conventions (0.2)

These resolve OQ-4. They were chosen to match the established ecosystem (lavaan,
piecewiseSEM) where one exists, and to be the conservative, non-breaking default
elsewhere.

### (a) Factor predictors use SD = 1 (default)

A factor / dummy coefficient is reported as its **raw per-contrast effect** (the
change in the component for that level vs the reference), not multiplied by any
column SD. This is lavaan's `std.nox` convention and matches piecewiseSEM, which
does not SD-rescale categorical predictors (it routes them to estimated marginal
means). Multiplying a 0/1 indicator by its Bernoulli SD `sqrt(p(1-p))` yields a
data-dependent number that is *not* "one SD of a construct" and is not comparable
across factors with different level balance.

**Opt-in alternative (planned, OQ-4):** a Gelman (2008) mode that divides the
*continuous* predictors by **2 SD** while leaving factor dummies on their natural
contrast scale, making continuous and binary paths directly comparable. This is
the one rescaling that is defensible for factor-vs-continuous comparison; it will
be surfaced as an explicit argument rather than changing the default.

### (b) `latent` is per-component

For a non-`mu` component there is no observed response whose SD is meaningful, so
full bivariate standardization (`b * sd_x / sd_y`) is undefined. The `latent`
divisor — the SD of the component's *own* linear predictor — is therefore the
correct and only available latent-scale standardization for `sigma`, `zi`,
`sd(*)`, etc., and drmSEM applies it per `(node, component)`. Standardizing
distributional-component paths this way is drmSEM's distinct contribution: lavaan,
piecewiseSEM, dsem, and MuMIn/partR2 all standardize only the mean/outcome.

### (c) Link scale only (default)

Standardized coefficients are reported on each component's link scale, where the
linear-predictor algebra and the latent-variance decomposition are valid. They
are **not** back-transformed: under a nonlinear link a standardized coefficient
has no constant response-scale counterpart (the response-scale effect is
non-constant). The `link` column of `paths()` makes the scale self-documenting.
For response-scale and functional interpretations, use the effect engine
(`direct_effects()`, `total_effects(target = )`), which is built for exactly that.

## GLM mean paths: the `sigma_E` term (OQ-4, resolved for constant-variance links)

For a **`mu`** path on a link whose latent-scale error variance is a **constant**,
the `latent` divisor is now `sd_y* = sqrt(var(eta) + sigma_E^2)`, adding the
distribution-specific theoretical error variance of the link's threshold
distribution: `sigma_E^2 = pi^2/3` (logit / logistic), `1` (probit / standard
normal), `pi^2/6` (cloglog / Gumbel) (Grace et al. 2018; piecewiseSEM's
`latent.linear`). This corrects the earlier mild **over-standardization** (the
old `sd(eta)`-only denominator was too small). Implemented as
`drm_latent_divisor()` / `drm_link_latent_var()` and validated in closed form
(`test-standardize.R`, V-44: a logit mean path standardizes by
`sqrt(var(eta) + pi^2/3)`).

Still deferred: the **log-link** families (Poisson, negative binomial, Gamma,
lognormal) have a *mean-dependent* (observation-level) latent variance rather
than a constant, so no `sigma_E` term is added for them yet. For
`sigma`/`zi`/`sd(*)` components — and for identity-link `mu` — the plain `sd(eta)`
form is correct (no canonical latent-outcome variance exists), unchanged.

## References

- Grace JB, Bollen KA (2005). Interpreting the results from multiple regression
  and structural equation models. *Bull. Ecol. Soc. Am.* 86(4):283-295.
- Grace JB, et al. (2018). Integrating the causes of biodiversity into structural
  equation models. *Ecosphere* — latent-theoretic standardization for GLM
  outcomes (basis of piecewiseSEM's `latent.linear`).
- Gelman A (2008). Scaling regression inputs by dividing by two standard
  deviations. *Stat. Med.* 27:2865-2873.
- Lefcheck JS (2016). piecewiseSEM: Piecewise structural equation modelling.
  *Methods Ecol. Evol.* 7(5):573-579.
