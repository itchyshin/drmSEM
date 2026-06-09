#!/usr/bin/env Rscript
# =============================================================================
# Wave-2 validation-study generator for drmSEM (precomputed-vignette cache).
#
# Run this in the live-drmTMB lane:
#
#     Rscript inst/validation/generate.R
#
# It fits the wave-2 grids with the real drmTMB engine, distils data-only
# summaries (coverage rates, selection rates, mean weights), stamps them with
# provenance, and writes
#
#     inst/validation/validation-results.rds
#
# which the precomputed vignettes/validation.Rmd reads back. NOTHING here is
# ever evaluated by R CMD check; the .rds is regenerated only in the live lane.
#
# Studies implemented here (see docs/design/12-coverage-calibration.md):
#   C-1  effect-interval coverage         -> `coverage`
#   C-3  model-selection recovery rate     -> `model_selection`
#
# C-2 (d-sep beyond the OQ-6 grid) is the calibration study in
# inst/calibration/generate.R; C-4 (sampler dispersion vs drmTMB::simulate) is
# the standalone probe inst/validation/sampler-dispersion-probe.R. Neither is
# reimplemented here.
#
# This is the recovery/coverage-tier study; the bounded CI smoke that checks
# the same coverage/selection LOGIC on a tiny deterministic case lives in the
# test suite and is not calibration evidence.
# =============================================================================

if (!requireNamespace("drmTMB", quietly = TRUE)) {
  stop(
    "inst/validation/generate.R needs the drmTMB engine (github::itchyshin/drmTMB)."
  )
}

suppressPackageStartupMessages({
  if (
    requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")
  ) {
    pkgload::load_all(".", export_all = FALSE, helpers = FALSE, quiet = TRUE)
  } else {
    library(drmSEM)
  }
})

drmSEM_source_version <- function() {
  if (file.exists("DESCRIPTION")) {
    version <- tryCatch(
      utils::read.dcf("DESCRIPTION", fields = "Version")[[1L]],
      error = function(e) NA_character_
    )
    if (!is.na(version) && nzchar(version)) {
      return(version)
    }
  }
  as.character(utils::packageVersion("drmSEM"))
}

# ----------------------------------------------------------------------------
# Study grid. Keep this the single source of truth: the display chunks in
# vignettes/validation.Rmd mirror it for transparency.
# ----------------------------------------------------------------------------
SEED <- 20260607L
GRID <- list(
  R = 300L, # replicate datasets per cell
  n_grid = c(300L, 1000L), # sample sizes
  B = 400L, # parametric-bootstrap draws per fit
  level = 0.95 # nominal CI level
)

# ----------------------------------------------------------------------------
# C-1 DGP. A linear identity-link Gaussian chain with a direct x -> y edge:
#
#     m = b_xm * x + e_m,   e_m ~ N(0, s_m^2)
#     y = b_xy * x + b_my * m + e_y,   e_y ~ N(0, s_y^2)
#
# The contrast is a one-sd-of-x shift, so the KNOWN TRUE effects (in response
# units of y, per sd(x)) are closed-form products of the data-generating
# coefficients times the contrast width sd(x):
#
#     indirect (mean-mediated) = b_xm * b_my * sd(x)
#     direct                   = b_xy        * sd(x)
#     total                    = (b_xy + b_xm * b_my) * sd(x)
#
# The chain is homoscedastic, so the distribution-mediated leg is ~0 and the
# mean-mediated indirect equals the total path minus the direct.
# ----------------------------------------------------------------------------
C1 <- list(
  b_xm = 0.6,
  b_my = 0.5,
  b_xy = 0.3,
  s_m = 1.0,
  s_y = 1.0
)

make_c1 <- function(seed, n) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, C1$b_xm * x, C1$s_m)
  y <- stats::rnorm(n, C1$b_xy * x + C1$b_my * m, C1$s_y)
  dat <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ x + m), family = stats::gaussian()),
    data = dat
  )
  list(sem = sem, sd_x = stats::sd(x))
}

# Known truth as a function of the realized sd(x): the contrast width is the
# per-replicate sd(x), so truth is rescaled per replicate.
c1_truth <- function(sd_x) {
  c(
    total = (C1$b_xy + C1$b_xm * C1$b_my) * sd_x,
    direct = C1$b_xy * sd_x,
    indirect = C1$b_xm * C1$b_my * sd_x
  )
}

