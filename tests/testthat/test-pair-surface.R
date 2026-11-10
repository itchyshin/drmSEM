# Bivariate pair plumbing (R/pair.R): declaration guards, family mapping, spec
# unpacking for drm_sem()/drm_psem(), covariance derivation from fitted pairs, and
# the rho12 accessor/print for declaration-only objects. Mostly pure R; the two
# live-fit checks use a tiny bivariate fit.

capture_msgs <- function(expr) {
  expr <- substitute(expr)
  env <- parent.frame()
  out <- utils::capture.output(msg <- cli::cli_fmt(eval(expr, env)))
  paste(c(msg, out), collapse = "\n")
}

# ---- drm_pair() guards ----------------------------------------------------------------

test_that("drm_pair rejects non-formulas, one-sided formulas, and responseless left-hand sides", {
  expect_error(drm_pair(a ~ x, "b ~ x"), "must both be formulas")
  expect_error(drm_pair(~x, b ~ x), "two-sided formula")
  expect_error(drm_pair(1 ~ x, b ~ x), "Could not read a response variable")
})

test_that("drm_pair reads the first variable of a cbind() response, and honours `names`", {
  p <- drm_pair(cbind(succ, fail) ~ x, b ~ x)
  expect_identical(p$responses, c("succ", "b"))
  q <- drm_pair(a ~ x, a ~ z, names = c("a1", "a2"))
  expect_identical(q$responses, c("a1", "a2"))
  expect_error(drm_pair(a ~ x, b ~ x, names = "only_one"), "two non-empty node names")
  expect_error(drm_pair(a ~ x, b ~ x, names = c("a", "")), "two non-empty node names")
  expect_error(drm_pair(a ~ x, b ~ x, names = c(NA, "b")), "two non-empty node names")
  expect_error(drm_pair(a ~ x, a ~ z), "two distinct")
})

test_that("drm_pair validates `level` and warns when it is not a shared grouping", {
  expect_error(drm_pair(a ~ x, b ~ x, level = 1), "NULL.*NA.*grouping")
  expect_error(drm_pair(a ~ x, b ~ x, level = c("g", "")), "NULL.*NA.*grouping")
  # NA suppresses the higher-level edge even when a grouping is shared
  p <- drm_pair(a ~ x + (1 | g), b ~ x + (1 | g), level = NA)
  expect_identical(p$levels, character(0))
  expect_identical(length(p$corpairs), 0L)
  # the default detects the shared grouping
  expect_identical(drm_pair(a ~ x + (1 | g), b ~ x + (1 | g))$levels, "g")
  expect_warning(drm_pair(a ~ x, b ~ x, level = "g"), "not a grouping shared")
  expect_error(drm_pair(a ~ x, b ~ x, rho12 = "x"), "one-sided formula")
})

# ---- joint family mapping ------------------------------------------------------------------

test_that("drm_pair_joint_family maps matching margins onto the drmTMB bivariate family", {
  skip_if_not_installed("drmTMB")
  fam_of <- function(a, b) {
    drmSEM:::drm_pair_joint_family(list(families = list(a, b)))
  }
  expect_identical(fam_of("gaussian", "gaussian")$family, drmTMB::biv_gaussian()$family)
  expect_identical(fam_of("lognormal", "lognormal")$family, drmTMB::biv_lognormal()$family)
  expect_identical(fam_of("student", "student")$family, drmTMB::biv_student()$family)
  # an already-bivariate family name maps back onto its stem
  expect_identical(fam_of("biv_student", "student")$family, drmTMB::biv_student()$family)
  expect_error(fam_of("gaussian", "lognormal"), "same family on both responses")
  expect_error(fam_of("poisson", "poisson"), "No joint bivariate family")
})

test_that("drm_fit_pair names the pair when the joint fit fails", {
  skip_if_not_installed("drmTMB")
  pr <- drm_pair(a ~ x, b ~ x)
  expect_error(
    drmSEM:::drm_fit_pair(pr, data.frame(x = 1:5)),
    "Bivariate pair .a & b. failed to fit"
  )
  expect_error(
    drmSEM:::drm_fit_pair(pr, data.frame(x = 1:5), name = "mypair"),
    "mypair"
  )
})

