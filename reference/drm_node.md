# Specify one endogenous node of a distributional SEM

`drm_node()` records the model for a single endogenous (response) node
without fitting it. It is the building block of the declarative
interface
[`drm_sem()`](https://itchyshin.github.io/drmSEM/reference/drm_sem.md):
each node becomes one
[`drmTMB::drmTMB()`](https://itchyshin.github.io/drmTMB/reference/drmTMB.html)
fit. The node's distributional-parameter formulae (for example `mu`,
`sigma`, `zi`, `hu`, `nu`, `sd(group)`, `rho12`) define
**component-labelled paths**: a predictor in the `sigma` formula is a
path to residual scale, not to the mean.

## Usage

``` r
drm_node(formula, family = stats::gaussian(), ...)
```

## Arguments

- formula:

  A
  [`drmTMB::bf()`](https://itchyshin.github.io/drmTMB/reference/drm_formula.html)
  /
  [`drmTMB::drm_formula()`](https://itchyshin.github.io/drmTMB/reference/drm_formula.html)
  object, or a plain formula for a mean-only node. Plain formulas are
  wrapped with `bf()`.

- family:

  A `drmTMB` family (for example
  [`drmTMB::nbinom2()`](https://itchyshin.github.io/drmTMB/reference/nbinom2.html),
  [`drmTMB::beta_binomial()`](https://itchyshin.github.io/drmTMB/reference/beta_binomial.html),
  or [`stats::gaussian()`](https://rdrr.io/r/stats/family.html)).

- ...:

  Further arguments passed to
  [`drmTMB::drmTMB()`](https://itchyshin.github.io/drmTMB/reference/drmTMB.html)
  when the node is fitted (for example `control`).

## Value

A `drm_node` specification object.

## Examples

``` r
if (requireNamespace("drmTMB", quietly = TRUE)) {
  abundance <- drm_node(
    drmTMB::bf(count ~ size + temp + (1 | site), sigma ~ temp, zi ~ habitat),
    family = drmTMB::nbinom2()
  )
  abundance
}
#> <drm_node> family = "nbinom2"
#> <drm_formula>
#> count ~ size + temp + (1 | site)
#> sigma ~ temp
#> zi ~ habitat
```
