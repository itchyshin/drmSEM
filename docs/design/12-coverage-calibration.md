# 12 — Coverage & calibration (validation wave 2)

Wave 1 (`11-validation-matrix.md`, V-45..V-73) established **point recovery**: the
machinery returns the right *number* on a known-answer DGP. Wave 2 establishes the
**operating characteristics** — does the *uncertainty* have the advertised
behaviour, and do the *inferential* procedures calibrate? These are
many-replicate studies, so the full grid runs in the live (Codex) lane and is
cached (mirroring the OQ-6 Fisher's C calibration: `inst/calibration/generate.R`
+ a cached `.rds` + a report vignette). CI runs only a bounded smoke.

This doc is the **spec** for that study so it can be authored and run on a live
engine without re-deriving the DGPs or the acceptance criteria.

## Studies

### C-1 — Effect-interval coverage (the biggest open property)
**Question:** does `uncertainty = "parametric"` produce intervals that cover the
true effect at the nominal rate?

- **DGP:** a linear identity-link Gaussian chain `x -> m -> y` (and a variant with
  a direct `x -> y` edge), where the **true total / direct / indirect effects are
  known in closed form** (products of the data-generating coefficients times the
  contrast width `sd(x)`).
- **Procedure:** for `R` replicate datasets (n ~ 500–2000): fit `drm_sem()`,
  compute `total_effects()` / `indirect_effects()` with `uncertainty =
  "parametric"`, `B ~ 500`; record whether the reported `conf.low/​conf.high`
  bracket the known true effect, for each `quantity` row.
- **Metric:** empirical coverage per quantity. **Acceptance:** coverage within
  Monte-Carlo bounds of nominal (e.g. 0.95 ± 2·SE for `R` reps). Report a coverage
  table. Also report mean interval width (efficiency) as a secondary diagnostic.
- **Why it matters:** every `drm_effect` row ships a CI; none of its *coverage* is
  currently measured. A pairing/var bug (cf. the #22 decomposition fix) would
  surface here.

### C-2 — d-separation Type-I / power (beyond the OQ-6 grid)
**Question:** does the any-component d-sep test hold its size and have power
outside the calibrated OQ-6 grid?

- Extends `inst/calibration/generate.R`. New scenarios: factor-heavy designs,
  `zi`/`hu` components, mixed links, larger graphs. Same acceptance shape as
  OQ-6 (Type-I near α; power increasing with effect size / n). Keep claims
  **scoped to the tested grid** (the standing rule).

### C-3 — Model-selection recovery rate
**Question:** does `compare()` / `best()` select the true DAG under the requested
ranking criterion?

- **DGP:** a true DAG plus a candidate set (`drm_dag()` / `drm_model_set()`) that
  includes the truth, an over-fitted, and an under-fitted (missing-edge) rival.
- **Procedure:** over `R` replicates, record how often `best()` returns the true
  model and the mean model weight on the truth for both `CICc` and `CBIC`.
- **Metric:** selection rate + mean truth-weight by criterion. **Acceptance:**
  `CBIC` selection rate is high and increasing with n; the missing-edge rival is
  reliably penalised (its d-sep claim is violated). `CBIC` is the default
  ranking criterion. `CICc` is still reported but is treated as a
  phylopath-style, AIC-like support measure that may retain over-fitted rivals
  rather than a consistent true-DAG selector.

### C-4 — Sampler dispersion vs `drmTMB::simulate()` (OQ-1 closeout)
Wave 1 initially suggested that `drm_sample_family()`'s **variance** did not
match `drmTMB::simulate()` for nbinom2/beta/Gamma and that the **lognormal mean**
was shifted. The live closeout resolved this into two concrete bugs: drmSEM's
prediction engine omitted default fitted dpars such as `sigma` when the user did
not declare an explicit `sigma ~ ...` formula, and lognormal `mu` is drmTMB's
`meanlog` (identity link), not a response mean to log again. After those fixes,
V-57..V-60 are real assertions against `drmTMB::simulate()`. The probe
`inst/validation/sampler-dispersion-probe.R` remains as a future drift diagnostic
for nbinom2, beta, Gamma, and lognormal parameterizations.

## Output schema (cached `.rds`)

`inst/validation/validation-results.rds` — a list with one element per study
(`coverage`, `dsep_power`, `model_selection`, `sampler_dispersion`), each a tidy
data frame + an `acceptance` logical vector, plus provenance (`drmTMB` version,
git SHA, `R`, seed, n-grid). A `vignettes/validation.Rmd` reads the cache and
tabulates it (built only when the cache is present, like `calibration.Rmd`).

## Lanes

- **Claude / CI lane:** this spec; the sampler-dispersion probe; and a *bounded*
  CI smoke that checks the coverage/selection **logic** on a tiny deterministic
  case (no heavy fitting, no flaky coverage assertion).
- **Live / Codex lane:** run `generate.R` at full replicate counts, commit the
  cached `.rds`, render the report, and promote the C-1..C-4 claims in the ledger.
  Tracked in `../memory/CODEX_HANDOFF.md`.
