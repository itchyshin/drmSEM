# Codex handoff — tasks that need a live drmTMB environment

This file lists work the Codex team (running in a cloud env that can compile
drmTMB/TMB and, if scoped, access the `itchyshin/drmTMB` repo) should do, because
the Claude Code session that built drmSEM 0.1 could **not** do them: it had no
network to compile drmTMB, no local `igraph`/`ggplot2`, and GitHub access scoped
to `drmSEM` only (so no drmTMB source reads and no drmTMB issue filing). Claude
drove everything through ~2-minute CI rounds instead.

The launchable team is mirrored in `.codex/agents/` — launch the same roles
(Ada/Gauss/Curie/Fisher/Florence/Grace/Rose…) as needed. Coordinate on a separate
branch; update `docs/memory/` (AGENT_LOG, VALIDATION_LEDGER, DECISIONS) as you go.

## Status drmSEM 0.1 reached (all green in CI, run 26984153215, PASS 83/FAIL 0)
Core builders, component-labelled `paths()`, any-component d-sep + Fisher's C,
simulation effects with the distribution-mediated decomposition, validated family
samplers (OQ-1: gaussian/poisson/nbinom2/beta/lognormal/Gamma), `plot.drm_sem`
(DAG) + `plot.drm_effect` (forest + stacked), recovery (V-14/15/16) and
calibration (V-17) tests, three vignettes, themed pkgdown + deploy workflow.

## High-value tasks for Codex (roughly in priority order)

1. **OQ-7 — root-cause the `sdreport` NaN.** `test-integration.R`'s canonical
   `size -> abundance -> survival` DGP (n=300) makes `TMB::sdreport()` emit
   "NaNs produced" (3 warnings; tests still pass). With a live drmTMB session,
   bisect which node/parameter is weakly identified (likely the Gaussian
   `sigma ~ temp` or the beta-binomial overdispersion), then EITHER recondition
   the DGP (larger n / gentler slopes) so the warning disappears, OR confirm it
   is a genuine drmTMB robustness gap. If the latter, file it on drmTMB and move
   the note from `docs/memory/DRMTMB_ISSUES.md` to "confirmed". drmSEM already
   guards effects against NaN vcov (`drm_draw_beta`), so this is about clean
   diagnostics, not correctness.

2. **`plot.drm_sem` visual polish (needs rendering).** D-8 in `DECISIONS.md`:
   add standardized-coefficient edge labels (from `paths()`/`standardize()`) and
   encode non-significance (e.g. lighter/thinner edge or a `*` on significant
   ones) WITHOUT colliding with the component linetype already in use. Claude
   deferred this because it cannot render igraph to eyeball it. Add a CI smoke
   test (`pdf(NULL); plot(sem); dev.off()`, engine+igraph gated) plus a rendered
   check. Files: `R/plotting.R` (`plot.drm_sem`, `drm_component_style`).

3. **Extra family samplers in `drm_sample_family()`** (`R/simulate_effects.R`).
   Currently beta_binomial / tweedie / zero_one_beta / cumulative_logit mediators
   fall back to their mean. Derive each parameterization from
   `drmTMB::simulate(fit)` on a live fit (the pattern from OQ-1: drmTMB `sigma` is
   SD-like, dispersion = 1/sigma^2) and extend the moment-recovery test
   `test-oq1-samplers.R`. beta_binomial is the tricky one — the number of trials
   must come from the response (`cbind(alive,dead)` row totals); decide and
   document how a beta_binomial *mediator* is sampled.

4. **Larger V-17 calibration study.** `test-calibration.R` is a fast 20-rep
   smoke check (Type-I < 0.25, power > 0.70). Run a proper study (hundreds of
   reps, several DGPs, power curves) locally — too slow for CI — and write it up
   as a precomputed `vignettes/calibration.Rmd` (cache results; do not refit on
   site build). This promotes V-17 from "lightweight" to a real calibration claim
   and addresses OQ-6.

5. **pkgdown: build, preview, and add a hero figure.** Build the site locally
   (`pkgdown::build_site()`), eyeball the flatly+teal theme, and add a rendered
   component-labelled DAG (`plot(sem)`) as a hero image in `README.md` /
   `man/figures/` — Claude could not render it. Confirm the `pkgdown.yaml` deploy
   workflow publishes to `gh-pages` cleanly (enable Pages on the repo).

6. **Confirm drmTMB family parameterizations from source.** With drmTMB repo
   access, verify the OQ-1 / D-7 / D-9 mappings against drmTMB's actual family
   definitions and `simulate.drmTMB` (Claude inferred them from fitted moments
   because the API/source was rate-limited/out of scope).

7. **Verify the mirrored agent kit in the Codex runtime.** Launch the
   `.codex/agents/*.toml` team and confirm one-to-one parity with
   `.claude/agents/*.md` still holds; fix drift in the same commit (the mirror
   rule in `AGENTS.md`).

## What does NOT need Codex
Everything pure-R/logic and ggplot2 (paths, d-sep graph logic, effect simulation
kernels, `plot.drm_effect`, recovery tests) is already validated and can stay with
the Claude Code lane via CI.
