#' @keywords internal
#' @noRd
NULL

# Marginalised latent declarations (`latent =`) for MAG m-separation.
# Selection / conditioned latents (L_C) are structurally unrepresentable in v1;
# see docs/design/14-m-separation.md.

#' Normalize a `latent =` argument to a character vector of graph vertex names.
#'
#' @param latent `NULL`, a character vector, or a single name.
#' @param dag_vertices All vertex names present on the structural DAG.
#' @return Character vector (possibly empty).
#' @keywords internal
#' @noRd
drm_build_latents <- function(latent, dag_vertices) {
  if (is.null(latent)) {
    return(character(0))
  }
  latent <- as.character(latent)
  if (length(latent) == 1L && !nzchar(latent[[1L]])) {
    return(character(0))
  }
  if (anyDuplicated(latent)) {
    cli::cli_abort(
      "Marginalised latent names must be unique; duplicated: {.val {latent[duplicated(latent)]}}."
    )
  }
  miss <- setdiff(latent, dag_vertices)
  if (length(miss)) {
    cli::cli_abort(c(
      "Marginalised latent{?s} not found in the structural graph: {.val {miss}}.",
      "i" = "Latent names must appear on at least one directed edge in the DAG
             (as an exogenous vertex) before marginalisation."
    ))
  }
  latent
}

#' Inform once that MAG m-separation assumes a compositional graphoid when families
#' or sigma paths break homoscedastic Gaussianity (guardrail 3).
#' @keywords internal
#' @noRd
drm_mag_compositionality_inform <- function(object) {
  if (!length(object$latents)) {
    return(invisible(NULL))
  }
  flagged <- FALSE
  for (nm in object$endogenous) {
    rec <- object$records[[nm]]
    if (!identical(rec$family, "gaussian")) {
      flagged <- TRUE
      break
    }
    if ("sigma" %in% rec$components) {
      flagged <- TRUE
      break
    }
  }
  if (!flagged) {
    return(invisible(NULL))
  }
  cli::cli_inform(c(
      "i" = "MAG m-separation claims are licensed under a compositional graphoid
             (Sadeghi & Lauritzen 2014 Thm 3; Lauritzen & Sadeghi 2018 Thm 4).",
      "i" = "That holds automatically for homoscedastic all-Gaussian models and under
             faithfulness otherwise; it is not guaranteed for non-Gaussian nodes or
             location-scale ({.code sigma ~}) paths. See {.file docs/design/14-m-separation.md}."
    ))
  invisible(NULL)
}
