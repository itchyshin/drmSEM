# Graph-derived imputation models (S6).
#
# V-77  auto-derived fit is numerically identical to the hand-written one
# V-78  the derivation reduces bias under outcome-dependent missingness
# V-79  >1 incomplete parent fails loud (drmTMB models one mi() at a time)
# V-80  the response/predictor family gate matches the engine's own rule
# V-81  mi() coefficient names resolve to the right node in paths()
#
# The load-bearing assertion is V-77, per this package's convention of comparing
# a public output against quantities recomputed from the SAME fit rather than
# against a hand formula: if the derived call ever stops matching the explicit
# one, the derivation is wrong no matter how good the recovery looks.

skip_if_not_installed("drmTMB")

# x -> m -> y. `mar` makes m missing as a function of the OUTCOME, which is the
# case where complete-case analysis is actually biased. Under MCAR complete-case
# is already unbiased, so an MCAR fixture would demonstrate plumbing, not value.
chain_dat <- function(n = 600, seed = 7, mar = TRUE, p_missing = 0.2) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.8 * x + stats::rnorm(n, sd = 0.5)
  y <- 0.6 * m + 0.3 * x + stats::rnorm(n, sd = 0.5)
  d <- data.frame(x = x, m = m, y = y)
  drop <- if (mar) {
    stats::runif(n) < stats::plogis(1.6 * as.numeric(scale(y)))
  } else {
    seq_len(n) %in% sample(n, floor(p_missing * n))
  }
  d$m[drop] <- NA
  d
}

auto_sem <- function(d, ...) {
  suppressWarnings(suppressMessages(drm_sem(
    m = drm_node(drmTMB::bf(m ~ x)),
    y = drm_node(drmTMB::bf(y ~ m + x)),
    data = d, impute = "auto", ...
  )))
}

test_that("V-77: the derived fit is identical to the hand-written one", {
  d <- chain_dat()
  auto <- auto_sem(d)
  hand <- suppressWarnings(suppressMessages(drm_sem(
    m = drm_node(drmTMB::bf(m ~ x)),
    y = drm_node(
      drmTMB::bf(y ~ mi(m) + x),
      impute = list(m = drmTMB::impute_model(m ~ x, family = stats::gaussian())),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$y$coefficients$mu),
    unlist(hand$nodes$y$coefficients$mu)
  )
})

test_that("imputation() reports what was derived, and nothing when unused", {
  imp <- imputation(auto_sem(chain_dat()))
  expect_identical(nrow(imp), 1L)
  expect_identical(imp$node, "y")
  expect_identical(imp$variable, "m")
  expect_identical(imp$family, "gaussian")
  expect_match(imp$model, "^m ~ x$")

  # Complete data: nothing to derive.
  clean <- suppressWarnings(suppressMessages(drm_sem(
    m = drm_node(drmTMB::bf(m ~ x)),
    y = drm_node(drmTMB::bf(y ~ m + x)),
    data = stats::na.omit(chain_dat()), impute = "auto"
  )))
  expect_identical(nrow(imputation(clean)), 0L)

  # impute = "none" is the default and must derive nothing.
  off <- suppressWarnings(drm_sem(
    m = drm_node(drmTMB::bf(m ~ x)),
    y = drm_node(drmTMB::bf(y ~ m + x)),
    data = chain_dat()
  ))
  expect_identical(nrow(imputation(off)), 0L)
})

test_that("V-77b: imputation keeps every row for the imputed node", {
  d <- chain_dat()
  auto <- auto_sem(d)
  expect_identical(drmSEM:::drm_fit_nobs(auto$nodes$y), nrow(d))
  # Node m's own RESPONSE is incomplete, so it legitimately loses those rows.
  expect_lt(drmSEM:::drm_fit_nobs(auto$nodes$m), nrow(d))
})

test_that("V-78: derivation reduces bias under outcome-dependent missingness", {
  # Replicated across seeds -- one seed is an anecdote. The honest claim is
  # about the intercept and the mediator coefficient; `x` is reported too
  # because the method does NOT uniformly win there.
  seeds <- c(7, 21, 34, 55)
  b_auto <- b_cc <- i_auto <- i_cc <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- chain_dat(seed = seeds[[k]])
    fit <- auto_sem(d)$nodes$y$coefficients$mu
    cc <- stats::coef(stats::lm(y ~ m + x, data = d))
    i_auto[[k]] <- unlist(fit)[[1L]]
    b_auto[[k]] <- unlist(fit)[[2L]]
    i_cc[[k]] <- cc[[1L]]
    b_cc[[k]] <- cc[[2L]]
  }
  # Truth: intercept 0, m 0.6.
  expect_lt(mean(abs(i_auto - 0)), mean(abs(i_cc - 0)))
  expect_lt(mean(abs(b_auto - 0.6)), mean(abs(b_cc - 0.6)))
})

test_that("V-79: more than one incomplete parent fails loud", {
  d <- chain_dat()
  d$m2 <- 0.5 * d$x + stats::rnorm(nrow(d))
  d$m2[1:50] <- NA
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      m2 = drm_node(drmTMB::bf(m2 ~ x)),
      y = drm_node(drmTMB::bf(y ~ m + m2 + x)),
      data = d, impute = "auto"
    )),
    "one at a time"
  )
})

