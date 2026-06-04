# AGENT LOG — drmSEM

Chronological log of meaningful agent work. Newest entries at the bottom. Leave
enough context for the next agent to continue without rediscovering the problem
(AGENTS.md, Multi-Agent Collaboration).

---

## 2026-06-04 — Bootstrap (Stage 0): scaffold + full R core + tests + memory

**Orchestrated by Ada**, with the standing review roles (Boole, Gauss, Noether,
Darwin, Florence, Fisher, Pat, Jason, Curie, Emmy, Grace, Rose).

**What shipped.**
- Stage 0 package scaffold (DESCRIPTION, NAMESPACE, LICENSE, README, `.github/`,
  `CLOUD.md`, `AGENTS.md`, vignettes/man stubs).
- Full R core — 13 files under `R/`:
  `drmSEM-package.R`, `drm_node.R`, `drm_sem.R` (declarative + `drm_psem` core),
  `edges.R`, `extractors.R` (the drmTMB adapter), `utils.R`, `paths.R`,
  `dsep.R`, `effects.R`, `simulate_effects.R`, `standardize.R`, `diagnostics.R`
  (`check_sem`), `plotting.R`.
- Tests under `tests/testthat/`: `helper-dgp.R` (the canonical
  `size -> abundance -> survival` DGP), `test-utils.R`, `test-dsep-kernels.R`,
  `test-effect-kernels.R` (pure-logic), and `test-integration.R` (drmTMB-gated).
- Design docs `docs/design/00-charter.md`, `01-semantics.md`,
  `02-effect-calculus.md`, `03-dsep.md`, `04-validation-plan.md`,
  `05-roadmap.md`.
- Project memory `docs/memory/`: `PROJECT_MEMORY.md`, `DECISIONS.md`,
  `VALIDATION_LEDGER.md`, `OPEN_QUESTIONS.md`, and this log.

**Validation state.**
- R 4.3.3 in the dev container; all 13 R/ source files parse clean.
- **18/18 pure-logic kernel tests PASS** locally: predictor extraction
  (bar/marker dropping), topological sort + cycle detection, ancestors + simple
  paths, Fisher's C, basis-set construction under the any-component rule, inverse
  links, family samplers (incl. zero-inflation), and — load-bearing — the
  distribution-mediated mechanism (contrast = 0.99 when a mediator's `sigma`
  depends on x, ~0 when `sigma` is constant).
- **drmTMB-integration tests are WRITTEN but PENDING runtime.** The dev
  container's network allowlist blocks CRAN/Posit/r-universe (`host_not_allowed`),
  so TMB and drmTMB cannot be installed/compiled here. They run in the Codex
  cloud env via `CLOUD.md`. The drmTMB adapter (`R/extractors.R`) was written
  against drmTMB 0.1.3.9000 real source.

**Locked decisions recorded** in `DECISIONS.md`: D-1 interface = both
(`drm_psem` core / `drm_sem` wrapper), D-2 d-separation = any modelled component,
D-3 effects = simulation (never coefficient products), plus D-4 naming, D-5
igraph for layout only, D-6 `model.matrix()` coding assumption.

**Open items** (see `OPEN_QUESTIONS.md`): exact drmTMB family-sampler
parameterizations (OQ-1), `model.matrix()` vs drmTMB contrast coding (OQ-2),
node-name vs response-var matching for `cbind()` (OQ-3), standardization
conventions (OQ-4), path-specific effect attribution (OQ-5), Fisher's C
calibration (OQ-6).

**Next for the following agent.** Run the cloud env (full internet) to install
drmTMB and execute `test-integration.R`. Confirm OQ-1 (family parameterizations)
and OQ-2 (contrast coding) against a live fit, then flip V-7/V-9/V-10 to
"validated" and V-11/V-12/V-13 from "pending" in `VALIDATION_LEDGER.md`. Do not
re-architect the engine/layer split or the locked decisions without a task,
evidence, and review.

(Authoring of the design docs and project memory in this entry by
Darwin + Rose, per the standing roles.)

## 2026-06-04 - Push, draft PR #1, CI hardening (Ada/Grace)

- Pushed branch `claude/distributional-sem-tmb-evbmH`; opened draft PR
  itchyshin/drmSEM#1. Subscribed to PR activity for CI/review events.
- Environment note: the dev sandbox network allowlist blocks CRAN, Posit,
  r-universe, and api.github.com (host_not_allowed); GitHub git/codeload is
  allowed. So drmTMB/TMB cannot be installed or compiled here, and CI cannot
  be polled from the sandbox. We rely on the PR-activity webhook (delivers CI
  failures) and act on those.
