# 02 — Effect calculus: the simulation engine

This document defines how drmSEM computes direct, indirect, and total effects.
The rule is simple and non-negotiable: **effects are computed by Monte-Carlo
do()-style propagation over the fitted DAG, never by multiplying coefficients**
for non-Gaussian or cross-link paths. Code: `R/effects.R` (user-facing) and
`R/simulate_effects.R` (kernels). If effect semantics change, this file changes
(AGENTS.md rule 4).

## Why coefficient products are rejected

The classical mediation identity "indirect = product of path coefficients" is
exact only on a single linear (identity-link) scale. A drmSEM path may cross
links (e.g. a `log`-link `mu` feeding a `logit`-link mean downstream) and may
flow through non-mean components. On those paths the product of coefficients has
no defined response-scale meaning. We therefore *simulate* the intervention and
read off the response-scale change. This also makes the
distribution-mediated effect (below) expressible at all — it has no
coefficient-product analogue.

## Scenarios (the intervention contrast)

`drm_build_scenarios()` builds a paired low/high population from the fitted
data:

- **Numeric `from`**: a one-SD contrast centred on the mean,
  `at = c(mean - 0.5*sd, mean + 0.5*sd)`.
- **Factor `from`**: the first two levels (or first two sorted unique values).
- A user-supplied length-2 `at` overrides both.

The contrast is applied to the *whole data population* (every row gets the low
value, then every row gets the high value), so reported effects are
population-average changes, not effects at a single covariate point.

## Topological propagation and the RE=0 convention

`drm_propagate()` walks the engines in topological `$order`. Each node:

1. Builds its fixed-effect design matrix per component on the current working
   data (`drm_fixed_design()`), forms the linear predictor `eta = X %*% beta`,
   and applies the inverse link (`drm_inv_link()`) to get response-scale
   parameters (`mu`, and any of `sigma`, `zi`, `nu`, ...).
2. **Random effects are held at zero** — population-level / typical-group
   prediction. This is the marginal-effect convention drmSEM uses; it is stated
   in the adapter and is the same convention `predict_parameters()` is asked for.
3. If the node is an *active mediator*, it writes a value into the working data
   for downstream nodes to read; otherwise the scenario's own column value
   stands.

## Mean vs distribution mediation

What an active mediator passes downstream is the crux:

- **Mean-mediated** (`mediation = "mean"`): the mediator passes its expected
  `mu`. Only the mediator's mean carries the signal.
- **Distribution-mediated** (`mediation = "distribution"`): the mediator passes
  a **realized draw** from its family (`drm_sample_family()`), using all of its
  response-scale parameters — `sigma`, `zi`, `nu`, trials, etc. Inner draws are
  averaged over `n_sim` realizations.

## The effect taxonomy (key novelty)

- **Direct**: `X -> mu(Y)`. The controlled direct effect (`direct_effects()`)
  holds all mediators inactive and changes only `X`, so only the arrows from `X`
  directly into `Y` operate.
- **Mean-mediated**: `X -> mu(M) -> mu(Y)`. Appears under mean mediation when
  `M` is active.
- **Distribution-mediated**: `X -> sigma(M) -> distribution(M) -> mu(Y)`. An
  indirect effect flowing through a mediator's *scale / zero-inflation / shape*.
  It is **zero under mean mediation** and only appears when realized mediator
  draws propagate through a downstream nonlinearity. This is the effect type
  that motivates the whole simulation machinery.

`indirect_effects()` returns five rows in `quantity`:

| quantity | definition (contrast of population-average response means) |
| --- | --- |
| `total_path` | distribution-mediated total with mediators active |
| `direct` | controlled direct effect (mediators inactive) |
| `indirect` | `total_path − direct` |
| `mean_mediated` | (mean-mediated total) − direct |
| `distribution_mediated` | (distribution total) − (mean total) |

So `indirect ≈ mean_mediated + distribution_mediated`, and the
distribution-mediated row isolates exactly the contribution that no
coefficient-product method can express.

**Controlled vs natural effects (identification caveat).** `direct` here is a
*controlled* direct effect — mediators are held at their **observed** values
while `X` moves — and `indirect = total − direct`. This coincides with the
*natural* direct/indirect effect decomposition of mediation analysis
(Pearl; Imai, Keele & Yamamoto) **only under linearity with no
exposure–mediator interaction**. drmSEM paths routinely cross nonlinear links
and the engine permits `X × M` interaction terms — exactly the cases where the
controlled and natural effects differ — so the package reports a controlled
direct effect and a simulation-based total/indirect split, and does **not**
claim a natural-effects identification. The recovery tests that cross-check the
decomposition use identity-link, no-interaction Gaussian DAGs (the one regime
where the two coincide), so they validate the arithmetic, not the natural-effect
identification. (See inference-review B-2; the roxygen for `direct_effects()`
already states "controlled direct effect".)

## Monte-Carlo coefficient uncertainty

`drm_draw_beta()` draws each node's coefficient vector from
`MVN(coef, vcov)` (per component, keyed by `dpar:term` names), using each node's
own `vcov` from the adapter. With `draw = TRUE` the whole propagation is
repeated `B` times to produce a sampling distribution of the contrast;
`drm_summ()` reports the mean and a percentile interval at `level`. With
`draw = FALSE` (or when `vcov` is unavailable) the MLE is used and only a point
estimate is returned.

## Knobs

- `B` — number of coefficient draws (outer Monte-Carlo, uncertainty).
- `n_sim` — inner realizations per draw under distribution mediation.
- `draw` — whether to propagate coefficient uncertainty (needs `vcov`).
- `at` — override the contrast values.
- `level`, `seed` — interval width and reproducibility.

All effects are reported on the **response scale** of `to`.
