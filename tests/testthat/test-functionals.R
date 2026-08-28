# ===========================================================================
# Test suite: Outcome Functionals & Non-Gaussian Tail Exceedance / Quantile
# Effects (OQ-11, V-139 .. V-141)
# ===========================================================================

fn_rows <- function(df, n) df[rep(1, n), ]

fn_engine <- function(name, family, components, predict_fn, coef = list(), vcov = NULL) {
  list(
    name = name,
    identifier = name,
    family = family,
    model_type = NA_character_,
    components = components,
    coef = coef,
    vcov = vcov,
    predict = predict_fn
  )
}

test_that("V-139: Exact recovery of analytic vs simulated lognormal and Gamma tail exceedance probabilities", {
  # -------------------------------------------------------------------------
  # (A) Lognormal family
  # mu = meanlog = 1.0 + 0.6 * x
  # sigma = sdlog = 0.4 + 0.3 * x
  # -------------------------------------------------------------------------
  eng_ln <- list(
    Y = fn_engine(
      "Y",
      "lognormal",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 1.0 + 0.6 * scenario$x,
          sigma = 0.4 + 0.3 * scenario$x
        )
      }
    )
  )

  n <- 5000
  lo <- fn_rows(data.frame(x = 0, Y = 0), n)
  hi <- fn_rows(data.frame(x = 1, Y = 0), n)
  scen <- list(lo = lo, hi = hi, column = "x")

  # Threshold t = 4.0
  t_ln <- 4.0
  mu0 <- 1.0; sig0 <- 0.4
  mu1 <- 1.6; sig1 <- 0.7
  p_gt_0_ln <- stats::plnorm(t_ln, meanlog = mu0, sdlog = sig0, lower.tail = FALSE)
  p_gt_1_ln <- stats::plnorm(t_ln, meanlog = mu1, sdlog = sig1, lower.tail = FALSE)
  expected_delta_p_gt_ln <- p_gt_1_ln - p_gt_0_ln

  # Analytic closed-form contrast
  analytic_contrast_ln <- drm_functional_contrast_analytic(
    eng_ln,
    scen,
    "Y",
    active = character(0),
    mediation = "mean",
    target = "p_gt",
    threshold = t_ln,
    prob = 0.5,
    B = 1,
    draw = FALSE
  )
  expect_equal(unname(analytic_contrast_ln), expected_delta_p_gt_ln, tolerance = 1e-10)

  # Monte Carlo simulated contrast
  set.seed(42)
  sim_contrast_ln <- drm_functional_contrast(
    eng_ln,
    scen,
    "Y",
    active = character(0),
    mediation = "distribution",
    target = "p_gt",
    threshold = t_ln,
    B = 1,
    n_sim = 40,
    draw = FALSE
  )
  expect_equal(unname(sim_contrast_ln), expected_delta_p_gt_ln, tolerance = 0.025)

  # Lognormal variance contrast
  var0_ln <- (exp(sig0^2) - 1) * exp(2 * mu0 + sig0^2)
  var1_ln <- (exp(sig1^2) - 1) * exp(2 * mu1 + sig1^2)
  expected_delta_var_ln <- var1_ln - var0_ln

  analytic_var_ln <- drm_functional_contrast_analytic(
    eng_ln,
    scen,
    "Y",
    active = character(0),
    mediation = "mean",
    target = "var",
    threshold = 0,
    prob = 0.5,
    B = 1,
    draw = FALSE
  )
  expect_equal(unname(analytic_var_ln), expected_delta_var_ln, tolerance = 1e-10)

  # -------------------------------------------------------------------------
  # (B) Gamma family
  # mu = 2.0 + 1.2 * x
  # sigma = 0.5 + 0.3 * x (shape = 1/sigma^2, rate = 1/(sigma^2 * mu))
  # -------------------------------------------------------------------------
  eng_ga <- list(
    Y = fn_engine(
      "Y",
      "Gamma",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 2.0 + 1.2 * scenario$x,
          sigma = 0.5 + 0.3 * scenario$x
        )
      }
    )
  )

  t_ga <- 5.0
  mu0_ga <- 2.0; sig0_ga <- 0.5; sh0_ga <- 1 / sig0_ga^2; rt0_ga <- 1 / (sig0_ga^2 * mu0_ga)
  mu1_ga <- 3.2; sig1_ga <- 0.8; sh1_ga <- 1 / sig1_ga^2; rt1_ga <- 1 / (sig1_ga^2 * mu1_ga)
  p_gt_0_ga <- stats::pgamma(t_ga, shape = sh0_ga, rate = rt0_ga, lower.tail = FALSE)
  p_gt_1_ga <- stats::pgamma(t_ga, shape = sh1_ga, rate = rt1_ga, lower.tail = FALSE)
  expected_delta_p_gt_ga <- p_gt_1_ga - p_gt_0_ga

  analytic_contrast_ga <- drm_functional_contrast_analytic(
    eng_ga,
    scen,
    "Y",
    active = character(0),
    mediation = "mean",
    target = "p_gt",
    threshold = t_ga,
    prob = 0.5,
    B = 1,
    draw = FALSE
  )
  expect_equal(unname(analytic_contrast_ga), expected_delta_p_gt_ga, tolerance = 1e-10)

  set.seed(43)
  sim_contrast_ga <- drm_functional_contrast(
    eng_ga,
    scen,
    "Y",
    active = character(0),
    mediation = "distribution",
    target = "p_gt",
    threshold = t_ga,
    B = 1,
    n_sim = 40,
    draw = FALSE
  )
  expect_equal(unname(sim_contrast_ga), expected_delta_p_gt_ga, tolerance = 0.025)

  # -------------------------------------------------------------------------
  # (C) Negative Binomial (nbinom2) & Beta families
  # -------------------------------------------------------------------------
  eng_nb <- list(
    Y = fn_engine(
      "Y",
      "nbinom2",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 3.0 + 2.0 * scenario$x,
          sigma = 0.6 + 0.4 * scenario$x
        )
      }
    )
  )
  t_nb <- 6
  mu0_nb <- 3.0; sz0_nb <- 1 / (0.6^2)
  mu1_nb <- 5.0; sz1_nb <- 1 / (1.0^2)
  p_gt_0_nb <- stats::pnbinom(t_nb, size = sz0_nb, mu = mu0_nb, lower.tail = FALSE)
  p_gt_1_nb <- stats::pnbinom(t_nb, size = sz1_nb, mu = mu1_nb, lower.tail = FALSE)
  expected_delta_p_gt_nb <- p_gt_1_nb - p_gt_0_nb

  analytic_contrast_nb <- drm_functional_contrast_analytic(
    eng_nb,
    scen,
    "Y",
    active = character(0),
    mediation = "mean",
    target = "p_gt",
    threshold = t_nb,
    prob = 0.5,
    B = 1,
    draw = FALSE
  )
  expect_equal(unname(analytic_contrast_nb), expected_delta_p_gt_nb, tolerance = 1e-10)

  eng_be <- list(
    Y = fn_engine(
      "Y",
      "beta",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 0.3 + 0.3 * scenario$x,
          sigma = 0.4 + 0.2 * scenario$x
        )
      }
    )
  )
  t_be <- 0.5
  mu0_be <- 0.3; phi0_be <- 1 / (0.4^2)
  mu1_be <- 0.6; phi1_be <- 1 / (0.6^2)
  p_gt_0_be <- stats::pbeta(t_be, shape1 = mu0_be * phi0_be, shape2 = (1 - mu0_be) * phi0_be, lower.tail = FALSE)
  p_gt_1_be <- stats::pbeta(t_be, shape1 = mu1_be * phi1_be, shape2 = (1 - mu1_be) * phi1_be, lower.tail = FALSE)
  expected_delta_p_gt_be <- p_gt_1_be - p_gt_0_be

  analytic_contrast_be <- drm_functional_contrast_analytic(
    eng_be,
    scen,
    "Y",
    active = character(0),
    mediation = "mean",
    target = "p_gt",
    threshold = t_be,
    prob = 0.5,
    B = 1,
    draw = FALSE
  )
  expect_equal(unname(analytic_contrast_be), expected_delta_p_gt_be, tolerance = 1e-10)
})

