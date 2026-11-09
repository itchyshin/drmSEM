# Effect engine (R/effects.R): the pure helpers (scenario builder, summaries,
# argument guards, printing) are tested with hand-built objects; the user-facing
# direct_/total_/indirect_effects() are tested on small drmTMB fits of the "chain"
# DGP in helper-cov-fits.R and checked against the known truth.

capture_effect_print <- function(x) {
  res <- NULL
  out <- utils::capture.output(msg <- cli::cli_fmt(res <- print(x)))
  list(text = paste(c(msg, out), collapse = "\n"), res = res)
}

# ---- drm_build_scenarios(): pure -------------------------------------------------

fake_obj <- function(data, endogenous = character(0), records = list()) {
  list(data = data, endogenous = endogenous, records = records, composites = NULL, latent_constructs = NULL)
}

test_that("drm_build_scenarios contrasts a numeric column at mean +/- 0.5 sd by default", {
  d <- data.frame(x = c(1, 2, 3, 4), y = 0)
  sc <- drmSEM:::drm_build_scenarios(fake_obj(d), "x")
  s <- stats::sd(d$x)
  expect_equal(sc$at, c(mean(d$x) - 0.5 * s, mean(d$x) + 0.5 * s))
  expect_equal(unique(sc$lo$x), sc$at[[1]])
  expect_equal(unique(sc$hi$x), sc$at[[2]])
  expect_identical(sc$column, "x")
  # explicit contrast values win
  sc2 <- drmSEM:::drm_build_scenarios(fake_obj(d), "x", at = c(0, 10))
  expect_equal(unique(sc2$hi$x), 10)
})

test_that("drm_build_scenarios contrasts the first two levels of a factor, keeping its levels", {
  d <- data.frame(g = factor(c("a", "b", "c", "a")), y = 0)
  sc <- drmSEM:::drm_build_scenarios(fake_obj(d), "g")
  expect_identical(sc$at, c("a", "b"))
  expect_identical(levels(sc$lo$g), c("a", "b", "c"))
  expect_true(all(sc$lo$g == "a"))
  expect_true(all(sc$hi$g == "b"))
  # character columns are sorted to pick the two levels
  dc <- data.frame(g = c("z", "y", "z"), y = 0)
  expect_identical(drmSEM:::drm_build_scenarios(fake_obj(dc), "g")$at, c("y", "z"))
})

test_that("drm_build_scenarios resolves a node name to its data column and rejects bad inputs", {
  d <- data.frame(size_cm = c(1, 2, 3), y = 0)
  obj <- fake_obj(d, "size", list(size = list(identifiers = c("size", "size_cm"))))
  expect_identical(drmSEM:::drm_build_scenarios(obj, "size")$column, "size_cm")

  no_col <- fake_obj(d, "size", list(size = list(identifiers = "size")))
  expect_error(drmSEM:::drm_build_scenarios(no_col, "size"), "Cannot find a data column")
  expect_error(drmSEM:::drm_build_scenarios(fake_obj(d), "nope"), "is not a column in the model data")
  one_level <- data.frame(g = factor(rep("a", 3)), y = 0)
  expect_error(drmSEM:::drm_build_scenarios(fake_obj(one_level), "g"), "fewer than two levels")
})

# ---- summaries ---------------------------------------------------------------------

test_that("drm_summ reports the mean and percentile interval of the finite draws only", {
  v <- c(1, 2, 3, 4, 5, NA, Inf)
  s <- drmSEM:::drm_summ(v, level = 0.8)
  expect_equal(s$estimate, 3)
  expect_equal(s$conf.low, stats::quantile(1:5, 0.1, names = FALSE))
  expect_equal(s$conf.high, stats::quantile(1:5, 0.9, names = FALSE))
  # a single finite draw has an estimate but no interval; none at all gives NA
  one <- drmSEM:::drm_summ(c(2, NA))
  expect_equal(one$estimate, 2)
  expect_true(is.na(one$conf.low) && is.na(one$conf.high))
  none <- drmSEM:::drm_summ(c(NA_real_, NaN))
  expect_true(is.na(none$estimate))
})

