# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved; A0–A8 landed on PRs.
**G1 OPEN.** A8 PR open. capability-status stays `partial`.

ARCS DONE (verified):
- A0 / G0 — planning kit + standing approval.
- **A1** — `LOOP/notes/A1-engine-contract.md`.
- **A2** — #963 https://github.com/itchyshin/drmTMB/issues/963#issuecomment-5429119689
  #962 https://github.com/itchyshin/drmTMB/issues/962#issuecomment-5429120815
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md` (leave `impute_joint`).
- **A4+A5+A6** — drmTMB **#1086 MERGED**
  `1cc1985cd87303d2300b0f311cb0ca91f4d06c34` (drmTMB 0.7.0).
  Feature `0781008b3`; C17 refresh `24bcef4c1`; phylo fixture
  `7f792508a`. Cell `mp-gaussian-gaussian-k2-indep`.
- drmSEM docs **#45 MERGED** `ec5692aa302f201891ba1b8ce19299cff6953aa2`.
- **A8+A10** — drmSEM PR https://github.com/itchyshin/drmSEM/pull/46
  (`cursor/lane-s6-a8` @ `cb5e287`). CI green. V-77 kept; V-79/79b/79c;
  V-82 auto ≡ hand against the k=2 engine.

ARC IN PROGRESS: none on this slice. Next is **A9**
(`uncertainty_status` tiers) then A11 docs. Do not claim
capability-status covered.

NEXT: A9 on this lane after #46 review, or wait for G2. Install
drmTMB from `main` @ `1cc1985cd` for V-82 in CI once that engine
is what the suite loads.

OPEN GATES:
- **G1** — OPEN. Engine item 2 is on drmTMB `main` @ `1cc1985cd`.
- **G2** — drmSEM #46 merge / public capability claim
- **G3** — if independence fails

TRUTH LIVES IN:
- drmSEM `main` @ `ec5692aa` (#45)
- drmSEM A8 PR https://github.com/itchyshin/drmSEM/pull/46
- drmTMB `main` @ `1cc1985cd` (#1086)
- MAG-completeness: **do not touch**

RESUME: read LOOP/GOAL.md → this file → A1 contract. Continue A9
or wait G2. Do not emit `impute_joint`. capability-status stays
`partial`.

HUMAN GATE: G2 before a public capability claim.
