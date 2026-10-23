# Input-validation behaviour of the exported constructors drm_node(), drm_sem()
# and drm_psem(), plus the print methods of drm_node / drm_paths /
# drm_standardized_paths. These pin the CURRENT messages; they do not change any
# behaviour.
#
# Reachability notes (read off R/drm_sem.R and R/pair.R):
# * "All nodes must be named." and "Node names must be unique." in new_drm_sem()
#   cannot be reached through drm_sem()/drm_psem(): drm_unpack_sem_specs() and
#   drm_expand_psem_fits() reject unnamed and duplicated nodes first (with their own
#   messages). They are pinned here by calling the internal constructor directly.
# * The second "Supply at least one drm_node() or drm_pair()" site in drm_sem()
#   (after unpacking) is unreachable: every spec either becomes a node or aborts.

# --- drm_sem() argument checks (no engine needed) ---------------------------

test_that("drm_sem() requires data", {
  expect_error(drm_sem(1), "is required for")
})

test_that("drm_sem() requires at least one node or pair", {
  expect_error(
    drm_sem(data = data.frame(x = 1)),
    "Supply at least one"
  )
})

test_that("drm_sem() rejects specs that are neither drm_node nor drm_pair", {
  expect_error(
    drm_sem(y = 1, data = data.frame(x = 1)),
    "expects.*drm_node.*or.*drm_pair"
  )
})

# --- new_drm_sem() internal guards (unreachable via the public API) ---------

test_that("new_drm_sem() rejects an empty, unnamed, or duplicated node list", {
  expect_error(
    drmSEM:::new_drm_sem(list(), data = data.frame(x = 1), call = NULL),
    "needs at least one endogenous node"
  )
  expect_error(
    drmSEM:::new_drm_sem(list(1), data = data.frame(x = 1), call = NULL),
    "All nodes must be named"
  )
  expect_error(
    drmSEM:::new_drm_sem(
      list(a = 1, a = 2),
      data = data.frame(x = 1),
      call = NULL
    ),
    "Node names must be unique"
  )
})

# --- drm_psem() ---------------------------------------------------------------

test_that("drm_psem() with no fits aborts with the endogenous-node message", {
  expect_error(
    drm_psem(data = data.frame(x = 1)),
    "needs at least one endogenous node"
  )
})

test_that("drm_psem() rejects non-drmTMB input and points at drm_sem()", {
  expect_error(drm_psem(y = 1, data = data.frame(x = 1)), "expects fitted")
})

# --- drm_node() ---------------------------------------------------------------

test_that("drm_node() rejects input that is not a formula or drm_formula", {
  expect_error(drm_node(1), "must be a")
  expect_error(drm_node("y ~ x"), "must be a")
})

test_that("drm_node() reports a missing drmTMB when given a plain formula", {
  testthat::local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(drm_node(y ~ x), "needs.*drmTMB.*to wrap it")
})

# --- engine-dependent: node fit failure and print methods ------------------

test_that("drm_sem() names the node whose fit fails", {
  skip_on_cran()
  skip_if_not_installed("drmTMB")
  d <- data.frame(x = stats::rnorm(20))
  expect_error(
    drm_sem(
      y = drm_node(drmTMB::bf(not_a_column ~ x)),
      data = d
    ),
    "failed to fit"
  )
})

test_that("print methods for drm_node, drm_paths and standardized paths", {
  skip_on_cran()
  skip_if_not_installed("drmTMB")
  set.seed(71)
  n <- 200
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.6 * m + 0.3 * x + stats::rnorm(n)
  d <- data.frame(x = x, m = m, y = y)

  node <- drm_node(drmTMB::bf(m ~ x), family = stats::gaussian())
  # cli routes text to messages; print(<drm_formula>) may use either stream, so
  # assert on both streams together.
  both <- function(expr) {
    msgs <- character()
    out <- withCallingHandlers(
      utils::capture.output(expr),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    paste(c(msgs, out), collapse = "\n")
  }
  txt <- both(print(node))
  expect_match(txt, "<drm_node> family", fixed = TRUE)
  expect_match(txt, "m ~ x", fixed = TRUE)
  expect_identical(suppressMessages(invisible(print(node))), node)

  sem <- drm_sem(
    m = node,
    y = drm_node(drmTMB::bf(y ~ m + x), family = stats::gaussian()),
    data = d
  )

  p <- paths(sem)
  expect_s3_class(p, "drm_paths")
  txt_p <- both(print(p))
  expect_match(txt_p, "3 component-labelled coefficients", fixed = TRUE)
  expect_match(txt_p, "estimate", fixed = TRUE)

  sp <- standardize(sem)
  expect_s3_class(sp, "drm_standardized_paths")
  expect_output(print(sp), "drmSEM standardized paths")
  expect_output(print(sp), "3 component-labelled coefficients", fixed = TRUE)
  utils::capture.output(res <- print(sp))
  expect_identical(res, sp)
})
