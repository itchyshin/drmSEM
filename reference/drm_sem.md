# Fit and assemble a distributional piecewise SEM

`drm_sem()` is the declarative interface. You describe each endogenous
node with
[`drm_node()`](https://itchyshin.github.io/drmSEM/reference/drm_node.md);
`drm_sem()` fits each node with
[`drmTMB::drmTMB()`](https://itchyshin.github.io/drmTMB/reference/drmTMB.html)
and then builds the same object
[`drm_psem()`](https://itchyshin.github.io/drmSEM/reference/drm_psem.md)
returns. Causal paths are component-labelled: a predictor may target
`mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`, or `rho12` of a node.

## Usage

``` r
drm_sem(..., data)
```

## Arguments

- ...:

  Named
  [`drm_node()`](https://itchyshin.github.io/drmSEM/reference/drm_node.md)
  specifications, one per endogenous node.

- data:

  A data frame supplied to every node fit.

## Value

A `drm_sem` object.

## See also

[`drm_psem()`](https://itchyshin.github.io/drmSEM/reference/drm_psem.md),
[`paths()`](https://itchyshin.github.io/drmSEM/reference/paths.md),
[`dsep()`](https://itchyshin.github.io/drmSEM/reference/dsep.md),
[`indirect_effects()`](https://itchyshin.github.io/drmSEM/reference/indirect_effects.md).

## Examples

``` r
if (FALSE) { # \dontrun{
sem <- drm_sem(
  size = drm_node(
    drmTMB::bf(size ~ temp + habitat + (1 | species), sigma ~ temp),
    family = stats::gaussian()
  ),
  abundance = drm_node(
    drmTMB::bf(abundance ~ size + temp + (1 | site), sigma ~ temp, zi ~ habitat),
    family = drmTMB::nbinom2()
  ),
  data = dat
)
paths(sem)
dsep(sem)
indirect_effects(sem, from = "temp", to = "abundance")
} # }
```
