# Standardized component-labelled path coefficients

Rescales fitted path coefficients so they are comparable across
predictors. Two scalings are offered, both reported on the component's
link scale:

## Usage

``` r
standardize(object, method = c("sd_x", "latent"), ...)

# S3 method for class 'drm_sem'
standardize(object, method = c("sd_x", "latent"), ...)
```

## Arguments

- object:

  A `drm_sem` object.

- method:

  `"sd_x"` or `"latent"`.

- ...:

  Unused.

## Value

The [`paths()`](https://itchyshin.github.io/drmSEM/reference/paths.md)
table with an added `std.estimate` column.

## Details

- `"sd_x"` multiplies each coefficient by the standard deviation of its
  predictor, giving the link-scale change in the component per one-SD
  change in the predictor.

- `"latent"` additionally divides by the standard deviation of the
  fitted linear predictor of that component, the latent-scale
  standardization used for generalized responses (after Grace & Bollen).