# One C-1 replicate: fit, pull total + the controlled decomposition, and record
# whether each CI brackets the known truth. Returns one row per quantity.
run_c1 <- function(seed, n, B, level) {
  empty <- function(status) {
    data.frame(
      n = n,
      seed = seed,
      quantity = c("total", "direct", "indirect"),
      truth = NA_real_,
      estimate = NA_real_,
      conf.low = NA_real_,
      conf.high = NA_real_,
      covered = NA,
      width = NA_real_,
      status = status,
      stringsAsFactors = FALSE
    )
  }
  built <- tryCatch(suppressMessages(make_c1(seed, n)), error = function(e) {
    NULL
  })
  if (is.null(built)) {
    return(empty("build_failed"))
  }

  tot <- tryCatch(
    suppressMessages(total_effects(
      built$sem,
      from = "x",
      to = "y",
      method = "simulate",
      uncertainty = "parametric",
      B = B,
      level = level,
      seed = seed
    )),
    error = function(e) NULL
  )
  dec <- tryCatch(
    suppressMessages(indirect_effects(
      built$sem,
      from = "x",
      to = "y",
      effect = "controlled",
      uncertainty = "parametric",
      B = B,
      level = level,
      seed = seed
    )),
    error = function(e) NULL
  )
  if (is.null(tot) || is.null(dec)) {
    return(empty("fit_failed"))
  }

  truth <- c1_truth(built$sd_x)

  pick <- function(df, col, value) df[df[[col]] == value, , drop = FALSE][1L, ]
  total_row <- tot[1L, ]
  direct_row <- pick(dec, "quantity", "direct")
  indirect_row <- pick(dec, "quantity", "indirect")

  rows <- rbind(
    data.frame(
      quantity = "total",
      estimate = total_row$estimate,
      conf.low = total_row$conf.low,
      conf.high = total_row$conf.high
    ),
    data.frame(
      quantity = "direct",
      estimate = direct_row$estimate,
      conf.low = direct_row$conf.low,
      conf.high = direct_row$conf.high
    ),
    data.frame(
      quantity = "indirect",
      estimate = indirect_row$estimate,
      conf.low = indirect_row$conf.low,
      conf.high = indirect_row$conf.high
    )
  )
  rows$truth <- truth[rows$quantity]
  rows$covered <- rows$conf.low <= rows$truth & rows$truth <= rows$conf.high
  rows$width <- rows$conf.high - rows$conf.low

  data.frame(
    n = n,
    seed = seed,
    quantity = rows$quantity,
    truth = rows$truth,
    estimate = rows$estimate,
    conf.low = rows$conf.low,
    conf.high = rows$conf.high,
    covered = rows$covered,
    width = rows$width,
    status = "ok",
    stringsAsFactors = FALSE
  )
}

# ----------------------------------------------------------------------------
# C-3 DGP + candidate set. The truth is the chain x -> m -> y with a direct
# x -> y edge OMITTED (so the basis claim x _||_ y | {m} is true). The three
# candidates are:
#   truth        : x -> m, m -> y           (the data-generating DAG)
#   overfit      : x -> m, {x, m} -> y       (adds a spurious x -> y edge)
#   missing_edge : x -> m, m -> y, but y NOT regressed on m (under-fits, leaving
#                  the true m -> y arrow out so its d-sep claim is violated)
# Over replicates we record best()'s selection and the model weight on truth.
# ----------------------------------------------------------------------------
C3 <- list(b_xm = 0.6, b_my = 0.6)

make_c3_data <- function(seed, n) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, C3$b_xm * x, 1)
  y <- stats::rnorm(n, C3$b_my * m, 1)
  data.frame(x = x, m = m, y = y)
}

c3_model_set <- function() {
  drm_model_set(
    truth = drm_dag(m ~ x, y ~ m),
    overfit = drm_dag(m ~ x, y ~ x + m),
    missing_edge = drm_dag(m ~ x, y ~ x)
  )
}

