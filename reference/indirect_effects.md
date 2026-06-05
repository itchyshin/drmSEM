# Indirect effect of a predictor on a node, with a distributional decomposition

The indirect effect is the simulation-based total path effect (mediators
in `through` allowed to respond) minus the controlled direct effect. It
is decomposed into a **mean-mediated** part (mediator means propagate)
and a **distribution-mediated** part (the extra effect that appears when
mediators pass realized draws, i.e. flowing through mediator scale /
zero-inflation / shape).

## Usage

``` r
indirect_effects(
  object,
  from,
  to,
  through = NULL,
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

- through:

  Optional set of mediator node names to route through. Defaults to all
  mediators between `from` and `to`.

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

A `drm_effect` data frame with rows for `total_path`, `direct`,
`indirect`, `mean_mediated`, and `distribution_mediated`.