test_that("drm_summ_boot keeps the original estimate and reports bootstrap SE and intervals", {
  b <- c(0.8, 1.0, 1.2, 1.4, NA)
  s <- drmSEM:::drm_summ_boot(1.1, b, level = 0.9)
  expect_equal(s$estimate, 1.1)
  expect_equal(s$std.error, stats::sd(b[1:4]))
  expect_equal(attr(s, "boot_ci_normal"), 1.1 + c(-1, 1) * stats::qnorm(0.95) * stats::sd(b[1:4]))
  expect_equal(attr(s, "boot_converged"), 4L)
  # a missing original estimate falls back to the mean of the replicates
  expect_equal(drmSEM:::drm_summ_boot(NA_real_, b)$estimate, mean(b[1:4]))
  # nothing finite at all: everything is NA, no error
  empty <- drmSEM:::drm_summ_boot(NA_real_, c(NA_real_, NA_real_))
  expect_true(is.na(empty$estimate) && is.na(empty$std.error))
  expect_equal(attr(empty, "boot_converged"), 0L)
})

test_that("drm_value_issues counts non-finite draws", {
  vi <- drmSEM:::drm_value_issues
  expect_identical(nrow(vi(list())), 0L)
  expect_identical(nrow(vi(list(c(1, 2), c(3)))), 0L)
  out <- vi(list(c(1, NA), c(Inf, 2, NaN)))
  expect_identical(out$issue, "nonfinite_effect_draws")
  expect_identical(out$n, 3L)
})

test_that("drm_finalize_effect warns about non-finite draws and attaches the issue tables", {
  out <- data.frame(estimate = 1)
  expect_warning(
    res <- drmSEM:::drm_finalize_effect(out, list(), FALSE, list(c(1, NA, 3))),
    "non-finite"
  )
  expect_identical(attr(res, "value_issues")$n, 1L)
  expect_identical(nrow(attr(res, "uncertainty_issues")), 0L)
  expect_no_warning(drmSEM:::drm_finalize_effect(out, list(), FALSE, list(c(1, 2))))
  # non-converged nodes surface as partial evidence
  eng <- list(a = list(name = "a", converged = FALSE, components = character(0)))
  expect_warning(
    res2 <- drmSEM:::drm_finalize_effect(out, eng, FALSE),
    "partial"
  )
  expect_identical(attr(res2, "uncertainty_issues")$issue, "not_converged")
})

# ---- argument guards ---------------------------------------------------------------

test_that("drm_validate_effect_args requires an endogenous target distinct from the source", {
  obj <- list(endogenous = c("m", "y"))
  expect_null(drmSEM:::drm_validate_effect_args(obj, "x", "y"))
  expect_error(drmSEM:::drm_validate_effect_args(obj, "x", "z"), "must be an endogenous node")
  expect_error(drmSEM:::drm_validate_effect_args(obj, "y", "y"), "must differ")
})

test_that("drm_analytic_or_abort explains when no closed form exists for the family", {
  eng <- list(
    y = list(
      name = "y", identifier = "y", family = "truncated_nbinom2", components = "mu",
      coef = list(), vcov = NULL,
      predict = function(scenario, beta = NULL) data.frame(mu = rep(0.5, nrow(scenario)))
    )
  )
  scen <- list(
    lo = data.frame(x = rep(0, 4), y = 0),
    hi = data.frame(x = rep(1, 4), y = 0),
    column = "x"
  )
  expect_error(
    drmSEM:::drm_analytic_or_abort(
      eng, scen, "y", character(0), "mean", "p_gt", 0, 0.5, 1L, FALSE, NULL
    ),
    "No closed-form"
  )
})

