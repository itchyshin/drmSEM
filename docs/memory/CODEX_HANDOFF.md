# Codex handoff — tasks that need a live drmTMB environment

This file lists work the Codex team (running in a cloud env that can compile
drmTMB/TMB) should do, because the Claude Code lane that built drmSEM 0.1 and the
post-0.1 increments **cannot**: it has no R or compiler in-container, so it
validates everything through CI and pure-R kernel tests. Every item below needs a
**live drmTMB fit** (or rendering, or drmTMB-repo access).

Coordinate on a separate branch; the launchable team is mirrored in
`.codex/agents/*.toml` (Ada/Gauss/Curie/Fisher/Florence/Grace/Rose…). Update
`docs/memory/` (`AGENT_LOG.md`, `VALIDATION_LEDGER.md`, `DECISIONS.md`,
`OPEN_QUESTIONS.md`) as you go.

## Message to Codex — 2026-06-07 (OQ-1 closeout + 0.5.0 cut coordination)

OQ-1 / V-57..V-60 is now closed for the common sampler families. The decisive
single-row probe showed nbinom2, beta, and Gamma keep the existing `1/sigma^2`
mapping; the aggregate variance failures were caused by drmSEM not carrying
fitted default dpars such as `sigma` into prediction engines when no explicit
`sigma ~ ...` formula was declared. Lognormal needed the real parameterization:
current drmTMB exposes `mu` as `meanlog` (identity link) and `sigma` as `sdlog`.
`test-recovery-samplers.R` now asserts V-57..V-60 against `drmTMB::simulate()`
and passes locally on a live engine.

The next ready-to-run engine item is now **wave-2 coverage**:
`Rscript inst/validation/generate.R` at full replicate counts -> commit
`inst/validation/validation-results.rds` -> render the validation vignette ->
promote C-1..C-4 in `VALIDATION_LEDGER.md`.

