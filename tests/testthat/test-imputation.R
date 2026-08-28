# Graph-derived imputation models (S6).
#
# V-77  auto-derived fit is numerically identical to the hand-written one
# V-78  the derivation reduces bias under outcome-dependent missingness
# V-79  two incomplete Gaussian parents emit independent mi() (A8; was abort)
# V-79b k > 2 still fails loud (engine limit)
# V-79c k = 2 on a non-Gaussian response fails loud (engine Phase 1 cell)
# V-80  the response/predictor family gate matches the engine's own rule
# V-80b Gamma × binary emits; Gamma × continuous still fails loud (A7c-2)
# V-80d leftover unwired response (student) still fails loud
# V-80e lognormal × binary emits; lognormal × continuous fails loud (A7c-3)
# V-80f beta_binomial × binary emits; beta_binomial × continuous fails loud (A7c-4)
# V-80h nbinom2 × gaussian emits; nbinom2 × poisson still fails (sibling)
# V-123 / V-123b lognormal × Bernoulli identity + MAR recovery
# V-124 / V-124b beta_binomial × Bernoulli identity + MAR recovery
# V-126 / V-126b nbinom2 × Gaussian identity + MAR recovery
# V-81  mi() coefficient names resolve to the right node in paths()
# V-82  two-parent auto fit matches the hand-written emit shape (needs k=2 engine)
# V-120 two-parent MAR recovery-to-truth (needs k=2 engine)
# V-121 imputation()/imputed() branch on uncertainty_status, never is.na(std_error)
# V-122 Gamma × Bernoulli identity + MAR recovery (engine mp-gamma-bernoulli)
#
# The load-bearing assertion is V-77, per this package's convention of comparing
# a public output against quantities recomputed from the SAME fit rather than
# against a hand formula: if the derived call ever stops matching the explicit
# one, the derivation is wrong no matter how good the recovery looks.

# V-121 kernel: no drmTMB needed. NA std_error is not a failure by itself.
test_that("V-121: std_error usability branches on uncertainty_status", {
  usable <- drmSEM:::drm_imputed_std_error_usable
  # Observed + ok + NA: not usable, and not a failure.
  expect_false(usable("ok", NA_real_, TRUE))
  # Missing + ok + finite: usable.
  expect_true(usable("ok", 0.12, FALSE))
  # Missing + ok + NA (se = FALSE request): not usable, not a failure.
  expect_false(usable("ok", NA_real_, FALSE))
  # Missing + failed + NA: not usable because of status.
  expect_false(usable("sdreport_failed", NA_real_, FALSE))
  # A finite SE is still unusable when status is not ok.
  expect_false(usable("sdreport_failed", 0.12, FALSE))
  expect_false(usable("route_conditional_se_unavailable", 0.12, FALSE))
})

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
  expect_gt(imp$n_missing, 0L)
  expect_identical(imp$uncertainty_status, "ok")
  expect_true(imp$std_error_usable)

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

two_parent_dat <- function(n = 400, seed = 11, mar = TRUE) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m1 <- 0.7 * x + stats::rnorm(n, sd = 0.5)
  m2 <- 0.5 * x + stats::rnorm(n, sd = 0.5)
  y <- 0.5 * m1 + 0.4 * m2 + 0.3 * x + stats::rnorm(n, sd = 0.5)
  d <- data.frame(x = x, m1 = m1, m2 = m2, y = y)
  drop1 <- if (mar) {
    stats::runif(n) < stats::plogis(1.2 * as.numeric(scale(y)) - 1.2)
  } else {
    seq_len(n) %in% sample(n, floor(0.15 * n))
  }
  drop2 <- if (mar) {
    stats::runif(n) < stats::plogis(1.0 * as.numeric(scale(y)) - 1.4)
  } else {
    seq_len(n) %in% sample(n, floor(0.15 * n))
  }
  d$m1[drop1] <- NA
  d$m2[drop2] <- NA
  d
}

two_parent_specs <- function() {
  list(
    m1 = drm_node(drmTMB::bf(m1 ~ x)),
    m2 = drm_node(drmTMB::bf(m2 ~ x)),
    y = drm_node(drmTMB::bf(y ~ m1 + m2 + x))
  )
}

engine_accepts_k2 <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("drmTMB")
  # Unique to the #1086 / 0.7.0 two-independent-Gaussian slice. The older
  # one-mi() helper is also named drm_prepare_gaussian_mi_setup.
  exists(
    "drm_prepare_two_independent_gaussian_mi_setup",
    envir = ns,
    inherits = FALSE
  )
}

