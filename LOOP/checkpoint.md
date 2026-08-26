# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved; A0–A6 landed; **A8 in
progress** on `cursor/lane-s6-a8`.

ARCS DONE (verified):
- A0 / G0 — planning kit + standing approval.
- **A1** — `LOOP/notes/A1-engine-contract.md`.
- **A2** — #963 https://github.com/itchyshin/drmTMB/issues/963#issuecomment-5429119689
  #962 https://github.com/itchyshin/drmTMB/issues/962#issuecomment-5429120815
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md` (leave `impute_joint`).
- **A4+A5+A6** — drmTMB PR https://github.com/itchyshin/drmTMB/pull/1086
  (`cursor/lane-s6-multi-mi` @ `24bcef4c1` after C17 receipt refresh;
  feature commit `0781008b3`). Cell `mp-gaussian-gaussian-k2-indep`.
- drmSEM docs PR **#45 MERGED** `ec5692aa302f201891ba1b8ce19299cff6953aa2`.

ARC IN PROGRESS: **A8** lift one-parent abort in `R/imputation.R` only
+ A10 tests. MAG `basis_set` untouched. capability-status stays
`partial`. Not FIML. No `impute_joint`.

NEXT: merge drmTMB #1086 when CI green; finish A8 tests against that
engine; open drmSEM A8 PR. Do not claim capability-status covered.

OPEN GATES:
- **G1** — opening: engine installable from #1086 (`24bcef4c1`); merge
  to drmTMB `main` still pending CI (R CMD check)
- **G2** — drmSEM merge / public capability claim
- **G3** — if independence fails

TRUTH LIVES IN:
- drmSEM `main` @ `ec5692aa` (#45)
- drmSEM A8 branch `cursor/lane-s6-a8`
- drmTMB PR https://github.com/itchyshin/drmTMB/pull/1086
- MAG-completeness: **do not touch**

RESUME: read LOOP/GOAL.md → this file → A1 contract. Continue A8/A10
on `cursor/lane-s6-a8`. Do not emit `impute_joint`. capability-status
stays `partial`.

HUMAN GATE: G2 before a public capability claim.