The **0.5.0 release marker** is cut on `claude/status-check-v0.5-OjpdI`
(**draft PR #36**): `DESCRIPTION` -> `0.5.0`, a `# drmSEM 0.5.0` NEWS section,
`cran-comments.md` refreshed, roadmap §0.5 marked **RELEASED**, and the README
status line synced. PR #35 has already landed on `main`, so #36 should now be
rebased on that state before merge.

**Unchanged by the cut — still engine-lane** (the 0.5→engine carry-over already
named in the NEWS lead and roadmap, none of which block the 0.5.0 marker):
coverage wave-2 (`inst/validation/generate.R` → commit the `.rds`), the OQ-7
`sdreport` NaN bisect, the joint bivariate *fit* + `rho12(fit)`/`corpairs(fit)`
read-back, OQ-9 marginal effects (needs the RE-variance API), and the post-0.5
consistent feedback estimation (IV/2SLS or a joint likelihood). Upstream asks for
drmTMB are collected in `DRMTMB_ISSUES.md`.

— Claude/CI lane

## ✉ Message to Codex — 2026-06-07 (from the Claude/CI lane)

Historical note: item 1 below is superseded by the OQ-1 closeout note above.
Item 2, the wave-2 coverage run, remains current.

Hi Gauss/Curie/Fisher — a validation-focused session just merged **#28–#31**.
The headline: the new recovery grid **found a real bug**, and I've set you up to
fix it in one run. Two things are teed up for the engine lane, in priority order.

**1. Fix the OQ-1 sampler-variance bug (P1, maybe P0) — `R/simulate_effects.R`.**
The new `test-recovery-samplers.R` (V-55..V-64) compared `drm_sample_family()` to
`drmTMB::simulate()` and found the **means match but the variances don't**
(nbinom2/beta/Gamma inflated; lognormal mean shifted). `drm_sample_family()`'s
`sigma↔dispersion` mapping (`size=1/sigma^2`, `phi=1/sigma^2`,
lognormal `meanlog=log(mu)`) feeds sigma on the wrong scale. **Do this:**
`Rscript inst/validation/sampler-dispersion-probe.R` — it isolates a single fitted
row (no mixture contamination) and sweeps candidate mappings, printing the
`<== BEST MATCH` per family and sigma on response+link scale. ⚠️ Ignore the
+61/+220/+150% aggregate figures in item 7 — they're mixture-contaminated; trust
only the single-row probe. Then patch `drm_sample_family()` (or the
`R/extractors.R` sigma read), and **flip the V-57..V-60 skips in
`test-recovery-samplers.R` to `expect_lt` asserts** so CI confirms it. Re-check
that V-7/V-37/V-41/V-53 (distribution-mediated effects, same sampler) still hold —
this likely de-biases distribution-mediated magnitudes through non-Gaussian
mediators. Then flip OQ-1 to resolved in `OPEN_QUESTIONS.md` and update the D-7/D-9
caveats in `DECISIONS.md`.

**2. Run the wave-2 coverage study — `inst/validation/generate.R` (authored).**
`Rscript inst/validation/generate.R` at full replicate counts → commit
`inst/validation/validation-results.rds` (like the calibration cache) → the
`validation` vignette renders it automatically. This gives the **first effect-CI
coverage numbers** (C-1, the biggest unmeasured property: does
`uncertainty="parametric"` cover at nominal?) and the model-selection recovery
rate (C-3). Spec + acceptance criteria: `docs/design/12-coverage-calibration.md`.
Then promote C-1..C-4 in `VALIDATION_LEDGER.md`.

Context maps if useful: `docs/design/11-validation-matrix.md` (full coverage map,
kernel + live-fit, V-1..V-73) and `12-coverage-calibration.md` (wave-2 spec).
The pure-R surface is green and the honest caveats are all recorded — over to the
engine. Thanks! — Claude/CI lane

## What shipped (pure-R / CI-green) up to this handoff

drmSEM 0.5.0 is cut (feedback-graph milestone); `main` then moves to the
post-0.5.0 dev line. The merged post-0.1/0.2 surface includes **OQ-12** unified effect API
(`method`/`uncertainty`/`nsim`/`population`, deprecated `mediation`/`draw`/
`n_sim`), **OQ-14** covariance-edge *grammar* (`covary()`/`covariances()`/
covariance-aware d-sep), analytic effect cross-checks (V-26..V-30),
standardization conventions (OQ-4), **OQ-6** calibration scaffold,
**0.3** composite constructs (`drm_composite()`/`loadings()`), **OQ-5**
per-mediator, per-component, and natural path attribution (`path_effects()`),
and the GitHub Pages deploy fix. The pure-R surface is kernel-validated unless
the ledger names a live-fit gate.

## P0 — live-engine closeout for the next dev slice

1. **DONE 2026-06-06 — OQ-6 Fisher's C calibration study.**
   `Rscript inst/calibration/generate.R` produced
   **`inst/calibration/calibration-results.rds`** (`drmTMB` 0.1.3.9000,
   `drmTMB` Git SHA `17b1321`, `drmSEM` 0.2.0.9000, git SHA `c951d31`,
   14,400 replicates) and
   `vignettes/calibration.Rmd` rendered from the source-tree cache. All five
   C1-C5 checks in `cal$acceptance` passed, so **V-17 -> validated** for the
   OQ-6 grid only. Keep future Fisher's C / d-sep claims scoped to that grid
   unless new calibration scenarios are added.
2. **Flip the remaining kernel tiers to *validated*.** **V-7 (distribution-mediated
   mechanism) is DONE:** `V-41` (`test-recovery.R`, drmTMB-gated, CI-green) runs the
   channel through a real `drm_sem()` fit (non-zero, additive identity closes,
   reproducible), and `V-37` pins the closed-form magnitude engine-free through the
   production path. Remaining here: promote the **d-sep claims** from
   "kernel-validated" -> "validated" on a live fit (run the `test-analytic-effects.R` /
   d-sep identities through a real fit), and — optional — a tight *live-fit* magnitude
   check of `distribution_mediated` vs the closed form computed from the fitted params
   (V-41 asserts direction + additivity + reproducibility, not the live magnitude).
3. **OQ-4 — standardization `sigma_E` term. DONE for constant-variance links** (#26,
   `V-44`): `R/standardize.R` now adds `sigma_E^2` to the `latent` divisor of a `mu`
   path on logit (`pi^2/3`) / probit (`1`) / cloglog (`pi^2/6`) links
   (`drm_link_latent_var()` / `drm_latent_divisor()`), closed-form validated with the
   fakefit harness. Remaining: the **log-link** families' mean-dependent
   (observation-level) latent variance, and — optional — a live-GLM-fit confirmation of
   the full pipeline. Spec: `docs/design/08-standardization.md`.

## P1 — feature completion needing a live fit

4. **OQ-5 follow-up.** Per-component **sigma-vs-zi** attribution and the
   **natural** per-mediator variant with a **recanting-witness** guard now ship
   and are kernel-validated (V-34/V-35). Remaining live-fit work: return **`NA`**
   for mean-fallback/unconfirmed-sampler families where attribution is not
   defensible, and add a `path_effects()` integration test on the canonical fit.
   Spec: `OQ-5`, `DECISIONS.md` D-17/D-19,
   `docs/design/02-effect-calculus.md`.
5. **OQ-14 — bivariate joint fit.** Grammar **and** the pure-R bivariate-node
   *declaration* now ship (`R/pair.R`): **`drm_pair()`** records the bivariate
   node, **`drm_expand_pair()`** bridges it to two `drm_node()` sub-nodes + the
   `covary()` edges, and **`rho12()` / `corpairs()`** return the declared edges
   with an `NA` estimate. The engine work remaining: a **live bivariate drmTMB
   fit** that estimates `rho12` jointly (replacing the two independent node fits
   in `drm_expand_pair()`), wired into `drm_sem()`; **`rho12(fit)` /
   `corpairs(fit)`** returning a real (non-`NA`) `estimate` read back from that
   fit (hook: a `drm_fit_rho12()` extractor in the adapter); and **deep
   level-compatibility validation** against the fitted RE blocks. Double-headed
   (`rho12`) / dashed (`corpair`) arc plotting already ships in the Claude lane
   (`plot.drm_sem`, `show = "all"`). Do **not** fake the joint estimate — keep
   `estimate = NA` until a real fit supplies it. Spec:
   `docs/design/07-bivariate-covariance-edges.md`.
6. **0.3 composites — integration test.** Confirm `drm_composite()` +
   `drm_sem(composites=)` fits end-to-end and `loadings()`/d-sep behave; document
   the indicator-intervention limitation. `docs/design/09-latent-variables.md`.

## P2 — robustness / parameterization

7. **DONE 2026-06-07 — OQ-1 / V-19 common-family sampler closeout.**
   The decisive single-row probe showed nbinom2, beta, and Gamma still use the
   D-7 `1/sigma^2` mapping; the aggregate +61/+220/+150% failures were caused by
   drmSEM omitting fitted default dpars (especially `sigma`) from prediction
   engines when no explicit `sigma ~ ...` formula was declared. The lognormal
   mismatch was real but different: current drmTMB exposes lognormal `mu` as
   `meanlog` (identity link), with `sigma` as `sdlog`. `R/simulate_effects.R` now
   carries fitted default dpars into effect propagation, samples lognormal with
   `rlnorm(meanlog = mu, sdlog = sigma)`, and propagates the lognormal expected
   response `exp(mu + sigma^2 / 2)` under mean mediation. V-57..V-60 in
   `test-recovery-samplers.R` are real `expect_lt` assertions against
   `drmTMB::simulate()` and pass locally on a live engine. Remaining sampler
   extensions are separate: `zero_one_beta` boundary inflation, `tweedie`
   mean-fallback, `student` nu, and beta_binomial trials.
12. **Validation wave 2 — coverage & calibration** (`docs/design/12-coverage-calibration.md`).
    `inst/validation/generate.R` is authored (C-1 effect-CI coverage vs closed-form
    truth; C-3 model-selection recovery) with a `validation.Rmd` report that renders
    with or without the cache. **Action:** run it at full replicate counts, commit
    the cached `inst/validation/validation-results.rds` (like the calibration
    cache), render the report, and promote C-1..C-4 in the ledger.
    (the biggest unmeasured property — known-effect linear-Gaussian DGP), C-2 d-sep
    Type-I/power beyond the OQ-6 grid, C-3 model-selection recovery rate, C-4 the
    sampler-dispersion close-out (C-4 == item 7). Full replicate counts run in the
    live lane; the spec, DGPs, estimands, and acceptance criteria are in the design
    doc.
8. **OQ-7** — root-cause the `sdreport` NaN on the canonical n=300 DGP (recondition
   or confirm a drmTMB robustness gap; file upstream). `docs/memory/DRMTMB_ISSUES.md`.
8b. **Effect-interval honesty (from the 2026-06-06 decomposition audit).** Two
    secondary engine-review findings, not decomposition-specific, need a live fit
    to fix/validate: (i) `drm_draw_beta()` silently falls back to the point
    estimate for a node whose `vcov` is non-PD / `NULL` (or non-convergent per
    `drm_fit_converged()`, which the effect path never consults), so that node
    contributes **zero** parameter uncertainty and the reported interval is too
    narrow with **no flag** — surface a `drm_warn_once`/attribute. (ii) `log`-link
    `drm_inv_link` can overflow to `Inf` on an extreme MVN draw; the resulting NA
    is dropped by `na.rm` in `drm_effect_contrast`, biasing the average over a
    shrinking row set — clamp `eta` or count/flag dropped rows. The pairing bug
    and the framing/over-claims from that audit are already fixed in the Claude
    lane (`drm_decomp_legs()`, V-36..V-41).
9. **`plot.drm_sem` visual polish** (needs rendering): standardized-coefficient
   edge labels + significance encoding without colliding with the component
   linetype; CI smoke test (`pdf(NULL); plot(sem); dev.off()`). `R/plotting.R`.

## P3 — release

10. **CRAN.** drmTMB must be on CRAN first; then drop `Remotes:` from `DESCRIPTION`
    (CRAN forbids it), keep `drmTMB` in `Suggests` (engine use is
    `requireNamespace`-guarded), get `R CMD check --as-cran` clean. The Claude lane
    has added runnable / `\dontrun` examples for the exported functions.
11. **0.4** — joint multivariate SEM / reflective latent measurement models (need a
    joint likelihood; deliberately out of scope for 0.x piecewise).

## What does NOT need Codex
Everything pure-R/logic and ggplot2 (the effect kernels, grammar layers, d-sep
graph logic, recovery/analytic tests, standardization math) is already validated
and stays in the Claude Code lane via CI.
