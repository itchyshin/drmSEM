# The drmTMB adapter (R/extractors.R). Pure shape-readers are tested on hand-built
# fit-like lists; the engine-backed ones (refit, rho12, design matrices) on small
# live fits. Every assumption about drmTMB's return shapes lives in this file, so
# these tests pin the contract the rest of drmSEM relies on.

fake_fit <- function(formula, coefficients = NULL, ...) {
  structure(c(list(formula = formula, coefficients = coefficients), list(...)), class = "fake_fit")
}

# ---- family / formula readers ------------------------------------------------------

test_that("drm_family_name reads character, list, and family objects, else 'unknown'", {
  expect_identical(drmSEM:::drm_family_name(c("poisson", "x")), "poisson")
  expect_identical(drmSEM:::drm_family_name(list(family = "beta")), "beta")
  expect_identical(drmSEM:::drm_family_name(stats::gaussian()), "gaussian")
  expect_identical(drmSEM:::drm_family_name(stats::poisson()), "poisson")
  expect_identical(drmSEM:::drm_family_name(42), "unknown")
  expect_identical(drmSEM:::drm_family_name(list(other = 1)), "unknown")
})

test_that("drm_fit_entries aborts with a clear message when the formula has no entries", {
  expect_error(drmSEM:::drm_fit_entries(list(formula = list())), "Could not read formula entries")
})

test_that("drm_fit_response, components, and predictors read the formula entries", {
  skip_if_not_installed("drmTMB")
  f <- drmTMB::bf(y ~ x + z, sigma ~ x)
  fit <- fake_fit(f, coefficients = list(
    mu = c("(Intercept)" = 0, x = 1, z = 2), sigma = c("(Intercept)" = 0, x = 0.3)
  ))
  r <- drmSEM:::drm_fit_response(fit)
  expect_identical(r$vars, "y")
  expect_identical(drmSEM:::drm_fit_components(fit), c("mu", "sigma"))
  expect_identical(drmSEM:::drm_fit_component_predictors(fit, "mu"), c("x", "z"))
  expect_identical(drmSEM:::drm_fit_component_predictors(fit, "sigma"), "x")
  expect_identical(drmSEM:::drm_fit_component_predictors(fit, "zi"), character(0))
  expect_setequal(drmSEM:::drm_node_vars(fit), c("y", "x", "z"))
  # prediction components include fitted default intercept components
  fit2 <- fake_fit(drmTMB::bf(y ~ x), coefficients = list(mu = c(x = 1), sigma = c("(Intercept)" = 0)))
  expect_identical(drmSEM:::drm_fit_prediction_components(fit2), c("mu", "sigma"))
})

test_that("drm_fit_response falls back to any entry with a response when mu has none", {
  fit <- fake_fit(list(entries = list(
    list(dpar = "sigma", response = NA_character_, lhs = quote(sigma)),
    list(dpar = "mu1", response = "a", lhs = quote(a))
  )))
  expect_identical(drmSEM:::drm_fit_response(fit), list(label = "a", vars = "a"))
  none <- fake_fit(list(entries = list(list(dpar = "sigma", response = NA_character_, lhs = quote(s)))))
  r <- drmSEM:::drm_fit_response(none)
  expect_true(is.na(r$label))
  expect_identical(r$vars, character(0))
})

# ---- coefficients, likelihood, convergence ----------------------------------------------

test_that("coefficient readers flatten to dpar:term names and tolerate absent components", {
  co <- list(mu = c("(Intercept)" = 1, x = 2), sigma = c("(Intercept)" = -0.5), zi = numeric(0))
  fit <- fake_fit(list(), coefficients = co)
  expect_equal(
    drmSEM:::drm_fit_coef_vector(fit),
    c("mu:(Intercept)" = 1, "mu:x" = 2, "sigma:(Intercept)" = -0.5)
  )
  expect_equal(drmSEM:::drm_fit_coef(fit, "mu"), co$mu)
  expect_identical(length(drmSEM:::drm_fit_coef(fit, "nu")), 0L)
  expect_identical(length(drmSEM:::drm_fit_coef(fake_fit(list()), "mu")), 0L)
})

test_that("drm_fit_logLik and drm_fit_vcov degrade to NA / NULL instead of erroring", {
  ll <- drmSEM:::drm_fit_logLik(fake_fit(list()))
  expect_true(is.na(ll$logLik))
  expect_true(is.na(ll$df))
  expect_null(drmSEM:::drm_fit_vcov(fake_fit(list())))
  expect_true(is.na(drmSEM:::drm_fit_nobs(fake_fit(list()))))
})

