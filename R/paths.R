#' @keywords internal
#' @noRd
NULL

# Map a fitted coefficient name (e.g. "habitatB", "temp:habitatB") back to the
# structural predictor variable it belongs to, given the component's predictor
# variable names. Returns the coefficient name itself if no variable matches.
drm_coef_variable <- function(coef_name, preds) {
  hits <- preds[vapply(preds, function(v) {
    identical(coef_name, v) || startsWith(coef_name, v)
  }, logical(1))]
  if (length(hits) == 0L) {
    return(coef_name)
  }
  hits[which.max(nchar(hits))]
}

#' Component-labelled path table for a distributional SEM
#'
#' `paths()` returns one row per fitted fixed-effect coefficient across all
#' nodes, labelled by the distributional component it targets (`mu`, `sigma`,
#' `nu`, `zi`, `hu`, `rho12`, `sd_*`). This makes explicit that a path to
#' `sigma` is a path to residual scale, not to the mean.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#'
#' @return A data frame with columns `from`, `to`, `component`, `link`, `term`,
#'   `estimate`, `std.error`, `statistic`, `p.value`, `endogenous`.
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' paths(sem)
#' }
#' @export
paths <- function(object, ...) {
  UseMethod("paths")
}

#' @rdname paths
#' @export
paths.drm_sem <- function(object, ...) {
  rows <- list()
  for (nm in object$order) {
    rec <- object$records[[nm]]
    fit <- rec$fit
    family <- rec$family
    V <- drm_fit_vcov(fit)
    for (component in rec$components) {
      coefs <- drm_fit_coef(fit, component)
      if (length(coefs) == 0L) next
      preds <- drm_fit_component_predictors(fit, component)
      link <- drm_nominal_link(family, component)
      for (cn in names(coefs)) {
        if (cn %in% c("(Intercept)", "Intercept")) next
        var <- drm_coef_variable(cn, preds)
        src <- drm_match_node(var, object$records, self = nm)
        endo <- !is.na(src)
        from <- if (endo) src else var
        est <- unname(coefs[[cn]])
        key <- paste0(component, ":", cn)
        se <- if (!is.null(V) && key %in% rownames(V)) sqrt(V[key, key]) else NA_real_
        z <- est / se
        rows[[length(rows) + 1L]] <- data.frame(
          from = from, to = nm, component = component, link = link,
          term = cn, estimate = est, std.error = se,
          statistic = z, p.value = 2 * stats::pnorm(-abs(z)),
          endogenous = endo, stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(
      from = character(0), to = character(0), component = character(0),
      link = character(0), term = character(0), estimate = numeric(0),
      std.error = numeric(0), statistic = numeric(0), p.value = numeric(0),
      endogenous = logical(0), stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  class(out) <- c("drm_paths", "data.frame")
  out
}

#' @export
print.drm_paths <- function(x, ...) {
  cli::cli_text("<drmSEM paths: {nrow(x)} component-labelled coefficient{?s}>")
  print.data.frame(
    within(as.data.frame(x), {
      estimate <- round(estimate, 4)
      std.error <- round(std.error, 4)
      statistic <- round(statistic, 3)
      p.value <- signif(p.value, 3)
    }),
    row.names = FALSE
  )
  invisible(x)
}