test_that("V-79: two incomplete Gaussian parents are planned, not aborted", {
  d <- two_parent_dat()
  plan <- drmSEM:::drm_imputation_plan(two_parent_specs(), d)
  expect_identical(sort(plan$y$variable), c("m1", "m2"))
  expect_length(plan$y$parents, 2L)
  expect_identical(
    sort(vapply(plan$y$parents, function(p) p$variable, character(1))),
    c("m1", "m2")
  )
})

test_that("V-79b: k > 2 incomplete parents still fails loud", {
  d <- two_parent_dat()
  d$m3 <- 0.4 * d$x + stats::rnorm(nrow(d))
  d$m3[1:40] <- NA
  specs <- two_parent_specs()
  specs$m3 <- drm_node(drmTMB::bf(m3 ~ x))
  specs$y <- drm_node(drmTMB::bf(y ~ m1 + m2 + m3 + x))
  expect_error(
    drmSEM:::drm_imputation_plan(specs, d),
    "k > 2"
  )
})

test_that("V-79c: two parents on a non-Gaussian response fail loud", {
  d <- two_parent_dat()
  d$cnt <- stats::rpois(nrow(d), lambda = 2)
  specs <- two_parent_specs()
  specs$cnt <- drm_node(
    drmTMB::bf(cnt ~ m1 + m2 + x),
    family = stats::poisson()
  )
  expect_error(
    drmSEM:::drm_imputation_plan(specs, d),
    "two independent Gaussian"
  )
})

