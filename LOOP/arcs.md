# Arcs — S6 generality multi-mi() (G0 approved 2026-08-26)

| # | arc | status | gate? |
|---|-----|--------|-------|
| A0 | Lane + charter + LOOP kit + D-22 | done | — |
| A1 | Engine contract draft (docs only) | done | G0 |
| A2 | Attach S6 prototype evidence to drmTMB #963 / #962 | done | authorised |
| A3 | Recon `drmTMB-joint-mi` vs #963 option (b) | done | G0 |
| A4 | drmTMB item 2: k ≥ 2 independent `mi()` | done | PR #1086 |
| A5 | drmTMB item 5: k=2 row on existing `missing_predictor` axis | done | pairs A4 |
| A6 | Two-predictor recovery + sentinel-invariance | done | ← A4 |
| A7 | drmTMB item 1: per-family C++ `has_mi` | todo | Phase 2 |
| A8 | drmSEM: lift abort, multi-`mi()` from DAG | done | PR #46 |
| A9 | drmSEM: `imputed()` / `uncertainty_status` tiers | todo | ← A8 |
| A10 | drmSEM tests (keep V-77; new two-parent DGP) | done | PR #46 |
| A11 | Docs + ledgers + capability-status honesty | todo | ← A10 |
| A12 | Review + reconcile | todo | **G2** |

Status: todo / doing / done / paused / blocked. `paused` = awaiting
Shinichi's named decision; `blocked` = external dependency.

A2 posted 2026-08-26. #45 merged `ec5692aa`. #1086 merged `1cc1985cd`.
A8/A10 PR https://github.com/itchyshin/drmSEM/pull/46. G1 open.
