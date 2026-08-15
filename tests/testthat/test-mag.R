# DAG -> MAG conversion (marginalised latents only).
#
# Acceptance is a PRINTED claim set, not "the code runs". Shipley & Douma (2021)
# Figure 1 works two DAGs and prints the resulting MAGs and, for the first, the full
# before/after claim table. Those printed graphs are the gate.
#
# The rules implemented are Richardson & Spirtes (2002) §4.2.1 (orientation) and
# §4.2.3 / Thm 4.2(ii) (adjacency via inducing paths), obtained from the source and
# cross-verified before implementation rather than written from memory.
#
# V-112  S&D Fig 1 DAG (I) reproduces the printed MAG
# V-113  S&D Fig 1 DAG (III) reproduces the printed (saturated) MAG
# V-114  ancestors are taken in the ORIGINAL DAG -- the latent-chain trap
# V-115  degenerate inputs behave

# Pure graph logic: no engine, deterministic everywhere. Deliberate -- a mechanism
# belongs where it is deterministic; this whole file would be untrustworthy if it
# depended on an optimizer.

mag_of <- function(from, to, latent = character(0)) {
  m <- drmSEM:::drm_dag_to_mag(
    data.frame(from = from, to = to, stringsAsFactors = FALSE), latent = latent
  )
  sort(paste0(m$from, m$type, m$to))
}

test_that("V-112: S&D Fig 1 DAG (I) reproduces the printed MAG", {
  # A -> X <- L -> Y -> B, marginalising L. Printed MAG: A -> X <-> Y -> B.
  got <- mag_of(c("A", "L", "L", "Y"), c("X", "X", "Y", "B"), latent = "L")
  expect_setequal(got, c("A-->X", "X<->Y", "Y-->B"))
  # X <-> Y is the whole point: a latent COMMON CAUSE becomes a bidirected edge, not
  # a directed one, and not nothing.
  expect_true("X<->Y" %in% got)
})

test_that("V-113: S&D Fig 1 DAG (III) reproduces the printed saturated MAG", {
  # A->X, A->Y, X->Y, Y->B, L->X, L->B ; marginalising L. Printed: complete on
  # {A,X,Y,B}, with X->B and A->B added and oriented (not bidirected).
  got <- mag_of(
    c("A", "A", "X", "Y", "L", "L"), c("X", "Y", "Y", "B", "X", "B"), latent = "L"
  )
  expect_length(got, 6L)
  expect_setequal(got, c("A-->B", "A-->X", "A-->Y", "X-->B", "X-->Y", "Y-->B"))
})

test_that("V-114: ancestors are taken in the ORIGINAL DAG (the latent-chain trap)", {
  # A -> u -> B with u latent. The inducing path makes A and B adjacent; because A
  # IS an ancestor of B in the original graph, the edge is A -> B.
  #
  # Deleting the latent first and then asking for ancestors gives A <-> B: a
  # perfectly valid MAG, the WRONG one, and every independence claim built on it
  # inherits the error with nothing to catch it. This test is that trap.
  expect_setequal(mag_of(c("A", "U"), c("U", "B"), latent = "U"), "A-->B")
  # Contrast: a latent COMMON CAUSE, where neither is an ancestor of the other.
  expect_setequal(mag_of(c("U", "U"), c("A", "B"), latent = "U"), "A<->B")
})

test_that("V-114b: with no latents the MAG is the DAG", {
  got <- mag_of(c("A", "B"), c("B", "C"))
  expect_setequal(got, c("A-->B", "B-->C"))
  # A and C are NOT adjacent: the only path has B as a non-collider, and B is not
  # latent, so it is not an inducing path.
  expect_false(any(grepl("^A..C$", got)))
})

test_that("V-115: degenerate inputs behave", {
  # A latent name that is not in the graph is simply ignored.
  expect_setequal(mag_of("A", "B", latent = "nowhere"), "A-->B")
  # Marginalising everything observable leaves no pairs, hence no edges.
  out <- drmSEM:::drm_dag_to_mag(
    data.frame(from = "A", to = "B", stringsAsFactors = FALSE), latent = c("A", "B")
  )
  expect_identical(nrow(out), 0L)
  expect_named(out, c("from", "to", "type"))
})

test_that("V-115b: the undirected path helper does not collide with the directed one", {
  # R redefines silently and collation order decides the winner. An earlier draft of
  # R/mag.R reused the name drm_simple_paths() -- already defined in R/utils.R and
  # used by path_effects() -- so the MAG code silently got the DIRECTED version and
  # produced a graph missing most of its edges. The printed example caught it; this
  # asserts the two stay distinct.
  e <- data.frame(from = c("A", "L"), to = c("X", "X"), stringsAsFactors = FALSE)
  # Undirected: A and L are connected through the collider X.
  expect_length(drmSEM:::drm_undirected_paths("A", "L", e), 1L)
  # Directed: no directed path from A to L.
  expect_length(drmSEM:::drm_simple_paths("A", "L", e), 0L)
})
