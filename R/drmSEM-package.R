#' drmSEM: Distributional Piecewise Structural Equation Modelling on drmTMB
#'
#' drmSEM adds a structural-equation-modelling layer on top of the `drmTMB`
#' fitting engine. Each endogenous node is one `drmTMB` fit; drmSEM extracts the
#' component-labelled graph, validates it as a DAG, and provides path tables,
#' d-separation tests, and simulation-based direct, indirect, and total effects.
#'
#' Causal paths are **component-labelled**: a predictor may target the expected
#' response (`mu`), residual scale (`sigma`), shape (`nu`), zero-inflation
#' (`zi`), hurdle probability (`hu`), random-effect scale (`sd(group)`), or
#' bivariate residual correlation (`rho12`) of a node. Indirect effects can flow
#' through a mediator's mean (mean-mediated) or its distribution
#' (distribution-mediated), and are always computed by simulation rather than by
#' coefficient products.
#'
#' @section Engine vs layer:
#' `drmTMB` is the model-fitting engine; `drmSEM` is the graph, SEM,
#' d-separation, path, and effect-decomposition layer. drmSEM never fits its own
#' likelihoods.
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom graphics plot
#' @importFrom stats as.formula model.matrix pnorm pchisq quantile sd setNames
#'   logLik vcov gaussian
NULL

# Quiet R CMD check notes for non-standard evaluation in data-frame helpers.
utils::globalVariables(c("estimate", "std.error", "statistic", "p.value", "LR"))
