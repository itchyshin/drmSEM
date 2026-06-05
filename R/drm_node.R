#' Specify one endogenous node of a distributional SEM
#'
#' `drm_node()` records the model for a single endogenous (response) node
#' without fitting it. It is the building block of the declarative interface
#' [drm_sem()]: each node becomes one [drmTMB::drmTMB()] fit. The node's
#' distributional-parameter formulae (for example `mu`, `sigma`, `zi`, `hu`,
#' `nu`, `sd(group)`, `rho12`) define **component-labelled paths**: a predictor
#' in the `sigma` formula is a path to residual scale, not to the mean.
#'
#' @param formula A [drmTMB::bf()] / [drmTMB::drm_formula()] object, or a plain
#'   formula for a mean-only node. Plain formulas are wrapped with `bf()`.
#' @param family A `drmTMB` family (for example [drmTMB::nbinom2()],
#'   [drmTMB::beta_binomial()], or [stats::gaussian()]).
#' @param ... Further arguments passed to [drmTMB::drmTMB()] when the node is
#'   fitted (for example `control`).
#'
#' @return A `drm_node` specification object.
#' @export
#'
#' @examples
#' if (requireNamespace("drmTMB", quietly = TRUE)) {
#'   abundance <- drm_node(
#'     drmTMB::bf(count ~ size + temp + (1 | site), sigma ~ temp, zi ~ habitat),
#'     family = drmTMB::nbinom2()
#'   )
#'   abundance
#' }
drm_node <- function(formula, family = stats::gaussian(), ...) {
  if (inherits(formula, "formula")) {
    if (!requireNamespace("drmTMB", quietly = TRUE)) {
      cli::cli_abort(c(
        "A plain formula was supplied to {.fn drm_node}, which needs {.pkg drmTMB} to wrap it.",
        "i" = "Pass a {.fn drmTMB::bf} object, or install {.pkg drmTMB}."
      ))
    }
    # bf() uses non-standard evaluation: `drmTMB::bf(formula)` would capture the
    # symbol `formula`, not its value (-> "input 1 is not a formula"). Splice the
    # actual formula object in via do.call so a stored formula (e.g. from a
    # drm_dag candidate) wraps correctly.
    formula <- do.call(drmTMB::bf, list(formula))
  }
  if (!inherits(formula, "drm_formula")) {
    cli::cli_abort(
      "{.arg formula} must be a {.fn drmTMB::bf} / {.fn drmTMB::drm_formula} object or a plain formula."
    )
  }
  out <- list(
    formula = formula,
    family = family,
    args = list(...)
  )
  class(out) <- "drm_node"
  out
}

#' @export
print.drm_node <- function(x, ...) {
  cli::cli_text("<drm_node> family = {.val {drm_family_name(x$family)}}")
  print(x$formula)
  invisible(x)
}

# Fit a single drm_node spec into a drmTMB object.
drm_fit_node <- function(spec, data, name) {
  drm_require_drmTMB()
  control <- spec$args$control
  if (is.null(control)) {
    # request standard errors so vcov(), Wald CIs, and d-separation refits work
    control <- tryCatch(drmTMB::drm_control(se = TRUE), error = function(e) NULL)
  }
  args <- spec$args
  args$control <- NULL
  call_args <- c(
    list(spec$formula, family = spec$family, data = data),
    if (!is.null(control)) list(control = control) else NULL,
    args
  )
  fit <- tryCatch(
    do.call(drmTMB::drmTMB, call_args),
    error = function(e) {
      cli::cli_abort(c(
        "Node {.val {name}} failed to fit.",
        "x" = conditionMessage(e)
      ))
    }
  )
  fit
}
