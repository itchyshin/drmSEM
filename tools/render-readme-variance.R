# Render the "caused variance" README figure from a live drmTMB fit.
# Run from the package root with: Rscript tools/render-readme-variance.R
#
# WHY THIS FIGURE EXISTS. The hero DAG (tools/render-readme-hero.R) encodes the
# *grammar*: an edge's line style tells you which distributional component it
# targets. It never shows the *payoff* -- a reader sees a dashed arrow labelled
# `sigma` and has to take it on trust. This figure shows the thing itself: a
# variance that is genuinely caused, and a downstream conclusion that a mean-only
# SEM gets wrong.
#
# THE EXAMPLE (cost of variance under diminishing returns; cross-sectional,
# SIMULATED -- not a real dataset). Three groups have EQUAL mean reproductive
# output by construction and differ only in how variable that output is.
# Recruitment saturates in output (logit link, intercept in the concave region),
# so spread alone depresses mean recruitment -- the Jensen-gap mechanism that
# test-effect-kernels.R and test-analytic-effects.R verify.
#
# DELIBERATELY NOT CALLED "BET-HEDGING" (corrected 2026-08-09). An earlier draft
# used that label and it misled the first reader, including the package author.
# In bet-hedging theory variance is ADAPTIVE -- it pays off in a FLUCTUATING
# environment through geometric-mean fitness. This example has a constant
# environment, where variance is purely a cost, so the label predicted the
# opposite of what the figure shows. Darwin's review flagged the terminology risk
# explicitly (drmSEM is cross-sectional and cannot represent the temporal /
# stochastic-environment literature where bet-hedging actually pays); the warning
# was recorded and then not applied. Do not reintroduce the term here.
#
# The concavity is BUILT IN, exactly as the hero's log-link abundance node is;
# that is a demonstration of a mechanism, not an empirical discovery, and the
# caption says so.

required <- c("devtools", "drmTMB", "ggplot2", "patchwork", "ragg")
missing <- required[
  !vapply(required, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing)) {
  stop(
    "Missing required packages: ",
    paste(missing, collapse = ", "),
    call. = FALSE
  )
}

devtools::load_all(".", quiet = TRUE)

# ---- 1. Simulate -----------------------------------------------------------
# seed 11 / n = 1500: the mu contrasts land at +0.027 and -0.023 (p = 0.77, 0.80),
# i.e. visibly null, which is what the figure claims. The true mu effect IS zero
# by construction; the seed is fixed so the picture is reproducible, not chosen to
# manufacture the result.
set.seed(11)
n <- 1500L
# Level names describe the VARIANCE plainly. The earlier
# conservative/mixed/diversified naming imported bet-hedging connotations --
# "diversified" reads as adaptive, while here it is the worst-performing group.
strategy <- factor(
  rep(c("consistent", "intermediate", "variable"), each = n / 3L),
  levels = c("consistent", "intermediate", "variable")
)
s_mixed <- as.integer(strategy == "intermediate")
s_div <- as.integer(strategy == "variable")

# EQUAL means; only the spread is caused.
output <- stats::rnorm(n, mean = 0, sd = exp(-0.35 + 0.55 * s_mixed + 1.05 * s_div))

trials <- 12L
recruited <- stats::rbinom(n, size = trials, prob = stats::plogis(1.6 + 0.9 * output))
dat <- data.frame(
  strategy,
  output,
  recruited,
  failed = trials - recruited
)

sem <- drm_sem(
  output = drm_node(
    drmTMB::bf(output ~ strategy, sigma ~ strategy),
    family = stats::gaussian()
  ),
  recruitment = drm_node(
    drmTMB::bf(cbind(recruited, failed) ~ output),
    family = stats::binomial()
  ),
  data = dat
)

fit <- sem$nodes[["output"]]
cf <- stats::coef(fit)
vc <- stats::vcov(fit)
levs <- levels(dat$strategy)