test_that("V-140: Quantile effect recovery against known DGP data", {
  # -------------------------------------------------------------------------
  # (A) Lognormal quantiles across median (0.5), upper tail (0.9, 0.95)
  # -------------------------------------------------------------------------
  eng_ln <- list(
    Y = fn_engine(
      "Y",
      "lognormal",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 1.0 + 0.5 * scenario$x,
          sigma = 0.3 + 0.4 * scenario$x
        )
      }
    )
  )

  n <- 5000
  lo <- fn_rows(data.frame(x = 0, Y = 0), n)
  hi <- fn_rows(data.frame(x = 1, Y = 0), n)
  scen <- list(lo = lo, hi = hi, column = "x")

  mu0 <- 1.0; sig0 <- 0.3
  mu1 <- 1.5; sig1 <- 0.7

  probs <- c(0.5, 0.9, 0.95)
  for (pr in probs) {
    q0 <- stats::qlnorm(pr, meanlog = mu0, sdlog = sig0)
    q1 <- stats::qlnorm(pr, meanlog = mu1, sdlog = sig1)
    expected_delta_q <- q1 - q0

    # Analytic
    an_q <- drm_functional_contrast_analytic(
      eng_ln,
      scen,
      "Y",
      active = character(0),
      mediation = "mean",
      target = "quantile",
      threshold = 0,
      prob = pr,
      B = 1,
      draw = FALSE
    )
    expect_equal(unname(an_q), expected_delta_q, tolerance = 1e-10)

    # Simulated
    set.seed(100 + as.integer(pr * 100))
    sim_q <- drm_functional_contrast(
      eng_ln,
      scen,
      "Y",
      active = character(0),
      mediation = "distribution",
      target = "quantile",
      threshold = 0,
      B = 1,
      n_sim = 50,
      draw = FALSE,
      prob = pr
    )
    expect_equal(unname(sim_q), expected_delta_q, tolerance = 0.25)
  }

  # -------------------------------------------------------------------------
  # (B) Gamma quantiles
  # -------------------------------------------------------------------------
  eng_ga <- list(
    Y = fn_engine(
      "Y",
      "Gamma",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 2.0 + 0.8 * scenario$x,
          sigma = 0.4 + 0.3 * scenario$x
        )
      }
    )
  )
  mu0_ga <- 2.0; sig0_ga <- 0.4; sh0_ga <- 1 / sig0_ga^2; rt0_ga <- 1 / (sig0_ga^2 * mu0_ga)
  mu1_ga <- 2.8; sig1_ga <- 0.7; sh1_ga <- 1 / sig1_ga^2; rt1_ga <- 1 / (sig1_ga^2 * mu1_ga)

  for (pr in c(0.5, 0.9, 0.95)) {
    q0_ga <- stats::qgamma(pr, shape = sh0_ga, rate = rt0_ga)
    q1_ga <- stats::qgamma(pr, shape = sh1_ga, rate = rt1_ga)
    expected_delta_q_ga <- q1_ga - q0_ga

    an_q_ga <- drm_functional_contrast_analytic(
      eng_ga,
      scen,
      "Y",
      active = character(0),
      mediation = "mean",
      target = "quantile",
      threshold = 0,
      prob = pr,
      B = 1,
      draw = FALSE
    )
    expect_equal(unname(an_q_ga), expected_delta_q_ga, tolerance = 1e-10)
  }
})

