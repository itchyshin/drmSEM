# Package index

## Building a distributional SEM

Assemble a piecewise SEM from drmTMB nodes.

- [`drm_node()`](https://itchyshin.github.io/drmSEM/reference/drm_node.md)
  : Specify one endogenous node of a distributional SEM
- [`drm_sem()`](https://itchyshin.github.io/drmSEM/reference/drm_sem.md)
  : Fit and assemble a distributional piecewise SEM
- [`drm_psem()`](https://itchyshin.github.io/drmSEM/reference/drm_psem.md)
  [`summary(`*`<drm_sem>`*`)`](https://itchyshin.github.io/drmSEM/reference/drm_psem.md)
  : Assemble a distributional piecewise SEM from fitted drmTMB models

## Graph and paths

Inspect the component-labelled structural graph.

- [`paths()`](https://itchyshin.github.io/drmSEM/reference/paths.md) :
  Component-labelled path table for a distributional SEM
- [`standardize()`](https://itchyshin.github.io/drmSEM/reference/standardize.md)
  : Standardized component-labelled path coefficients
- [`plot(`*`<drm_sem>`*`)`](https://itchyshin.github.io/drmSEM/reference/plot.drm_sem.md)
  : Plot the distributional SEM as a component-labelled DAG

## d-separation

Test missing arrows on any distributional component.

- [`basis_set()`](https://itchyshin.github.io/drmSEM/reference/basis_set.md)
  : Basis set of independence claims for a distributional SEM
- [`dsep()`](https://itchyshin.github.io/drmSEM/reference/dsep.md) :
  Test directed-separation claims by likelihood-ratio refits
- [`fisher_c()`](https://itchyshin.github.io/drmSEM/reference/fisher_c.md)
  : Fisher's C statistic for a fitted distributional SEM

## Effects

Simulation-based direct, indirect, and total effects.

- [`direct_effects()`](https://itchyshin.github.io/drmSEM/reference/direct_effects.md)
  : Response-scale direct (controlled) effect of a predictor on a node
- [`indirect_effects()`](https://itchyshin.github.io/drmSEM/reference/indirect_effects.md)
  : Indirect effect of a predictor on a node, with a distributional
  decomposition
- [`total_effects()`](https://itchyshin.github.io/drmSEM/reference/total_effects.md)
  : Total effect of a predictor on a node by simulation
- [`plot(`*`<drm_effect>`*`)`](https://itchyshin.github.io/drmSEM/reference/plot.drm_effect.md)
  : Plot an effect decomposition as a forest plot

## Diagnostics

- [`check_sem()`](https://itchyshin.github.io/drmSEM/reference/check_sem.md)
  : Diagnose a fitted distributional SEM
