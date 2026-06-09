# Graph-interchange (interop) layer. Everything here is pure string / graph
# logic, so it runs without drmTMB: we build edge tables / drm_dag()s by hand
# (or parse literal lavaan strings) and never fit a model. The load-bearing
# claim under test is the honesty rule -- a non-mu component path is NEVER
# emitted as a lavaan mean (`~`) regression; it is dropped-with-notice.

# A drm_sem stub carrying only the slots the interop layer reads.
make_interop_sem <- function(
  edges,
  covariances = NULL,
  order = NULL,
  endogenous = NULL,
  exogenous = NULL
) {
  if (is.null(order)) {
    order <- unique(edges$to)
  }
  if (is.null(endogenous)) {
    endogenous <- unique(edges$to)
  }
  if (is.null(exogenous)) {
    exogenous <- setdiff(unique(edges$from), endogenous)
  }
  structure(
    list(
      edges = edges,
      covariances = covariances,
      order = order,
      endogenous = endogenous,
      exogenous = exogenous
    ),
    class = "drm_sem"
  )
}

mu_edge <- function(from, to) {
  data.frame(
    from = from,
    to = to,
    component = "mu",
    link = "identity",
    term = from,
    endogenous = FALSE,
    stringsAsFactors = FALSE
  )
}

# ---- as_lavaan(): mean structure + covariances ------------------------------

test_that("as_lavaan emits one regression per node and a ~~ line per covariance", {
  edges <- rbind(
    mu_edge("temp", "size"),
    mu_edge("size", "abundance"),
    mu_edge("temp", "abundance")
  )
  cov_df <- data.frame(
    y1 = "size",
    y2 = "abundance",
    class = "residual",
    level = NA_character_,
    structure = "unstructured",
    label = "rho12(size, abundance)",
    stringsAsFactors = FALSE
  )
  sem <- make_interop_sem(
    edges,
    covariances = cov_df,
    order = c("size", "abundance")
  )
  lav <- as_lavaan(sem)
  expect_s3_class(lav, "drm_lavaan")
  txt <- unclass(lav)
  expect_match(txt, "size ~ temp", fixed = TRUE)
  expect_match(txt, "abundance ~ size + temp", fixed = TRUE)
  expect_match(txt, "size ~~ abundance", fixed = TRUE)
  # nothing was dropped: all paths are mean paths
  expect_identical(attr(lav, "dropped"), character(0))
})

test_that("as_lavaan drops non-mu component paths with an explicit notice (honesty)", {
  edges <- rbind(
    mu_edge("temp", "size"),
    data.frame(
      from = "habitat",
      to = "size",
      component = "sigma",
      link = "log",
      term = "habitat",
      endogenous = FALSE,
      stringsAsFactors = FALSE
    )
  )
  sem <- make_interop_sem(edges, order = "size")
  # the message fires once and names the dropped distributional path
  expect_message(lav <- as_lavaan(sem), "cannot be expressed")
  txt <- unclass(lav)
  # the sigma path is NOT smuggled into the mean regression
  expect_match(txt, "size ~ temp", fixed = TRUE)
  expect_false(grepl("habitat", txt, fixed = TRUE))
  expect_identical(attr(lav, "dropped"), "habitat -> sigma of size")
})

test_that("as_lavaan works on an unfitted drm_dag", {
  dag <- drm_dag(size ~ temp, abundance ~ size + temp)
  lav <- as_lavaan(dag)
  txt <- unclass(lav)
  expect_match(txt, "size ~ temp", fixed = TRUE)
  expect_match(txt, "abundance ~ size + temp", fixed = TRUE)
})

# ---- from_lavaan(): parse syntax into a graph skeleton ----------------------

test_that("from_lavaan parses ~ into a drm_dag and ~~ into covary()", {
  skel <- from_lavaan("abundance ~ size + temp\nsize ~ temp\nsize ~~ abundance")
  expect_s3_class(skel, "drm_skeleton")
  expect_s3_class(skel$dag, "drm_dag")
  expect_setequal(skel$dag$responses, c("abundance", "size"))
  expect_length(skel$covary, 1L)
  expect_s3_class(skel$covary[[1L]], "drm_covary")
  expect_identical(
    sort(c(skel$covary[[1L]]$y1, skel$covary[[1L]]$y2)),
    c("abundance", "size")
  )
})

