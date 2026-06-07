#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# OQ-1 sampler-dispersion probe (run on a LIVE drmTMB engine; not run in CI).
#
# Wave-1 recovery tests (V-57..V-60, test-recovery-samplers.R) found that
# drmSEM::drm_sample_family() reproduces drmTMB::simulate()'s MEAN but not its
# VARIANCE for nbinom2/beta/Gamma (variance inflated +61/+220/+150%), and shifts
# the lognormal MEAN. This script isolates the cause so the correct
# sigma <-> dispersion mapping can be read off and drm_sample_family() (or the
# R/extractors.R sigma read) fixed. After the fix, flip the V-57..V-60 skips to
# asserts and update OPEN_QUESTIONS OQ-1 / CODEX_HANDOFF item 7.
#
# Usage:  Rscript inst/validation/sampler-dispersion-probe.R
# Needs:  a working drmTMB install (compiler/TMB). See CLOUD.md.
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  stopifnot(requireNamespace("drmTMB", quietly = TRUE))
  library(drmSEM)
}))

set.seed(1)
n <- 4000
x <- stats::rnorm(n)

# Fit a heteroscedastic (sigma ~ x) node for one family, then at the fitted,
# per-row response-scale params compare drm_sample_family() vs drmTMB::simulate()
# and report the dispersion drmTMB actually used vs the one drmSEM assumed.
probe <- function(family_name, family, response) {
  dat <- data.frame(x = x, y = response)
  fit <- tryCatch(
    drmTMB::drmTMB(drmTMB::bf(y ~ x, sigma ~ x), family = family, data = dat),
    error = function(e) { message("fit failed for ", family_name, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(fit)) return(invisible(NULL))

  # response-scale fitted params per row (the same drm_sample_family() consumes)
  pp <- drmTMB::predict_parameters(fit, newdata = dat, dpar = c("mu", "sigma"),
                                   type = "response")
  pp <- as.data.frame(pp)
  mu <- as.numeric(pp[["mu"]]); sigma <- as.numeric(pp[["sigma"]])

  params <- list(mu = mu, sigma = sigma)
  rep <- 60L
  big_mu <- rep(mu, rep); big_sigma <- rep(sigma, rep)
  drm_draws <- drmSEM:::drm_sample_family(family_name,
                                          list(mu = big_mu, sigma = big_sigma),
                                          length(big_mu))
  sim <- tryCatch(as.numeric(unlist(drmTMB::simulate(fit, nsim = rep))),
                  error = function(e) NULL)

  cat(sprintf("\n=== %s ===\n", family_name))
  cat(sprintf("  fitted sigma: mean=%.4g  range=[%.4g, %.4g]\n",
              mean(sigma), min(sigma), max(sigma)))
  cat(sprintf("  drmSEM    sampler: mean=%.5g  var=%.5g\n",
              mean(drm_draws), stats::var(drm_draws)))
  if (!is.null(sim)) {
    cat(sprintf("  drmTMB::simulate : mean=%.5g  var=%.5g\n",
                mean(sim), stats::var(sim)))
    cat(sprintf("  var ratio drmSEM/drmTMB = %.3f\n",
                stats::var(drm_draws) / stats::var(sim)))
  }

  # Back out the dispersion drmTMB actually used, per family, from its variance,
  # and compare to drmSEM's assumed mapping. Read off the corrected sigma-scale.
  m <- mean(mu)
  if (!is.null(sim)) {
    v_tmb <- stats::var(sim)
    if (family_name == "nbinom2") {
      # NB2: var = mu + mu^2 / theta  =>  theta_tmb = mu^2 / (var - mu)
      theta_tmb <- m^2 / (v_tmb - m)
      cat(sprintf("  [nbinom2] drmTMB theta ~= %.4g ; drmSEM used size=1/sigma^2=%.4g ; sigma_implied=1/sqrt(theta)=%.4g vs fitted sigma=%.4g\n",
                  theta_tmb, 1 / mean(sigma)^2, 1 / sqrt(theta_tmb), mean(sigma)))
    } else if (family_name == "beta") {
      # Beta: var = mu(1-mu)/(1+phi)  =>  phi_tmb = mu(1-mu)/var - 1
      phi_tmb <- m * (1 - m) / v_tmb - 1
      cat(sprintf("  [beta] drmTMB phi ~= %.4g ; drmSEM used phi=1/sigma^2=%.4g ; sigma_implied=1/sqrt(phi)=%.4g vs fitted sigma=%.4g\n",
                  phi_tmb, 1 / mean(sigma)^2, 1 / sqrt(phi_tmb), mean(sigma)))
    } else if (family_name == "Gamma") {
      # Gamma: var = mu^2 / shape  =>  shape_tmb = mu^2 / var
      shape_tmb <- m^2 / v_tmb
      cat(sprintf("  [Gamma] drmTMB shape ~= %.4g ; drmSEM used shape=1/sigma^2=%.4g ; sigma_implied=1/sqrt(shape)=%.4g vs fitted sigma=%.4g\n",
                  shape_tmb, 1 / mean(sigma)^2, 1 / sqrt(shape_tmb), mean(sigma)))
    } else if (family_name == "lognormal") {
      # lognormal: E[Y]=exp(meanlog+s^2/2). drmSEM uses meanlog=log(mu); if mu is
      # the RESPONSE MEAN, meanlog should be log(mu)-s^2/2. Report the implied s.
      cat(sprintf("  [lognormal] drmSEM meanlog=log(mu) gives mean=%.5g; drmTMB mean=%.5g. If mu is the response mean, meanlog should be log(mu)-sigma^2/2.\n",
                  mean(drm_draws), mean(sim)))
    }
  }
  invisible(NULL)
}

# nbinom2 / Gamma / lognormal: positive responses; beta: (0,1).
probe("nbinom2",  drmTMB::nbinom2(),  rnbinom(n, mu = exp(1 + 0.5 * x), size = 3))
probe("Gamma",    drmTMB::Gamma(link = "log"),
      rgamma(n, shape = 2, rate = 2 / exp(1 + 0.5 * x)))
probe("lognormal", drmTMB::lognormal(),
      rlnorm(n, meanlog = 1 + 0.5 * x, sdlog = 0.5))
probe("beta",     drmTMB::beta(),
      plogis(rnorm(n, 0.2 * x, 0.8)))

cat("\nRead off the corrected sigma<->dispersion mapping above, fix",
    "drm_sample_family() / the sigma extractor, then flip V-57..V-60 to asserts.\n")
