# GOAL — drmSEM Step 2 S3 grouping (IMMUTABLE — re-read at the top of EVERY arc)

## Mission
Stop Fisher's C from inheriting anti-conservative p-values on mis-scaled
d-separation claims, without silently testing a different SEM than the user
specified.

## Headline
Estimand A: status `wrong_scale`; those p-values do not enter Fisher's C.

## Invariants
- ONE lane: `claude/lane-s3-grouping` at `~/local-scratch/lanes/drmSEM-s3-grouping`.
  Do not touch MAG-completeness or the merged MAG-wire worktree.
- Locked estimand A (G0). Do **not** auto-refit both sides inside `dsep()`.
  Do **not** add `(1 | g)` only to the augmented fit.
- Q3: `model_set()` / CICc inherit C on remaining valid claims (do not refuse
  the whole candidate).
- Touch only the scale/status block of `R/dsep.R`. Do not retouch MAG
  `basis_set_mag()`.
- Never call a non-mean path a mean effect.
- Explicit paths on every `git add`. NEVER `git add -A`.
- Never push, merge, or publish — those are HUMAN GATES.

## Authoritative WHAT
`LOOP/ultra-plan.md` (approved G0). This file wins on "what must never be lost".

## Definition of done
`03-dsep.md` states the scale rule · D-21 committed · `dsep()` marks
`wrong_scale` and excludes those p-values from C · V-109c recovers the known
DGP (true independence is not condemned via C) · V-110 still silent · suite
green · ledgers updated · LOOP kit is this Step 2 kit, not the inherited
defect/MAG-wire kit.

## Pre-authorisation
- Routine scoped edits, local commands, tests, `devtools::document()` /
  `devtools::test()` / `devtools::check(error_on = "never")` /
  `tools/check-vignette-tangling.R`, local commits: CONTINUE.
- Optional remote: none (no push, no PR).
- Must stop: merge/release/public claim; credentials; destructive work
  outside this worktree; Step 3 drmTMB; new estimand beyond A.

## Out of scope
- Step 3 drmTMB engine items
- Orthogonal-hierarchy claim skipping
- Auto-adding `(1 | g)` to the stored node
- MAG semantics beyond the already-merged wire