test_that("V-80: the family gate matches the engine's own allow-list", {
  # Anti-drift lock, mirroring drmTMB's test-missing-data-capability-gate.R:
  # loosening drmSEM's gate without the engine loosening its own must fail here
  # rather than surfacing as a confusing abort from inside drmTMB.
  skip_if_not(
    is.function(getFromNamespace("drm_missing_predictor_families", "drmTMB")),
    "engine does not expose its allow-list"
  )
  engine <- getFromNamespace("drm_missing_predictor_families", "drmTMB")()
  expect_setequal(drmSEM:::drm_impute_response_families(), engine)
})

test_that("V-80b: an unsupported response family is refused with a reason", {
  d <- chain_dat()
  d$count <- stats::rpois(nrow(d), lambda = 2)
  # Gamma response is outside the engine's missing-predictor allow-list.
  d$g <- stats::rgamma(nrow(d), shape = 2, rate = 1)
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      g = drm_node(drmTMB::bf(g ~ m + x), family = stats::Gamma(link = "log")),
      data = d, impute = "auto"
    )),
    "cannot carry a modelled missing predictor"
  )
})

test_that("V-80c: a non-Gaussian response demands a binary missing predictor", {
  d <- chain_dat()
  d$cnt <- stats::rpois(nrow(d), lambda = exp(0.2 * d$x))
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      cnt = drm_node(drmTMB::bf(cnt ~ m + x), family = stats::poisson()),
      data = d, impute = "auto"
    )),
    "BINARY missing predictor"
  )
})

test_that("mi() is refused where the engine would reject it anyway", {
  d <- chain_dat()
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      y = drm_node(drmTMB::bf(y ~ m:x + x)),
      data = d, impute = "auto"
    )),
    "not a plain additive term"
  )
})

test_that("V-81: an mi() coefficient resolves to its own node, not a prefix", {
  # "mi(mass)" starts with "m", so prefix matching used to resolve the mass path
  # onto a node named `m`. Unit-level because building a live SEM with both a
  # node `m` and an imputed `mass` is awkward; the defect is in the mapping.
  expect_identical(drmSEM:::drm_coef_variable("mi(mass)", c("m", "mass")), "mass")
  expect_identical(drmSEM:::drm_coef_variable("mi(m)", c("m", "x")), "m")
  # Ordinary longest-prefix behaviour must be unchanged.
  expect_identical(drmSEM:::drm_coef_variable("habitatB", c("hab", "habitat")), "habitat")
  expect_identical(drmSEM:::drm_coef_variable("temp", c("temp")), "temp")
})

test_that("paths() still labels the imputed edge as endogenous", {
  p <- paths(auto_sem(chain_dat()))
  edge <- p[p$from == "m" & p$to == "y", , drop = FALSE]
  expect_identical(nrow(edge), 1L)
  expect_true(all(edge$endogenous))
})