test_that("V-82: two-parent auto fit matches the hand-written emit shape", {
  skip_if_not(engine_accepts_k2(), "engine does not accept two mi() terms")
  d <- two_parent_dat()
  auto <- suppressWarnings(suppressMessages(drm_sem(
    m1 = drm_node(drmTMB::bf(m1 ~ x)),
    m2 = drm_node(drmTMB::bf(m2 ~ x)),
    y = drm_node(drmTMB::bf(y ~ m1 + m2 + x)),
    data = d, impute = "auto"
  )))
  hand <- suppressWarnings(suppressMessages(drm_sem(
    m1 = drm_node(drmTMB::bf(m1 ~ x)),
    m2 = drm_node(drmTMB::bf(m2 ~ x)),
    y = drm_node(
      drmTMB::bf(y ~ mi(m1) + mi(m2) + x),
      impute = list(
        m1 = drmTMB::impute_model(m1 ~ x, family = stats::gaussian()),
        m2 = drmTMB::impute_model(m2 ~ x, family = stats::gaussian())
      ),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$y$coefficients$mu),
    unlist(hand$nodes$y$coefficients$mu)
  )
  imp <- imputation(auto)
  expect_identical(nrow(imp), 2L)
  expect_identical(sort(imp$variable), c("m1", "m2"))
  expect_true(all(imp$node == "y"))
  expect_true(all(imp$uncertainty_status == "ok"))
  expect_true(all(imp$std_error_usable))
})

test_that("V-120: two-parent auto recovers known MAR coefficients", {
  skip_if_not(engine_accepts_k2(), "engine does not accept two mi() terms")
  seeds <- c(11L, 21L, 34L)
  b1 <- b2 <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- two_parent_dat(n = 400, seed = seeds[[k]])
    fit <- suppressWarnings(suppressMessages(drm_sem(
      m1 = drm_node(drmTMB::bf(m1 ~ x)),
      m2 = drm_node(drmTMB::bf(m2 ~ x)),
      y = drm_node(drmTMB::bf(y ~ m1 + m2 + x)),
      data = d, impute = "auto"
    )))$nodes$y$coefficients$mu
    coefs <- unlist(fit)
    b1[[k]] <- coefs[[2L]]
    b2[[k]] <- coefs[[3L]]
  }
  # Truth: m1 0.5, m2 0.4. Recovery-to-truth, not a complete-case contest.
  expect_lt(mean(abs(b1 - 0.5)), 0.15)
  expect_lt(mean(abs(b2 - 0.4)), 0.15)
})

test_that("V-121b: imputed() stacks parents and never silent-first", {
  d <- chain_dat()
  sem <- auto_sem(d)
  miss <- imputed(sem)
  expect_true(all(miss$node == "y"))
  expect_true(all(miss$variable == "m"))
  expect_true(all(!miss$observed))
  expect_true(all(miss$uncertainty_status == "ok"))
  expect_true(all(is.finite(miss$std_error)))
  expect_true(all(drmSEM:::drm_imputed_std_error_usable(
    miss$uncertainty_status, miss$std_error, miss$observed
  )))

  all_rows <- imputed(sem, rows = "all")
  obs <- all_rows[all_rows$observed, , drop = FALSE]
  expect_gt(nrow(obs), 0L)
  expect_true(all(obs$uncertainty_status == "ok"))
  expect_true(all(is.na(obs$std_error)))
  expect_false(any(drmSEM:::drm_imputed_std_error_usable(
    obs$uncertainty_status, obs$std_error, obs$observed
  )))

  quiet <- imputed(sem, se = FALSE)
  expect_true(all(quiet$uncertainty_status == "ok"))
  expect_true(all(is.na(quiet$std_error)))
  expect_false(any(drmSEM:::drm_imputed_std_error_usable(
    quiet$uncertainty_status, quiet$std_error, quiet$observed
  )))
})

test_that("V-121c: two-parent imputed() is stacked, never first-only", {
  skip_if_not(engine_accepts_k2(), "engine does not accept two mi() terms")
  d <- two_parent_dat()
  sem <- suppressWarnings(suppressMessages(drm_sem(
    m1 = drm_node(drmTMB::bf(m1 ~ x)),
    m2 = drm_node(drmTMB::bf(m2 ~ x)),
    y = drm_node(drmTMB::bf(y ~ m1 + m2 + x)),
    data = d, impute = "auto"
  )))
  stacked <- imputed(sem)
  expect_identical(sort(unique(stacked$variable)), c("m1", "m2"))
  expect_true(all(stacked$node == "y"))
  m1_only <- imputed(sem, variable = "m1")
  expect_true(all(m1_only$variable == "m1"))
  expect_error(imputed(sem, variable = "nope"), "Unknown modelled missing")
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

engine_accepts_gamma <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("drmTMB")
  if (!exists("drm_missing_predictor_families", envir = ns, inherits = FALSE)) {
    return(FALSE)
  }
  "gamma" %in% getFromNamespace("drm_missing_predictor_families", "drmTMB")()
}

# z -> treatment (Bernoulli) -> g (Gamma, log link). Engine cell
# mp-gamma-bernoulli / #1088. Mean-CV parameterization matches the engine
# recovery DGP (shape = 1/cv^2, scale = mu * cv^2).
gamma_binary_dat <- function(n = 200, seed = 13L, mar = TRUE) {
  set.seed(seed)
  z <- stats::rnorm(n)
  treatment <- stats::rbinom(n, 1L, stats::plogis(0.3 + 0.8 * z))
  eta <- 0.4 + 0.5 * z + 0.7 * treatment
  mu <- exp(eta)
  cv <- 0.3
  g <- stats::rgamma(n, shape = 1 / cv^2, scale = mu * cv^2)
  d <- data.frame(z = z, treatment = treatment, g = g)
  drop <- if (isTRUE(mar)) {
    stats::runif(n) < stats::plogis(-0.8 + 0.6 * as.numeric(scale(log(g))))
  } else {
    seq_len(n) %in% sample(n, floor(0.2 * n))
  }
  d$treatment[drop] <- NA
  d
}

gamma_binary_specs <- function() {
  list(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    g = drm_node(
      drmTMB::bf(g ~ treatment + z),
      family = stats::Gamma(link = "log")
    )
  )
}

test_that("V-80b: Gamma + binary parent emits; Gamma + continuous fails loud", {
  d_bin <- gamma_binary_dat()
  plan <- drmSEM:::drm_imputation_plan(gamma_binary_specs(), d_bin)
  expect_identical(plan$g$variable, "treatment")
  expect_identical(
    drmSEM:::drm_impute_family_key(plan$g$family_name),
    "binomial"
  )

  d_cont <- chain_dat()
  d_cont$g <- stats::rgamma(nrow(d_cont), shape = 2, rate = 1)
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      g = drm_node(drmTMB::bf(g ~ m + x), family = stats::Gamma(link = "log")),
      data = d_cont, impute = "auto"
    )),
    "BINARY missing predictor"
  )
})