test_that("drm_block_feedback_decomp is silent for an acyclic SEM", {
  expect_null(drmSEM:::drm_block_feedback_decomp(list(feedback = NULL, edges = data.frame()), "indirect_effects"))
})

# ---- print.drm_effect --------------------------------------------------------------

test_that("print.drm_effect shows the table, coefficient block, and issue notes", {
  eff <- structure(
    data.frame(
      from = "x", to = "y", estimate = 0.123456, conf.low = NA_real_,
      identified = NA, mediator = NA_character_
    ),
    coefficients = data.frame(from = "x", to = "y", component = "mu", estimate = 0.3),
    uncertainty_issues = data.frame(node = "y", component = "sigma", issue = "vcov_not_psd"),
    value_issues = data.frame(issue = "nonfinite_effect_draws", n = 2L),
    class = c("drm_effect", "data.frame")
  )
  p <- capture_effect_print(eff)
  expect_identical(p$res, eff)
  expect_match(p$text, "<drmSEM effect>", fixed = TRUE)
  expect_match(p$text, "0.1235", fixed = TRUE) # rounded to 4 d.p.
  expect_no_match(p$text, "identified") # all-NA helper columns are dropped
  expect_no_match(p$text, "mediator")
  expect_match(p$text, "conf.low", fixed = TRUE) # but NA interval columns stay visible
  expect_match(p$text, "Direct fitted coefficients")
  expect_match(p$text, "Uncertainty notes")
  expect_match(p$text, "vcov_not_psd")
  expect_match(p$text, "Effect-draw notes")
  expect_match(p$text, "nonfinite_effect_draws")
})

# ---- end-to-end on the chain DGP ---------------------------------------------------

chain_truth <- function(dat, at_x, mediate = FALSE) {
  # P(y > 0) at a given x, with m held at its observed value (direct) or at its
  # DGP conditional mean (mediated), averaged over the observed rows
  m_obs <- if (mediate) 0.5 * at_x + 0.4 * (dat$g == "B") else dat$m
  mean(stats::pnorm((0.3 * at_x + 0.8 * m_obs) / exp(-0.2 + 0.3 * at_x)))
}

test_that("direct_effects recovers the direct mean effect and its sigma-path coefficients", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  de <- direct_effects(sem, "x", "y", uncertainty = "none")
  expect_s3_class(de, "drm_effect")
  # direct mean effect: 0.3 per unit x, contrasted over +/- 0.5 sd (one sd)
  expect_lt(abs(de$estimate - 0.3 * stats::sd(dat$x)), 0.1)
  # the coefficient table is component-labelled and restricted on request
  all_co <- attr(de, "coefficients")
  expect_setequal(all_co$component, c("mu", "sigma"))
  sig <- direct_effects(sem, "x", "y", component = "sigma", uncertainty = "none")
  co <- attr(sig, "coefficients")
  expect_identical(unique(co$component), "sigma")
  expect_lt(abs(co$estimate[co$term == "x"] - 0.3), 0.25) # DGP: log-sigma slope 0.3
})

test_that("direct_effects on a tail probability tracks the DGP, via analytic and simulated routes", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  s <- stats::sd(dat$x)
  at <- mean(dat$x) + c(-0.5, 0.5) * s
  truth <- chain_truth(dat, at[2]) - chain_truth(dat, at[1])

  an <- direct_effects(
    sem, "x", "y", target = "p_gt", threshold = 0, functional = "analytic",
    uncertainty = "none"
  )
  expect_identical(an$target, "p_gt")
  expect_lt(abs(an$estimate - truth), 0.04)

  sm <- direct_effects(
    sem, "x", "y", target = "p_gt", threshold = 0, functional = "simulate",
    uncertainty = "none", nsim = 60, seed = 1
  )
  # the simulated route agrees with the closed form up to Monte-Carlo error
  expect_lt(abs(sm$estimate - an$estimate), 0.02)
})

