#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# Typed-edge extraction.
#
# A drmSEM edge is component-labelled: (from, to, component, link, term). The
# `to` is always an endogenous node; `from` is either another node (a
# node-to-node path) or an exogenous variable. `component` is the distributional
# parameter of `to` that `from` targets (mu, sigma, nu, zi, hu, rho12, sd_*).
# ---------------------------------------------------------------------------

# Nominal link per (family, component). Best-effort labels for display and
# standardization; not used to alter any drmTMB computation.
drm_nominal_link <- function(family_name, component) {
  if (startsWith(component, "sd") || component %in% c("sigma", "nu")) {
    return("log")
  }
  if (component %in% c("zi", "hu", "zoi", "coi")) {
    return("logit")
  }
  if (component == "rho12") {
    return("tanh")
  }
  # component == "mu" (or mu1/mu2): link follows the family
  switch(
    family_name,
    gaussian = "identity",
    student = "identity",
    lognormal = "log",
    Gamma = "log",
    gamma = "log",
    tweedie = "log",
    poisson = "log",
    nbinom2 = "log",
    truncated_nbinom2 = "log",
    beta = "logit",
    beta_binomial = "logit",
    zero_one_beta = "logit",
    binomial = "logit",
    cumulative_logit = "logit",
    "identity"
  )
}

# Build node metadata records from a named list of fitted drmTMB objects.
drm_build_node_records <- function(fits) {
  nms <- names(fits)
  records <- vector("list", length(fits))
  for (i in seq_along(fits)) {
    fit <- fits[[i]]
    resp <- drm_fit_response(fit)
    ids <- unique(stats::na.omit(c(nms[[i]], resp$label, resp$vars)))
    records[[i]] <- list(
      name = nms[[i]],
      fit = fit,
      family = drm_family_name(drm_fit_family(fit)),
      response_label = resp$label,
      response_vars = resp$vars,
      components = drm_fit_components(fit),
      identifiers = ids
    )
  }
  names(records) <- nms
  records
}

# Map a predictor token to a node name (or NA if exogenous), excluding `self`.
drm_match_node <- function(token, records, self) {
  for (nm in names(records)) {
    if (identical(nm, self)) next
    if (token %in% records[[nm]]$identifiers) {
      return(nm)
    }
  }
  NA_character_
}

#' Build the typed edge table for a set of node records
#' @return data.frame(from, to, component, link, term, endogenous)
#' @keywords internal
#' @noRd
drm_build_edges <- function(records) {
  rows <- list()
  for (nm in names(records)) {
    rec <- records[[nm]]
    for (component in rec$components) {
      preds <- drm_fit_component_predictors(rec$fit, component)
      for (p in preds) {
        src <- drm_match_node(p, records, self = nm)
        endogenous <- !is.na(src)
        from <- if (endogenous) src else p
        if (identical(from, nm)) next # no self loops from response self-reference
        rows[[length(rows) + 1L]] <- data.frame(
          from = from,
          to = nm,
          component = component,
          link = drm_nominal_link(rec$family, component),
          term = p,
          endogenous = endogenous,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(
      from = character(0), to = character(0), component = character(0),
      link = character(0), term = character(0), endogenous = logical(0),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Collapse a typed edge table to a variable-level directed edge list
#' @keywords internal
#' @noRd
drm_collapse_edges <- function(edges) {
  if (nrow(edges) == 0L) {
    return(data.frame(from = character(0), to = character(0),
                      stringsAsFactors = FALSE))
  }
  ve <- unique(edges[, c("from", "to")])
  rownames(ve) <- NULL
  ve
}