run_c3 <- function(seed, n) {
  empty <- function(status) {
    data.frame(
      n = n,
      seed = seed,
      criterion = c("CICc", "CBIC"),
      selected = NA_character_,
      selected_truth = NA,
      truth_weight = NA_real_,
      status = status,
      stringsAsFactors = FALSE
    )
  }
  dat <- tryCatch(make_c3_data(seed, n), error = function(e) NULL)
  if (is.null(dat)) {
    return(empty("build_failed"))
  }
  cmp <- tryCatch(
    suppressMessages(compare(
      c3_model_set(),
      data = dat,
      family = list(m = stats::gaussian(), y = stats::gaussian())
    )),
    error = function(e) NULL
  )
  if (is.null(cmp)) {
    return(empty("compare_failed"))
  }

  result_for <- function(criterion) {
    weight_col <- paste0("w", criterion)
    selected <- cmp$model[[which.min(cmp[[criterion]])]]
    truth_weight <- {
      w <- cmp[[weight_col]][cmp$model == "truth"]
      if (length(w)) w[[1L]] else NA_real_
    }
    data.frame(
      n = n,
      seed = seed,
      criterion = criterion,
      selected = selected,
      selected_truth = identical(selected, "truth"),
      truth_weight = truth_weight,
      status = "ok",
      stringsAsFactors = FALSE
    )
  }
  rbind(result_for("CICc"), result_for("CBIC"))
}

# ----------------------------------------------------------------------------
# C-1 sweep: n x R. Seeds are deterministic so the cache is reproducible.
# ----------------------------------------------------------------------------
message(
  "drmSEM wave-2 C-1 coverage: ",
  length(GRID$n_grid),
  " n x ",
  GRID$R,
  " reps = ",
  length(GRID$n_grid) * GRID$R,
  " fits (B = ",
  GRID$B,
  ")."
)

c1_rows <- list()
k <- 0L
for (n in GRID$n_grid) {
  for (r in seq_len(GRID$R)) {
    seed <- as.integer(SEED + 1e4 * match(n, GRID$n_grid) + r)
    k <- k + 1L
    c1_rows[[k]] <- run_c1(seed, n, GRID$B, GRID$level)
  }
  message("  done C-1 n = ", n)
}
c1_per_rep <- do.call(rbind, c1_rows)
rownames(c1_per_rep) <- NULL

# ----------------------------------------------------------------------------
# C-3 sweep: n x R.
# ----------------------------------------------------------------------------
message(
  "drmSEM wave-2 C-3 model selection: ",
  length(GRID$n_grid),
  " n x ",
  GRID$R,
  " reps = ",
  length(GRID$n_grid) * GRID$R,
  " comparisons."
)

c3_rows <- list()
k <- 0L
for (n in GRID$n_grid) {
  for (r in seq_len(GRID$R)) {
    seed <- as.integer(SEED + 2e5 + 1e4 * match(n, GRID$n_grid) + r)
    k <- k + 1L
    c3_rows[[k]] <- run_c3(seed, n)
  }
  message("  done C-3 n = ", n)
}
c3_per_rep <- do.call(rbind, c3_rows)
rownames(c3_per_rep) <- NULL

# ----------------------------------------------------------------------------
# C-1 distillation: empirical coverage per (n, quantity), with a Monte-Carlo
# acceptance band of nominal +/- 2*SE (SE of a binomial coverage proportion).
# ----------------------------------------------------------------------------
ok1 <- c1_per_rep[
  c1_per_rep$status == "ok" & !is.na(c1_per_rep$covered),
  ,
  drop = FALSE
]

coverage <- {
  by <- list(n = ok1$n, quantity = ok1$quantity)
  cov_rate <- aggregate(list(coverage = ok1$covered), by = by, FUN = mean)
  n_rep <- aggregate(list(n_rep = ok1$covered), by = by, FUN = length)
  width <- aggregate(list(mean_width = ok1$width), by = by, FUN = mean)
  out <- merge(
    merge(cov_rate, n_rep, by = c("n", "quantity")),
    width,
    by = c("n", "quantity")
  )
  out
}
coverage$se <- sqrt(GRID$level * (1 - GRID$level) / coverage$n_rep)
coverage$mc_lower <- GRID$level - 2 * coverage$se
coverage$mc_upper <- GRID$level + 2 * coverage$se
coverage$acceptance <- coverage$coverage >= coverage$mc_lower &
  coverage$coverage <= coverage$mc_upper
coverage <- coverage[order(coverage$quantity, coverage$n), , drop = FALSE]
rownames(coverage) <- NULL

# ----------------------------------------------------------------------------
# C-3 distillation: selection rate of the truth + mean criterion weight on
# truth, per criterion and n. Acceptance: selection rate is high (>= 0.80) and
# the missing-edge rival is essentially never selected.
# ----------------------------------------------------------------------------
ok3 <- c3_per_rep[
  c3_per_rep$status == "ok" & !is.na(c3_per_rep$selected_truth),
  ,
  drop = FALSE
]

