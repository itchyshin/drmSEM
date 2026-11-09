# The drm_sem object's user-facing surface (R/drm_sem.R): print and summary
# methods with every optional section, the `latents =` / `latent =` argument forms
# of drm_sem() and drm_psem(), and constructor guards.

show_sem <- function(x) {
  res <- NULL
  out <- utils::capture.output(msg <- cli::cli_fmt(res <- withVisible(print(x))))
  list(text = paste(c(msg, out), collapse = "\n"), res = res)
}

latent_dgp <- function(n = 200, seed = 31) {
  set.seed(seed)
  L <- stats::rnorm(n)
  data.frame(
    L = L,
    x = stats::rnorm(n, 0.85 * L, 0.5),
    y = stats::rnorm(n, 0.85 * L, 0.5),
    i1 = L + stats::rnorm(n, 0, 0.3),
    i2 = 0.8 * L + stats::rnorm(n, 0, 0.3)
  )
}

latent_nodes <- function() {
  list(
    x = drm_node(drmTMB::bf(x ~ L), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ L), family = stats::gaussian())
  )
}

# ---- print / summary ------------------------------------------------------------------

test_that("print.drm_sem reports nodes, order, families, components, and edge counts", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  p <- show_sem(sem)
  expect_identical(p$res$value, sem)
  expect_false(p$res$visible)
  expect_match(p$text, "drmSEM distributional piecewise SEM")
  expect_match(p$text, "2 endogenous nodes")
  expect_match(p$text, "Topological order")
  expect_match(p$text, "m.*\\[gaussian\\].*components")
  expect_match(p$text, "sigma") # y carries a sigma sub-model
  expect_match(p$text, "component-labelled edge")
  expect_no_match(p$text, "NOT converged")
  expect_no_match(p$text, "covariance edge")
  expect_no_match(p$text, "composite construct")
  expect_no_match(p$text, "marginalised latent")
})

test_that("print.drm_sem flags non-converged and unknown-convergence nodes and row alignment", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  bad <- sem
  bad$records$y$fit$opt$convergence <- 1L
  testthat::local_mocked_bindings(
    drm_fit_converged = function(fit) if (identical(fit, bad$records$y$fit)) FALSE else NA,
    .package = "drmSEM"
  )
  p <- show_sem(bad)
  expect_match(p$text, "NOT converged")
  expect_match(p$text, "convergence unknown")

  aligned <- sem
  attr(aligned, "alignment_issues") <- data.frame(
    node = "y", issue = "rows_dropped", n = 7L, stringsAsFactors = FALSE
  )
  pa <- show_sem(aligned)
  expect_match(pa$text, "(7 rows)", fixed = TRUE)
  expect_match(pa$text, "Row alignment")
  expect_match(pa$text, "rows_dropped")
})

test_that("print.drm_sem lists covariances, composites, latent constructs, motifs, and marginalised latents", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  dat <- cov_chain_dgp()
  sem$covariances <- data.frame(y1 = "m", y2 = "y", class = "residual", stringsAsFactors = FALSE)
  sem$composites <- list(drm_composite("C", c("x", "m"), data = dat))
  sem$latent_constructs <- list(drm_latent("eta", c("x", "m"), data = dat))
  sem$feedback <- drmSEM:::drm_build_feedback(drm_cycle("m", "y"), sem$records)
  sem$latents <- "U"
  p <- show_sem(sem)
  expect_match(p$text, "1 covariance edge")
  expect_match(p$text, "1 composite construct")
  expect_match(p$text, "1 latent construct")
  expect_match(p$text, "1 declared feedback motif")
  expect_match(p$text, "1 marginalised latent")
  expect_match(p$text, "m-separation")
})

test_that("summary.drm_sem counts nodes and edges by component and prints them", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  s <- summary(sem)
  expect_s3_class(s, "summary.drm_sem")
  expect_identical(s$n_nodes, 2L)
  expect_identical(s$n_exogenous, length(sem$exogenous))
  expect_identical(s$order, sem$order)
  expect_identical(unname(s$families), c("gaussian", "gaussian"))
  expect_identical(unname(s$converged), c(TRUE, TRUE))
  expect_identical(s$components$y, c("mu", "sigma"))
  # edges by component: x and m both enter y's mu, and x enters y's sigma
  tb <- s$edges_by_component
  expect_equal(unname(tb[["sigma"]]), 1L)
  expect_equal(unname(tb[["mu"]]), sum(sem$edges$component == "mu"))
  expect_s3_class(s$paths, "drm_paths")
  p <- show_sem(s)
  expect_match(p$text, "drmSEM summary")
  expect_match(p$text, "Edges by component")
  expect_match(p$text, "sigma")
  expect_match(p$text, "Paths")
  expect_identical(p$res$value, s)
})

