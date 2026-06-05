# Fisher's C statistic for a fitted distributional SEM

Combines the independence-claim p-values from
[`dsep()`](https://itchyshin.github.io/drmSEM/reference/dsep.md) into
Fisher's C, `C = -2 * sum(log(p))`, which is chi-squared with `2k`
degrees of freedom under the hypothesis that all missing arrows are
absent. A small p-value indicates the DAG omits a needed path.

## Usage

``` r
fisher_c(object, ...)

# S3 method for class 'drm_sem'
fisher_c(object, ...)

# S3 method for class 'drm_dsep'
fisher_c(object, ...)
```

## Arguments

- object:

  A `drm_sem` object or the result of
  [`dsep()`](https://itchyshin.github.io/drmSEM/reference/dsep.md).

- ...:

  Unused.

## Value

A one-row data frame with `fisher_c`, `df`, `n_claims`, `p.value`.
