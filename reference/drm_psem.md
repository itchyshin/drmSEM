# Assemble a distributional piecewise SEM from fitted drmTMB models

`drm_psem()` is the piecewiseSEM-style core: you fit each endogenous
node yourself with
[`drmTMB::drmTMB()`](https://itchyshin.github.io/drmTMB/reference/drmTMB.html)
and pass the fitted models. drmSEM extracts the component-labelled
graph, validates it as a DAG, and provides path tables, d-separation
tests, and simulation-based effects on top.

## Usage

``` r
drm_psem(..., data = NULL)

# S3 method for class 'drm_sem'
summary(object, ...)
```

## Arguments

- ...:

  Named fitted `drmTMB` objects, one per endogenous node. The name is
  the node identifier used in path queries; predictors are matched to a
  node by its name or its response variable.

- data:

  The data frame all nodes were fitted to. Defaults to the data of the
  first node.

- object:

  A `drm_sem` object.

## Value

A `drm_sem` object.

## Details

Fit nodes with `control = drmTMB::drm_control(se = TRUE)` so that
[`vcov()`](https://rdrr.io/r/stats/vcov.html), Wald intervals, and
d-separation refits are available.

## See also

[`drm_sem()`](https://itchyshin.github.io/drmSEM/reference/drm_sem.md)
for the declarative interface that fits nodes for you.
