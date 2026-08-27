# Arcs — S6 A7 consumer (docs kickoff 2026-08-27)

Phase 1 (A0–A6, A8–A12) is **CLOSED** on drmSEM `main` @ `e7392d7`
(#45 / #46 / #47). This kit is the **consumer follow-on** only.
Engine A7 (per-family C++ `has_mi`, #962) is sibling
`0a5d078f` / `~/local-scratch/lanes/drmTMB-s6-family-gate`.
Do not re-open Phase 1. Do not implement engine likelihoods.

| # | arc | status | gate? |
|---|-----|--------|-------|
| A7c-0 | Fresh LOOP kit + consumer contract + AGENT_LOG stubs | done | — |
| A7c-1 | Wait for first new-family engine PR to be **mergeable** | done | **G-engine** (#1088 `6e553879`) |
| A7c-2 | Lift `R/imputation.R` gates for **Gamma × Bernoulli only** (separate PR) | todo | ← G-engine |
| A7c-3 | V-80 still equals engine allow-list; leftovers fail loud | todo | ← A7c-2 |
| A7c-4 | Known-DGP recovery + identity for the new cell | todo | ← A7c-2 |
| A7c-5 | Ledger cross-ref (V-number ↔ engine `missing_predictor` row) | todo | ← A7c-4 |
| A7c-6 | Docs honesty; capability-status stays `partial` | todo | ← A7c-5 |
| A7c-7 | Review + reconcile | todo | G-claim (keep `partial`) |

Status: todo / doing / done / paused / blocked / deferred.
`blocked` = waiting on the sibling engine PR. `paused` = Shinichi's
named decision.

G-engine is discharged. A7c-2 is a **separate** consumer PR for
Gamma × Bernoulli only — not nbinom2 × Gaussian, not lognormal.
A later family repeats A7c-2–A7c-6; it does not flip capability-status.