test_that("V-80d: a still-unwired response family is refused with a reason", {
  d <- chain_dat()
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      y = drm_node(drmTMB::bf(y ~ m + x), family = drmTMB::student()),
      data = d, impute = "auto"
    )),
    "cannot carry a modelled missing predictor"
  )
})

engine_accepts_lognormal <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("drmTMB")
  if (!exists("drm_missing_predictor_families", envir = ns, inherits = FALSE)) {
    return(FALSE)
  }
  "lognormal" %in% getFromNamespace("drm_missing_predictor_families", "drmTMB")()
}

# z -> treatment (Bernoulli) -> w (lognormal). Engine cell
# mp-lognormal-bernoulli / #1092. Identity log-location: meanlog = eta,
# sdlog = 0.3. Matches the engine recovery DGP.
lognormal_binary_dat <- function(n = 200, seed = 13L, mar = TRUE) {
  set.seed(seed)
  z <- stats::rnorm(n)
  treatment <- stats::rbinom(n, 1L, stats::plogis(0.3 + 0.8 * z))
  mu <- 0.4 + 0.5 * z + 0.7 * treatment
  sdlog <- 0.3
  w <- stats::rlnorm(n, meanlog = mu, sdlog = sdlog)
  d <- data.frame(z = z, treatment = treatment, w = w)
  drop <- if (isTRUE(mar)) {
    stats::runif(n) < stats::plogis(-0.8 + 0.6 * as.numeric(scale(log(w))))
  } else {
    seq_len(n) %in% sample(n, floor(0.2 * n))
  }
  d$treatment[drop] <- NA
  d
}

lognormal_binary_specs <- function() {
  list(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    w = drm_node(
      drmTMB::bf(w ~ treatment + z),
      family = drmTMB::lognormal()
    )
  )
}

test_that("V-80e: lognormal + binary parent emits; lognormal + continuous fails loud", {
  d_bin <- lognormal_binary_dat()
  plan <- drmSEM:::drm_imputation_plan(lognormal_binary_specs(), d_bin)
  expect_identical(plan$w$variable, "treatment")
  expect_identical(
    drmSEM:::drm_impute_family_key(plan$w$family_name),
    "binomial"
  )

  d_cont <- chain_dat()
  d_cont$w <- exp(d_cont$y)
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      w = drm_node(drmTMB::bf(w ~ m + x), family = drmTMB::lognormal()),
      data = d_cont, impute = "auto"
    )),
    "BINARY missing predictor"
  )
})

test_that("V-122: Gamma x binary auto fit matches the hand-written emit", {
  skip_if_not(engine_accepts_gamma(), "engine has no Gamma has_mi")
  d <- gamma_binary_dat(n = 200, seed = 13L)
  auto <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    g = drm_node(
      drmTMB::bf(g ~ treatment + z),
      family = stats::Gamma(link = "log")
    ),
    data = d, impute = "auto"
  )))
  hand <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    g = drm_node(
      drmTMB::bf(g ~ mi(treatment) + z),
      family = stats::Gamma(link = "log"),
      impute = list(
        treatment = drmTMB::impute_model(
          treatment ~ z,
          family = stats::binomial()
        )
      ),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$g$coefficients$mu),
    unlist(hand$nodes$g$coefficients$mu)
  )
  imp <- imputation(auto)
  expect_identical(nrow(imp), 1L)
  expect_identical(imp$node, "g")
  expect_identical(imp$variable, "treatment")
  expect_identical(imp$family, "binomial")
})

test_that("V-122b: Gamma x binary auto recovers known MAR coefficients", {
  skip_if_not(engine_accepts_gamma(), "engine has no Gamma has_mi")
  seeds <- c(13L, 21L, 34L)
  b_trt <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- gamma_binary_dat(n = 800, seed = seeds[[k]])
    fit <- suppressWarnings(suppressMessages(drm_sem(
      treatment = drm_node(
        drmTMB::bf(treatment ~ z),
        family = stats::binomial()
      ),
      g = drm_node(
        drmTMB::bf(g ~ treatment + z),
        family = stats::Gamma(link = "log")
      ),
      data = d, impute = "auto"
    )))$nodes$g$coefficients$mu
    coefs <- unlist(fit)
    # mu: (Intercept), mi(treatment), z. Truth: 0.4, 0.7, 0.5.
    b_trt[[k]] <- coefs[["mi(treatment)"]]
  }
  expect_lt(mean(abs(b_trt - 0.7)), 0.20)
})