# ---- drm_unpack_sem_specs / drm_expand_psem_fits ---------------------------------------------

test_that("drm_unpack_sem_specs splits nodes, pairs, and covariance edges, and guards names", {
  skip_if_not_installed("drmTMB")
  nd <- drm_node(drmTMB::bf(y ~ x), family = stats::gaussian())
  pr <- drm_pair(a ~ x, b ~ x)
  out <- drmSEM:::drm_unpack_sem_specs(list(y = nd, pr))
  expect_setequal(names(out$nodes), c("y", "a", "b"))
  expect_length(out$pairs, 1L)
  expect_identical(unname(unlist(out$member_pair[c("a", "b")])[1]), unname(unlist(out$member_pair)[2]))
  expect_gte(length(out$covariances), 1L)

  expect_error(drmSEM:::drm_unpack_sem_specs(list(nd)), "must be named")
  expect_error(drmSEM:::drm_unpack_sem_specs(list(y = nd, y = nd)), "used more than once")
  expect_error(drmSEM:::drm_unpack_sem_specs(list(a = nd, pr)), "collide with an existing node name")
  expect_error(drmSEM:::drm_unpack_sem_specs(list(z = "not a spec")), "expects.*drm_node.*drm_pair")
})

test_that("drm_expand_psem_fits validates fitted inputs and names", {
  expect_error(drmSEM:::drm_expand_psem_fits(list(y = "not a fit")), "expects fitted")
  fake <- structure(list(), class = "drmTMB")
  testthat::local_mocked_bindings(drm_is_bivariate_fit = function(fit) FALSE, .package = "drmSEM")
  expect_error(drmSEM:::drm_expand_psem_fits(list(fake)), "must be named")
  expect_error(drmSEM:::drm_expand_psem_fits(list(y = fake, y = fake)), "used more than once")
  ok <- drmSEM:::drm_expand_psem_fits(list(y = fake))
  expect_identical(names(ok), "y")
})

test_that("drm_expand_psem_fits expands one bivariate fit into two nodes and rejects clashes", {
  fit1 <- structure(list(id = 1), class = "drmTMB")
  fit2 <- structure(list(id = 2), class = "drmTMB")
  testthat::local_mocked_bindings(
    drm_is_bivariate_fit = function(fit) TRUE,
    drm_biv_response_names = function(fit) c("a", "b"),
    .package = "drmSEM"
  )
  out <- drmSEM:::drm_expand_psem_fits(list(fit1))
  expect_identical(names(out), c("a", "b"))
  expect_identical(out$a, fit1)
  # naming the fit after one of its responses registers it under that name only
  named <- drmSEM:::drm_expand_psem_fits(list(a = fit1))
  expect_identical(names(named), "a")
  # the same name carried by two different fits is ambiguous
  expect_error(
    drmSEM:::drm_expand_psem_fits(list(a = fit1, a = fit2)),
    "supplied twice with different fits"
  )
  expect_error(
    drmSEM:::drm_expand_psem_fits(list(fit1, fit2)),
    "supplied twice with different fits"
  )
  # re-supplying the identical fit is harmless
  same <- drmSEM:::drm_expand_psem_fits(list(fit1, fit1))
  expect_identical(names(same), c("a", "b"))
})

test_that("drm_expand_psem_fits refuses a bivariate fit whose responses cannot be read", {
  fit <- structure(list(), class = "drmTMB")
  testthat::local_mocked_bindings(
    drm_is_bivariate_fit = function(fit) TRUE,
    drm_biv_response_names = function(fit) c("a", NA),
    .package = "drmSEM"
  )
  expect_error(drmSEM:::drm_expand_psem_fits(list(fit)), "Could not read both response names")
})

test_that("drm_combine_covariances wraps a single covary() and returns NULL for nothing", {
  cv <- covary("a", "b")
  expect_identical(drmSEM:::drm_combine_covariances(NULL, NULL), NULL)
  expect_length(drmSEM:::drm_combine_covariances(list(), cv), 1L)
  expect_length(drmSEM:::drm_combine_covariances(list(covary("c", "d")), cv), 2L)
})

