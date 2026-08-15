# GOAL — drmSEM defect-and-evidence lane (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file. Unsure after a
compaction? Re-read THIS, then checkpoint.md, then ultra-plan.md, then continue.

## Mission
Close the **silent-wrong-answer class** in drmSEM: every place the package returns a
plausible-looking number, or advertises a capability, with nothing verifying it. Five arcs
(A1..A5). Done when each is fixed or explicitly documented as a known limitation, with a test,
and CI is green on all three platforms.

## Headline
If only one thing ships: **A1** — six vignettes execute code under `R CMD check` that their
authors believed was disabled. CI structurally cannot see it.

## Invariants (never violated, even after compaction)
- ONE lane: `drmSEM defect-and-evidence`, on `main`. Re-run `lane_preflight.sh` each arc.
  Note: it reports FOREIGN LANE ACTIVE from our OWN direct-to-main commits — verify against
  live peer sessions before believing it.
- Verify in this order, no shortcuts: full suite -> R CMD check -> push -> CI green on
  Windows+Ubuntu+macOS. **Read the log, not the exit code.**
- Explicit paths on every `git add`. NEVER `git add -A`.
- NEVER delete or commit `man/figures/drmsem-thermal-*.png` or `tools/render-readme-thermal.R`
  (PROTECTED — they carry reviewed biology corrections and were never committed).
- Pin drmTMB: tests run against the INSTALLED build. Record its version each arc; two drmTMB
  sessions are live in other lanes.
- A claim with no test is a limitation to document, not a capability to advertise.

## Authoritative WHAT
`LOOP/ultra-plan.md` (detail wins there). This file wins on "what must never be lost".

## Definition of done
A1 vignettes tangle-safe + CI able to see regressions · A2 ordinal evidence exists and the two
silent-wrong-answer findings are pinned · A3 check_sem covered beyond nobs · A4 nominal_link
gaps closed · A5 hu gap documented (fix gated) · every arc pushed and CI-green · ledgers updated.

## Gates (STOP and wait for the human)
new public capability claim · estimand/semantics/charter change · anything destructive ·
a surprise that invalidates the plan.
