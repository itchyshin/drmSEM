# Plan vs actual — S6 A7 clone tranche pause (2026-08-27)

Reconciler: this Cursor lane (docs only). Plan:
`LOOP/GOAL.md` / `LOOP/ultra-plan.md` / `LOOP/notes/A7-consumer-contract.md`.
Predecessor closeout:
`docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md` (A12; A7
deferred). Shinichi: **"pause A7"**.

Counts as filed: **adaptive 1 · drift 0 · unclear 0**.

Filed here, not at `docs/dev-log/plan-actual/`: that path is
**gitignored** in this repo.

This is an **honest stop**, not a capability closeout. The clone
tranche shipped the cells that were clones of Gamma × Bernoulli.
Remaining #962 leftovers need **new derivations** or an
**expand-gated** engine cell. Parallel siblings pursue those
separately. This lane does **not** implement them.

capability-status stays **`partial`**. No `"covered"`. Not FIML.

---

## Why pause (Shinichi's named decision)

The remaining cells are not another A7c-2-style lift:

| Leftover | Why this lane stops | Who owns it now |
|---|---|---|
| **student** | Needs a `nu` ABI / leaf derivation that does not exist on the current engine. Not a clone of Gamma × Bernoulli. | Parallel sibling |
| **zi + `mi`** (`zi_poisson`, `zi_nbinom2`, …) | A path to `zi` is not a path to the conditional mean; `zi` + `mi` is already refused. Mixture observed-data likelihood is a new derivation, not a family-list edit. | Parallel sibling |
| **nbinom2 × Gaussian** | Engine G0 rejected this as the first #962 cell. nbinom2 already has Bernoulli `has_mi`; widening the *predictor* catalogue is expand-gated engine work. | Parallel sibling |

Extra-#962 `truncated_nbinom2` only if Shinichi asks. Do not start
any of these on this pause branch.

---

## Cells that landed (clone tranche + Phase 1 Gaussian k=2)

| Cell | drmTMB engine | drmSEM consumer | Ledger |
|---|---|---|---|
| Gaussian k=2 independent `mi()` | #1086 `1cc1985cd` (0.7.0) | #46 `7280125` (A8–A11) | V-79 / V-82 / V-120 |
| Gamma × Bernoulli | #1088 `6e553879` | #49 `ae2b925` (A7c-2) | V-122 / V-122b |
| lognormal × Bernoulli | #1092 `7c104bbd5` | #50 `1e5d4cf` (A7c-3) | V-123 / V-123b |
| beta_binomial × Bernoulli | #1094 `4c34c9bb` | #51 `e78bb94` (A7c-4) | V-124 / V-124b |

Kickoff kit: drmSEM #48 `1593a23` (A7c-0; docs/LOOP only).
G-engine / G-engine-ln / G-engine-bb are **discharged**.

`main` at this pause: drmSEM `25c4fe2` (A7c-4 AGENT_LOG stamp).
Engine `main` at this pause: drmTMB `4c34c9bb` (#1094).

---

## Slice table (A7c)

| ID | planned | actual | tag | note |
|---|---|---|---|---|
| A7c-0 | LOOP kit + consumer contract | #48 `1593a23` | — | Docs only |
| A7c-1 | Wait for first new-family engine PR | drmTMB #1088 `6e553879` | — | G-engine discharged |
| A7c-2 | Lift Gamma × Bernoulli only | #49 `ae2b925` | — | V-80b / V-122 |
| A7c-3 | lognormal × Bernoulli | #50 `1e5d4cf` | — | V-80e / V-123 |
| A7c-4 | beta_binomial × Bernoulli | #51 `e78bb94` | — | V-80f / V-124 |
| clone leftovers | student / zi_* / nbinom2 × Gaussian as later clones | **PAUSED** | adaptive | Not clones. Handed to siblings. This file. |

---

## PRs and merge shas

| PR | Repo | Merge sha | What |
|---|---|---|---|
| [#48](https://github.com/itchyshin/drmSEM/pull/48) | drmSEM | `1593a234ec6409092de4b7367b4b7aadfefca67a` | A7c-0 kit + contract |
| [#1088](https://github.com/itchyshin/drmTMB/pull/1088) | drmTMB | `6e553879753a2a932ed09d2bba19b21a4b1e00d2` | Gamma `has_mi` |
| [#49](https://github.com/itchyshin/drmSEM/pull/49) | drmSEM | `ae2b925521555e604101a58ed821e33d95c3661b` | Gamma consumer |
| [#1092](https://github.com/itchyshin/drmTMB/pull/1092) | drmTMB | `7c104bbd5fb796b02e75bf319e01701fb902067e` | lognormal `has_mi` |
| [#50](https://github.com/itchyshin/drmSEM/pull/50) | drmSEM | `1e5d4cfbef3d1e130f205a910b86750ecf5f1fc0` | lognormal consumer |
| [#1094](https://github.com/itchyshin/drmTMB/pull/1094) | drmTMB | `4c34c9bbca35be93d1ebad997d2d15d02024712e` | beta_binomial `has_mi` |
| [#51](https://github.com/itchyshin/drmSEM/pull/51) | drmSEM | `e78bb9465ffe4328825b5313cefe26222ccd79e0` | beta_binomial consumer |

---

## Evidence vs claim

| Claim | Evidence | Match? |
|---|---|---|
| Clone tranche shipped three #962 family cells | #49 / #50 / #51 on `main`; V-122..V-124 | yes |
| Earlier Gaussian k=2 still live | #46; V-79 / V-82 / V-120 | yes |
| capability stays `partial` | `docs/design/capability-status.md` S6 row; no edit in this pause | yes |
| Leftovers are not covered | student / zi+mi / nbinom2 × Gaussian still fail loud or are engine-gated | yes |
| This pause implements no leftover | No `R/` on this branch | yes |

---

## What this pause does **not** claim

- A general missing-data SEM.
- FIML, `impute_joint`, or across-node imputation uncertainty.
- student, zi+`mi`, or nbinom2 × Gaussian as shipped cells.
- capability-status `"covered"`.

---

## Lane

Fresh worktree `~/local-scratch/lanes/drmSEM-s6-a7-pause` on
`cursor/lane-s6-a7-pause` from `origin/main` @ `25c4fe2`. Did **not**
reuse `drmSEM-s6-a7-consumer` (that worktree still sits on
`cursor/lane-s6-a7-consumer`). MAG-completeness / MAG-wire /
S3-grouping untouched. Never `git add -A`.
