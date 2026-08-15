# Ordinal (cumulative_logit) nodes — retained evidence, and two pinned limitations.
#
# drmSEM imposes no family whitelist, so an ordinal node has worked end-to-end for
# some time — but nothing tested it, and untested capability is worse than absent
# capability because the capability surface advertises it. This file is that evidence.
#
# V-number -> test map:
#   V-87  paths() labels the ordinal node logit/mu and does NOT leak the cutpoints
#   V-88  latent-scale recovery of a known DGP through a gaussian -> ordinal chain
#   V-89  dsep()/Fisher's C run over an ordinal node and do not reject a true DAG
#   V-90  LIMITATION: `mu` is the LATENT linear predictor, not E[category]
#   V-91  LIMITATION: a non-mean target (p_gt) degenerates to exactly 0
#   V-92  engine constraint: an ordinal node cannot be distributional
#
# V-90 and V-91 are pinned as *limitations*, not fixed. Both are silent-wrong-answer
# shaped, so the test exists to make them loud in the suite rather than discovered by
# a user. Changing either to return NA is a semantics change and is deliberately NOT
# done here.

skip_if_not_installed("drmTMB")

# x -> m -> y, y ordinal with 4 categories. True latent coefficients: x->m 0.5,
# m->y 0.9. Seed fixed so the recovered numbers below are reproducible -- an earlier
# audit quoted figures that could not be reproduced without its seed.
ordinal_dat <- function(n = 800, seed = 101) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  eta <- 0.9 * m
  cuts <- c(-1.2, 0, 1.2)
  p <- vapply(cuts, function(k) stats::plogis(k - eta), numeric(n))
  u <- stats::runif(n)
  y <- 1L + (u > p[, 1]) + (u > p[, 2]) + (u > p[, 3])
  data.frame(x = x, m = m, y = ordered(y))
}

ordinal_sem <- function(d = ordinal_dat()) {
  drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = drmTMB::cumulative_logit()),
    data = d
  )
}

test_that("V-87: paths() labels an ordinal node logit/mu and hides its cutpoints", {
  p <- as.data.frame(paths(ordinal_sem()))
  edge <- p[p$from == "m" & p$to == "y", , drop = FALSE]
  expect_identical(nrow(edge), 1L)
  expect_identical(edge$component, "mu")
  expect_identical(edge$link, "logit")
  # The cutpoints are free scalars, not structural paths. They must never appear as
  # an edge source or a coefficient term.
  expect_false(any(grepl("cut|thresh|intercept", p$from, ignore.case = TRUE)))
  expect_false(any(grepl("cut|thresh", p$term, ignore.case = TRUE)))
  expect_setequal(p$from, c("x", "m"))
})

test_that("V-88: a gaussian -> ordinal chain recovers its known latent coefficients", {
  p <- as.data.frame(paths(ordinal_sem()))
  b_xm <- p$estimate[p$from == "x" & p$to == "m"]
  b_my <- p$estimate[p$from == "m" & p$to == "y"]
  # Truth is 0.5 and 0.9 on the LATENT scale, which is where cumulative_logit's
  # linear predictor lives (see V-90).
  expect_equal(b_xm, 0.5, tolerance = 0.12)
  expect_equal(b_my, 0.9, tolerance = 0.15)
})

test_that("V-89: dsep()/Fisher's C run over an ordinal node and hold on a true DAG", {
  sem <- ordinal_sem()
  ds <- as.data.frame(dsep(sem))
  # The DGP has no direct x -> y edge, so the single claim must be TESTED (not
  # skipped for want of a sampler) and must not be rejected.
  expect_true(nrow(ds) >= 1L)
  claim <- ds[ds$x == "x" & ds$y == "y", , drop = FALSE]
  expect_identical(nrow(claim), 1L)
  expect_identical(claim$status, "ok")
  expect_true(is.finite(claim$p.value))
  expect_gt(claim$p.value, 0.01)
  fc <- fisher_c(sem)
  expect_true(is.finite(fc$fisher_c))
})

test_that("V-89b: effects decompose through an ordinal outcome and close additively", {
  sem <- ordinal_sem()
  ie <- suppressWarnings(
    indirect_effects(sem, from = "x", to = "y", uncertainty = "none", nsim = 400)
  )
  q <- stats::setNames(ie$estimate, ie$quantity)
  expect_true(all(c("total_path", "direct", "indirect") %in% names(q)))
  expect_true(all(is.finite(q)))
  # Recomputed from the same object, not a hand formula.
  expect_equal(q[["total_path"]], q[["direct"]] + q[["indirect"]], tolerance = 1e-8)
})

test_that("V-90: LIMITATION -- ordinal `mu` is the latent predictor, not E[category]", {
  d <- ordinal_dat()
  sem <- ordinal_sem(d)
  mu <- drmSEM:::drm_predict_parameter_values(
    sem$nodes$y, newdata = d, dpar = "mu", type = "response"
  )
  cats <- as.numeric(as.character(d$y))
  # Measured: mu spans about (-3.2, 3.2) while the categories are 1..4. If `mu` were
  # E[category] it would sit inside the category range; it does not, and NOTHING
  # warns. Any effect reported with target = "mean" on an ordinal node is therefore a
  # LATENT-SCALE effect. This test exists so that stops being a surprise.
  expect_lt(min(mu), min(cats))
  expect_true(any(mu < 0))
  expect_false(all(mu >= min(cats) & mu <= max(cats)))
})

test_that("V-91: LIMITATION -- a non-mean target on an ordinal node degenerates to 0", {
  sem <- ordinal_sem()
  te <- suppressWarnings(
    total_effects(sem, from = "x", to = "y", target = "p_gt", threshold = 2,
                  uncertainty = "none", nsim = 400)
  )
  # cumulative_logit has no realized-value sampler, so propagation falls back to the
  # deterministic mean; both scenarios then collapse to the same value and every
  # quantity is EXACTLY zero. The sampler warning fires, but a reader who sees only
  # the number sees a confident "no effect".
  expect_true(all(te$estimate == 0))
  expect_identical(unique(te$target), "p_gt")
  # And the fallback must announce itself.
  wenv <- drmSEM:::drm_warn_once_env
  key <- "family-sampler-cumulative_logit"
  if (!is.null(wenv[[key]])) rm(list = key, envir = wenv)
  expect_warning(
    total_effects(sem, from = "x", to = "y", target = "p_gt", threshold = 2,
                  uncertainty = "none", nsim = 100),
    "No realized-value sampler"
  )
})

test_that("V-91b: check_sem() reports the ordinal node as having no sampler", {
  chk <- as.data.frame(check_sem(ordinal_sem()))
  row <- chk[chk$node == "y", , drop = FALSE]
  expect_identical(row$family, "cumulative_logit")
  expect_false(row$sampler)
  # ... but it is otherwise a healthy node: this is a propagation gap, not a fit gap.
  expect_true(row$converged)
  expect_true(row$vcov_available)
})

test_that("V-92: an ordinal node cannot be distributional (engine constraint)", {
  d <- ordinal_dat(n = 200)
  # cumulative_logit declares dpars = "mu" only; the fitter rejects any non-mu
  # formula. So a causal path can never target an ordinal node's scale -- which is
  # the one place drmSEM's headline capability is structurally unavailable.
  expect_error(
    drm_sem(
      m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
      y = drm_node(drmTMB::bf(y ~ m, disc ~ x), family = drmTMB::cumulative_logit()),
      data = d
    )
  )
})
