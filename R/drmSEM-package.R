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
#' @section Methodological background:
#' `drmSEM` builds on a number of distinct literatures, all of which are cited
#' at the point of use in the individual function help pages and the package
#' vignettes. The canonical entry points are:
#' \itemize{
#'   \item Piecewise SEM and local-likelihood d-separation:
#'     \insertRef{Shipley2000}{drmSEM},
#'     \insertRef{Shipley2009}{drmSEM},
#'     \insertRef{Lefcheck2016}{drmSEM}.
#'   \item d-separation foundation:
#'     \insertRef{Pearl2009}{drmSEM}.
#'   \item Counterfactual mediation (direct, indirect, natural, interventional):
#'     \insertRef{Pearl2001}{drmSEM},
#'     \insertRef{Imai2010}{drmSEM},
#'     \insertRef{VanderWeele2015}{drmSEM},
#'     \insertRef{VanderWeele2014}{drmSEM},
#'     \insertRef{Vansteelandt2017}{drmSEM}.
#'   \item Distributional regression:
#'     \insertRef{Rigby2005}{drmSEM},
#'     \insertRef{Brooks2017}{drmSEM}.
#'   \item Phylogenetic comparative covariance:
#'     \insertRef{Felsenstein1985}{drmSEM},
#'     \insertRef{Pagel1999}{drmSEM},
#'     \insertRef{MartinsHansen1997}{drmSEM},
#'     \insertRef{vanderBijl2018}{drmSEM}.
#'   \item Model selection on Fisher's C:
#'     \insertRef{Shipley2013}{drmSEM},
#'     \insertRef{Schwarz1978}{drmSEM},
#'     \insertRef{Burnham2002}{drmSEM}.
#' }
#' Within `drmSEM`, the **any-component d-separation** test, the
#' **distribution-mediated effect** row, and the BIC-style **CBIC** information
#' criterion are package-specific constructions built on these foundations and
#' are flagged as such in their respective help pages and vignettes.
#'
#' @references
#' \insertRef{Shipley2000}{drmSEM}
#'
#' \insertRef{Shipley2009}{drmSEM}
#'
#' \insertRef{Shipley2013}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#'
#' \insertRef{Pearl2001}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#'
#' \insertRef{Imai2010}{drmSEM}
#'
#' \insertRef{VanderWeele2015}{drmSEM}
#'
#' \insertRef{Rigby2005}{drmSEM}
#'
#' \insertRef{Brooks2017}{drmSEM}
#'
#' \insertRef{Felsenstein1985}{drmSEM}
#'
#' \insertRef{vanderBijl2018}{drmSEM}
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom graphics plot
#' @importFrom stats as.formula model.matrix pnorm pchisq quantile sd setNames
#' @importFrom stats logLik vcov gaussian
#' @importFrom Rdpack reprompt
NULL

# Quiet R CMD check notes for non-standard evaluation in data-frame helpers.
utils::globalVariables(c("estimate", "std.error", "statistic", "p.value", "LR"))
