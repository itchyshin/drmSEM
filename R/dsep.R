#' @keywords internal
#' @noRd
NULL

# A variable is "adjacent" to node Y if it is a direct parent of Y on any
# component (the any-component adjacency rule).
drm_is_parent <- function(x, y, edges) {
  any(as.character(edges$from) == x & as.character(edges$to) == y)
}

# Order index of a variable: endogenous nodes use their topological position;
# exogenous variables sort before all nodes (index 0).
drm_order_index <- function(object) {
  idx <- stats::setNames(seq_along(object$order), object$order)
  function(v) {
    if (v %in% names(idx)) idx[[v]] else 0L
  }
}

#' Basis set of independence claims for a distributional SEM
#'
#' The basis set is the collection of non-adjacent variable pairs (X, Y) where Y
#' is endogenous and X is causally no later than Y. Each claim asserts that X has
#' **no effect on any modelled distributional component of Y**, conditional on
#' Y's existing parents. This any-component reading is drmSEM's definition of a
#' missing arrow (see `docs/design/03-dsep.md`).
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame with columns `claim`, `x`, `y`, `given` (comma-separated
#'   conditioning set = Y's parents).
#' @export
basis_set <- function(object, ...) {
  UseMethod("basis_set")
}

#' @rdname basis_set
#' @export
basis_set.drm_sem <- function(object, ...) {
  edges <- object$edges
  ord <- drm_order_index(object)
  all_vars <- unique(c(object$endogenous, object$exogenous))
  rows <- list()
  for (y in object$order) {
    yi <- ord(y)
    parents_y <- drm_parents(y, edges)
    for (x in all_vars) {
      if (identical(x, y)) next
      if (ord(x) > yi) next            # X must be causally no later than Y
      if (x %in% parents_y) next        # adjacent -> not a missing arrow
      if (drm_is_parent(y, x, edges)) next
      rows[[length(rows) + 1L]] <- data.frame(
        x = x, y = y,
        given = paste(parents_y, collapse = ", "),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    out <- data.frame(claim = character(0), x = character(0), y = character(0),
                      given = character(0), stringsAsFactors = FALSE)
    return(out)
  }
  out <- do.call(rbind, rows)
  out <- cbind(claim = paste0(out$x, " _||_ ", out$y, " | {", out$given, "}"), out)
  rownames(out) <- NULL
  out
}

# Choose the data column to add for variable `v` (node identifier or exogenous).
drm_add_column <- function(v, object) {
  data <- object$data
  if (v %in% names(data)) {
    return(v)
  }
  if (v %in% object$endogenous) {
    ids <- object$records[[v]]$identifiers
    hit <- ids[ids %in% names(data)]
    if (length(hit)) return(hit[[1L]])
  }
  NA_character_
}

#' Test directed-separation claims by likelihood-ratio refits
#'
#' For each claim X _||_ Y in [basis_set()], `dsep()` refits node Y with X added
#' as a fixed-effect predictor to **every modelled distributional component**,
#' and compares it to the base node fit by a likelihood-ratio test. A small
#' p-value means X carries information about some component of Y beyond Y's
#' parents, i.e. a missing arrow.
#'
#' Requires nodes fitted so that refits converge (the declarative [drm_sem()]
#' requests standard errors automatically).
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame of claims with `df`, `LR`, and `p.value`, carrying a
#'   `fisher_c` attribute (see [fisher_c()]).
#' @export
dsep <- function(object, ...) {
  UseMethod("dsep")
}

#' @rdname dsep
#' @export
dsep.drm_sem <- function(object, ...) {
  drm_require_drmTMB()
  bs <- basis_set(object)
  if (nrow(bs) == 0L) {
    # Saturated DAG: no independence claims to test. Return an empty, typed
    # result (assigning a scalar column to a 0-row data.frame would error).
    cli::cli_warn("Basis set is empty: the graph is fully saturated, no claims to test.")
    bs$df <- integer(0)
    bs$LR <- numeric(0)
    bs$p.value <- numeric(0)
    bs$status <- character(0)
    attr(bs, "fisher_c") <- drm_fisher_c_from_p(numeric(0))
    class(bs) <- c("drm_dsep", "data.frame")
    return(bs)
  }
  bs$df <- NA_integer_
  bs$LR <- NA_real_
  bs$p.value <- NA_real_
  bs$status <- "ok"
  for (i in seq_len(nrow(bs))) {
    y <- bs$y[[i]]
    fit <- object$records[[y]]$fit
    add_var <- drm_add_column(bs$x[[i]], object)
    if (is.na(add_var)) {
      bs$status[[i]] <- "no_data_column"
      next
    }
    base <- drm_fit_logLik(fit)
    aug_fit <- drm_refit_augmented(fit, add_var)
    if (is.null(aug_fit)) {
      bs$status[[i]] <- "refit_failed"
      next
    }
    aug <- drm_fit_logLik(aug_fit)
    df_diff <- aug$df - base$df
    lr <- 2 * (aug$logLik - base$logLik)
    if (is.na(df_diff) || df_diff <= 0 || is.na(lr)) {
      bs$status[[i]] <- "degenerate"
      next
    }
    bs$df[[i]] <- as.integer(df_diff)
    bs$LR[[i]] <- lr
    bs$p.value[[i]] <- stats::pchisq(lr, df = df_diff, lower.tail = FALSE)
  }
  fc <- drm_fisher_c_from_p(bs$p.value[bs$status == "ok" & !is.na(bs$p.value)])
  attr(bs, "fisher_c") <- fc
  class(bs) <- c("drm_dsep", "data.frame")
  bs
}

drm_fisher_c_from_p <- function(p) {
  p <- p[!is.na(p) & p > 0]
  k <- length(p)
  C <- -2 * sum(log(p))
  df <- 2L * k
  list(
    C = C, df = df, k = k,
    p.value = if (k > 0) stats::pchisq(C, df = df, lower.tail = FALSE) else NA_real_
  )
}

#' Fisher's C statistic for a fitted distributional SEM
#'
#' Combines the independence-claim p-values from [dsep()] into Fisher's C,
#' `C = -2 * sum(log(p))`, which is chi-squared with `2k` degrees of freedom
#' under the hypothesis that all missing arrows are absent. A small p-value
#' indicates the DAG omits a needed path.
#'
#' @param object A `drm_sem` object or the result of [dsep()].
#' @param ... Unused.
#' @return A one-row data frame with `fisher_c`, `df`, `n_claims`, `p.value`.
#' @export
fisher_c <- function(object, ...) {
  UseMethod("fisher_c")
}

#' @rdname fisher_c
#' @export
fisher_c.drm_sem <- function(object, ...) {
  fisher_c(dsep(object))
}

#' @rdname fisher_c
#' @export
fisher_c.drm_dsep <- function(object, ...) {
  fc <- attr(object, "fisher_c")
  data.frame(
    fisher_c = fc$C, df = fc$df, n_claims = fc$k, p.value = fc$p.value,
    stringsAsFactors = FALSE
  )
}

#' @export
print.drm_dsep <- function(x, ...) {
  fc <- attr(x, "fisher_c")
  cli::cli_text("<drmSEM d-separation: {nrow(x)} claim{?s}>")
  print.data.frame(
    transform(as.data.frame(x), p.value = signif(p.value, 3), LR = round(LR, 3)),
    row.names = FALSE
  )
  if (!is.null(fc) && fc$k > 0) {
    cli::cli_text(
      "Fisher's C = {round(fc$C, 2)} on {fc$df} df, p = {signif(fc$p.value, 3)}"
    )
  }
  invisible(x)
}