# ---- latent argument forms ---------------------------------------------------------------

test_that("drm_sem accepts marginalised latents as a vector, a character list, or `latent =`", {
  skip_if_not_installed("drmTMB")
  dat <- latent_dgp()
  nodes <- latent_nodes()
  a <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latents = "L")
  b <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latents = list("L"))
  cc <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latent = "L")
  both <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latent = "L", latents = "L")
  for (s in list(a, b, cc, both)) {
    expect_identical(s$latents, "L")
    expect_length(s$latent_constructs, 0L)
  }
  # the MAG drops the x _||_ y claim that the DAG (wrongly) makes
  bs <- basis_set(a)
  expect_false(any((bs$x == "x" & bs$y == "y") | (bs$x == "y" & bs$y == "x")))
})

test_that("drm_sem separates latent constructs from marginalised latent names in one list", {
  skip_if_not_installed("drmTMB")
  dat <- latent_dgp()
  nodes <- latent_nodes()
  construct <- drm_latent("eta", c("i1", "i2"))
  mixed <- drm_sem(
    x = nodes$x, y = nodes$y, data = dat, latents = list(construct, "L")
  )
  expect_identical(mixed$latents, "L")
  expect_length(mixed$latent_constructs, 1L)
  expect_identical(mixed$latent_constructs[[1]]$name, "eta")
  # a single construct and a list of constructs are both accepted
  one <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latents = construct)
  expect_length(one$latents, 0L)
  expect_identical(one$latent_constructs[[1]]$name, "eta")
  many <- drm_sem(x = nodes$x, y = nodes$y, data = dat, latents = list(construct))
  expect_length(many$latent_constructs, 1L)
  # the materialised construct score is a column of the model data
  expect_true("eta" %in% names(one$data))
})

test_that("drm_psem takes the same latent argument forms over already-fitted nodes", {
  skip_if_not_installed("drmTMB")
  dat <- latent_dgp()
  ctrl <- drmTMB::drm_control(se = TRUE)
  fx <- drmTMB::drmTMB(drmTMB::bf(x ~ L), family = stats::gaussian(), data = dat, control = ctrl)
  fy <- drmTMB::drmTMB(drmTMB::bf(y ~ L), family = stats::gaussian(), data = dat, control = ctrl)
  chr <- drm_psem(x = fx, y = fy, data = dat, latents = "L")
  expect_identical(chr$latents, "L")
  lst <- drm_psem(x = fx, y = fy, data = dat, latents = list("L"))
  expect_identical(lst$latents, "L")
  construct <- drm_latent("eta", c("i1", "i2"), data = dat)
  mixed <- drm_psem(x = fx, y = fy, data = dat, latents = list(construct, "L"))
  expect_identical(mixed$latents, "L")
  expect_identical(mixed$latent_constructs[[1]]$name, "eta")
  single <- drm_psem(x = fx, y = fy, data = dat, latents = construct)
  expect_identical(single$latent_constructs[[1]]$name, "eta")
  multi <- drm_psem(x = fx, y = fy, data = dat, latents = list(construct))
  expect_length(multi$latent_constructs, 1L)
  # unrelated list entries are ignored rather than mis-read as latent names
  ignored <- drm_psem(x = fx, y = fy, data = dat, latents = list(1, "L"))
  expect_identical(ignored$latents, "L")
})

# ---- constructor guards ------------------------------------------------------------------

test_that("drm_sem rejects an empty specification and a missing data argument", {
  skip_if_not_installed("drmTMB")
  expect_error(drm_sem(data = data.frame(x = 1)), "Supply at least one")
  expect_error(
    drm_sem(y = drm_node(drmTMB::bf(y ~ x), family = stats::gaussian())),
    "data.*required"
  )
})
