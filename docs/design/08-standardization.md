# 08 — Standardized path coefficients

How `standardize()` rescales component-labelled path coefficients, and the
conventions finalized for 0.2/0.3 (OQ-4). Code: `R/standardize.R`. If these
conventions change, this file changes.

## What `standardize()` does

`paths()` returns one fitted coefficient per (node, component, term) on that
component's link scale. `standardize()` adds a `std.estimate` column under one of
two scalings and two standardization bases, **both reported on the link scale**:

- **`sd_x`** — multiply the coefficient by the SD (or 2 SD under `scale = "2sd"`)
  of its predictor: `b * sx`. The link-scale change in the component per one-SD
  (or 2-SD) change in the predictor.
- **`latent`** — additionally divide by the total latent SD of that component's
  fitted linear predictor (incorporating theoretical link error variance):
  `b * sx / sqrt(Var(eta_component) + sigma_E^2)`, where
  `eta_component = X_component %*% b_component`. This is the latent-scale
  standardization of Grace & Bollen (2005) and Grace et al. (2018), generalized
  **per component** so a `sigma` or `zi` path is standardized on its own link scale.

## Finalized conventions (OQ-4 fully resolved)

These resolve OQ-4. They match the established ecosystem (lavaan, piecewiseSEM)
and Gelman (2008) recommendations.

### (a) Factor predictors & binary indicators use SD = 1 (default)

A factor / dummy coefficient or binary {0, 1} indicator is reported as its **raw
per-contrast effect** (the change in the component for that level vs the reference),
not multiplied by any column SD. This is lavaan's `std.nox` convention and matches
piecewiseSEM, which does not SD-rescale categorical predictors. Multiplying a 0/1
indicator by its Bernoulli SD $\sqrt{p(1-p)}$ yields a data-dependent number that
is *not* "one SD of a construct" and is not comparable across factors with different
level balance.

### (b) Gelman (2008) 2-SD standardization (`scale = "2sd"`)

Under `scale = "2sd"`, *continuous* predictors are scaled by **$2 \times \text{SD}(X)$**,
while factor dummies and binary {0, 1} indicators retain a scale multiplier of 1.
This places continuous and binary predictors on a directly comparable footing:
a 2-SD shift in a symmetric continuous variable spans the middle 50–80% of its
distribution, corresponding to a 0-to-1 categorical transition (Gelman 2008).

### (c) `latent` is per-component

For a non-`mu` component there is no observed response whose SD is meaningful, so
full bivariate standardization (`b * sd_x / sd_y`) is undefined. The `latent`
divisor — the SD of the component's *own* linear predictor — is therefore the
correct and only available latent-scale standardization for `sigma`, `zi`,
`sd(*)`, etc., and drmSEM applies it per `(node, component)`. Standardizing
distributional-component paths this way is drmSEM's distinct contribution: lavaan,
piecewiseSEM, dsem, and MuMIn/partR2 all standardize only the mean/outcome.

### (d) Link scale only

Standardized coefficients are reported on each component's link scale, where the
linear-predictor algebra and the latent-variance decomposition are valid. They
are **not** back-transformed: under a nonlinear link a standardized coefficient
has no constant response-scale counterpart (the response-scale effect is
non-constant). The `link` column of `paths()` makes the scale self-documenting.
For response-scale and functional interpretations, use the effect engine
(`direct_effects()`, `total_effects(target = )`), which is built for exactly that.

## GLM mean paths: theoretical link variance ($\sigma_E^2$)

For a **`mu`** path on a generalized link, the `latent` divisor is
$\text{SD}(y^*) = \sqrt{\text{Var}(\eta) + \sigma_E^2}$, adding the
distribution-specific theoretical error variance of the link's threshold or
observation-level distribution:
- **Logit**: $\sigma_E^2 = \pi^2 / 3 \approx 3.290$ (standard logistic distribution)
- **Probit**: $\sigma_E^2 = 1.0$ (standard normal distribution)
- **Cloglog**: $\sigma_E^2 = \pi^2 / 6 \approx 1.645$ (Gumbel distribution)
- **Log**: $\sigma_E^2 \approx \log(1 + 1 / \bar{\mu})$ where
  $\bar{\mu} = \text{mean}(\exp(\eta))$, from the observation-level delta-method
  approximation (Nakagawa & Schielzeth 2010; Grace et al. 2018).
- **Identity**: $\sigma_E^2 = 0$.

For `sigma`/`zi`/`sd(*)` components — and for identity-link `mu` — the plain
$\text{sd}(\eta)$ form is used (the component's own link scale).

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
- Nakagawa S, Schielzeth H (2010). A general and simple method for obtaining $R^2$
  from generalized linear mixed-effects models. *Methods Ecol. Evol.* 4(2):133-142.