# ---- 2. Fitted mean and spread per strategy, with compatibility intervals ----
# Contrast matrix for a treatment-coded 3-level factor: rows are the three
# strategies, columns (Intercept), mixed, diversified.
L <- rbind(
  conservative = c(1, 0, 0),
  mixed = c(1, 1, 0),
  diversified = c(1, 0, 1)
)
sig_idx <- grep("^sigma:", rownames(vc))
mu_idx <- grep("^mu:", rownames(vc))

log_sd <- as.vector(L %*% cf$sigma)
log_sd_se <- sqrt(diag(L %*% vc[sig_idx, sig_idx] %*% t(L)))
fitted_mu <- as.vector(L %*% cf$mu)

# Interval built on the log scale then exponentiated: exp() is monotone, so the
# transformed endpoints remain a valid interval (no delta-method approximation).
crit <- stats::qnorm(0.975)
spread <- data.frame(
  strategy = factor(levs, levels = levs),
  sd = exp(log_sd),
  lo = exp(log_sd - crit * log_sd_se),
  hi = exp(log_sd + crit * log_sd_se),
  log_sd = log_sd,
  log_sd_se = log_sd_se,
  mu = fitted_mu
)

# ---- 3. The payoff: effect decomposition by channel -------------------------
eff <- indirect_effects(sem, from = "strategy", to = "recruitment")
channels <- eff[eff$quantity %in% c("mean_mediated", "distribution_mediated"), ]
channels$label <- factor(
  ifelse(
    channels$quantity == "mean_mediated",
    "through the mean",
    "through the spread"
  ),
  levels = c("through the spread", "through the mean")
)

# ---- 4. Shared visual vocabulary -------------------------------------------
# One hue only, taken from the package's own sigma swatch, so this figure and the
# hero DAG cannot drift apart. Strategy levels are distinguished by POSITION and
# direct labels, never by colour (colour carries exactly one message here: "this
# is the sigma story").
sigma_style <- drm_component_style("sigma")
sig_col <- sigma_style$col
pale <- grDevices::adjustcolor(sig_col, alpha.f = 0.22)
mid <- grDevices::adjustcolor(sig_col, alpha.f = 0.55)

base_theme <- ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.y = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold", size = 11.5),
    plot.subtitle = ggplot2::element_text(size = 9.4, colour = "grey30"),
    axis.title = ggplot2::element_text(size = 9.6)
  )

# ---- 5. Panel A: the fitted distributions, stacked --------------------------
# This is the demonstration. A reader watches the bump get wider as they scan
# down and needs no SEM notation to see that the spread is what changed.
x_lim <- 3.4 * max(spread$sd)
grid_x <- seq(-x_lim, x_lim, length.out = 500)
ridge_gap <- 1
# Common vertical scaling across ridges: densities are NOT individually
# normalised to equal height, because equal-height curves would hide exactly the
# property being demonstrated. The scale is set so the TALLEST ridge (the
# narrowest strategy) fills 82% of its lane -- otherwise it overruns the lane
# above and gets clipped by the panel edge.
peak <- max(stats::dnorm(0, 0, spread$sd))
dens_scale <- 0.82 * ridge_gap / peak
baseline <- (nrow(spread) - seq_len(nrow(spread))) * ridge_gap

ridge <- do.call(rbind, lapply(seq_len(nrow(spread)), function(i) {
  dens <- stats::dnorm(grid_x, mean = spread$mu[i], sd = spread$sd[i])
  data.frame(
    strategy = spread$strategy[i],
    x = grid_x,
    y = baseline[i] + dens * dens_scale,
    base = baseline[i]
  )
}))

p_a <- ggplot2::ggplot() +
  ggplot2::geom_ribbon(
    data = ridge,
    ggplot2::aes(x = x, ymin = base, ymax = y, group = strategy),
    fill = pale, colour = sig_col, linewidth = 0.5
  ) +
  ggplot2::labs(
    title = "The same average, different spread",
    subtitle = "Fitted distribution of reproductive output in each group",
    x = "Reproductive output", y = NULL
  ) +
  # Strategy names live on the axis rather than floating in the panel, so a label
  # can never collide with a curve whose width is the whole point of the figure.
  ggplot2::scale_y_continuous(
    breaks = baseline,
    labels = sprintf("%s\n(SD %.2f)", levs, spread$sd),
    expand = ggplot2::expansion(mult = c(0.02, 0.10))
  ) +
  ggplot2::coord_cartesian(xlim = c(-x_lim, x_lim)) +
  base_theme +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8.6, colour = "grey20"))

