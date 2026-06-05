# drmSEM: Distributional Piecewise Structural Equation Modelling on drmTMB

drmSEM adds a structural-equation-modelling layer on top of the `drmTMB`
fitting engine. Each endogenous node is one `drmTMB` fit; drmSEM
extracts the component-labelled graph, validates it as a DAG, and
provides path tables, d-separation tests, and simulation-based direct,
indirect, and total effects.

## Details

Causal paths are **component-labelled**: a predictor may target the
expected response (`mu`), residual scale (`sigma`), shape (`nu`),
zero-inflation (`zi`), hurdle probability (`hu`), random-effect scale
(`sd(group)`), or bivariate residual correlation (`rho12`) of a node.
Indirect effects can flow through a mediator's mean (mean-mediated) or
its distribution (distribution-mediated), and are always computed by
simulation rather than by coefficient products.

## Engine vs layer

`drmTMB` is the model-fitting engine; `drmSEM` is the graph, SEM,
d-separation, path, and effect-decomposition layer. drmSEM never fits
its own likelihoods.

## See also

Useful links:

- <https://github.com/itchyshin/drmSEM>

- <https://itchyshin.github.io/drmSEM>

- Report bugs at <https://github.com/itchyshin/drmSEM/issues>

## Author

**Maintainer**: Shinichi Nakagawa <itchyshin@gmail.com>

Authors:

- Shinichi Nakagawa <itchyshin@gmail.com>
