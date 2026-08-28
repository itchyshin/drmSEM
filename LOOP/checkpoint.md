# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-5 in progress.** Engine
#1096 `5fdf834c1` student × Bernoulli `has_mi`. Consumer lift on
`cursor/lane-s6-a7-student`. The #52 pause named leftovers;
Shinichi then authorized student as a parallel hard case (not a
clone). capability-status stays **`partial`**.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + contract (#48 `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
- **A7c-2** — consumer Gamma lift. drmSEM **#49 MERGED**
  `ae2b925521555e604101a58ed821e33d95c3661b`.
- **A7c-3** — consumer lognormal lift. drmSEM **#50 MERGED**
  `1e5d4cfbef3d1e130f205a910b86750ecf5f1fc0`.
- **A7c-4** — consumer beta_binomial lift. drmSEM **#51 MERGED**
  `e78bb9465ffe4328825b5313cefe26222ccd79e0`.
- **sibling nbinom2 × Gaussian** — drmTMB #1095 `3c239a55e` /
  drmSEM #54 `2482e27`. `test-imputation.R`: **97/0/0**.

ARC IN PROGRESS: **A7c-5** student × Bernoulli consumer lift.

LEFTOVERS after this cell:
- **zi + `mi`** (`zi_poisson`, `zi_nbinom2`, …) — mixture; G0 (b)
  locked as D-23. Engine #1097 is a separate lane.
- Extra-#962 `truncated_nbinom2` only if Shinichi asks.

CELL LAST CONSUMED: **nbinom2 × Gaussian**
(`mp-nbinom2-gaussian`). Ledger: V-126 / V-126b ↔ #1095
`3c239a55e` / drmSEM #54 `2482e27`.
CELL IN FLIGHT: **student × Bernoulli** (`mp-student-bernoulli`)
↔ drmTMB #1096 `5fdf834c1` / V-125 / V-125b.

OPEN GATES:
- **G-engine / G-engine-ln / G-engine-bb** — discharged.
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- drmSEM this branch (A7c-5) rebased onto #54 `2482e27`
- Pause note: `docs/memory/PLAN-ACTUAL-2026-08-27-s6-a7-pause.md`
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1096 `5fdf834c1`
- MAG-completeness: **do not touch**

RESUME: finish A7c-5 after #1096 merges. Never `git add -A`.