# ---- 6. Panel B: spread vs strategy, as Confidence Eyes ---------------------
# Confidence Eye contract: pale tapered compatibility region, darker outline,
# HOLLOW point estimate. No filled points, no interval bars, no guide line
# through the eye.
#
# The lens geometry comes from the package's own drm_confidence_eyes() rather
# than being re-invented here, so this figure and plot.drm_effect() cannot drift
# apart. It is a HALF-SINE taper, not a density curve: the contract is explicit
# that the taper is a visual compatibility cue and must not be read as a
# likelihood, sampling density, or posterior. (An earlier draft of this script
# built the shape from dnorm() and described it as tracking the sampling density
# of log-sigma -- exactly the reading the contract rules out.)
#
# The helper returns the interval along x and the row position along y; Panel B
# wants the interval vertical, so x and y are swapped on the way in.
eye_src <- data.frame(
  estimate = spread$log_sd,
  conf.low = spread$log_sd - crit * spread$log_sd_se,
  conf.high = spread$log_sd + crit * spread$log_sd_se,
  quantity = levs,
  .channel = "sigma",
  .y = seq_len(nrow(spread)),
  stringsAsFactors = FALSE
)
eye_raw <- drm_confidence_eyes(eye_src, height = 0.34)
eye <- data.frame(
  strategy = factor(eye_raw$.group, levels = levs),
  # Built on the log scale, then exponentiated back onto the SD axis the reader
  # sees -- the same monotone transform used for the interval itself.
  y = exp(eye_raw$x),
  x = eye_raw$y
)

p_b <- ggplot2::ggplot() +
  ggplot2::geom_polygon(
    data = eye,
    ggplot2::aes(x = x, y = y, group = strategy),
    fill = pale, colour = mid, linewidth = 0.55
  ) +
  ggplot2::geom_point(
    data = data.frame(x = seq_len(nrow(spread)), y = spread$sd),
    ggplot2::aes(x = x, y = y),
    shape = 21, size = 2.9, stroke = 0.95, colour = sig_col, fill = "white"
  ) +
  ggplot2::scale_x_continuous(
    breaks = seq_len(nrow(spread)), labels = levs, limits = c(0.4, 3.6)
  ) +
  ggplot2::labs(
    title = "The spread is estimated, not assumed",
    subtitle = "Fitted variability (SD) of output, with 95% compatibility eyes",
    x = NULL, y = "Variability (SD) of output"
  ) +
  # No guide lines through the eyes, in EITHER direction. base_theme blanks the
  # horizontal ones; this panel puts the categories on x, so its vertical
  # gridlines are the row guides and run straight down through every eye.
  base_theme +
  ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())

# ---- 7. Panel C: what a mean-only SEM would miss ----------------------------
# The crux. The mean channel's interval covers zero; the spread channel's does
# not. A mean-only SEM has access to the first row only, and would conclude that
# strategy does not matter.
# Same package helper, used directly: here the interval is already horizontal.
# indirect_effects() reports an interval, not a standard error, and its Monte
# Carlo interval is mildly asymmetric; the half-sine taper scales each side
# independently, so the waist sits on the estimate and the drawn endpoints are
# the reported conf.low / conf.high rather than anything re-derived.
ch_src <- data.frame(
  estimate = channels$estimate,
  conf.low = channels$conf.low,
  conf.high = channels$conf.high,
  quantity = as.character(channels$label),
  .channel = "sigma",
  .y = match(as.character(channels$label), levels(channels$label)),
  stringsAsFactors = FALSE
)
ch_eye <- drm_confidence_eyes(ch_src, height = 0.30)
ch_eye$label <- factor(ch_eye$.group, levels = levels(channels$label))