- Grace: the standard r-lib workflow does not run document(), and no man/*.Rd
  is committed, which would fail R CMD check on undocumented objects. Added an
  `any::roxygen2` dep and a `roxygen2::roxygenise()` step before check so man/
  and NAMESPACE are generated in CI.
- The vignette's model-fitting chunks are set to `eval = FALSE` (illustrative)
  while drmTMB-integration is pending validation, so vignette build is not a
  failure surface. Integration test-integration.R still runs in CI when drmTMB
  installs, serving as the integration validation.

## 2026-06-04 — Launchable agent roster mirrored (.codex + .claude)

**Orchestrated by Ada.**

**What shipped.**
- Materialized the 13 standing review roles from `AGENTS.md` as launchable
  agents in two mirrored directories: `.codex/agents/<slug>.toml` (Codex) and
  `.claude/agents/<slug>.md` (Claude Code). One-to-one, with **verbatim-identical
  instruction bodies** (generated from a single shared body per agent and diff-
  verified). Role→slug map recorded in the `AGENTS.md` Multi-Agent Collaboration
  table (e.g. Ada=`orchestrator-integrator`, Curie=`simulation-tester`,
  Rose=`systems-auditor`).
- Each body re-scopes the drmTMB persona to drmSEM: opens "You are <Persona>, the
  <role> for drmSEM", states the observed-variable/piecewise/DAG-only scope, the
  role's primary questions, and the concrete files/skills to consult. Review-only
  roles get read tools (Read, Grep, Glob); engineer/tester/orchestrator roles get
  Bash/Edit/Write as needed.
- Updated `AGENTS.md`: the mirror paragraph now says the agents exist (was "when
  added") and carries the role→slug table.

**Mirror rule (enforce going forward).** Changing any agent updates BOTH
`.codex/agents/<slug>.toml` and `.claude/agents/<slug>.md` in the same commit;
bodies must stay byte-identical. Rose audits this.

**Verified.** All 13 `.md`/`.toml` body pairs diffed identical. All `R/*.R` and
`tests/**/*.R` parse cleanly under R 4.3.3. Full `devtools::test()` /
`R CMD check` not run locally: CRAN is unreachable in this container and drmTMB
needs TMB compilation, so the suite runs in CI (`.github/workflows/R-CMD-check.yaml`).

## 2026-06-04 — Independent kernel re-verification (Gauss/Curie)

Ran a base-R-only harness (no testthat/MASS/cli/drmTMB needed) that sources
`R/simulate_effects.R` and re-checks the effect kernels outside the test suite.
All pass; the distribution-mediated effect reproduces independently (+0.99 when a
mediator's sigma rises in x, ≈0 when constant). Recorded under VALIDATION_LEDGER
"Independent kernel re-verification". Confirmed all `R/*.R` + tests parse under
R 4.3.3. drmTMB-integration + OQ-1/OQ-2 still require the cloud env (no CRAN/TMB
in this container).

## 2026-06-04 — CI evidence triage + NaN-vcov robustness fix (Ada/Gauss/Curie)

PR #1 CI (run 26981892600) went green on 3 OSes; read the ubuntu job log to
verify it was real, not skipped: `FAIL 0 | WARN 3 | SKIP 0 | PASS 39`, nodes
fitted with live drmTMB. Promoted V-10/11/12/13/20 to validated and largely
resolved OQ-2 in the ledger. Found + fixed a latent bug: `drm_draw_beta()` drew
from NaN vcov blocks (from sdreport `NaNs produced`), which would poison effects;
now falls back to the per-component point estimate. Strengthened the effect
integration test to assert `is.finite(estimate)`. Logged the sdreport NaN itself
as OQ-7 (root cause still needs a live drmTMB bisect).

## 2026-06-04 — OQ-1 closed: sampler parameterization (Gauss/Fisher/Curie)

Used a CI introspection probe (CI run 26982805627) to read drmTMB's
predict_parameters()/simulate() shapes and fitted (mu, sigma), then deduced that
drmTMB's sigma is SD-like with dispersion = 1/sigma^2. Fixed drm_sample_family()
for nbinom2/truncated_nbinom2 (size=1/sigma^2) and beta (phi=1/sigma^2);
lognormal/Gamma were already correct. Replaced the probe with an asserting
moment-recovery test (test-oq1-samplers.R). Recorded as D-7; OQ-1 resolved;
V-19 validated pending this commit's CI. Recovery suite (V-14/15/16) passed in the
prior run (PASS 66, FAIL 0). OQ-7 (sdreport NaN) still open.

## 2026-06-04 — OQ-1 fully confirmed; effect-decomposition plot added (Jason/Florence/Gauss)

CI runs 26983330989 / 26983569684 drove OQ-1 to closure: gaussian, poisson,
nbinom2, beta, lognormal samplers all PASS against live drmTMB (PASS 74/FAIL 1);
the only remaining failure was the Gamma *link* (stats::Gamma defaults to
"inverse"; drmTMB needs link="log"), now fixed. drmTMB's error confirmed Gamma
sigma = CV, validating the existing shape=1/sigma^2 sampler (D-9). Two earlier
self-inflicted failures: drmTMB::poisson/Gamma (not exported -> stats::), then the
Gamma link. Added plot.drm_effect() (ggplot2-gated forest plot of the
direct/mean-mediated/distribution-mediated/total decomposition) + test-plotting.R;
landscape scan (D-8) shows no peer plots this. pkgdown: flatly+teal theme, README
badges, pages URL. V-17 calibration test still queued (separate push).