test_that("V-123: lognormal x binary auto fit matches the hand-written emit", {
  skip_if_not(engine_accepts_lognormal(), "engine has no lognormal has_mi")
  d <- lognormal_binary_dat(n = 200, seed = 13L)
  auto <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    w = drm_node(
      drmTMB::bf(w ~ treatment + z),
      family = drmTMB::lognormal()
    ),
    data = d, impute = "auto"
  )))
  hand <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    w = drm_node(
      drmTMB::bf(w ~ mi(treatment) + z),
      family = drmTMB::lognormal(),
      impute = list(
        treatment = drmTMB::impute_model(
          treatment ~ z,
          family = stats::binomial()
        )
      ),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$w$coefficients$mu),
    unlist(hand$nodes$w$coefficients$mu)
  )
  imp <- imputation(auto)
  expect_identical(nrow(imp), 1L)
  expect_identical(imp$node, "w")
  expect_identical(imp$variable, "treatment")
  expect_identical(imp$family, "binomial")
})

test_that("V-123b: lognormal x binary auto recovers known MAR coefficients", {
  skip_if_not(engine_accepts_lognormal(), "engine has no lognormal has_mi")
  seeds <- c(13L, 21L, 34L)
  b_trt <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- lognormal_binary_dat(n = 800, seed = seeds[[k]])
    fit <- suppressWarnings(suppressMessages(drm_sem(
      treatment = drm_node(
        drmTMB::bf(treatment ~ z),
        family = stats::binomial()
      ),
      w = drm_node(
        drmTMB::bf(w ~ treatment + z),
        family = drmTMB::lognormal()
      ),
      data = d, impute = "auto"
    )))$nodes$w$coefficients$mu
    coefs <- unlist(fit)
    # mu is identity meanlog: (Intercept), mi(treatment), z. Truth: 0.4, 0.7, 0.5.
    b_trt[[k]] <- coefs[["mi(treatment)"]]
  }
    expect_lt(mean(abs(b_trt - 0.7)), 0.20)
})

engine_accepts_beta_binomial <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("drmTMB")
  if (!exists("drm_missing_predictor_families", envir = ns, inherits = FALSE)) {
    return(FALSE)
  }
  "beta_binomial" %in% getFromNamespace("drm_missing_predictor_families", "drmTMB")()
}

rbeta_binomial <- function(n, trials, mu, phi) {
  alpha <- mu * phi
  beta_shape <- (1 - mu) * phi
  p <- stats::rbeta(n, alpha, beta_shape)
  stats::rbinom(n, size = trials, prob = p)
}

# z -> treatment (Bernoulli) -> cbind(success, failure) (beta_binomial).
# Engine cell mp-beta-binomial-bernoulli / #1094. Logit mu:
# eta = 0.4 + 0.5*z + 0.7*treatment, sigma = 0.3, phi = 1/sigma^2,
# trials = 20. Matches the engine recovery DGP.
beta_binomial_binary_dat <- function(n = 200, seed = 13L, mar = TRUE) {
  set.seed(seed)
  z <- stats::rnorm(n)
  treatment <- stats::rbinom(n, 1L, stats::plogis(0.3 + 0.8 * z))
  eta <- 0.4 + 0.5 * z + 0.7 * treatment
  sigma <- 0.3
  phi <- 1 / sigma^2
  trials <- 20L
  success <- rbeta_binomial(n, trials, stats::plogis(eta), phi)
  d <- data.frame(
    z = z,
    treatment = treatment,
    success = success,
    failure = trials - success
  )
  drop <- if (isTRUE(mar)) {
    stats::runif(n) < stats::plogis(-0.8 + 0.6 * as.numeric(scale(success / trials)))
  } else {
    seq_len(n) %in% sample(n, floor(0.2 * n))
  }
  d$treatment[drop] <- NA
  d
}

beta_binomial_binary_specs <- function() {
  list(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    bb = drm_node(
      drmTMB::bf(cbind(success, failure) ~ treatment + z, sigma ~ 1),
      family = drmTMB::beta_binomial()
    )
  )
}