p_c <- ggplot2::ggplot() +
  ggplot2::geom_vline(xintercept = 0, linetype = 3, colour = "grey45") +
  ggplot2::geom_polygon(
    data = ch_eye,
    ggplot2::aes(x = x, y = y, group = label),
    fill = pale, colour = mid, linewidth = 0.55
  ) +
  ggplot2::geom_point(
    data = data.frame(
      x = channels$estimate,
      y = match(as.character(channels$label), levels(channels$label))
    ),
    ggplot2::aes(x = x, y = y),
    shape = 21, size = 2.9, stroke = 0.95, colour = sig_col, fill = "white"
  ) +
  # The payoff panel prints its own numbers: without them a reader can only
  # extract "crosses zero" vs "doesn't" by eye, and the magnitude -- the thing
  # the whole figure is arguing about -- appears nowhere on the page.
  ggplot2::geom_text(
    data = data.frame(
      x = channels$estimate,
      y = match(as.character(channels$label), levels(channels$label)) + 0.42,
      lab = sprintf(
        "%.3f  [%.3f, %.3f]",
        channels$estimate, channels$conf.low, channels$conf.high
      )
    ),
    ggplot2::aes(x = x, y = y, label = lab),
    size = 2.9, colour = "grey25"
  ) +
  ggplot2::scale_y_continuous(
    breaks = seq_along(levels(channels$label)),
    labels = levels(channels$label),
    limits = c(0.45, 2.75)
  ) +
  ggplot2::labs(
    title = "What a mean-only SEM would miss",
    subtitle = "Effect of group on recruitment, split by channel",
    x = "Change in recruitment probability", y = NULL
  ) +
  # Pad the x range: without this the mean channel's upper tail sits exactly on
  # the panel edge and reads as truncated.
  ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.18)) +
  # No row guide lines through the eyes or their hollow points (contract).
  base_theme

# ---- 8. Compose and write --------------------------------------------------
# NO DAG inset. plot.drm_sem() draws its two legends unconditionally
# (R/plotting.R -- there is no `legend` argument), so at inset scale the graph
# arrived illegible and wrapped in redundant keys, and cropping them out of the
# raster by fixed proportions would silently break the moment that layout
# changes. The hero DAG remains the place to read the grammar; this figure's job
# is to show what the grammar is asserting.
fig <- (p_a | p_b | p_c) +
  patchwork::plot_layout(widths = c(1.35, 1, 1.15)) +
  patchwork::plot_annotation(
    title = "A caused variance, and why it changes the answer",
    # The panel titles already carry the claim, so the caption says only what no
    # panel can: the provenance, the honest caveat, and the one thing a reader
    # can misread off panel A.
    caption = paste(
      "Simulated example (n = 1500), fitted with drmSEM on a live drmTMB engine, and unrelated to the size/abundance/survival diagram elsewhere. In panel A a taller curve is more concentrated, not more important.",
      "Recruitment saturates in reproductive output, so two units above average gain less than two units below lose -- being variable drags the mean down even when mean output is unchanged.",
      "That saturating response is built into the simulation, not discovered in it.",
      sep = "\n"
    ),
    theme = ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.caption = ggplot2::element_text(hjust = 0, size = 8.1, colour = "grey35")
    )
  )

out_dir <- file.path("man", "figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(out_dir, "drmsem-caused-variance.png")

ragg::agg_png(out, width = 2400, height = 950, units = "px", res = 200, background = "white")
print(fig)
grDevices::dev.off()

# ---- 9. Report the numbers the figure asserts ------------------------------
message("\n--- numbers this figure asserts ---")
message("fitted SD by strategy:  ", paste(sprintf("%s=%.2f", levs, spread$sd), collapse = "  "))
message("mu contrasts (should be ~0):  ", paste(sprintf("%.3f", cf$mu[-1]), collapse = "  "))
print(eff)
message("Wrote ", normalizePath(out))
