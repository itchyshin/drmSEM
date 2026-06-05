# Plot an effect decomposition as a forest plot

Visualizes the output of
[`indirect_effects()`](https://itchyshin.github.io/drmSEM/reference/indirect_effects.md)
(or
[`direct_effects()`](https://itchyshin.github.io/drmSEM/reference/direct_effects.md)
/
[`total_effects()`](https://itchyshin.github.io/drmSEM/reference/total_effects.md))
as a horizontal point-and-interval (forest) plot, with a reference line
at zero. This is the picture the rest of the SEM ecosystem does not
draw: `piecewiseSEM`, `dsem`, and `lavaan` plot the path diagram but
leave the direct / indirect / total *decomposition* as a table. drmSEM
separates the **distribution-mediated** contribution (the effect flowing
through a mediator's scale, zero-inflation, or shape) from the
**mean-mediated** part, so a path that acts on dispersion rather than
the mean is visible.

## Usage

``` r
# S3 method for class 'drm_effect'
plot(x, style = c("forest", "stacked"), ...)
```

## Arguments

- x:

  A `drm_effect` data frame from
  [`indirect_effects()`](https://itchyshin.github.io/drmSEM/reference/indirect_effects.md),
  [`direct_effects()`](https://itchyshin.github.io/drmSEM/reference/direct_effects.md),
  or
  [`total_effects()`](https://itchyshin.github.io/drmSEM/reference/total_effects.md).

- style:

  `"forest"` (default; one point-and-interval row per quantity) or
  `"stacked"` (a single bar stacking `direct` + `mean_mediated` +
  `distribution_mediated`, which sum to the total effect). `"stacked"`
  needs the decomposition rows from
  [`indirect_effects()`](https://itchyshin.github.io/drmSEM/reference/indirect_effects.md)
  and falls back to `"forest"` if they are absent.

- ...:

  Unused.

## Value

A `ggplot` object (invisibly printed by default).

## Details

Requires `ggplot2` (Suggests); returns a `ggplot` object you can
restyle.
