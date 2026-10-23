# Engine-free helpers in R/extractors.R (the drmTMB adapter). None of these
# needs drmTMB: fits are plain list stand-ins, and the fit accessors are mocked
# where the helper goes through them.

test_that("is_drmTMB_fit tests the class only", {
  is_fit <- drmSEM:::is_drmTMB_fit
  expect_true(is_fit(structure(list(), class = "drmTMB")))
  expect_false(is_fit(list()))
  expect_false(is_fit("drmTMB"))
  expect_false(is_fit(NULL))
})

test_that("drm_require_drmTMB aborts with an install hint when drmTMB is absent", {
  if (requireNamespace("drmTMB", quietly = TRUE)) {
    mocked <- tryCatch(
      {
        testthat::local_mocked_bindings(
          requireNamespace = function(...) FALSE,
          .package = "base"
        )
        TRUE
      },
      error = function(e) FALSE
    )
    skip_if(!mocked, "installed testthat refuses to mock base functions")
  }
  expect_error(drmSEM:::drm_require_drmTMB(), "drmTMB")
  expect_error(drmSEM:::drm_require_drmTMB(), "install_github")
})

test_that("drm_family_name reads character, list, 'family' class and falls back", {
  fam <- drmSEM:::drm_family_name
  expect_identical(fam("gaussian"), "gaussian")
  expect_identical(fam(c("poisson", "gaussian")), "poisson")
  expect_identical(fam(list(family = "nbinom2", link = "log")), "nbinom2")
  expect_identical(fam(stats::binomial()), "binomial")
  expect_identical(
    fam(structure(list(family = "Gamma"), class = "family")), "Gamma"
  )
  # No usable name -> "unknown"
  expect_identical(fam(list(link = "log")), "unknown")
  expect_identical(fam(NULL), "unknown")
  expect_identical(fam(1L), "unknown")
})

test_that("drm_coarser_scales returns a typed 0-row frame when var is missing", {
  d <- data.frame(a = 1:4, g = rep(c("u", "v"), each = 2))
  out <- drmSEM:::drm_coarser_scales("zzz", d)
  expect_s3_class(out, "data.frame")
  expect_identical(names(out), c("group", "n_groups"))
  expect_identical(nrow(out), 0L)
  expect_type(out$group, "character")
  expect_type(out$n_groups, "integer")
})

test_that("drm_coarser_scales finds groupings within which var is constant", {
  d <- data.frame(
    sp = rep(c("a", "b", "c"), each = 4),
    x = rep(c(1, 2, 3), each = 4),
    stringsAsFactors = FALSE
  )
  out <- drmSEM:::drm_coarser_scales("x", d)
  expect_identical(out$group, "sp")
  expect_identical(out$n_groups, 3L)
  # factor groupings count too
  d$sp <- factor(d$sp)
  expect_identical(drmSEM:::drm_coarser_scales("x", d)$group, "sp")
})

test_that("drm_coarser_scales skips non-grouping and degenerate columns", {
  n <- 12
  d <- data.frame(
    x = rep(c(1, 2, 3), each = 4),
    num = rep(c(1, 2, 3), each = 4),             # numeric: not a grouping
    one = rep("only", n),                        # a single level
    id = paste0("r", seq_len(n)),                # as many levels as rows
    sp = rep(c("a", "b", "c"), each = 4),
    stringsAsFactors = FALSE
  )
  out <- drmSEM:::drm_coarser_scales("x", d)
  expect_identical(out$group, "sp")
})

test_that("drm_coarser_scales reports nothing when var varies within every group", {
  d <- data.frame(
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    g = rep(c("a", "b"), each = 4),
    stringsAsFactors = FALSE
  )
  out <- drmSEM:::drm_coarser_scales("x", d)
  expect_identical(nrow(out), 0L)
  expect_identical(names(out), c("group", "n_groups"))
})

