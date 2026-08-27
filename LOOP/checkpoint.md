# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7 clone tranche PAUSED.**
Shinichi: "pause A7". capability-status stays **`partial`**.

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
  `test-imputation.R`: **88 pass / 0 fail / 0 skip**. CI: macos /
  ubuntu / windows green.

ARC IN PROGRESS: **none.** Clone tranche **PAUSED** (named decision).

LEFTOVERS (named; not this lane):
- **student** — needs a `nu` ABI / leaf derivation. Not a clone.
- **zi + `mi`** (`zi_poisson`, `zi_nbinom2`, …) — mixture; `zi`
  is not the conditional mean; already refused. New derivation.
- **nbinom2 × Gaussian** — expand-gated engine cell (G0 rejected
  it as first #962 cell). Handed to a sibling.
- Extra-#962 `truncated_nbinom2` only if Shinichi asks.

Do **not** implement those leftovers here. Parallel siblings
pursue nbinom2×Gaussian, student, and zi+mi separately.

CELL LAST CONSUMED: **beta_binomial × Bernoulli**
(`mp-beta-binomial-bernoulli`). Ledger: V-124 / V-124b ↔ #1094
`4c34c9bb` / #51 `e78bb94`. Earlier clone cells: Gamma (#49 /
#1088) and lognormal (#50 / #1092). Phase 1 Gaussian k=2 remains
live (#46 / #1086).

OPEN GATES:
- **G-engine / G-engine-ln / G-engine-bb** — discharged.
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- drmSEM `main` @ `25c4fe2` (post A7c-4 stamp)
- Pause note: `docs/memory/PLAN-ACTUAL-2026-08-27-s6-a7-pause.md`
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB `main` @ `4c34c9bb` (#1094)
- MAG-completeness: **do not touch**

RESUME: clone tranche is paused. Remaining cells are sibling
work, not A7c-5. Never `git add -A`.