test_that("V-141: Decomposition of tail risk into mean vs dispersion pathways", {
  # -------------------------------------------------------------------------
  # Mediation DAG: X -> M -> Y
  # M is Gaussian with mu = 0.4 * x, sigma = exp(-0.2 + 0.5 * x)
  # Y is Gamma with mu = exp(0.3 + 0.5 * M), sigma = 0.35
  # -------------------------------------------------------------------------
  engines <- list(
    M = fn_engine(
      "M",
      "gaussian",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 0.4 * scenario$x,
          sigma = exp(-0.2 + 0.5 * scenario$x)
        )
      }
    ),
    Y = fn_engine(
      "Y",
      "Gamma",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = exp(0.3 + 0.5 * scenario$M),
          sigma = rep(0.35, nrow(scenario))
        )
      }
    )
  )

  n <- 4000
  lo <- fn_rows(data.frame(x = 0, M = 0, Y = 0), n)
  hi <- fn_rows(data.frame(x = 1, M = 0, Y = 0), n)
  scen <- list(lo = lo, hi = hi, column = "x")

  t_risk <- 2.5 # tail threshold for Pr(Y > 2.5)

  # 1. Natural cross-world decomposition on tail exceedance functional
  set.seed(42)
  nat_decomp <- drm_natural_target(
    engines,
    scen,
    "x",
    "Y",
    active = "M",
    mediation = "distribution",
    n_sim = 40,
    target = "p_gt",
    threshold = t_risk,
    functional = "simulate"
  )
  expect_equal(
    unname(nat_decomp[["total"]]),
    unname(nat_decomp[["nde"]] + nat_decomp[["nie"]] + nat_decomp[["mediated_interaction"]]),
    tolerance = 1e-8
  )
  expect_gt(nat_decomp[["nie"]], 0) # Indirect shift in tail exceedance risk through M

  # 2. Path-specific per-component attribution on tail risk
  set.seed(42)
  comp_decomp <- drm_component_contrasts(
    engines,
    scen,
    "Y",
    mj = "M",
    B = 1,
    n_sim = 50,
    draw = FALSE,
    target = "p_gt",
    threshold = t_risk,
    functional = "simulate"
  )

  expect_true("mean" %in% names(comp_decomp))
  expect_true("sigma" %in% names(comp_decomp$channels))
  expect_true("remainder" %in% names(comp_decomp))

  # Both mean and sigma inflation contribute to increasing tail exceedance risk
  expect_gt(unname(comp_decomp$mean), 0)
  expect_gt(unname(comp_decomp$channels$sigma), 0)
  expect_equal(
    unname(comp_decomp$inclusion),
    unname(comp_decomp$mean + comp_decomp$channels$sigma + comp_decomp$remainder),
    tolerance = 1e-8
  )

  # When mediator sigma is constant in x (sigma = exp(-0.2)), sigma_channel drops to ~0
  engines_const_sig <- list(
    M = fn_engine(
      "M",
      "gaussian",
      c("mu", "sigma"),
      function(scenario, beta = NULL) {
        data.frame(
          mu = 0.4 * scenario$x,
          sigma = rep(exp(-0.2), nrow(scenario))
        )
      }
    ),
    Y = engines$Y
  )
  set.seed(42)
  comp_decomp_const <- drm_component_contrasts(
    engines_const_sig,
    scen,
    "Y",
    mj = "M",
    B = 1,
    n_sim = 50,
    draw = FALSE,
    target = "p_gt",
    threshold = t_risk,
    functional = "simulate"
  )
  expect_equal(unname(comp_decomp_const$channels$sigma), 0, tolerance = 0.02)
  expect_gt(unname(comp_decomp_const$mean), 0)
})

