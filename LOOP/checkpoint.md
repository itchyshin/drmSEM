GOAL: see LOOP/GOAL.md.  STATE: LANE COMPLETE. A1-A7 landed, all CI-green on three
platforms, reconciled, all reconciliation drifts closed. Two items remain that this
lane is MECHANICALLY unable to do (below) -- they need the human, not more work.

ARCS DONE (each verified by log/artifact, never by exit code; run SHA recorded):
- A1 vignette tangling — 35 headers given explicit `eval`, 2 authoring bugs fixed.
  Verified 4 ways incl. tangling all 13 vignettes (ZERO engine calls emitted).
  R CMD check 1 ERROR/3N -> 0 ERROR/2N.                       CI green @5b15fef
- A2 ordinal + spatial — test-ordinal.R (8/28), test-spatial.R (2/11). Recovery
  0.5009/0.9330 vs true 0.500/0.900, seed 101. Two limitations PINNED (V-90 latent
  mu; V-91 p_gt exactly 0).                                    CI green @94b3073
- A4 nominal link — 4 families named that reached the fallback; label already correct
  so no output changed. V-95 locks the table to the sampler list. CI green @94b3073
- A3 check_sem — test-diagnostics.R (8/26). Row content live; every warning branch on
  HAND-BUILT objects (the Windows lesson).                      CI green @a1b68cf
- A5 hurdle gap — PINNED as a defect, fix gated.                CI green @a1b68cf
- A6 drm_psem (ADDED ARC) — test-psem.R (4/21). A documented interface with zero
  tests. Interfaces asserted to agree on COEFFICIENTS, not just shape. CI green @e341646
- A7 hurdle FIX (A5's gate, approved) — drm_effective_family() prefers model_type for
  an explicit allow-list only, so zi_poisson/zi_nbinom2 cannot regress (V-104 asserts
  that). Zero fraction 0.4444 vs drmTMB's 0.4446.               CI green @f05570f

NEXT: nothing queued. Remaining roadmap (S2 m-separation, S3 scale-aware d-sep) is
  FENCED and needs a fresh plan gate — do not start it from this checkpoint.

OPEN — MECHANICALLY BLOCKED FOR THIS LANE (not deferred work; the lane cannot do them):
1. WORKFLOW CI GATE. `git apply LOOP/workflow-ci-gate.patch` then commit+push.
   Retried after explicit authorisation and rejected again: the push token lacks OAuth
   `workflow` scope, which chat authorisation cannot grant. The commit was backed out
   locally because carrying it would block every later push.
   ** WITHOUT THIS, A1 IS FIXED BUT UNGUARDED — CI still cannot see that class. **
2. `.uinit/` deletion. `rm` is denied by the harness permission layer. Deliberately NOT
   worked around by re-spelling it (e.g. python shutil.rmtree): evading a denied
   command is the wrong instinct even for a safe deletion. Already .Rbuildignore'd, so
   it costs no check NOTE; the directory is still on disk.

TRUTH LIVES IN: origin/main @ f05570f.
  Suite 948 pass / 0 fail / 3 skip / 10 warn  (lane started at 817).
  R CMD check 0E / 0W / 2N  (lane started at 1E / 0W / 3N).
  Both remaining notes pre-existing: ggplot NSE bindings in plot.drm_effect;
  symbolizer not installed. drmTMB pinned at INSTALLED 0.6.0.

RECONCILED: docs/memory/PLAN-ACTUAL-2026-08-15-defect-lane.md (adaptive 7/drift 4/
  unclear 1). Filed there, not at the doctrinal docs/dev-log/ path, because that path
  is GITIGNORED — an unreachable deliverable is a non-deliverable. All four drifts
  closed; one reconciler finding was partly refuted with evidence (commits are not
  pushes: four pushes, each awaited green).

LESSONS THIS LANE PAID FOR, worth carrying:
- Two pushes per arc cancels the first CI run. One push per arc.
- Dispatch audits the MODEL and never the TOOL GRANT — hit twice: a reconciler with no
  Bash/Write, and a verifier run against a tree being concurrently edited.
- A verification claim should carry its run SHA. Commit cadence cannot distinguish
  "pushed and waited" from "pushed and ran on", and the reconciler rightly could not
  tell.
- Test a mechanism where it is DETERMINISTIC (hand-built objects) and only the
  CONTRACT live. The Windows failure came from asserting an optimizer's failure mode.

RESUME: Read LOOP/GOAL.md, then this file. Re-run lane_preflight.sh and expect FOREIGN
  LANE ACTIVE — on 2026-08-15 that was a FALSE POSITIVE caused by this lane's own
  direct-to-main commits; verify against live peer sessions before believing it.