test_that("drm_biv_role and drm_biv_components_for_role map margins to dpars", {
  testthat::local_mocked_bindings(
    drm_biv_response_names = function(fit) c("y1", "y2")
  )
  role <- drmSEM:::drm_biv_role
  expect_identical(role(NULL, "y1"), 1L)
  expect_identical(role(NULL, "y2"), 2L)
  expect_identical(role(NULL, "other"), NA_integer_)

  comp <- drmSEM:::drm_biv_components_for_role
  expect_identical(comp(1L), c("mu1", "sigma1"))
  expect_identical(comp(1L, include_rho12 = TRUE), c("mu1", "sigma1", "rho12"))
  # rho12 is attached to margin 1 only
  expect_identical(comp(2L), c("mu2", "sigma2"))
  expect_identical(comp(2L, include_rho12 = TRUE), c("mu2", "sigma2"))
  expect_identical(comp(NA_integer_, include_rho12 = TRUE), character(0))
})

test_that("drm_biv_role is NA when the response names are unknown", {
  testthat::local_mocked_bindings(
    drm_biv_response_names = function(fit) c(NA_character_, NA_character_)
  )
  expect_identical(drmSEM:::drm_biv_role(NULL, "y1"), NA_integer_)
})

test_that("drm_wald_rows is an empty typed frame when there are no coefficients", {
  testthat::local_mocked_bindings(
    drm_fit_coef = function(fit, component) {
      stats::setNames(numeric(0), character(0))
    }
  )
  out <- drmSEM:::drm_wald_rows(NULL, "mu")
  expect_identical(nrow(out), 0L)
  expect_identical(
    names(out), c("term", "estimate", "std.error", "statistic", "p.value")
  )
})

test_that("drm_wald_rows looks SEs up by the 'component:term' vcov key", {
  testthat::local_mocked_bindings(
    drm_fit_coef = function(fit, component) c("(Intercept)" = 1, x = 2),
    drm_fit_vcov = function(fit) {
      keys <- c("mu:(Intercept)", "mu:x", "sigma:(Intercept)")
      matrix(
        diag(c(0.25, 1, 100)), 3, 3, dimnames = list(keys, keys)
      )
    }
  )
  out <- drmSEM:::drm_wald_rows(NULL, "mu")
  expect_identical(out$term, c("(Intercept)", "x"))
  expect_equal(out$estimate, c(1, 2))
  expect_equal(out$std.error, c(0.5, 1))
  expect_equal(out$statistic, c(2, 2))
  expect_equal(out$p.value, 2 * stats::pnorm(-c(2, 2)))
})

test_that("drm_wald_rows gives NA SE/z/p when the key or the vcov is missing", {
  testthat::local_mocked_bindings(
    drm_fit_coef = function(fit, component) c("(Intercept)" = 1, x = 2),
    drm_fit_vcov = function(fit) {
      matrix(0.25, 1, 1, dimnames = list("mu:x", "mu:x"))
    }
  )
  out <- drmSEM:::drm_wald_rows(NULL, "mu")
  expect_true(is.na(out$std.error[[1L]]))
  expect_equal(out$std.error[[2L]], 0.5)
  expect_true(is.na(out$p.value[[1L]]))

  testthat::local_mocked_bindings(drm_fit_vcov = function(fit) NULL)
  out2 <- drmSEM:::drm_wald_rows(NULL, "mu")
  expect_true(all(is.na(out2$std.error)))
  expect_true(all(is.na(out2$statistic)))
  expect_true(all(is.na(out2$p.value)))
})

test_that("drm_imputed_status_levels is the six engine statuses, ok first", {
  lv <- drmSEM:::drm_imputed_status_levels()
  expect_identical(lv, c(
    "ok", "sdreport_skipped", "sdreport_failed", "sdreport_non_pd_hessian",
    "sdreport_unavailable", "route_conditional_se_unavailable"
  ))
  expect_length(lv, 6L)
})

test_that("drm_imputed_std_error_usable follows the V-121 rule, vectorised", {
  usable <- drmSEM:::drm_imputed_std_error_usable
  lv <- drmSEM:::drm_imputed_status_levels()
  # usable only for status ok, row not observed, finite std_error
  expect_identical(
    usable(
      c("ok", "ok", "ok", "ok", "sdreport_failed"),
      c(0.1, 0.1, NA, Inf, 0.1),
      c(FALSE, TRUE, FALSE, FALSE, FALSE)
    ),
    c(TRUE, FALSE, FALSE, FALSE, FALSE)
  )
  # no non-ok status is ever usable, even with a finite SE on a missing row
  expect_false(any(usable(lv[-1L], 0.1, FALSE)))
  expect_true(usable(lv[[1L]], 0.1, FALSE))
})
