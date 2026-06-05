# Component-labelled path table for a distributional SEM

`paths()` returns one row per fitted fixed-effect coefficient across all
nodes, labelled by the distributional component it targets (`mu`,
`sigma`, `nu`, `zi`, `hu`, `rho12`, `sd_*`). This makes explicit that a
path to `sigma` is a path to residual scale, not to the mean.

## Usage

``` r
paths(object, ...)

# S3 method for class 'drm_sem'
paths(object, ...)
```

## Arguments

- object:

  A `drm_sem` object.

- ...:

  Unused.

## Value

A data frame with columns `from`, `to`, `component`, `link`, `term`,
`estimate`, `std.error`, `statistic`, `p.value`, `endogenous`.
