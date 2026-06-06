#!/usr/bin/env Rscript
# =============================================================================
# OQ-6 calibration study generator for drmSEM (precomputed-vignette cache).
#
# Run this in the live-drmTMB lane:
#
#     Rscript inst/calibration/generate.R
#
# It fits the full grid with the real drmTMB engine, distils a data-only
# summary (p-values, df = augmented-component count, status, and the
# per-replicate Fisher's C p-value), stamps it with provenance, and writes
#
#     inst/calibration/calibration-results.rds
#
# which the precomputed vignettes/calibration.Rmd reads back. NOTHING here is
# ever evaluated by R CMD check; the .rds is regenerated only in the live lane.
#
# Relationship to the test suite: tests/testthat/test-calibration.R is the FAST
# 20-rep smoke check (V-17). It shares the SAME chain DGP defined below
# (deliberately duplicated, not refactored into a shared helper, so this script
# stays standalone and the test stays standalone). This file is the
# recovery/coverage-tier study; the smoke test is not.
# =============================================================================

if (!requireNamespace("drmTMB", quietly = TRUE)) {
  stop("inst/calibration/generate.R needs the drmTMB engine (github::itchyshin/drmTMB).")
}

suppressPackageStartupMessages({
  library(drmSEM)
})

# ----------------------------------------------------------------------------
# Study grid (OQ-6). Keep this the single source of truth: the display chunks
# in vignettes/calibration.Rmd mirror it for transparency.
# ----------------------------------------------------------------------------
GRID <- list(
  n      = c(100L, 250L, 500L, 1000L),
  beta   = c(0, 0.1, 0.2, 0.3, 0.5, 0.8),
  family = c("mean_only", "distributional", "cross_link"),
  reps   = 200L
)

# ----------------------------------------------------------------------------
# DGP families. Each returns a data.frame and a drm_sem whose basis set
# contains the x _||_ y | {m} claim. `beta` is the strength of the OMITTED
# x -> y edge: beta = 0 is the null (Type-I), beta > 0 is the alternative
# (power). The omitted edge enters a different distributional component per
# family, which is the whole point of the any-component d-sep test.
# ----------------------------------------------------------------------------

# Mean-only chain x -> m -> y, omitted x -> y acts on the MEAN of y.
# NOTE: this is the same chain DGP that tests/testthat/test-calibration.R uses
# as its fast smoke version (duplicated here on purpose; see header).
make_mean_only <- function(seed, beta, n) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.7 * x, 1)
  y <- stats::rnorm(n, beta * x + 0.7 * m, 1)
  dat <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = dat
  )
  list(sem = sem)
}

# Distributional chain: the omitted x -> y edge acts on a NON-MEAN component
# (here the log-sd / sigma of a gaussian; swap to zi for a zero-inflated count
# response). A mean-only refit would miss this; the any-component refit should
# not.
make_distributional <- function(seed, beta, n) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.7 * x, 1)
  log_sd <- 0.0 + beta * x          # x perturbs the SPREAD of y, not its mean
  y <- stats::rnorm(n, 0.7 * m, exp(log_sd))
  dat <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m, sigma ~ 1), family = stats::gaussian()),
    data = dat
  )
  list(sem = sem)
}

# Cross-link chain: the omitted edge acts on the mean of y while m itself is
# distributionally driven by x (x perturbs m's spread). Exercises an augmented
# refit where the conditioning node carries multiple components.
make_cross_link <- function(seed, beta, n) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.5 * x, exp(0.3 * x))
  y <- stats::rnorm(n, beta * x + 0.7 * m, 1)
  dat <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x, sigma ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = dat
  )
  list(sem = sem)
}

DGP <- list(
  mean_only      = make_mean_only,
  distributional = make_distributional,
  cross_link     = make_cross_link
)

# ----------------------------------------------------------------------------
# One replicate: build the SEM, run dsep(), pull the x _||_ y | {m} claim's
# p-value + df (= augmented-component count) + status, and the per-replicate
# Fisher's C p-value. Returns a one-row data.frame; never returns a fit.
# ----------------------------------------------------------------------------
run_one <- function(family, seed, beta, n) {
  built <- tryCatch(DGP[[family]](seed, beta, n), error = function(e) NULL)
  if (is.null(built)) {
    return(data.frame(
      family = family, n = n, beta = beta, seed = seed,
      claim_p = NA_real_, claim_df = NA_integer_, status = "build_failed",
      fisher_c_p = NA_real_, stringsAsFactors = FALSE
    ))
  }
  d <- tryCatch(dsep(built$sem), error = function(e) NULL)
  if (is.null(d)) {
    return(data.frame(
      family = family, n = n, beta = beta, seed = seed,
      claim_p = NA_real_, claim_df = NA_integer_, status = "dsep_failed",
      fisher_c_p = NA_real_, stringsAsFactors = FALSE
    ))
  }
  row <- d$x == "x" & d$y == "y"
  fc <- attr(d, "fisher_c")
  data.frame(
    family   = family,
    n        = n,
    beta     = beta,
    seed     = seed,
    claim_p  = if (any(row)) d$p.value[row][[1L]] else NA_real_,
    claim_df = if (any(row)) as.integer(d$df[row][[1L]]) else NA_integer_,
    status   = if (any(row)) d$status[row][[1L]] else "claim_absent",
    fisher_c_p = if (!is.null(fc)) fc$p.value else NA_real_,
    stringsAsFactors = FALSE
  )
}

