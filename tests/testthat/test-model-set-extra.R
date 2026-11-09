# Remaining branches of the candidate-model layer (R/model_set.R): response
# discovery from any formula flavour, per-node family selection, and the
# model-averaging edge cases. Pure R: no model is fitted.

# ---- drm_dag_response ----------------------------------------------------------------------

test_that("drm_dag_response reads the response of plain formulas", {
  r <- drmSEM:::drm_dag_response
  expect_identical(r(y ~ x + z), "y")
  expect_identical(r(log(y) ~ x), "y")
  expect_identical(r(cbind(succ, fail) ~ x), "succ")
  expect_error(r(~x), "needs a response")
  expect_error(r(1 ~ x), "Could not read a response")
})

test_that("drm_dag_response prefers the mu response of a drmTMB formula, then any entry", {
  skip_if_not_installed("drmTMB")
  expect_identical(drmSEM:::drm_dag_response(drmTMB::bf(sigma_y ~ x)), "sigma_y")
  expect_identical(drmSEM:::drm_dag_response(drmTMB::bf(y ~ x, sigma ~ z)), "y")
  # no mu entry with a response: the first entry's left-hand-side variable is used
  f <- structure(
    list(entries = list(
      list(dpar = "sigma", response = NA_character_, lhs = quote(s_var)),
      list(dpar = "zi", response = NA_character_, lhs = quote(z_var))
    )),
    class = "drm_formula"
  )
  expect_identical(drmSEM:::drm_dag_response(f), "s_var")
  # entries with nothing usable fall through to all.vars() of the object, then abort
  empty <- structure(list(entries = list(list(dpar = "mu", response = NA_character_, lhs = NULL))), class = "drm_formula")
  expect_error(drmSEM:::drm_dag_response(empty), "Could not determine the response")
  expect_identical(drmSEM:::drm_dag_response(quote(a + b)), "a")
  expect_error(drmSEM:::drm_dag_response(42), "Could not determine the response")
})

# ---- per-node family selection ---------------------------------------------------------------

test_that("drm_dag_node applies a shared family, a named per-node family, or the node default", {
  skip_if_not_installed("drmTMB")
  f <- y ~ x
  default <- drmSEM:::drm_dag_node(f, "y", NULL)
  expect_s3_class(default, "drm_node")
  shared <- drmSEM:::drm_dag_node(f, "y", stats::poisson())
  expect_identical(drmSEM:::drm_family_name(shared$family), "poisson")
  named <- list(y = stats::poisson(), z = stats::gaussian())
  expect_identical(drmSEM:::drm_family_name(drmSEM:::drm_dag_node(f, "y", named)$family), "poisson")
  # a response absent from the named list gets the node default
  other <- drmSEM:::drm_dag_node(f, "w", named)
  expect_identical(other$family, default$family)
})

# ---- model averaging --------------------------------------------------------------------------

test_that("average.drm_compare requires fitted models and degrades to an empty table", {
  cmp <- structure(
    data.frame(model = c("m1", "m2"), weight = c(0, NA), stringsAsFactors = FALSE),
    class = c("drm_compare", "data.frame")
  )
  expect_error(average(cmp), "carries no fitted models")
  attr(cmp, "fits") <- list(m1 = NULL, m2 = NULL)
  out <- average(cmp)
  expect_s3_class(out, "drm_average")
  expect_identical(nrow(out), 0L)
  expect_named(out, c("from", "to", "component", "std.estimate", "weight_sum"))
  # positive weight but no fit object for the model: still nothing to average
  cmp2 <- cmp
  cmp2$weight <- c(0.6, 0.4)
  expect_identical(nrow(average(cmp2)), 0L)
})

test_that("average.drm_compare takes the weight-weighted mean of standardized paths", {
  std_tab <- function(est) {
    data.frame(
      from = c("x", "x"), to = c("y", "y"), component = c("mu", "sigma"),
      std.estimate = est, stringsAsFactors = FALSE
    )
  }
  fits <- list(m1 = std_tab(c(0.5, 0.2)), m2 = std_tab(c(0.1, NA)), m3 = std_tab(c(9, 9)))
  cmp <- structure(
    data.frame(model = c("m1", "m2", "m3"), weight = c(0.75, 0.25, 0), stringsAsFactors = FALSE),
    class = c("drm_compare", "data.frame"),
    fits = fits
  )
  testthat::local_mocked_bindings(
    standardize = function(fit, ...) fit,
    .package = "drmSEM"
  )
  out <- average(cmp)
  expect_s3_class(out, "drm_average")
  mu <- out[out$component == "mu", ]
  sg <- out[out$component == "sigma", ]
  # mu: (0.75 * 0.5 + 0.25 * 0.1) / 1 ; zero-weight model 3 is ignored
  expect_equal(mu$std.estimate, 0.4, tolerance = 1e-12)
  expect_equal(mu$weight_sum, 1, tolerance = 1e-12)
  # sigma: model 2 is non-finite there, so only model 1 contributes (weight 0.75)
  expect_equal(sg$std.estimate, 0.2, tolerance = 1e-12)
  expect_equal(sg$weight_sum, 0.75, tolerance = 1e-12)
  # a model with an empty standardized table contributes nothing
  fits$m1 <- std_tab(c(0.5, 0.2))[0, ]
  attr(cmp, "fits") <- fits
  expect_equal(average(cmp)$std.estimate[1], 0.1, tolerance = 1e-12)
})

test_that("print.drm_average rounds and lists the averaged paths", {
  avg <- structure(
    data.frame(
      from = "x", to = "y", component = "mu", std.estimate = 0.123456,
      weight_sum = 0.98765, stringsAsFactors = FALSE
    ),
    class = c("drm_average", "data.frame")
  )
  out <- utils::capture.output(msg <- cli::cli_fmt(res <- print(avg)))
  txt <- paste(c(msg, out), collapse = "\n")
  expect_match(txt, "1 path")
  expect_match(txt, "0.1235", fixed = TRUE)
  expect_match(txt, "0.988", fixed = TRUE)
  expect_identical(res, avg)
})
