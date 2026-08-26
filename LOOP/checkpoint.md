# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved; A1+A3 committed; A2 comments
posted. **IN PROGRESS** — next is drmTMB Phase 1 lane (A4–A6).

ARCS DONE (verified):
- S0 / A0 @ `ec41d94` / `40fb85c` — LOOP kit, charter, D-22.
- **G0** — Shinichi approved all 10 items + standing approval
  (push / PR / issue comments / new lanes / Totoro).
- **A1** — `LOOP/notes/A1-engine-contract.md`. Independence, emit
  shape, first cell two Gaussian `mi()`. Ledger correction: axis
  already exists (17 G2 rows); A5 adds `mp-gaussian-gaussian-k2-indep`.
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md`. Leave
  `impute_joint`; clone 207 behind / 3 ahead @ `cbbf380bd`.
- **A2** — comments posted:
  https://github.com/itchyshin/drmTMB/issues/963#issuecomment-5429119689
  https://github.com/itchyshin/drmTMB/issues/962#issuecomment-5429120815

ARC IN PROGRESS: drmTMB Phase 1 (A4+A5, then A6). Not this worktree.

NEXT: Push this docs branch as draft PR. Create
`~/local-scratch/lanes/drmTMB-s6-multi-mi` on `cursor/lane-s6-multi-mi`
from drmTMB `origin/main`. Implement k=2 independent Gaussian `mi()`.

OPEN GATES (need human):
- **G1** — before any drmSEM `R/`
- **G2** — before drmSEM merge / public capability claim
- **G3** — if independence fails and only `impute_joint` works
- Push/PR/issue-comment: authorised tonight by standing approval

TRUTH LIVES IN:
- Lane `cursor/lane-s6-imputation` @ `~/local-scratch/lanes/drmSEM-s6-imputation`
- Parent `main` @ `0852f9f` (`R/` untouched)
- Contract: `LOOP/notes/A1-engine-contract.md`
- Joint-mi verdict: `LOOP/notes/A3-joint-mi-verdict.md`
- MAG-completeness worktree: **do not touch**

RESUME: read LOOP/GOAL.md → LOOP/checkpoint.md →
LOOP/notes/A1-engine-contract.md → LOOP/notes/A3-joint-mi-verdict.md.
Continue from NEXT (drmTMB Phase 1). Do not start drmSEM `R/`.
Do not emit `impute_joint`.

HUMAN GATE: G1 before drmSEM `R/`.