test_that("from_lavaan strips fixed-coefficient prefixes and intercept/variance lines", {
  skel <- from_lavaan("y ~ 1 + 0.5*x + z\ny ~~ y")
  expect_setequal(skel$dag$responses, "y")
  # `0.5*x` -> `x`; intercept `1` dropped; the y~~y variance line is not a cov edge
  rhs <- all.vars(skel$dag$formulas[["y"]])
  expect_true(all(c("x", "z") %in% rhs))
  expect_length(skel$covary, 0L)
})

test_that("from_lavaan warns on reflective measurement (=~) and ignores it", {
  expect_warning(
    skel <- from_lavaan("f =~ x1 + x2 + x3\ny ~ f"),
    "reflective measurement"
  )
  # the =~ line is dropped; only the regression survives
  expect_setequal(skel$dag$responses, "y")
})

test_that("from_lavaan rejects non-string input", {
  expect_error(from_lavaan(42), "single lavaan")
  expect_error(from_lavaan(c("a ~ b", "c ~ d")), "single lavaan")
})

# ---- round-trip: from_lavaan(as_lavaan(sem)) recovers the structure ---------

test_that("round-trip recovers directed mean structure and covariances", {
  edges <- rbind(
    mu_edge("temp", "size"),
    mu_edge("size", "abundance"),
    mu_edge("temp", "abundance")
  )
  cov_df <- data.frame(
    y1 = "size",
    y2 = "abundance",
    class = "residual",
    level = NA_character_,
    structure = "unstructured",
    label = "rho12(size, abundance)",
    stringsAsFactors = FALSE
  )
  sem <- make_interop_sem(
    edges,
    covariances = cov_df,
    order = c("size", "abundance")
  )

  back <- from_lavaan(unclass(as_lavaan(sem)))

  # directed structure: same responses and same parent sets
  expect_setequal(back$dag$responses, c("size", "abundance"))
  expect_setequal(all.vars(back$dag$formulas[["size"]]), c("size", "temp"))
  expect_setequal(
    all.vars(back$dag$formulas[["abundance"]]),
    c("abundance", "size", "temp")
  )
  # covariance edge recovered
  expect_length(back$covary, 1L)
  expect_setequal(
    c(back$covary[[1L]]$y1, back$covary[[1L]]$y2),
    c("size", "abundance")
  )
})

test_that("round-trip on a drm_dag recovers the directed edges", {
  dag <- drm_dag(size ~ temp, abundance ~ size + temp)
  back <- from_lavaan(unclass(as_lavaan(dag)))
  expect_setequal(back$dag$responses, c("size", "abundance"))
  expect_setequal(
    all.vars(back$dag$formulas[["abundance"]]),
    c("abundance", "size", "temp")
  )
})

# ---- as_dot(): component-labelled DOT export --------------------------------

test_that("as_dot emits one labelled edge per typed edge, keeping non-mu paths", {
  edges <- rbind(
    mu_edge("temp", "size"),
    data.frame(
      from = "habitat",
      to = "size",
      component = "sigma",
      link = "log",
      term = "habitat",
      endogenous = FALSE,
      stringsAsFactors = FALSE
    )
  )
  sem <- make_interop_sem(edges, order = "size")
  dot <- as_dot(sem)
  expect_s3_class(dot, "drm_dot")
  txt <- unclass(dot)
  expect_match(txt, "digraph drmSEM", fixed = TRUE)
  expect_match(txt, '"temp" -> "size" [label="mu"]', fixed = TRUE)
  # the sigma path is KEPT (unlike lavaan), labelled and dashed
  expect_match(txt, '"habitat" -> "size"', fixed = TRUE)
  expect_match(txt, 'label="sigma"', fixed = TRUE)
  expect_match(txt, "style=dashed", fixed = TRUE)
})

test_that("as_dot works on a drm_dag including a distributional component", {
  dag <- drm_dag(size ~ temp, abundance ~ size)
  dot <- as_dot(dag)
  txt <- unclass(dot)
  expect_match(txt, '"temp" -> "size"', fixed = TRUE)
  expect_match(txt, '"size" -> "abundance"', fixed = TRUE)
})

# ---- internal helpers -------------------------------------------------------

test_that("drm_lavaan_rhs_tokens strips numeric/label prefixes", {
  expect_setequal(
    drmSEM:::drm_lavaan_rhs_tokens("a + 0.5*b + lab*c"),
    c("a", "b", "c")
  )
  expect_identical(drmSEM:::drm_lavaan_rhs_tokens("1"), character(0))
})
