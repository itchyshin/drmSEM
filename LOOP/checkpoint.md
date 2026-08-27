# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A12 done. Arc CLOSED.**
G0 approved; G1 discharged; **G2 resolved — keep `partial`.**
A7 (drmTMB item 1 C++) remains Phase 2, not this programme.

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
- **A12** — Ada + Rose + Melissa reconcile. PLAN-ACTUAL
  `docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`.
  G2 = keep `partial`; no NEWS overclaim.

ARC IN PROGRESS: none. Programme closed.

NEXT: none on this lane. A7 is a later drmTMB Phase 2 item — do
**not** start it from this checkpoint. Archive the stale worktree
`~/local-scratch/lanes/drmSEM-s6-imputation` after this lands on
`main`. Do not touch MAG-completeness.

OPEN GATES:
- **G1** — discharged (engine item 2 on drmTMB `main` @ `1cc1985cd`;
  consumer shipped in #46).
- **G2** — **resolved 2026-08-27:** retain capability-status
  `partial`. No public “covered” / FIML / general missing-data SEM
  claim.
- **G3** — did not fire.

TRUTH LIVES IN:
- drmSEM `cursor/lane-s6-a12` (this closeout) → `main` after merge
- drmSEM #45 `ec5692aa` / #46 `7280125d` / stamp `6c9d6ca`
- drmTMB `main` @ `1cc1985cd` (#1086)
- PLAN-ACTUAL: `docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`
- MAG-completeness: **do not touch**

RESUME: not applicable — arc CLOSED. If a later chat opens A7,
that is a new drmTMB lane from `origin/main`, not a resume of
this kit. capability-status stays `partial`.

HUMAN GATE: none remaining on S6 Phase 1 + consumer.