test_that("drm_fit_converged falls back to the optimiser code, or NA when it is absent", {
  expect_true(drmSEM:::drm_fit_converged(list(opt = list(convergence = 0L))))
  expect_false(drmSEM:::drm_fit_converged(list(opt = list(convergence = 1L))))
  expect_true(is.na(drmSEM:::drm_fit_converged(list())))
})

test_that("drm_fit_model_type and drm_fit_trials read engine metadata defensively", {
  expect_identical(drmSEM:::drm_fit_model_type(list(model = list(model_type = "hurdle_nbinom2"))), "hurdle_nbinom2")
  expect_true(is.na(drmSEM:::drm_fit_model_type(list())))
  expect_true(is.na(drmSEM:::drm_fit_model_type(list(model = list(model_type = c("a", "b"))))))
  expect_equal(drmSEM:::drm_fit_trials(list(model = list(trials = 10)), 4), rep(10, 4))
  expect_equal(drmSEM:::drm_fit_trials(list(model = list(trials = c(5, 6, 7))), 3), c(5, 6, 7))
  # a length that cannot be aligned, or a non-numeric entry, is refused rather than guessed
  expect_null(drmSEM:::drm_fit_trials(list(model = list(trials = c(5, 6))), 3))
  expect_null(drmSEM:::drm_fit_trials(list(model = list(trials = "ten")), 3))
  expect_null(drmSEM:::drm_fit_trials(list(), 3))
})

# ---- grouping variables ------------------------------------------------------------------

test_that("drm_fit_grouping_vars reads bars from nodes, pairs, formulas, and lists", {
  skip_if_not_installed("drmTMB")
  f <- drmTMB::bf(y ~ x + (1 | site), sigma ~ (1 | year))
  node <- drm_node(f, family = stats::gaussian())
  expect_setequal(drmSEM:::drm_fit_grouping_vars(node), c("site", "year"))
  expect_setequal(drmSEM:::drm_fit_grouping_vars(f), c("site", "year"))
  expect_setequal(drmSEM:::drm_fit_grouping_vars(fake_fit(f)), c("site", "year"))
  expect_identical(drmSEM:::drm_fit_grouping_vars(NULL), character(0))
  expect_identical(drmSEM:::drm_fit_grouping_vars(1 + 1), character(0))
  expect_setequal(drmSEM:::drm_fit_grouping_vars(y ~ x + (1 | g)), "g")
  expect_identical(drmSEM:::drm_fit_grouping_vars(list(formula = y ~ x + (1 | g))), "g")
  expect_warning(pr <- drm_pair(a ~ x, b ~ x, level = "site"), "not a grouping")
  expect_identical(drmSEM:::drm_fit_grouping_vars(pr), "site")
  # intercept-only / ungrouped nodes have none
  expect_identical(drmSEM:::drm_fit_grouping_vars(drm_node(drmTMB::bf(y ~ x), family = stats::gaussian())), character(0))
})

test_that("drm_sem_grouping_vars collects the grouping factors across nodes", {
  skip_if_not_installed("drmTMB")
  obj <- list(nodes = list(
    a = drmTMB::bf(a ~ x + (1 | site)),
    b = drmTMB::bf(b ~ x + (1 | year))
  ))
  expect_setequal(drmSEM:::drm_sem_grouping_vars(obj), c("site", "year"))
  expect_identical(drmSEM:::drm_sem_grouping_vars(list()), character(0))
})

# ---- engine function borrowing ------------------------------------------------------------

test_that("drm_engine_fun returns a function when the engine has it, NULL otherwise", {
  skip_if_not_installed("drmTMB")
  expect_null(drmSEM:::drm_engine_fun("definitely_not_a_drmTMB_internal"))
  expect_true(is.function(drmSEM:::drm_engine_fun("drmTMB")))
})

# ---- node rows ---------------------------------------------------------------------------

test_that("drm_node_rows is the complete-case set over the node's own variables", {
  skip_if_not_installed("drmTMB")
  fit <- fake_fit(drmTMB::bf(y ~ x))
  d <- data.frame(y = c(1, NA, 3, 4), x = c(1, 2, NA, 4), other = c(NA, NA, NA, NA))
  expect_identical(drmSEM:::drm_node_rows(fit, d), c(TRUE, FALSE, FALSE, TRUE))
  # an imputed predictor keeps its rows
  expect_identical(drmSEM:::drm_node_rows(fit, d, exclude = "x"), c(TRUE, FALSE, TRUE, TRUE))
  # nothing to check -> every row is used
  expect_identical(drmSEM:::drm_node_rows(fit, data.frame(z = 1:3)), rep(TRUE, 3))
})

# ---- prediction column selection ------------------------------------------------------------

