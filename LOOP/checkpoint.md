# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-1 done. G-engine discharged.**
Engine #1088 MERGED. drmSEM `R/` is **not** lifted on this commit.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + `LOOP/notes/A7-consumer-contract.md` (#48
  `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
  Cell `mp-gamma-bernoulli` (Gamma × one Bernoulli `mi()`).

ARC IN PROGRESS: none on this commit.

NEXT: **A7c-2 as a separate consumer PR** (Gamma lift only). Do not
implement `R/` here. Do not start lognormal.

FIRST CELL (locked): **Gamma × Bernoulli** (`mp-gamma-bernoulli`,
#962 first *unwired* family). **Not** nbinom2 × Gaussian — that is a
later expand-gated-family cell (engine G0). nbinom2 already has
Bernoulli `has_mi`; do not treat it as the A7 first cell.

G-ENGINE OPEN STEPS (A7c-2, new branch from `main`; not this commit):
1. Branch e.g. `cursor/lane-s6-a7c-gamma-lift` from drmSEM `main`.
2. Confirm the installed engine is drmTMB `main` @ `6e553879` (or
   later): `drmTMB:::drm_missing_predictor_families()` includes
   `"gamma"`. If V-80 fails that way, the lock is working.
3. Add `"gamma"` to `drm_impute_response_families()` only.
4. V-80b: Gamma + **binary** parent emits; Gamma + continuous parent
   still fails loud. Leave other leftovers unchanged.
5. Identity first (auto-derived ≡ hand-written `mi()` +
   `impute_model()`), then MAR known-DGP recovery.
6. Ledger: one new V-number ↔ engine `mp-gamma-bernoulli` / #1088
   `6e553879`.
7. `13-missing-data.md` names the cell. capability-status stays
   `partial`. No `"covered"`. Not FIML. Not `impute_joint`.
8. Stop. Next *engine* family is lognormal, not this consumer PR.

OPEN GATES:
- **G-engine** — **discharged** (#1088 on drmTMB `main` @ `6e553879`).
  Opens A7c-2; does not authorise a same-PR `R/` lift.
- **G-claim** — later; default **keep `partial`**. No `"covered"`.

TRUTH LIVES IN:
- drmSEM `main` @ this commit (post #48)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1088 `6e553879` (Gamma `has_mi`)
- Phase 1 engine: drmTMB #1086 `1cc1985cd`
- MAG-completeness: **do not touch**

RESUME: You are the S6 A7 **consumer** lane after G-engine.
READ FIRST: LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md
→ LOOP/notes/A7-consumer-contract.md → repo AGENTS.md.
CONTINUE FROM: **A7c-2 on a new branch**. Do not lift `R/` on `main`
in the merge-follow-up commit. capability-status stays `partial`.
Never `git add -A`.
