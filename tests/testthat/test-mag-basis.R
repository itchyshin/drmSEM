# MAG anterior helpers and Cor. 5.3 basis set (marginalised latents).
#
# Shipley & Douma (2021) Fig 1 DAG (I): A -> X <- L -> Y -> B with L marginalised.
# Printed MAG: A -> X <-> Y -> B. Richardson & Spirtes (2002) Cor. 5.3 conditions on
# anteriors in the MAG, not parents on the collapsed DAG. Bidirected spouses are
# not anteriors: walking <-> would emit the false claim A _||_ Y | {X} (conditioning
# on the collider X opens A -> X <-> Y).
#
# V-117  S&D Fig 1 DAG (I) MAG basis claims match Cor. 5.3 anterior conditioning

sd_dag_I_edges <- function() {
  data.frame(
    from = c("A", "L", "L", "Y"),
    to = c("X", "X", "Y", "B"),
    stringsAsFactors = FALSE
  )
}

sd_mag_I <- function() {
  drmSEM:::drm_dag_to_mag(sd_dag_I_edges(), latent = "L")
}

sd_sem_I <- function() {
  # B is endogenous (Y -> B). Treating it as exogenous would drop A _||_ B | {Y}
  # and swap the X-B claim labels.
  structure(
    list(
      order = c("X", "Y", "B"),
      endogenous = c("X", "Y", "B"),
      exogenous = "A",
      latents = "L",
      mag = sd_mag_I(),
      covariances = NULL,
      records = list(
        X = list(family = "gaussian", components = "mu"),
        Y = list(family = "gaussian", components = "mu"),
        B = list(family = "gaussian", components = "mu")
      )
    ),
    class = "drm_sem"
  )
}

test_that("MAG adjacency on S&D Fig 1 DAG (I)", {
  mag <- sd_mag_I()
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "A", "X"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "X", "Y"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "Y", "B"))
  expect_false(drmSEM:::drm_mag_is_adjacent(mag, "A", "Y"))
  expect_false(drmSEM:::drm_mag_is_adjacent(mag, "X", "B"))
  expect_false(drmSEM:::drm_mag_is_adjacent(mag, "A", "B"))
})

test_that("MAG anterior conditioning on S&D Fig 1 DAG (I)", {
  mag <- sd_mag_I()
  # A --> X <-> Y: ant({A,Y}) \\ {A,Y} is empty. X is a spouse of Y, not anterior.
  expect_setequal(drmSEM:::drm_mag_anteriors(mag, "A", "Y"), character(0))
  expect_setequal(drmSEM:::drm_mag_anteriors(mag, "X", "B"), c("A", "Y"))
  # Reflexive anterior sets include the vertex itself.
  expect_true("X" %in% drmSEM:::drm_mag_anterior_of("X", mag))
  expect_true("A" %in% drmSEM:::drm_mag_anterior_of("X", mag))
  expect_false("A" %in% drmSEM:::drm_mag_anterior_of("Y", mag))
})

test_that("V-117: basis_set_mag matches S&D Fig 1 DAG (I) m-sep claims", {
  bs <- drmSEM:::basis_set_mag(sd_sem_I())
  claims <- bs$claim
  # A and Y are non-adjacent; ant({A,Y}) \\ {A,Y} = empty (not {X}).
  expect_true("A _||_ Y | {}" %in% claims)
  expect_false("A _||_ Y | {X}" %in% claims)
  # A and B are non-adjacent; ant({A,B}) \\ {A,B} = {Y}.
  expect_true("A _||_ B | {Y}" %in% claims)
  # X and B are non-adjacent; ant({X,B}) \\ {X,B} = {A, Y}. B is later, so the
  # basis-set loop emits X as x and B as y.
  expect_true("X _||_ B | {A, Y}" %in% claims)
  expect_false("B _||_ X | {A, Y}" %in% claims)
  # Adjacent MAG pairs must not appear.
  expect_false(any(grepl("A _\\|\\|_ X", claims)))
  expect_false(any(grepl("X _\\|\\|_ Y", claims)))
  expect_false(any(grepl("Y _\\|\\|_ B", claims)))
})

test_that("basis_set routes latent SEMs to the MAG basis set", {
  bs <- basis_set(sd_sem_I())
  expect_true("A _||_ Y | {}" %in% bs$claim)
  expect_true("A _||_ B | {Y}" %in% bs$claim)
  expect_true("X _||_ B | {A, Y}" %in% bs$claim)
})

test_that("compositionality inform is silent for homoscedastic Gaussian nodes", {
  expect_silent(basis_set(sd_sem_I()))
})

test_that("compositionality inform fires for sigma or non-Gaussian nodes", {
  sem_sigma <- sd_sem_I()
  sem_sigma$records$X$components <- c("mu", "sigma")
  expect_message(basis_set(sem_sigma), "compositional graphoid")

  sem_nb <- sd_sem_I()
  sem_nb$records$Y$family <- "nbinom2"
  expect_message(basis_set(sem_nb), "compositional graphoid")
})

test_that("MAG basis set enumerates observed vertices only", {
  sem <- structure(
    list(
      order = c("x", "y"),
      endogenous = c("x", "y"),
      exogenous = "L",
      latents = "L",
      mag = drmSEM:::drm_dag_to_mag(
        data.frame(from = c("L", "L"), to = c("x", "y"), stringsAsFactors = FALSE),
        latent = "L"
      ),
      covariances = NULL,
      records = list(
        x = list(family = "gaussian", components = "mu"),
        y = list(family = "gaussian", components = "mu")
      )
    ),
    class = "drm_sem"
  )
  bs <- drmSEM:::basis_set_mag(sem)
  expect_false(any(bs$x == "L" | bs$y == "L"))
  expect_false(any((bs$x == "x" & bs$y == "y") | (bs$x == "y" & bs$y == "x")))
})
