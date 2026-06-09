#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# OQ-1 sampler-dispersion probe (run on a LIVE drmTMB engine; not run in CI).
#
# Wave-1 recovery tests (V-57..V-60, test-recovery-samplers.R) originally found
# moment mismatches. The closeout showed two causes: default fitted dpars
# (especially `sigma`) were not carried into the prediction engine when no
# explicit `sigma ~ ...` formula was declared, and lognormal `mu` is drmTMB's
# `meanlog` (identity link), not a response mean to log again. This probe remains
# as a live-engine diagnostic for future drmTMB parameterization drift.
#
# Usage:  Rscript inst/validation/sampler-dispersion-probe.R
# Needs:  a working drmTMB install (compiler/TMB). See CLOUD.md.
#
# WHY THE OLD PROBE WAS NOT DECISIVE
# ----------------------------------
# The first version backed out drmTMB's dispersion from the AGGREGATE variance of
# a sigma ~ x fit. Under a heteroscedastic (varying-sigma) fit, drmTMB::simulate()
# draws each row at its OWN (mu_i, sigma_i); the pooled sample is a MIXTURE, whose
# variance is  E_i[Var(Y|i)] + Var_i[E(Y|i)]  -- it carries the between-row spread
# of the MEAN as well as the within-row dispersion. So a single dispersion backed
# out of the pooled variance is contaminated and the implied-sigma ratios are not
# clean constants (CI aggregate gave ratios 1.86/2.53/5.79, uninterpretable).
#
# THIS PROBE IS DECISIVE BY CONSTRUCTION
# --------------------------------------
# It isolates ONE row (a single fitted (mu, sigma)) and draws a large iid sample
# at exactly those constant parameters from BOTH sides. With mu and sigma held
# constant there is NO mixture term, so:
#   * drmTMB::simulate() var == the within-row dispersion var at (mu, sigma);
#   * for each candidate sigma->dispersion mapping we can compute drm_sample_family
#     (or its closed-form var) at the SAME (mu, sigma) and read off the unique
#     mapping whose variance equals drmTMB's.
# It prints, per family: the fitted (mu, sigma), the true generating dispersion,
# drmTMB's per-row mean/var, and a SWEEP of candidate mappings with their var and
# relative error vs drmTMB -- the winning row IS the corrected mapping.
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  stopifnot(requireNamespace("drmTMB", quietly = TRUE))
  library(drmSEM)
}))

set.seed(1)
n <- 4000
x <- stats::rnorm(n)

# A single representative row at which to evaluate constant (mu, sigma). We use a
# value near the centre of x so the fit is well determined there.
x_probe <- 0

# Large iid draw count at the fixed (mu, sigma).
NDRAW <- 400000L

fmt <- function(v) formatC(v, digits = 5, format = "g")

# Report relative error of a candidate var vs the drmTMB target var.
relerr <- function(cand, target) abs(cand - target) / (abs(target) + 1e-12)

# Pretty-print one candidate mapping line and flag the best.
sweep_report <- function(label_var_fns, target_var) {
  errs <- vapply(
    label_var_fns,
    function(e) relerr(e$var, target_var),
    numeric(1)
  )
  best <- which.min(errs)
  for (i in seq_along(label_var_fns)) {
    e <- label_var_fns[[i]]
    flag <- if (i == best) "  <== BEST MATCH" else ""
    cat(sprintf(
      "    %-34s var=%-12s relerr=%-9s%s\n",
      e$label,
      fmt(e$var),
      fmt(errs[i]),
      flag
    ))
  }
}