test_that("V-80f: beta_binomial + binary parent emits; beta_binomial + continuous fails loud", {
  d_bin <- beta_binomial_binary_dat()
  plan <- drmSEM:::drm_imputation_plan(beta_binomial_binary_specs(), d_bin)
  expect_identical(plan$bb$variable, "treatment")
  expect_identical(
    drmSEM:::drm_impute_family_key(plan$bb$family_name),
    "binomial"
  )

  d_cont <- chain_dat()
  trials <- 8L
  d_cont$success <- stats::rbinom(nrow(d_cont), trials, 0.4)
  d_cont$failure <- trials - d_cont$success
  expect_error(
    suppressMessages(drm_sem(
      m = drm_node(drmTMB::bf(m ~ x)),
      bb = drm_node(
        drmTMB::bf(cbind(success, failure) ~ m + x, sigma ~ 1),
        family = drmTMB::beta_binomial()
      ),
      data = d_cont, impute = "auto"
    )),
    "BINARY missing predictor"
  )
})

test_that("V-124: beta_binomial x binary auto fit matches the hand-written emit", {
  skip_if_not(engine_accepts_beta_binomial(), "engine has no beta_binomial has_mi")
  d <- beta_binomial_binary_dat(n = 200, seed = 13L)
  auto <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    bb = drm_node(
      drmTMB::bf(cbind(success, failure) ~ treatment + z, sigma ~ 1),
      family = drmTMB::beta_binomial()
    ),
    data = d, impute = "auto"
  )))
  hand <- suppressWarnings(suppressMessages(drm_sem(
    treatment = drm_node(
      drmTMB::bf(treatment ~ z),
      family = stats::binomial()
    ),
    bb = drm_node(
      drmTMB::bf(cbind(success, failure) ~ mi(treatment) + z, sigma ~ 1),
      family = drmTMB::beta_binomial(),
      impute = list(
        treatment = drmTMB::impute_model(
          treatment ~ z,
          family = stats::binomial()
        )
      ),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$bb$coefficients$mu),
    unlist(hand$nodes$bb$coefficients$mu)
  )
  imp <- imputation(auto)
  expect_identical(nrow(imp), 1L)
  expect_identical(imp$node, "bb")
  expect_identical(imp$variable, "treatment")
  expect_identical(imp$family, "binomial")
})

test_that("V-124b: beta_binomial x binary auto recovers known MAR coefficients", {
  skip_if_not(engine_accepts_beta_binomial(), "engine has no beta_binomial has_mi")
  seeds <- c(13L, 21L, 34L)
  b_trt <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- beta_binomial_binary_dat(n = 1500, seed = seeds[[k]])
    fit <- suppressWarnings(suppressMessages(drm_sem(
      treatment = drm_node(
        drmTMB::bf(treatment ~ z),
        family = stats::binomial()
      ),
      bb = drm_node(
        drmTMB::bf(cbind(success, failure) ~ treatment + z, sigma ~ 1),
        family = drmTMB::beta_binomial()
      ),
      data = d, impute = "auto"
    )))$nodes$bb$coefficients$mu
    coefs <- unlist(fit)
    # logit mu: (Intercept), mi(treatment), z. Truth: 0.4, 0.7, 0.5.
    b_trt[[k]] <- coefs[["mi(treatment)"]]
  }
  expect_lt(mean(abs(b_trt - 0.7)), 0.20)
})

engine_accepts_nbinom2_gaussian <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(FALSE)
  }
  # nbinom2 is already on drm_missing_predictor_families() from the
  # Bernoulli cell. Probe the installed engine's R gate: #1095 lifts
  # gaussian() only; earlier builds abort "binary missing predictor".
  d <- data.frame(
    y = c(1L, 2L, 3L, 1L, 4L, 2L),
    z = seq_len(6),
    x = c(0.1, NA_real_, 0.3, 0.4, 0.2, 0.5)
  )
  ok <- tryCatch({
    drmTMB::drmTMB(
      drmTMB::bf(y ~ z + mi(x), sigma ~ 1),
      data = d,
      family = drmTMB::nbinom2(),
      impute = list(x = drmTMB::impute_model(x ~ z, family = stats::gaussian())),
      missing = drmTMB::miss_control(predictor = "model"),
      control = drmTMB::drm_control(se = FALSE)
    )
    TRUE
  }, error = function(e) FALSE)
  isTRUE(ok)
}

