# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-4 MERGED.** G-engine-bb
discharged. drmSEM `main` @ `e78bb94` lifts beta_binomial ×
Bernoulli. capability-status stays **`partial`**.

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

ARC IN PROGRESS: none on this commit.

NEXT: #962 leftovers are **student** (`nu` not on leaf ABI — wait)
and **zi_*** (`zi` + `mi` already refused — wait). Extra-#962
`truncated_nbinom2` only if Shinichi asks. Do **not** start
nbinom2 × Gaussian. Do **not** start student.

CELL JUST CONSUMED: **beta_binomial × Bernoulli**
(`mp-beta-binomial-bernoulli`). Ledger: V-124 / V-124b ↔ #1094
`4c34c9bb` / #51 `e78bb94`.

OPEN GATES:
- **G-engine-bb** — **discharged.**
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- drmSEM `main` @ this commit (post #51)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1094 `4c34c9bb`
- MAG-completeness: **do not touch**

RESUME: A7c-4 is closed. Honest stop: remaining #962 cells need
new derivations. Never `git add -A`.
