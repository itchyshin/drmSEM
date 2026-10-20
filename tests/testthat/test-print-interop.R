# Engine-free tests for the four print methods that had no assertion:
# print.drm_lavaan and print.drm_dot (cat() to stdout), print.drm_skeleton and
# print.drm_dag (cli text to the message stream). Each must show its key text
# and return its argument invisibly. Objects are built without fitting.

# cli text goes to the message stream, so capture messages and stdout together.
show <- function(expr) {
  expr <- substitute(expr)
  env <- parent.frame()
  msgs <- character()
  out <- utils::capture.output(
    msgs <- testthat::capture_messages(eval(expr, env))
  )
  paste(c(msgs, out), collapse = "\n")
}

# Print once, silently; check it is invisible and returns its input unchanged.
expect_prints_invisibly <- function(obj) {
  vis <- NULL
  utils::capture.output(suppressMessages(vis <- withVisible(print(obj))))
  expect_false(vis$visible)
  expect_identical(vis$value, obj)
}

dag_pi <- drm_dag(size ~ temp, abundance ~ size + temp)

test_that("print.drm_lavaan prints the syntax and returns invisibly", {
  local_reproducible_output()
  lav <- as_lavaan(dag_pi)
  expect_output(print(lav), "abundance ~ size + temp", fixed = TRUE)
  expect_output(print(lav), "size ~ temp", fixed = TRUE)
  expect_prints_invisibly(lav)
  # a from_lavaan() round trip is not needed: the text is the class payload
  expect_identical(
    paste(capture.output(print(lav)), collapse = "\n"),
    paste(unclass(lav), collapse = "\n")
  )
})

test_that("print.drm_dot prints a digraph and returns invisibly", {
  local_reproducible_output()
  dot <- as_dot(dag_pi)
  expect_output(print(dot), "digraph")
  expect_output(print(dot), "temp", fixed = TRUE)
  expect_prints_invisibly(dot)
})

test_that("print.drm_skeleton shows the regression branch", {
  local_reproducible_output()
  skel <- from_lavaan("a ~ b")
  expect_prints_invisibly(skel)
  res <- show(print(skel))
  expect_match(res, "drmSEM graph skeleton")
  expect_match(res, "1 node")
  expect_match(res, "0 covariance edges")
  expect_no_match(res, "no regression")
})

test_that("print.drm_skeleton shows the no-regression branch and covariances", {
  local_reproducible_output()
  skel <- from_lavaan("x ~~ y")
  expect_null(skel$dag)
  expect_prints_invisibly(skel)
  res <- show(print(skel))
  expect_match(res, "no regression (`~`) structure", fixed = TRUE)
  expect_match(res, "1 covariance edge ")
  expect_no_match(res, "nodes?:")
})

test_that("print.drm_dag lists nodes and formulas and returns invisibly", {
  local_reproducible_output()
  expect_prints_invisibly(dag_pi)
  res <- show(print(dag_pi))
  expect_match(res, "<drm_dag> 2 nodes")
  expect_match(res, "size: size ~ temp", fixed = TRUE)
  expect_match(res, "abundance: abundance ~ size + temp", fixed = TRUE)
})
