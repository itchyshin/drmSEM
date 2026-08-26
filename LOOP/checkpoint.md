# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved; A0–A6 landed tonight.
**IN PROGRESS** only for CI on the engine PR. G1 still closed.

ARCS DONE (verified):
- A0 / G0 — planning kit + standing approval.
- **A1** — `LOOP/notes/A1-engine-contract.md`.
- **A2** — #963 https://github.com/itchyshin/drmTMB/issues/963#issuecomment-5429119689
  #962 https://github.com/itchyshin/drmTMB/issues/962#issuecomment-5429120815
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md` (leave `impute_joint`).
- **A4+A5+A6** — drmTMB PR https://github.com/itchyshin/drmTMB/pull/1086
  (`cursor/lane-s6-multi-mi` @ `0781008b3`). Local: 20 + 109 + 24 pass;
  ledger `--check` OK. Cell `mp-gaussian-gaussian-k2-indep`.

ARC IN PROGRESS: wait for drmTMB #1086 CI. No drmSEM `R/`.

NEXT: After #1086 is mergeable / installed, assess **G1**. Then A8
(lift abort) on this drmSEM lane. Do not start A8 tonight.

OPEN GATES:
- **G1** — engine item 2 on an engine this suite can see (PR not yet
  merged to drmTMB `main`)
- **G2** — drmSEM merge / public capability claim
- **G3** — if independence fails

TRUTH LIVES IN:
- drmSEM `cursor/lane-s6-imputation` draft PR https://github.com/itchyshin/drmSEM/pull/45
- drmTMB `cursor/lane-s6-multi-mi` PR https://github.com/itchyshin/drmTMB/pull/1086
- MAG-completeness: **do not touch**

RESUME: read LOOP/GOAL.md → this file → A1 contract. Continue from
G1 assessment after #1086 CI. Do not start drmSEM `R/`. Do not emit
`impute_joint`. capability-status stays `partial`.

HUMAN GATE: G1 before drmSEM `R/`.