test_that("drm_bivariate_fit_covariances derives residual and higher-level edges from fitted pairs", {
  fit <- structure(list(), class = "drmTMB")
  tab <- data.frame(
    level = c("residual", "site", NA, "year"),
    class = c("residual", "higher_level", "higher_level", "higher_level"),
    group = c(NA, "site", "plot", ""),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    drm_is_bivariate_fit = function(fit) TRUE,
    drm_biv_response_names = function(fit) c("b", "a"),
    drm_fit_corpairs = function(fit, ...) tab,
    .package = "drmSEM"
  )
  out <- drmSEM:::drm_bivariate_fit_covariances(list(n1 = fit, n2 = fit))
  # the pair is visited once (n2 duplicates n1): the residual edge plus one edge per
  # usable higher-level row (an empty `group` falls back to `level`)
  expect_length(out, 4L)
  expect_true(all(vapply(out, inherits, logical(1), "drm_covary")))
  lv <- vapply(out, function(e) if (is.null(e$level)) NA_character_ else e$level, character(1))
  expect_setequal(lv, c(NA, "site", "plot", "year"))
})

test_that("drm_bivariate_fit_covariances skips unreadable pairs and non-bivariate nodes", {
  fit <- structure(list(), class = "drmTMB")
  testthat::local_mocked_bindings(
    drm_is_bivariate_fit = function(fit) TRUE,
    drm_biv_response_names = function(fit) c("a", NA),
    .package = "drmSEM"
  )
  expect_length(drmSEM:::drm_bivariate_fit_covariances(list(n = fit)), 0L)
  testthat::local_mocked_bindings(drm_is_bivariate_fit = function(fit) FALSE, .package = "drmSEM")
  expect_length(drmSEM:::drm_bivariate_fit_covariances(list(n = fit)), 0L)
})

# ---- rho12 accessors --------------------------------------------------------------------------

test_that("print.drm_rho12 handles empty and populated tables", {
  empty <- structure(drmSEM:::drm_rho12_empty(), class = c("drm_rho12", "data.frame"))
  expect_match(capture_msgs(print(empty)), "none")

  tab <- rho12(drm_pair(a ~ x, b ~ x, rho12 = ~x))
  txt <- capture_msgs(print(tab))
  expect_match(txt, "residual correlation \\(rho12\\): 1 edge")
  expect_match(txt, "declaration only")
  expect_identical(tab$predictors, "x")
  expect_false(tab$constant)
  expect_true(is.na(tab$estimate))
})

test_that("rho12 on a drm_sem without live bivariate fits reports declared edges, or none", {
  sem <- structure(
    list(
      nodes = list(),
      covariances = data.frame(
        class = c("residual", "higher_level"), y1 = c("a", "a"), y2 = c("b", "b"),
        level = c(NA, "site"), stringsAsFactors = FALSE
      ),
      edges = data.frame(
        from = "x", to = "a", component = "rho12", term = "x", stringsAsFactors = FALSE
      )
    ),
    class = "drm_sem"
  )
  r <- rho12(sem)
  expect_s3_class(r, "drm_rho12")
  expect_identical(nrow(r), 1L) # only the residual declaration; the site-level one is a corpair
  expect_identical(c(r$y1, r$y2), c("a", "b"))
  expect_identical(r$predictors, "x")
  expect_false(r$constant)
  expect_match(attr(r, "note"), "declaration only")

  none <- structure(list(nodes = list(), covariances = NULL, edges = NULL), class = "drm_sem")
  rn <- rho12(none)
  expect_identical(nrow(rn), 0L)
  expect_s3_class(rn, "drm_rho12")
})

test_that("rho12 on a fitted pair with no rho12 coefficient table falls back to the declaration", {
  fit <- structure(list(), class = "drmTMB")
  testthat::local_mocked_bindings(
    drm_is_bivariate_fit = function(fit) TRUE,
    drm_biv_response_names = function(fit) c("a", "b"),
    drm_fit_rho12_coef = function(fit) data.frame(term = character(0)),
    drm_fit_component_predictors = function(fit, component) character(0),
    .package = "drmSEM"
  )
  sem <- structure(list(nodes = list(a = fit, b = fit), covariances = NULL, edges = NULL), class = "drm_sem")
  r <- rho12(sem)
  expect_identical(nrow(r), 1L)
  expect_true(r$constant)
  expect_true(is.na(r$estimate))
  expect_match(attr(r, "note"), "tanh")
})