test_that("drm_prediction_estimate_column finds the estimate under any drmTMB column layout", {
  f <- drmSEM:::drm_prediction_estimate_column
  expect_equal(f(data.frame(mu = c(1, 2)), "mu", 2), c(1, 2))
  expect_equal(f(data.frame(estimate = c(3, 4), row = 1:2), "mu", 2), c(3, 4))
  # no named column: the last numeric non-metadata column is taken
  pp <- data.frame(row = 1:2, std.error = c(0.1, 0.1), fitted_value = c(5, 6), x = c(9, 9))
  expect_equal(f(pp, "mu", 2, newdata_names = "x"), c(5, 6))
  # wrong length everywhere -> NA of the right length, never a recycled guess
  expect_identical(f(data.frame(mu = 1), "mu", 3), rep(NA_real_, 3))
  expect_identical(f(data.frame(label = c("a", "b")), "mu", 2), rep(NA_real_, 2))
})

# ---- design matrices ---------------------------------------------------------------------------

test_that("drm_fixed_design builds model-matrix columns aligned to fitted coefficient names", {
  skip_if_not_installed("drmTMB")
  fit <- fake_fit(
    drmTMB::bf(y ~ x + g + (1 | site)),
    coefficients = list(mu = c("(Intercept)" = 0, x = 1, gB = 2))
  )
  nd <- data.frame(x = c(1, NA, 3), g = factor(c("A", "B", "B"), levels = c("A", "B")))
  dm <- drmSEM:::drm_fixed_design(fit, "mu", nd)
  expect_identical(colnames(dm), c("(Intercept)", "x", "gB"))
  expect_identical(nrow(dm), 3L)
  expect_equal(dm[, "x"], c(1, NA, 3))
  expect_equal(dm[, "gB"], c(0, 1, 1))
  # a component with no fitted coefficients yields a zero-column matrix
  expect_identical(dim(drmSEM:::drm_fixed_design(fit, "sigma", nd)), c(3L, 0L))
  # intercept-free coefficient set drops the intercept column
  fit0 <- fake_fit(drmTMB::bf(y ~ x), coefficients = list(mu = c(x = 1)))
  d0 <- drmSEM:::drm_fixed_design(fit0, "mu", data.frame(x = c(2, 4)))
  expect_equal(unname(d0[, "x"]), c(2, 4))
})

# ---- engine-backed adapters ----------------------------------------------------------------------

test_that("drm_refit_augmented adds a predictor to chosen components, and returns NULL on failure", {
  skip_if_not_installed("drmTMB")
  d <- cov_chain_dgp(n = 150)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x, sigma ~ x),
    family = stats::gaussian(), data = d, control = drmTMB::drm_control(se = TRUE)
  )
  aug <- drmSEM:::drm_refit_augmented(fit, "m", components = "mu", se = FALSE)
  expect_s3_class(aug, "drmTMB")
  expect_true("m" %in% names(aug$coefficients$mu))
  expect_false("m" %in% names(aug$coefficients$sigma))
  both <- drmSEM:::drm_refit_augmented(fit, "m")
  expect_true(all(c("mu", "sigma") %in% names(both$coefficients)))
  expect_true("m" %in% names(both$coefficients$sigma))
  # a predictor the data does not carry cannot be fitted
  expect_null(drmSEM:::drm_refit_augmented(fit, "not_a_column"))
})

test_that("drm_fit_rho12 returns the fitted residual correlation of a bivariate fit", {
  skip_if_not_installed("drmTMB")
  set.seed(77)
  n <- 300
  e1 <- stats::rnorm(n)
  e2 <- 0.5 * e1 + sqrt(1 - 0.25) * stats::rnorm(n)
  dat <- data.frame(a = e1, b = e2, x = stats::rnorm(n))
  sem <- drm_sem(drm_pair(a ~ x, b ~ x), data = dat)
  fit <- sem$nodes$a
  r <- drmSEM:::drm_fit_rho12(fit, type = "response")
  expect_true(all(is.finite(unlist(r[vapply(r, is.numeric, logical(1))]))))
  est <- unlist(r[vapply(r, is.numeric, logical(1))])
  expect_lt(abs(max(est[est < 1 & est > -1]) - 0.5), 0.15)
  expect_error(drmSEM:::drm_fit_rho12(fit, type = "bogus"), "should be one of")
  expect_false(is.null(drmSEM:::drm_fit_corpairs(fit)))
  expect_true(is.data.frame(drmSEM:::drm_fit_rho12_coef(fit)))
})

# ---- higher-level correlation extraction (engine stubbed) -----------------------------------------

fake_drm <- function() structure(list(), class = "drmTMB")

