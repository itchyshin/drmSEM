# Plan vs actual — MAG m-separation wire (2026-08-26)

Reconciler: Melissa (Cursor closeout). Plan: `LOOP/GOAL.md`.
Counts as filed: **adaptive 3 · drift 0 · unclear 0**.

Filed here, not at `docs/dev-log/plan-actual/`: that path is **gitignored**
in this repo (same reason as the 2026-08-15 defect-lane report).

| axis | planned | actual | tag | note |
|---|---|---|---|---|
| Scope | `latent=` + MAG Cor. 5.3 basis; guardrail 3; S&D + DGP tests; docs/memory; no selection latents; no push | All landed. S1 `86564c3`, anterior `66a80e9`, S3 `679b615`, S2 `df2ea9f`, S4 `587d08a`. Selection argument still absent. No push. | adaptive | S2 fixture review fixed B from exogenous → endogenous before commit |
| Evidence | suite green; printed claim set + DGP where DAG d-sep is wrong | V-117 / V-118 / V-119 validated. Suite **1026 pass / 0 fail / 3 skip / 10 warn**. Warning/skip counts held vs V-116 baseline (987). | adaptive | S3 was already green at 16 pass when this closeout started; not redone |
| Model routing | Cursor on MAG-wire worktree; Grok/Composer for the slice | Cursor Grok on `claude/lane-mag-wire`. Lease `cursor:drmSEM`. | adaptive | Branch name is Claude's; ownership is this Cursor closeout (Shinichi assigned) |
| Safety gates | no push/merge; no evidence-worktree edits; LRT unchanged | No push. `drmSEM-mag-completeness` untouched. `dsep()` LRT body unchanged; only claim generation + latent filter. | adaptive | — |
| Public claims | docs/roxygen; no ungated capability-status row | `14-m-separation.md` + `05-roadmap.md` + roxygen + bib. **No** `capability-status.md` / NEWS / README row. | adaptive | new public capability claim stays gated |
| Handoff | checkpoint DONE; residual gap stated | `LOOP/checkpoint.md` DONE. OQ-16 is residual gap Y. Next action is Shinichi review + optional merge. | adaptive | — |

## Drift → owner

None.

## Judgement calls (not drift)

1. **S2 fixture treated B as exogenous.** Review-fixed before commit so V-117 matches S&D Fig 1 (`Y → B` endogenous). Adaptive.
2. **`05-roadmap.md` was still "DESIGN ONLY".** Updated in S4 so the roadmap does not contradict the wire. Adaptive; not a new public capability claim.
3. **D-20 / OQ-16 claimed by committing** on this branch. Historical other-branch edits to the same memory files are June-era and do not contain a MAG decision.

## The lesson worth keeping

The load-bearing S2 assertion is the *printed claim set*, not "the helper returns a data frame". A fixture that listed B as exogenous would still have passed a weaker "A ⊥ Y | {}" check and missed `A _||_ B | {Y}`.