test_that("total_effects recovers the total mean effect, and a factor source uses its level contrast", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  te <- total_effects(sem, "x", "y", method = "gcomp", uncertainty = "none")
  expect_lt(abs(te$estimate - 0.7 * stats::sd(dat$x)), 0.12)
  # factor source: g = B shifts m by 0.4, so y by 0.8 * 0.4 through the chain
  tg <- total_effects(sem, "g", "y", method = "gcomp", uncertainty = "none")
  expect_lt(abs(tg$estimate - 0.32), 0.2)
  # an unknown source is rejected with a pointer to the model data
  expect_error(total_effects(sem, "nope", "y", uncertainty = "none"), "not a column")
  expect_error(total_effects(sem, "y", "y", uncertainty = "none"), "must differ")
  expect_error(total_effects(sem, "x", "g", uncertainty = "none"), "endogenous node")
})

test_that("total_effects tail probability: analytic matches the DGP, simulate needs the right method", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  at <- mean(dat$x) + c(-0.5, 0.5) * stats::sd(dat$x)
  truth <- chain_truth(dat, at[2], TRUE) - chain_truth(dat, at[1], TRUE)
  an <- total_effects(
    sem, "x", "y", method = "gcomp", target = "p_gt", threshold = 0,
    functional = "analytic", uncertainty = "none"
  )
  expect_lt(abs(an$estimate - truth), 0.04)
  # analytic functionals need deterministic mediators
  expect_error(
    total_effects(
      sem, "x", "y", method = "simulate", target = "p_gt", functional = "analytic",
      uncertainty = "none"
    ),
    "requires mean mediation"
  )
  sm <- total_effects(
    sem, "x", "y", method = "simulate", target = "p_gt", threshold = 0,
    uncertainty = "none", nsim = 80, seed = 3
  )
  expect_lt(abs(sm$estimate - truth), 0.05)
})

test_that("indirect_effects: controlled legs close and are mean-consistent", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  s <- stats::sd(dat$x)
  ie <- indirect_effects(sem, "x", "y", uncertainty = "none", nsim = 30, seed = 5)
  est <- stats::setNames(ie$estimate, ie$quantity)
  expect_equal(unname(est["indirect"]), unname(est["mean_mediated"] + est["distribution_mediated"]), tolerance = 1e-8)
  expect_equal(unname(est["total_path"]), unname(est["direct"] + est["indirect"]), tolerance = 1e-8)
  expect_lt(abs(est[["mean_mediated"]] - 0.4 * s), 0.1)
})

test_that("indirect_effects reports an outcome functional on every leg and bootstraps it", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  ie <- indirect_effects(
    sem, "x", "y", target = "p_gt", threshold = 0, uncertainty = "none", nsim = 30, seed = 7
  )
  expect_true(all(ie$target == "p_gt"))
  est <- stats::setNames(ie$estimate, ie$quantity)
  expect_equal(unname(est["indirect"]), unname(est["mean_mediated"] + est["distribution_mediated"]), tolerance = 1e-8)
  # raising x raises the chance that y > 0 through m
  expect_gt(est[["indirect"]], 0)

  qb <- indirect_effects(
    sem, "x", "y", target = "quantile", prob = 0.75, uncertainty = "bootstrap", B = 2L,
    seed = 8L, nsim = 5
  )
  expect_s3_class(qb, "drm_effect")
  expect_true(all(is.finite(qb$estimate)))
  # a restricted `through` set that excludes every mediator leaves no indirect path
  none <- indirect_effects(sem, "x", "y", through = "zzz", uncertainty = "none", nsim = 5, seed = 9)
  expect_equal(none$estimate[none$quantity == "indirect"], 0, tolerance = 1e-8)
})

test_that("print.drm_effect on a fitted effect lists the direct coefficients", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  de <- direct_effects(sem, "x", "y", uncertainty = "none")
  p <- capture_effect_print(de)
  expect_match(p$text, "Direct fitted coefficients")
  expect_match(p$text, "sigma")
})