probe <- function(family_name, family, response, true_disp_desc) {
  dat <- data.frame(x = x, y = response)
  fit <- tryCatch(
    drmTMB::drmTMB(drmTMB::bf(y ~ x, sigma ~ x), family = family, data = dat),
    error = function(e) {
      message("fit failed for ", family_name, ": ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(fit)) {
    return(invisible(NULL))
  }

  # ---- Constant per-row (mu, sigma) at x = x_probe (NO mixture contamination) --
  # Request each dpar SEPARATELY and extract the adapter-normalized estimate:
  # predict_parameters() does not reliably name its column `mu`/`sigma`, and
  # current builds append numeric newdata columns after `estimate`.
  pp_get <- function(dp, type) {
    out <- tryCatch(
      drmSEM:::drm_predict_parameter_values(
        fit,
        newdata = nd1,
        dpar = dp,
        type = type
      ),
      error = function(e) NULL
    )
    if (is.null(out) || !length(out)) NA_real_ else as.numeric(out)[1]
  }
  nd1 <- data.frame(x = x_probe)
  mu <- pp_get("mu", "response")
  sigma <- pp_get("sigma", "response")
  sigma_link <- pp_get("sigma", "link") # to expose a possible link-scale read bug

  # ---- drmTMB ground truth at this constant row -------------------------------
  # drmTMB's simulate is an S3 method dispatched via stats::simulate (the package
  # does NOT export `drmTMB::simulate` -- the matching test helper drm_sim_vector
  # calls stats::simulate). Simulate many nsim at the ORIGINAL data and keep the
  # rows nearest x_probe (params ~constant there, negligible mixture).
  sim_full <- tryCatch(
    stats::simulate(fit, nsim = 300L, seed = 7),
    error = function(e) NULL
  )
  sim <- if (is.null(sim_full)) {
    NULL
  } else {
    keep <- which(abs(x - x_probe) < 0.03)
    suppressWarnings(as.numeric(as.matrix(sim_full)[keep, , drop = FALSE]))
  }
  if (!is.null(sim)) {
    sim <- sim[is.finite(sim)]
  }
  sim <- sim[is.finite(sim)]

  cat(sprintf("\n=== %s ===\n", family_name))
  cat(sprintf(
    "  fitted at x=%.3g : mu(response)=%s  sigma(response)=%s  sigma(link)=%s\n",
    x_probe,
    fmt(mu),
    fmt(sigma),
    fmt(sigma_link)
  ))
  cat(sprintf("  true generating dispersion: %s\n", true_disp_desc))
  if (length(sim) == 0L) {
    cat("  drmTMB::simulate() unavailable at this row.\n")
    return(invisible(NULL))
  }
  m_tmb <- mean(sim)
  v_tmb <- stats::var(sim)
  cat(sprintf(
    "  drmTMB::simulate() @ row : mean=%s  var=%s  (n=%d)\n",
    fmt(m_tmb),
    fmt(v_tmb),
    length(sim)
  ))

  # ---- drm_sample_family() at this constant row (current mapping) -------------
  set.seed(11)
  drm_now <- drmSEM:::drm_sample_family(
    family_name,
    list(mu = rep(mu, NDRAW), sigma = rep(sigma, NDRAW)),
    NDRAW
  )
  cat(sprintf(
    "  drm_sample_family() CURRENT: mean=%s  var=%s  (var ratio drmSEM/drmTMB=%.3f)\n",
    fmt(mean(drm_now)),
    fmt(stats::var(drm_now)),
    stats::var(drm_now) / v_tmb
  ))

  # ---- Candidate sigma->dispersion mapping SWEEP (closed-form var) ------------
  # For each candidate dispersion parameter value d, the family variance is known
  # in closed form, so we can compare to drmTMB's var WITHOUT Monte-Carlo noise.
  cand <- function(label, v) list(label = label, var = v)
  cat("  candidate mappings (closed-form var at the SAME mu,sigma):\n")
  if (family_name == "nbinom2") {
    # NB2: var = mu + mu^2 / size  (size == theta)
    cands <- list(
      cand("size = 1/sigma^2 (CURRENT)", mu + mu^2 / (1 / sigma^2)),
      cand("size = 1/sigma", mu + mu^2 / (1 / sigma)),
      cand("size = sigma", mu + mu^2 / sigma),
      cand("size = sigma^2", mu + mu^2 / sigma^2),
      cand("size = exp(sigma) (link?)", mu + mu^2 / exp(sigma))
    )
    cat(sprintf(
      "    drmTMB implied theta = mu^2/(var-mu) = %s\n",
      fmt(mu^2 / (v_tmb - mu))
    ))
  } else if (family_name == "Gamma") {
    # Gamma: var = mu^2 / shape
    cands <- list(
      cand("shape = 1/sigma^2 (CURRENT)", mu^2 / (1 / sigma^2)),
      cand("shape = 1/sigma", mu^2 / (1 / sigma)),
      cand("shape = sigma", mu^2 / sigma),
      cand("shape = sigma^2", mu^2 / sigma^2),
      cand("var = sigma^2 (sigma=SD)", sigma^2)
    )
    cat(sprintf(
      "    drmTMB implied shape = mu^2/var = %s ; CV^2 = var/mu^2 = %s\n",
      fmt(mu^2 / v_tmb),
      fmt(v_tmb / mu^2)
    ))
  } else if (family_name == "beta") {
    # Beta: var = mu(1-mu)/(1+phi)
    pv <- function(phi) mu * (1 - mu) / (1 + phi)
    cands <- list(
      cand("phi = 1/sigma^2 (CURRENT)", pv(1 / sigma^2)),
      cand("phi = 1/sigma", pv(1 / sigma)),
      cand("phi = sigma", pv(sigma)),
      cand("phi = sigma^2", pv(sigma^2)),
      cand("phi = exp(sigma) (link?)", pv(exp(sigma)))
    )
    cat(sprintf(
      "    drmTMB implied phi = mu(1-mu)/var - 1 = %s\n",
      fmt(mu * (1 - mu) / v_tmb - 1)
    ))
  } else if (family_name == "lognormal") {
    # lognormal: with meanlog=ml, sdlog=sl:  mean=exp(ml+sl^2/2), var=(exp(sl^2)-1)*exp(2ml+sl^2)
    lnmean <- function(ml, sl) exp(ml + sl^2 / 2)
    lnvar <- function(ml, sl) (exp(sl^2) - 1) * exp(2 * ml + sl^2)
    cat(sprintf(
      "    drmTMB mean=%s var=%s. Candidate (meanlog,sdlog) means:\n",
      fmt(m_tmb),
      fmt(v_tmb)
    ))
    cat(sprintf(
      "      meanlog=mu,              sdlog=sigma  -> mean=%s var=%s (CURRENT)\n",
      fmt(lnmean(mu, sigma)),
      fmt(lnvar(mu, sigma))
    ))
    cat(sprintf(
      "      meanlog=log(mu),         sdlog=sigma  -> mean=%s var=%s\n",
      fmt(lnmean(log(mu), sigma)),
      fmt(lnvar(log(mu), sigma))
    ))
    cat(sprintf(
      "      meanlog=log(mu)-sig^2/2, sdlog=sigma  -> mean=%s var=%s\n",
      fmt(lnmean(log(mu) - sigma^2 / 2, sigma)),
      fmt(lnvar(log(mu) - sigma^2 / 2, sigma))
    ))
    cat(sprintf(
      "      meanlog=log(mu),         sdlog=sqrt(log(1+sig^2/mu^2)) -> mean=%s\n",
      fmt(lnmean(log(mu), sqrt(log(1 + sigma^2 / mu^2))))
    ))
    cat(
      "    (Current drmTMB exposes lognormal mu as meanlog, so meanlog=mu should match.)\n"
    )
    cands <- NULL
  } else {
    cands <- NULL
  }
  if (!is.null(cands)) {
    sweep_report(cands, v_tmb)
  }

  invisible(list(
    family = family_name,
    mu = mu,
    sigma = sigma,
    sigma_link = sigma_link,
    mean_tmb = m_tmb,
    var_tmb = v_tmb
  ))
}

# nbinom2 / Gamma / lognormal: positive responses; beta: (0,1).
probe(
  "nbinom2",
  drmTMB::nbinom2(),
  rnbinom(n, mu = exp(1 + 0.5 * x), size = 3),
  "size/theta = 3 (so var = mu + mu^2/3)"
)
probe(
  "Gamma",
  stats::Gamma(link = "log"), # drmTMB has no Gamma(); use stats::Gamma
  rgamma(n, shape = 2, rate = 2 / exp(1 + 0.5 * x)),
  "shape = 2 (so var = mu^2/2, CV^2 = 0.5)"
)
probe(
  "lognormal",
  drmTMB::lognormal(),
  rlnorm(n, meanlog = 1 + 0.5 * x, sdlog = 0.5),
  "sdlog = 0.5 (meanlog = 1 + 0.5x)"
)
probe(
  "beta",
  drmTMB::beta(),
  plogis(rnorm(n, 0.2 * x, 0.8)),
  "(no fixed phi; whatever drmTMB fits)"
)

cat("\n--------------------------------------------------------------------\n")
cat("HOW TO READ THIS DIAGNOSTIC:\n")
cat(
  "  * Each family's sweep prints candidate sigma->dispersion mappings with\n"
)
cat(
  "    their closed-form variance and relative error vs drmTMB::simulate().\n"
)
cat(
  "    The row marked '<== BEST MATCH' (relerr ~ 0) IS the corrected mapping.\n"
)
cat(
  "  * Compare fitted sigma(response) vs sigma(link) and the true generating\n"
)
cat(
  "    dispersion: for nbinom2, beta, and Gamma the current 1/sigma^2 mapping\n"
)
cat("    should remain the best match.\n")
cat("  * lognormal: current drmTMB exposes mu as meanlog and sigma as sdlog.\n")
cat(
  "  V-57..V-60 should remain real expect_lt assertions; failures here mean\n"
)
cat("  drmTMB's parameterization or predict_parameters() shape has drifted.\n")