# z -> x (Gaussian, incomplete) -> y (nbinom2). Engine cell
# mp-nbinom2-gaussian / #1095. Log-mean DGP matches the engine
# recovery: mu = exp(0.4 + 0.5 z + 0.7 x), size = 3.
nbinom2_gaussian_dat <- function(n = 200, seed = 13L, mar = TRUE) {
  set.seed(seed)
  z <- stats::rnorm(n)
  x <- 0.3 + 0.8 * z + stats::rnorm(n, sd = 0.40)
  y <- stats::rnbinom(n, size = 3, mu = exp(0.4 + 0.5 * z + 0.7 * x))
  d <- data.frame(z = z, x = x, y = y)
  drop <- if (isTRUE(mar)) {
    stats::runif(n) < stats::plogis(-0.8 + 0.6 * as.numeric(scale(log(y + 1))))
  } else {
    seq_len(n) %in% sample(n, floor(0.2 * n))
  }
  d$x[drop] <- NA_real_
  d
}

nbinom2_gaussian_specs <- function() {
  list(
    x = drm_node(drmTMB::bf(x ~ z)),
    y = drm_node(
      drmTMB::bf(y ~ x + z, sigma ~ 1),
      family = drmTMB::nbinom2()
    )
  )
}

test_that("V-80h: nbinom2 + gaussian parent emits; nbinom2 + poisson fails loud", {
  d <- nbinom2_gaussian_dat()
  plan <- drmSEM:::drm_imputation_plan(nbinom2_gaussian_specs(), d)
  expect_identical(plan$y$variable, "x")
  expect_identical(plan$y$family_name, "gaussian")

  d_pois <- d
  d_pois$count <- pmax(0L, as.integer(round(exp(d_pois$z))))
  d_pois$count[seq_len(5)] <- NA_integer_
  expect_error(
    suppressMessages(drm_sem(
      count = drm_node(
        drmTMB::bf(count ~ z),
        family = stats::poisson()
      ),
      y = drm_node(
        drmTMB::bf(y ~ count + z, sigma ~ 1),
        family = drmTMB::nbinom2()
      ),
      data = d_pois, impute = "auto"
    )),
    "BINARY or GAUSSIAN missing predictor"
  )
})

test_that("V-126: nbinom2 x gaussian auto fit matches the hand-written emit", {
  skip_if_not(engine_accepts_nbinom2_gaussian(), "engine has no nbinom2 x gaussian mi")
  d <- nbinom2_gaussian_dat(n = 200, seed = 13L)
  auto <- suppressWarnings(suppressMessages(drm_sem(
    x = drm_node(drmTMB::bf(x ~ z)),
    y = drm_node(
      drmTMB::bf(y ~ x + z, sigma ~ 1),
      family = drmTMB::nbinom2()
    ),
    data = d, impute = "auto"
  )))
  hand <- suppressWarnings(suppressMessages(drm_sem(
    x = drm_node(drmTMB::bf(x ~ z)),
    y = drm_node(
      drmTMB::bf(y ~ mi(x) + z, sigma ~ 1),
      family = drmTMB::nbinom2(),
      impute = list(x = drmTMB::impute_model(x ~ z, family = stats::gaussian())),
      missing = drmTMB::miss_control(predictor = "model")
    ),
    data = d
  )))
  expect_equal(
    unlist(auto$nodes$y$coefficients$mu),
    unlist(hand$nodes$y$coefficients$mu)
  )
  imp <- imputation(auto)
  expect_identical(nrow(imp), 1L)
  expect_identical(imp$node, "y")
  expect_identical(imp$variable, "x")
  expect_identical(imp$family, "gaussian")
})

test_that("V-126b: nbinom2 x gaussian auto recovers known MAR coefficients", {
  skip_if_not(engine_accepts_nbinom2_gaussian(), "engine has no nbinom2 x gaussian mi")
  seeds <- c(13L, 21L, 34L)
  b_x <- numeric(length(seeds))
  for (k in seq_along(seeds)) {
    d <- nbinom2_gaussian_dat(n = 1500, seed = seeds[[k]])
    fit <- suppressWarnings(suppressMessages(drm_sem(
      x = drm_node(drmTMB::bf(x ~ z)),
      y = drm_node(
        drmTMB::bf(y ~ x + z, sigma ~ 1),
        family = drmTMB::nbinom2()
      ),
      data = d, impute = "auto"
    )))$nodes$y$coefficients$mu
    coefs <- unlist(fit)
    # log-mean mu: (Intercept), mi(x), z. Truth: 0.4, 0.7, 0.5.
    b_x[[k]] <- coefs[["mi(x)"]]
  }
  expect_lt(mean(abs(b_x - 0.7)), 0.20)
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