test_that("drm_extract_corpairs drops residual rows and keeps higher-level ones", {
  tab <- data.frame(
    level = c("residual", "site", "site"),
    class = c("residual", "higher_level", "higher_level"),
    from_response = c("a", "a", "a"),
    to_response = c("b", "b", "c"),
    estimate = c(0.1, 0.4, -0.2),
    std.error = c(0.01, 0.05, 0.06),
    p.value = c(0.5, 0.01, 0.2),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) tab, .package = "drmSEM")
  out <- drmSEM:::drm_extract_corpairs(list(fake_drm()))
  expect_s3_class(out, "drm_corpairs")
  expect_identical(nrow(out), 2L)
  expect_identical(out$level, c("site", "site"))
  expect_identical(out$y1, c("a", "a"))
  expect_identical(out$y2, c("b", "c"))
  expect_equal(out$estimate, c(0.4, -0.2))
  expect_equal(out$std.error, c(0.05, 0.06))
  # single fit accepted; non-fit input yields the empty table
  expect_identical(nrow(drmSEM:::drm_extract_corpairs(fake_drm())), 2L)
  empty <- drmSEM:::drm_extract_corpairs("nonsense")
  expect_identical(nrow(empty), 0L)
  expect_s3_class(empty, "drm_corpairs")
})

test_that("drm_extract_corpairs accepts alternative column layouts (group/from/to, y1/y2, se)", {
  tab <- data.frame(
    level = NA_character_, class = "higher_level", group = "plot", from = "u", to = "v",
    estimate = 0.3, se = 0.07, stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) tab, .package = "drmSEM")
  out <- drmSEM:::drm_extract_corpairs(list(fake_drm()))
  expect_identical(out$level, "plot")
  expect_identical(c(out$y1, out$y2), c("u", "v"))
  expect_equal(out$std.error, 0.07)
  expect_true(is.na(out$p.value))

  tab2 <- data.frame(level = "site", class = "higher_level", y1 = "p", y2 = "q", estimate = 0.5, stringsAsFactors = FALSE)
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) tab2, .package = "drmSEM")
  out2 <- drmSEM:::drm_extract_corpairs(list(fake_drm()))
  expect_identical(out2$level, "site") # falls back to `level` when no `group`
  expect_identical(c(out2$y1, out2$y2), c("p", "q"))
  expect_true(is.na(out2$std.error))
})

test_that("drm_extract_corpairs matches extracted rows to declared higher-level covariances", {
  tab <- data.frame(
    level = c("site", "site"), class = "higher_level",
    from_response = c("a", "a"), to_response = c("b", "c"),
    estimate = c(0.4, 0.2), std.error = c(0.05, 0.05), p.value = c(0.01, 0.2),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) tab, .package = "drmSEM")
  obj <- structure(
    list(
      nodes = list(a = fake_drm()),
      covariances = data.frame(
        class = c("higher_level", "higher_level", "residual"),
        level = c("site", "year", NA), y1 = c("b", "a", "a"), y2 = c("a", "d", "b"),
        stringsAsFactors = FALSE
      )
    ),
    class = "drm_sem"
  )
  out <- drmSEM:::drm_extract_corpairs(obj)
  # declared (site: b,a) matches the extracted a-b row; declared (year: a,d) has no
  # fitted counterpart and is reported with NA; the unmatched fitted a-c row is kept
  expect_identical(nrow(out), 3L)
  expect_equal(out$estimate[out$level == "site" & out$y2 == "b"], 0.4)
  expect_true(is.na(out$estimate[out$level == "year"]))
  expect_equal(out$estimate[out$y2 == "c"], 0.2)
})

test_that("drm_extract_corpairs returns the empty table when nothing is fitted", {
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) NULL, .package = "drmSEM")
  out <- drmSEM:::drm_extract_corpairs(list(fake_drm(), "not a fit"))
  expect_identical(nrow(out), 0L)
  expect_s3_class(out, "drm_corpairs")
  only_residual <- data.frame(level = "residual", class = "residual", estimate = 0.1, stringsAsFactors = FALSE)
  testthat::local_mocked_bindings(drm_fit_corpairs = function(fit, ...) only_residual, .package = "drmSEM")
  expect_identical(nrow(drmSEM:::drm_extract_corpairs(list(fake_drm()))), 0L)
})

test_that("drm_imputed_std_error_usable keys on status, not on a missing standard error", {
  u <- drmSEM:::drm_imputed_std_error_usable
  expect_identical(u(c("ok", "ok", "sdreport_failed", "ok"), c(0.1, 0.1, 0.1, NA), c(FALSE, TRUE, FALSE, FALSE)), c(TRUE, FALSE, FALSE, FALSE))
  expect_true(all(drmSEM:::drm_imputed_status_levels() %in% c(
    "ok", "sdreport_skipped", "sdreport_failed", "sdreport_non_pd_hessian",
    "sdreport_unavailable", "route_conditional_se_unavailable"
  )))
})
