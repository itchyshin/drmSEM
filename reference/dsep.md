# Test directed-separation claims by likelihood-ratio refits

For each claim X *\|\|* Y in
[`basis_set()`](https://itchyshin.github.io/drmSEM/reference/basis_set.md),
`dsep()` refits node Y with X added as a fixed-effect predictor to
**every modelled distributional component**, and compares it to the base
node fit by a likelihood-ratio test. A small p-value means X carries
information about some component of Y beyond Y's parents, i.e. a missing
arrow.

## Usage

``` r
dsep(object, ...)

# S3 method for class 'drm_sem'
dsep(object, ...)
```

## Arguments

- object:

  A `drm_sem` object.

- ...:

  Unused.

## Value

A data frame of claims with `df`, `LR`, and `p.value`, carrying a
`fisher_c` attribute (see
[`fisher_c()`](https://itchyshin.github.io/drmSEM/reference/fisher_c.md)).

## Details

Requires nodes fitted so that refits converge (the declarative
[`drm_sem()`](https://itchyshin.github.io/drmSEM/reference/drm_sem.md)
requests standard errors automatically).
