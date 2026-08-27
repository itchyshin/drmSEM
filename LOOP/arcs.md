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
| A7c-2 | Lift `R/imputation.R` gates for **Gamma × Bernoulli only** (separate PR). Old ultra-plan A7c-3–A7c-7 (V-80 / recovery / ledger / honesty / review) landed inside #49 | done | ← G-engine |
| A7c-3 | lognormal × Bernoulli consumer lift | done | **G-engine-ln** (#1092 / #50 `1e5d4cf`) |
| A7c-4 | beta_binomial × Bernoulli consumer lift | done | **G-engine-bb** (#1094 / #51 `e78bb94`) |
| clone tranche | student / zi+mi / nbinom2 × Gaussian | **paused** | Shinichi: "pause A7" |

Status: todo / doing / done / paused / blocked / deferred.
`blocked` = waiting on the sibling engine PR. `paused` = Shinichi's
named decision.

G-engine (Gamma) is discharged (#1088 / #49). **G-engine-ln is
discharged** (#1092 / #50). **G-engine-bb is discharged**
(#1094 `4c34c9bb` / drmSEM #51 `e78bb94`). Consumer tests
**88/0/0**. **Clone tranche PAUSED.** Leftovers — student
(`nu` ABI), zi+`mi` (mixture), nbinom2 × Gaussian (expand-gated)
— are sibling work, not A7c-5. Extra-#962 `truncated_nbinom2`
only if asked. capability-status stays `partial`.
See `docs/memory/PLAN-ACTUAL-2026-08-27-s6-a7-pause.md`.
