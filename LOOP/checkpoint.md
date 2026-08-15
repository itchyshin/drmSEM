GOAL: see LOOP/GOAL.md.  STATE: LANE COMPLETE. A1-A5 landed, all CI-green, reconciled, drifts closed.

ARCS DONE (verified by log/artifact, never by exit code):
- A1 vignette tangling — 35 headers given explicit `eval`; 2 authoring bugs fixed.
  Verified 4 ways: independent header audit reproduced the count (35 missing, 0 in
  every passing vignette); tangling all 13 vignettes emits ZERO engine calls;
  R CMD check 1 ERROR/3N -> 0 ERROR/2N; suite unchanged. CI green 3/3 @5b15fef.
- A2 ordinal + spatial — test-ordinal.R (8 tests/28 assertions), test-spatial.R
  (2/11). Recovery x->m 0.5009 vs 0.500, m->y 0.9330 vs 0.900, seed 101 fixed.
  Two limitations PINNED (V-90 latent mu; V-91 p_gt degenerates to exactly 0).
  Corrected a half-wrong premise: spatial DID have evidence, under a phylo label.
  CI green 3/3 @94b3073.
- A4 nominal link — 4 families named that were reaching the fallback; the label was
  already correct, so no output changed. V-95 locks the table to the sampler list.
  CI green 3/3 @94b3073.
- A3 check_sem — test-diagnostics.R (8 tests/26 assertions). Row content live; every
  warning branch against HAND-BUILT objects (the Windows lesson). PUSHED, CI pending.
- A5 hurdle gap — PINNED not fixed (semantics gate). V-103: hu=0.9 gives BIT-IDENTICAL
  draws to no hu; zi=0.9 gives >80% zeros. A hurdle mediator reports sampler=TRUE and
  drops its zeros. False `hu` promise removed from the roxygen. PUSHED, CI pending.

ARC IN PROGRESS: none.

NEXT: RECONCILE — dispatch Melissa (Sonnet, medium) to diff plan vs actual across the
  six axes (scope · evidence · model routing · safety gates · public claims · handoff)
  -> docs/memory/PLAN-ACTUAL-2026-08-15-defect-lane.md. Then close the lane.

OPEN GATES (need human):
1. WORKFLOW CI GATE — unchanged. `git apply LOOP/workflow-ci-gate.patch`. This lane's
   token lacks OAuth `workflow` scope. WITHOUT IT A1 IS FIXED BUT UNGUARDED.
2. CAPABILITY CLAIM for ordinal/spatial — evidence now exists (39 assertions) but
   adding a "covered" row to capability-status.md/NEWS is a new public capability
   claim, which this lane gates. Proposed wording, for approval:
     | Ordinal (`cumulative_logit`) nodes | covered | `drm_node(family =
     drmTMB::cumulative_logit())` | paths() labels mu/logit and hides the cutpoints;
     dsep()/Fisher's C test the claim; effects close additively; latent-scale recovery
     0.5009/0.9330 vs true 0.500/0.900 (test-ordinal.R, V-87..V-89b, seed 101).
     **Does not cover:** `mu` is the LATENT predictor not E[category] and
     target="mean" reports latent scale with no warning (V-90); a non-mean target
     returns exactly 0 (V-91); an ordinal node cannot be distributional (V-92). |
     | Spatially-structured nodes | covered | `relmat(1 | site, K = <matrix>)` |
     V-93/V-94; strictly more flexible than drmTMB's `spatial()` marker, whose only
     kernel is a fixed exponential with a heuristic range and whose mesh= is
     unimplemented. |
3. HURDLE FIX — keying on `model_type` instead of family name. Semantics change.
4. CLOSED — A3/A5 CI confirmed green: `a1b68cf` R-CMD-check success, pkgdown success.
   All five arcs are therefore CI-verified: 5b15fef(A1) 94b3073(A2,A4) a1b68cf(A3,A5),
   each green on windows + ubuntu + macos. Kept here rather than deleted so the record
   shows the gate was raised and then discharged with its run SHA -- which is the
   lesson the reconciliation drew.
5. `.uinit/` — permission layer blocks `rm` from this lane. Now .Rbuildignore'd so it
   causes no check NOTE; directory still on disk.

TRUTH LIVES IN: origin/main. Suite 918 pass / 0 fail / 3 skip / 10 warn (from 817).
  R CMD check 0E / 0W / 2N (from 1E / 0W / 3N). Both remaining notes pre-existing
  (ggplot NSE bindings; symbolizer not installed). drmTMB pinned INSTALLED 0.6.0.

RECONCILED: docs/memory/PLAN-ACTUAL-2026-08-15-defect-lane.md (adaptive 7 / drift 4 /
  unclear 1). Drifts owned and closed: the planned Haiku MECH-VERIFY was never
  dispatched (remediated after the fact, and the reason it went unnoticed is that
  arcs.md carried the budget line as if spent); capability-status' evidence anchor was
  stale at "205 blocks / 2026-07-19" despite the file being edited twice this lane; and
  11-validation-matrix.md had no V-87..V-104 rows. All three fixed at close-out.
  One reconciler finding was PARTLY REFUTED on review: it inferred from commit
  timestamps that no CI wait occurred between arcs. Commits are not pushes -- the lane
  made four pushes and each awaited green. The residual real finding (A3/A5) is gate 4.
  Recorded lesson: a verification claim should carry the run SHA and its per-platform
  conclusion, not be left to be re-inferred from commit cadence.

LESSON APPLIED MID-LANE: pushing code and checkpoint as two pushes cancelled the
  first CI run (the handover's "rapid successive pushes race"). One push per arc since.

RESUME: Read LOOP/GOAL.md, then this file, then LOOP/ultra-plan.md. Re-run
  lane_preflight.sh (expect FOREIGN LANE ACTIVE — on 2026-08-15 that was a FALSE
  POSITIVE from this lane's own direct-to-main commits; verify against live peer
  sessions). Then run RECONCILE and close.
