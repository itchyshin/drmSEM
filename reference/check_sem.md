# Diagnose a fitted distributional SEM

Reports, per node, the family, modelled components, convergence, whether
a fixed-effect covariance is available (needed for Wald intervals,
d-separation refits, and effect uncertainty), and whether a
realized-value sampler exists (needed for distribution-mediated
effects). Also lists exogenous variables and warns about anything that
will silently degrade a downstream computation.

## Usage

``` r
check_sem(object, ...)

# S3 method for class 'drm_sem'
check_sem(object, ...)
```

## Arguments

- object:

  A `drm_sem` object.

- ...:

  Unused.

## Value

A data frame of per-node diagnostics (class `drm_diagnostics`).
