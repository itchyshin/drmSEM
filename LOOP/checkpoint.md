GOAL: see LOOP/GOAL.md.  STATE: A1 landed and pushed; awaiting CI. A2 next.

ARCS DONE (verified):
- RECON — two Explore sizings. Verified by their findings changing the plan: one
  REFUTED a premise (spatial already has evidence at test-phylo-cov.R:199-243), the
  other found the knitr tangle root cause. Both corroborated independently before use.
- A1 — vignette tangling. Verified FOUR ways, not by exit code:
  (1) independent header audit reproduced the agent's count exactly (35 missing; 0 in
      every passing vignette);
  (2) tangled all 13 vignettes in memory -> ZERO engine calls emitted;
  (3) R CMD check 1 ERROR/0W/3N -> 0 ERROR/0W/2N, both remaining notes pre-existing;
  (4) suite unchanged 817/0/3/10.
  Pushed as 8ffccea.

ARC IN PROGRESS: none. (A1's CI run is the outstanding check — see OPEN GATES.)

NEXT: A2 — ordinal evidence + spatial relabel.
  New tests/testthat/test-ordinal.R (~150 lines): paths() component/link labelling,
  cutpoints not leaked into `from`, dsep()/Fisher's C, latent-scale recovery with a
  FIXED SEED. Plus ~40 lines near test-phylo-cov.R:199 for a distance-kernel relmat()
  case carrying dsep() + effects.
  MUST pin as known limitations (both are silent-wrong-answer, same class as the lane):
   - cumulative_logit `mu` is the LATENT linear predictor, not E[category]; measured
     ≈(-1.7,1.6) against categories 1-4. target="mean" reports latent scale, NO warning.
   - target="p_gt" returns 0.0000 for EVERY quantity (mean fallback collapses both
     scenarios). The sampler warning fires; the RESULT is a degenerate zero.
  Do NOT quote the old audit's 0.518/0.875 — irreproducible; an independent run gave
  0.4877 vs true 0.5. Fix a seed, pin fresh numbers.
  Engine constraint to record: cumulative_logit accepts only a `mu` formula, so an
  ordinal node cannot be distributional.

OPEN GATES (need human):
1. WORKFLOW CI GATE — cannot push `.github/workflows/`: this lane's OAuth token lacks
   `workflow` scope (remote rejected). The 6-line change is saved at
   LOOP/workflow-ci-gate.patch. Apply with:
       git apply LOOP/workflow-ci-gate.patch && git add .github/workflows/R-CMD-check.yaml
   It sets `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_: false` so CI can catch A1's defect class.
   WITHOUT IT, A1 IS FIXED BUT UNGUARDED — CI still cannot see a regression.
   NOT a blocker for A2-A5; the loop continues.
2. `.uinit/` deletion — permission layer blocks `rm` from this lane. Now .Rbuildignore'd
   so it no longer causes a check NOTE, but the directory is still on disk.

TRUTH LIVES IN: origin/main @ 8ffccea (pushed). LOOP/{GOAL,arcs,ultra-plan,checkpoint}.md
  committed. Baseline to beat: 817 pass / 0 fail / 3 skip / 10 warn; check 0E/0W/2N.
  drmTMB pinned at INSTALLED 0.6.0 — two drmTMB lanes are live elsewhere; re-check each arc.

RESUME: Read LOOP/GOAL.md, then this file, then LOOP/ultra-plan.md. Re-run
  `bash ~/shinichi-brain/tools/lane_preflight.sh` (expect FOREIGN LANE ACTIVE — verify it
  against live peer sessions before believing it; on 2026-08-15 it was a false positive
  caused by this lane's own direct-to-main commits). Then execute A2 above.