test_that("V-141: User-facing indirect_effects and path_effects functionals run on live fitted models", {
  skip_if_not_installed("drmTMB")
  set.seed(123)
  n <- 800
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, mean = 0.4 * x, sd = exp(-0.2 + 0.3 * x))
  y <- stats::rgamma(
    n,
    shape = 1 / (0.3^2),
    rate = 1 / (0.3^2 * exp(0.2 + 0.4 * m))
  )
  dat <- data.frame(x = x, m = m, y = y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x, sigma ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::Gamma(link = "log")),
    data = dat
  )

  # 1. indirect_effects controlled decomposition on tail exceedance
  ind_ctrl <- indirect_effects(
    sem,
    from = "x",
    to = "y",
    through = "m",
    effect = "controlled",
    target = "p_gt",
    threshold = 2.0,
    uncertainty = "none",
    nsim = 60,
    seed = 123
  )
  expect_s3_class(ind_ctrl, "drm_effect")
  expect_identical(unique(ind_ctrl$target), "p_gt")
  expect_setequal(
    ind_ctrl$quantity,
    c("total_path", "direct", "indirect", "mean_mediated", "distribution_mediated")
  )
  expect_true(all(is.finite(ind_ctrl$estimate)))

  # 2. indirect_effects natural decomposition on tail exceedance
  ind_nat <- indirect_effects(
    sem,
    from = "x",
    to = "y",
    through = "m",
    effect = "natural",
    target = "p_gt",
    threshold = 2.0,
    uncertainty = "none",
    nsim = 60,
    seed = 123
  )
  expect_s3_class(ind_nat, "drm_effect")
  expect_identical(unique(ind_nat$target), "p_gt")
  expect_setequal(
    ind_nat$quantity,
    c("total_path", "natural_direct", "natural_indirect", "mediated_interaction")
  )
  expect_true(all(is.finite(ind_nat$estimate)))

  # 3. path_effects by component on tail exceedance
  pe_comp <- path_effects(
    sem,
    from = "x",
    to = "y",
    through = "m",
    by = "component",
    target = "p_gt",
    threshold = 2.0,
    uncertainty = "none",
    nsim = 60,
    seed = 123
  )
  expect_s3_class(pe_comp, "drm_effect")
  expect_identical(unique(pe_comp$target), "p_gt")
  expect_true("mean_channel" %in% pe_comp$estimand)
  expect_true("sigma_channel" %in% pe_comp$estimand)
  expect_true(all(is.finite(pe_comp$estimate)))

  # 4. direct_effects and total_effects with quantile_prob and analytic functional
  de_q <- direct_effects(
    sem,
    from = "m",
    to = "y",
    target = "quantile",
    quantile_prob = 0.95,
    functional = "analytic",
    uncertainty = "none"
  )
  expect_s3_class(de_q, "drm_effect")
  expect_identical(de_q$target, "quantile")
  expect_true(is.finite(de_q$estimate))

  te_q <- total_effects(
    sem,
    from = "x",
    to = "y",
    target = "quantile",
    quantile_prob = 0.95,
    functional = "analytic",
    uncertainty = "none"
  )
  expect_s3_class(te_q, "drm_effect")
  expect_identical(te_q$target, "quantile")
  expect_true(is.finite(te_q$estimate))
})

