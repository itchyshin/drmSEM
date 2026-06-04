# OQ-1: confirm drmSEM's family samplers (drm_sample_family) match drmTMB's
# parameterization. drmTMB is the ground truth via simulate(); we compare the
# moments of drm_sample_family() at the fitted parameters to the data and to
# drmTMB::simulate(). Requires the engine; runs in CI.
#
# STEP 1 (this commit) is an *introspection* probe: it logs the shapes of
# predict_parameters() and simulate() so the moment-comparison can be written
# against the real API rather than guessed. It does not assert parameterization
# yet (expect_true(TRUE)); the CI log is the deliverable.

skip_if_not_installed("drmTMB")

dump_obj <- function(label, x) {
  cat("\n--- ", label, " ---\n", sep = "")
  cat(paste(utils::capture.output(utils::str(x)), collapse = "\n"), "\n")
}

test_that("OQ-1 introspection: nbinom2 predict_parameters / simulate shapes", {
  set.seed(1)
  n <- 600
  y <- stats::rnbinom(n, mu = 6, size = 2)        # var = mu + mu^2/size = 6 + 18 = 24
  dat <- data.frame(y = y, g = stats::rnorm(n))
  fit <- tryCatch(
    drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::nbinom2(), data = dat),
    error = function(e) { cat("FIT ERROR:", conditionMessage(e), "\n"); NULL }
  )
  skip_if(is.null(fit), "nbinom2 fit failed")

  nd <- dat[1, , drop = FALSE]
  pp <- tryCatch(drm_predict_parameters(fit, newdata = nd, type = "response"),
                 error = function(e) paste("predict_parameters error:", conditionMessage(e)))
  dump_obj("predict_parameters(type=response)", pp)
  ppl <- tryCatch(drm_predict_parameters(fit, newdata = nd, type = "link"),
                  error = function(e) paste("predict_parameters(link) error:", conditionMessage(e)))
  dump_obj("predict_parameters(type=link)", ppl)

  co <- tryCatch(fit$coefficients, error = function(e) NULL)
  dump_obj("fit$coefficients", co)

  sm <- tryCatch(stats::simulate(fit, nsim = 1), error = function(e) paste("simulate error:", conditionMessage(e)))
  dump_obj("simulate(nsim=1)", sm)

  cat("\n--- data moments: mean =", round(mean(y), 3), " var =", round(stats::var(y), 3),
      " (theoretical var = 24) ---\n")
  expect_true(TRUE)
})

test_that("OQ-1 introspection: beta and lognormal shapes", {
  set.seed(2)
  n <- 600
  # beta: mean 0.4, moderate precision
  yb <- stats::rbeta(n, shape1 = 0.4 * 8, shape2 = 0.6 * 8)
  db <- data.frame(y = yb)
  fb <- tryCatch(drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::beta(), data = db),
                 error = function(e) { cat("beta fit error:", conditionMessage(e), "\n"); NULL })
  if (!is.null(fb)) {
    pp <- tryCatch(drm_predict_parameters(fb, newdata = db[1, , drop = FALSE], type = "response"),
                   error = function(e) paste("err:", conditionMessage(e)))
    dump_obj("beta predict_parameters(response)", pp)
    cat("beta data: mean =", round(mean(yb), 3), " var =", round(stats::var(yb), 4), "\n")
  }

  # lognormal: response-scale mean exp(mu + s^2/2)
  yl <- stats::rlnorm(n, meanlog = 1.0, sdlog = 0.5)
  dl <- data.frame(y = yl)
  fl <- tryCatch(drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::lognormal(), data = dl),
                 error = function(e) { cat("lognormal fit error:", conditionMessage(e), "\n"); NULL })
  if (!is.null(fl)) {
    pp <- tryCatch(drm_predict_parameters(fl, newdata = dl[1, , drop = FALSE], type = "response"),
                   error = function(e) paste("err:", conditionMessage(e)))
    dump_obj("lognormal predict_parameters(response)", pp)
    cat("lognormal data: mean =", round(mean(yl), 3), " sd =", round(stats::sd(yl), 3), "\n")
  }
  expect_true(TRUE)
})
