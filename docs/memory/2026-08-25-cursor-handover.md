# Handover: drmSEM m-separation completeness hunt (Claude → Cursor)

Meta: 2026-08-25 · `AUTHOR = claude` · `TARGET = cursor` · authorised by Shinichi ("go drmSEM", 2026-08-25)

**You are a fresh Cursor lane. You inherit no chat.** This document plus the repo is your entire state.

---

## 0. READ FIRST — what this lane is and is not

Your job is the **designed, READ-ONLY evidence arc** at
[`docs/memory/2026-08-15-next-arc-mag-completeness.md`](2026-08-15-next-arc-mag-completeness.md).
That file is the authoritative GOAL + arcs (A1→A4) + invariants + gates. **Do not restate or
"improve" it — seed your `/goal` LOOP kit from it verbatim.** This handover only adds the state
you need to start safely.

One sentence of mission: find (or honestly fail to find) a published result that pairwise
m-separation claims imply GLOBAL m-separation for a MAG, and write the decision packet so
Shinichi can pick among (a)/(b)/(c). **You gather evidence; you do not decide, and you do not
implement.**

## 0b. LOOP/ collision — read before touching LOOP/ (added 2026-08-25, post-commit)

`LOOP/` in this checkout is **not yours and not empty**: it holds the CLOSED 2026-08-15 Claude
lane's kit (its `checkpoint.md` says "LANE COMPLETE AND CLOSED … no unblocked work left").
That checkpoint describes the *previous* lane, not yours — do **not** read it as your state,
and do not conclude from it that there is nothing to do. Before seeding your own kit:
`mv LOOP LOOP-archive-2026-08-15` (it is gitignored/local-only, so this touches no git state),
then build yours fresh from the arc doc. The archived kit's `workflow-ci-gate.patch` is that
old lane's parked, **unapplied** CI artifact — leave it archived; applying anything is G1.

## 1. Rehydrate (do these in order, before any work)

1. Read the repo's `AGENTS.md`.
2. Run `bash ~/shinichi-brain/tools/lane_preflight.sh` from the repo root; state the LANE line.
3. Read the arc doc (above) in full. It wins over this handover on anything it covers.
4. Classify every item in §3 below as `OWED / DONE / RETRACTED / PROTECTED` against live git
   state, then act only on `OWED`.

## 2. Plan gate (required before A2)

The arc doc says it "needs its own plan gate." Shinichi's "go drmSEM" opened the **lane**, not
the loop. So: build the LOOP kit (GOAL.md, arcs.md, checkpoint.md seeded from the arc doc), run
A1 (writing the proposition is safe and self-verifying), then **present the kit + A1's
proposition to Shinichi as G0 and wait for one approval** before A2's corpus interrogation.
After that approval, loop A2→A4 without further prompts, stopping only at the arc doc's gates.

## 3. Landing state (gate run 2026-08-25; classify at rehydrate time)

| Item | State | Why / resume |
|---|---|---|
| `main` = `4412cd4` (Shannon charter) | **LANDED** — pushed to origin 2026-08-25 by Claude | nothing owed |
| `chore/worktree-house-rule` (1 unpushed) | **PROTECTED** — another lane's declared carry-over (2026-08-15 handover) | do not touch, do not push |
| `codex/issue-2-hero-dag` (1 unpushed, upstream gone) | **PROTECTED** — same declaration | do not touch |
| `.git/index.lock` (0 bytes, 2026-08-25 06:03) | **REPORTED to Shinichi** — stale; blocks commits until he clears it | if still present when you start: report again, never `rm` it yourself |
| This handover file | **CARRIED-OVER uncommitted** — the stale lock blocked the commit | commit it (`git add docs/memory/2026-08-25-cursor-handover.md && git commit`) once the lock is gone; it IS in Dropbox meanwhile |

## 4. Environment Cursor actually needs

- **Working dir:** `/Users/z3437171/Dropbox/Github Local/drmSEM` (branch `main`; your loop's
  scratch lives wherever `/goal` puts it — `~/local-scratch` is allow-listed).
- **No R toolchain required.** This arc reads literature, not code. You never run
  `devtools::*`. The only package file you may write is `docs/design/14-m-separation.md`
  (append-only addendum, A4) — invariant 1 of the arc doc.
- **Research loop:** the `/notebook` skill (NotebookLM, Ranga's loop) for A2. Personal Google
  account, never UAlberta Workspace. Its auth may need `nlm login` — if it fails, degrade to
  WebSearch + primary PDFs; do not block the arc on it.
- **Primary source access:** Richardson & Spirtes via **UW TR 375** (Project Euclid is
  paywalled). Cite by section/theorem, never page.
- **Verification command (safe, read-only):** `git status --short && git log --oneline -3` —
  your tree should stay clean apart from `LOOP/` and, at A4, the one design doc.
- **Never stage:** anything under `R/`, `tests/`, the two PROTECTED branches' content, or a
  blanket `git add -A` (forbidden repo-wide).

## 5. Stop conditions (from the arc doc — restated because they are the contract)

- **G1:** never wire MAG into `basis_set()`/`dsep()` — whatever A3 concludes.
- **G2:** no `git push` from the loop; commit locally, surface for approval.
- **G3:** a surprise that invalidates the plan (e.g. `R/mag.R` conversion *wrong*, not just
  incomplete) → stop, back to Shinichi.
- A2's 70-minute risk branch is binding: no result by then → A3 with the strongest available;
  the honest negative IS the deliverable.

## 6. Definition of done

Exactly the arc doc's: an actionable addendum in `docs/design/14-m-separation.md` — formal
proposition, per-source verdicts with section/theorem citations (UNVERIFIED marked), an
(a)/(b)/(c) recommendation with cost and residual gap, and the list of searches that returned
nothing. **Then STOP** and write the after-task report + handover per `~/shinichi-brain/protocols/`.

---

## Resume prompt (paste into a fresh Cursor agent opened in this repo)

```text
Read AGENTS.md and docs/memory/2026-08-25-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
