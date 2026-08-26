# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved; A0–A11 landed on #46.
**G1 OPEN.** **G2 partial** until Shinichi reviews the public claim.
capability-status stays `partial`.

ARCS DONE (verified):
- A0 / G0 — planning kit + standing approval.
- **A1** — `LOOP/notes/A1-engine-contract.md`.
- **A2** — #963 https://github.com/itchyshin/drmTMB/issues/963#issuecomment-5429119689
  #962 https://github.com/itchyshin/drmTMB/issues/962#issuecomment-5429120815
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md` (leave `impute_joint`).
- **A4+A5+A6** — drmTMB **#1086 MERGED**
  `1cc1985cd87303d2300b0f311cb0ca91f4d06c34` (drmTMB 0.7.0).
  Cell `mp-gaussian-gaussian-k2-indep`.
- drmSEM docs **#45 MERGED** `ec5692aa302f201891ba1b8ce19299cff6953aa2`.
- **A8** — lift one-parent abort; two Gaussian `mi()` from the DAG.
- **A9** — `imputation()` / `imputed()` branch on `uncertainty_status`.
- **A10** — V-77 kept; V-79/79b/79c; V-82 identity; V-120 recovery;
  V-121 tiers.
- **A11** — `13-missing-data.md` (no FIML); ledger; capability stays
  `partial`.

ARC IN PROGRESS: none on this slice. Next is **A12** (review) / G2
public-claim review. Do not start A7 (drmTMB item 1 C++).

NEXT: merge #46 when CI green (standing approval). Then pull parent
`main`. G2 stays partial until Shinichi reviews the public claim.

OPEN GATES:
- **G1** — OPEN. Engine item 2 is on drmTMB `main` @ `1cc1985cd`.
- **G2** — partial: consumer merge authorised; public capability
  claim waits for Shinichi.
- **G3** — if independence fails

TRUTH LIVES IN:
- drmSEM `main` @ `ec5692aa` (#45) until #46 merges
- drmSEM A8–A11 PR https://github.com/itchyshin/drmSEM/pull/46
- drmTMB `main` @ `1cc1985cd` (#1086)
- MAG-completeness: **do not touch**

RESUME: read LOOP/GOAL.md → this file → A1 contract. A12 / G2
review. Do not emit `impute_joint`. capability-status stays
`partial`. Do not start A7 here.

HUMAN GATE: G2 before a public capability claim.