# ----------------------------------------------------------------------------
# Full grid sweep: family x n x beta x reps. Seeds are deterministic per cell
# so the cache is reproducible.
# ----------------------------------------------------------------------------
message("drmSEM OQ-6 calibration: ",
        length(GRID$family), " families x ", length(GRID$n), " n x ",
        length(GRID$beta), " beta x ", GRID$reps, " reps = ",
        length(GRID$family) * length(GRID$n) * length(GRID$beta) * GRID$reps,
        " fits.")

results <- list()
k <- 0L
for (family in GRID$family) {
  for (n in GRID$n) {
    for (beta in GRID$beta) {
      for (r in seq_len(GRID$reps)) {
        # Stable, collision-free seed across the whole grid.
        seed <- as.integer(
          1e6 * match(family, GRID$family) +
          1e4 * match(n, GRID$n) +
          1e2 * match(beta, GRID$beta) +
          r
        )
        k <- k + 1L
        results[[k]] <- run_one(family, seed, beta, n)
      }
    }
  }
  message("  done family: ", family)
}

per_rep <- do.call(rbind, results)
rownames(per_rep) <- NULL

# ----------------------------------------------------------------------------
# Distil a compact data-only summary. Type-I is the rejection rate at beta == 0;
# power is the rejection rate at beta > 0. Stratify Type-I by claim_df, the
# augmented-component count (the centerpiece OQ-6 diagnostic).
# ----------------------------------------------------------------------------
alpha <- 0.05
ok <- per_rep[per_rep$status == "ok" & is.finite(per_rep$claim_p), , drop = FALSE]

agg <- function(df, by) {
  out <- aggregate(
    list(reject = df$claim_p < alpha),
    by = by,
    FUN = function(z) mean(z, na.rm = TRUE)
  )
  n_out <- aggregate(list(n_rep = df$claim_p), by = by, FUN = length)
  merge(out, n_out, by = names(by))
}

type1 <- agg(
  ok[ok$beta == 0, , drop = FALSE],
  by = list(family = ok$family[ok$beta == 0], n = ok$n[ok$beta == 0])
)
type1_by_df <- {
  sub <- ok[ok$beta == 0, , drop = FALSE]
  agg(sub, by = list(family = sub$family, claim_df = sub$claim_df))
}
power <- agg(
  ok[ok$beta > 0, , drop = FALSE],
  by = list(
    family = ok$family[ok$beta > 0],
    n      = ok$n[ok$beta > 0],
    beta   = ok$beta[ok$beta > 0]
  )
)

# Per-replicate Fisher's C p-values for the uniformity/QQ plot (nulls only:
# beta == 0, where the DAG is correctly specified).
fisher_c_null_p <- per_rep$fisher_c_p[per_rep$beta == 0 & is.finite(per_rep$fisher_c_p)]

git_sha <- tryCatch(
  {
    s <- system2("git", c("rev-parse", "--short", "HEAD"),
                 stdout = TRUE, stderr = FALSE)
    if (length(s)) s[[1L]] else NA_character_
  },
  error = function(e) NA_character_
)

meta <- list(
  generated_at  = format(Sys.time(), tz = "UTC", usetz = TRUE),
  date          = as.character(Sys.Date()),
  drmTMB_version = as.character(utils::packageVersion("drmTMB")),
  drmSEM_version = as.character(utils::packageVersion("drmSEM")),
  R_version     = R.version.string,
  git_sha       = git_sha,
  reps          = GRID$reps,
  alpha         = alpha,
  grid          = GRID
)

cal <- list(
  meta            = meta,
  per_rep         = per_rep,
  type1           = type1,
  type1_by_df     = type1_by_df,
  power           = power,
  fisher_c_null_p = fisher_c_null_p
)

out_path <- file.path("inst", "calibration", "calibration-results.rds")
saveRDS(cal, out_path)
message("Wrote ", out_path, " (drmTMB ", meta$drmTMB_version,
        ", sha ", meta$git_sha, ").")
