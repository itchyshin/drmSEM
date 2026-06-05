# Basis set of independence claims for a distributional SEM

The basis set is the collection of non-adjacent variable pairs (X, Y)
where Y is endogenous and X is causally no later than Y. Each claim
asserts that X has **no effect on any modelled distributional component
of Y**, conditional on Y's existing parents. This any-component reading
is drmSEM's definition of a missing arrow (see
`docs/design/03-dsep.md`).

## Usage

``` r
basis_set(object, ...)

# S3 method for class 'drm_sem'
basis_set(object, ...)
```

## Arguments

- object:

  A `drm_sem` object.

- ...:

  Unused.

## Value

A data frame with columns `claim`, `x`, `y`, `given` (comma-separated
conditioning set = Y's parents).
