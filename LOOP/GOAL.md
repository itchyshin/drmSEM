# GOAL — Horizon 1–4 Capability Matrix & Manuscript Closeout (IMMUTABLE — re-read at top of EVERY arc)

## Mission

Deliver the complete Horizon 1–4 capability matrix for `drmSEM`:
1. **Track 1:** Indicator-Level Interventions (OQ-15, V-148..V-150) — COMPLETE (PR #69)
2. **Track 2:** Deep RE-Level Covariance Introspection & `corpairs()` (OQ-14, V-151..V-153) — COMPLETE (PR #67)
3. **Track 3:** Gelman 2-SD Standardization & GLM Latent Divisors (OQ-4, V-154..V-156) — COMPLETE (PR #68)
4. **Track 4:** Scientific Manuscript & JOSS/JSS Synthesis (`paper.md` / `paper.bib`) — COMPLETE (PR #66)

## Headline

All Horizon tracks are complete, tested, and documented. Open questions OQ-4, OQ-14, and OQ-15 are resolved with 100% passing tests (1,400+ assertions).

## Invariants

- Preserve piecewise SEM and engine/layer boundary: drmSEM delegates fitting to drmTMB.
- Observed-variable, piecewise, DAG-only scope.
- Component-labelled paths across all distributional parameters.
- DGP recovery test coverage for every newly shipped feature.
- Explicit staging: NEVER `git add -A`.

## Definition of Done

- All 4 parallel tracks verified with green CI and PRs merged.
- Full test suite passes with 0 failures / 0 errors.
- `docs/memory/OPEN_QUESTIONS.md` updated with resolutions for OQ-4, OQ-14, OQ-15.
- `paper.md` and documentation fully updated and consistent.
