# Total effect of a predictor on a node by simulation

Propagates a do()-style change in `from` through the whole DAG (all
mediators respond) and reports the population-average change in the
response-scale mean of `to`. With `mediation = "distribution"`,
mediators pass realized draws from their families, so effects flowing
through a mediator's scale, zero-inflation, or shape
(distribution-mediated paths) are included; with `"mean"` only the
mediator means propagate.

## Usage

``` r
total_effects(
  object,
  from,
  to,
  mediation = c("mean", "distribution"),
  at = NULL,
  B = 200L,
  n_sim = 50L,
  draw = TRUE,
  level = 0.95,
  seed = NULL,
  ...
)
```

## Arguments

- object:

  A `drm_sem` object.

- from:

  Predictor variable or node name.

- to:

  Endogenous target node.

- mediation:

  `"mean"` (mediator means propagate) or `"distribution"` (realized
  mediator draws propagate).

- at:

  Optional length-2 contrast values for `from`.

- B:

  Monte-Carlo draws for coefficient uncertainty.

- n_sim:

  Inner realizations per draw when `mediation = "distribution"`.

- draw:

  Whether to propagate coefficient uncertainty (needs `vcov`).

- level:

  Confidence level for the Monte-Carlo interval.

- seed:

  Optional RNG seed.

- ...:

  Unused.

## Value

A one-row `drm_effect` data frame.
