# Response-scale direct (controlled) effect of a predictor on a node

The controlled direct effect holds all mediators at their observed
values and changes only `from`, so only the arrow(s) from `from`
directly into `to` operate. Reported as the population-average change in
the response-scale mean of `to` for a one-SD (numeric) or
first-to-second-level (factor) change in `from`. The fitted direct
coefficients are attached as a `coefficients` attribute.

## Usage

``` r
direct_effects(
  object,
  from,
  to,
  component = NULL,
  at = NULL,
  B = 200L,
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

- component:

  Optional component filter for the attached coefficient table.

- at:

  Optional length-2 contrast values for `from`.

- B:

  Monte-Carlo draws for coefficient uncertainty.

- draw:

  Whether to propagate coefficient uncertainty (needs `vcov`).

- level:

  Confidence level for the Monte-Carlo interval.

- seed:

  Optional RNG seed.

- ...:

  Unused.

## Value

A one-row data frame (`from`, `to`, `scale`, `estimate`, `conf.low`,
`conf.high`) with a `coefficients` attribute.