model_selection <- {
  by <- list(criterion = ok3$criterion, n = ok3$n)
  sel <- aggregate(
    list(selection_rate = ok3$selected_truth),
    by = by,
    FUN = mean
  )
  wt <- aggregate(
    list(mean_truth_weight = ok3$truth_weight),
    by = by,
    FUN = function(z) mean(z, na.rm = TRUE)
  )
  miss <- aggregate(
    list(missing_edge_rate = ok3$selected == "missing_edge"),
    by = by,
    FUN = mean
  )
  nrep <- aggregate(list(n_rep = ok3$selected_truth), by = by, FUN = length)
  out <- merge(
    merge(
      merge(sel, wt, by = c("criterion", "n")),
      miss,
      by = c("criterion", "n")
    ),
    nrep,
    by = c("criterion", "n")
  )
  out <- out[order(out$criterion, out$n), , drop = FALSE]
  rownames(out) <- NULL
  out
}
model_selection$acceptance <- model_selection$selection_rate >= 0.80 &
  model_selection$missing_edge_rate <= 0.05

# Selection rate should be nondecreasing in n (a secondary diagnostic).
selection_monotone <- all(vapply(
  split(model_selection, model_selection$criterion),
  function(x) {
    all(diff(x$selection_rate[order(x$n)]) >= -0.05)
  },
  logical(1)
))

# ----------------------------------------------------------------------------
# Provenance.
# ----------------------------------------------------------------------------
git_sha <- tryCatch(
  {
    s <- system2(
      "git",
      c("rev-parse", "--short", "HEAD"),
      stdout = TRUE,
      stderr = FALSE
    )
    if (length(s)) s[[1L]] else NA_character_
  },
  error = function(e) NA_character_
)

drmTMB_desc <- utils::packageDescription("drmTMB")
drmTMB_remote_sha <- if (is.null(drmTMB_desc$RemoteSha)) {
  NA_character_
} else {
  drmTMB_desc$RemoteSha
}

provenance <- list(
  generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  date = as.character(Sys.Date()),
  drmTMB_version = as.character(utils::packageVersion("drmTMB")),
  drmTMB_remote_sha = drmTMB_remote_sha,
  drmSEM_version = drmSEM_source_version(),
  R_version = R.version.string,
  git_sha = git_sha,
  R = GRID$R,
  seed = SEED,
  n_grid = GRID$n_grid,
  B = GRID$B,
  level = GRID$level
)

acceptance <- list(
  coverage = all(coverage$acceptance),
  model_selection_cicc = all(
    model_selection$acceptance[model_selection$criterion == "CICc"]
  ),
  model_selection_cbic = all(
    model_selection$acceptance[model_selection$criterion == "CBIC"]
  ),
  selection_monotone = selection_monotone,
  criteria = data.frame(
    criterion = c(
      "C1 effect-CI coverage",
      "C3 model-selection recovery (CICc)",
      "C3 model-selection recovery (CBIC)",
      "C3 selection rate increasing in n, by criterion"
    ),
    rule = c(
      "Every (n, quantity) empirical coverage lies inside nominal +/- 2*SE.",
      "Every n has truth selection rate >= 0.80 and missing-edge selection rate <= 0.05 under CICc.",
      "Every n has truth selection rate >= 0.80 and missing-edge selection rate <= 0.05 under CBIC.",
      "Truth selection rate is nondecreasing in n for each criterion (within 0.05 Monte-Carlo jitter)."
    ),
    pass = c(
      all(coverage$acceptance),
      all(model_selection$acceptance[model_selection$criterion == "CICc"]),
      all(model_selection$acceptance[model_selection$criterion == "CBIC"]),
      selection_monotone
    ),
    stringsAsFactors = FALSE
  )
)

validation <- list(
  coverage = coverage,
  model_selection = model_selection,
  acceptance = acceptance,
  c1_per_rep = c1_per_rep,
  c3_per_rep = c3_per_rep,
  provenance = provenance
)

out_path <- file.path("inst", "validation", "validation-results.rds")
saveRDS(validation, out_path)
message(
  "Wrote ",
  out_path,
  " (drmTMB ",
  provenance$drmTMB_version,
  ", drmTMB sha ",
  provenance$drmTMB_remote_sha,
  ", drmSEM sha ",
  provenance$git_sha,
  ")."
)
