# Plan vs actual — drmSEM defect-and-evidence lane (2026-08-15)

Reconciler: Melissa (Sonnet). Plan: `LOOP/ultra-plan.md`. Arcs: A1–A5.
Counts as filed: **adaptive 7 · drift 4 · unclear 1**.

*Filed here, not at the doctrinal `docs/dev-log/plan-actual/` path: `docs/dev-log` is
**gitignored** in this repo, so a reconciliation report written there would be invisible
to the fresh session it exists to inform. An unreachable deliverable is a
non-deliverable.*

**Dispatch defect, recorded first because it shaped the report.** Melissa was routed to
the `systems-auditor` lens, which grants Read/Grep/Glob only — while her brief required
Bash (to re-run the suite and `R CMD check`) and Write (to file this report). She could
do neither, flagged it rather than fabricating a result, and substituted static
verification. That is the hub's documented failure mode — *dispatch audits the MODEL and
never the TOOL GRANT* — and this lane hit it **twice** in one day. Ada's error, not hers.
This file was written by the orchestrator from her returned content.

| axis | planned | actual | tag | note |
|---|---|---|---|---|
| Scope A1–A5 | all five land | all five landed: `8ffccea`(A1) `7f9f459`(A2) `94b3073`(A4) `bccb3b6`(A3) `32d1190`(A5); executed A1,A2,**A4,A3**,A5 | adaptive | no `dep` blocked the swap |
| DEFER fence | S2/S3/9 engine issues/estimands untouched | `R/dsep.R:86-90` m-sep comment pre-existing and unedited; `DRMTMB_ISSUES.md` items 1–9 unedited (item 7 only *cited* by V-92); zero S2/S3 hits in `DECISIONS.md` | adaptive | fence honoured |
| Evidence — counts | 817 → 856 → 884 → 910 → 918 | ledger shows exactly that. Independently re-derived from the five new files: 28+11+28+26+8 = **101** = 918−817 | adaptive | arithmetic closes on an independent count |
| Evidence — verify order | suite → check → push → CI green, before the next arc | **Partly refuted on review.** Melissa inferred from *commit* timestamps that no CI wait occurred. Commits are not pushes: the lane made **four** pushes (`8ffccea`, `5b15fef`, `94b3073`, `a1b68cf`), and the run history shows each awaited green before the next. A2+A4 were committed 3.5 min apart and pushed **together** after A1 went green; likewise A3+A5. | adaptive | the *residual* real finding is below |
| Evidence — A3/A5 CI | green before close | still `in_progress` at reconciliation time | **drift** | genuine; the lane's own checkpoint said "CI pending" but OPEN GATES did not list it |
| Model routing | MECH-VERIFY → Haiku · Agent, recurring per arc | **never dispatched.** `arcs.md` allocated `scout 1 (MECH-VERIFY, Haiku)`; it went unspent | **drift** | Ada's error. Remediated after the fact by an actual Haiku run; the budget line was aspirational until then |
| Gate — capability claims | new public claim gated | `capability-status.md` edits are (a) an A3 **correction** of a now-false "zero coverage" statement and (b) an A5 **limitation** disclosure. The 20-row matrix has **no** Ordinal or Spatial row; `NEWS.md` has zero A1–A5 content | adaptive | the one genuine new-capability case was correctly left as open gate #2 |
| Gate — hurdle / ordinal-NA | both deferred | `drm_sample_family()` body has no `params$hu`; `test-hurdle-gap.R:34` proves bit-identical ignoring. `test-ordinal.R:121` proves `p_gt` still returns exactly 0, not `NA`, with an in-code note that the change is deliberately deferred | adaptive | both honoured |
| Public claims | numbers not to exceed evidence | seed 101 fixed; `hu` claim is a real `expect_identical`; A4's "no output changed" confirmed (all four families resolve to `identity`, the old fallback value); V-90/91/103 labelled limitations everywhere | adaptive | one imprecision: 0.5009/0.9330 are a narrated snapshot; the tests bound them by tolerance (0.12/0.15), not bit-for-bit |
| Ledger freshness | "ledgers updated" | `capability-status.md`'s Evidence-anchors block still claims "205 `test_that()` blocks across 25 files, 2026-07-19" — stale *before* this lane and not corrected despite the file being edited twice. `11-validation-matrix.md` has zero hits for V-87..V-104 | **drift** | pre-existing but uncorrected; fixed in the close-out commit |
| Handoff — open gates | accurate and actionable | all four verified real: workflow file unmodified; matrix lacks the rows; hurdle unfixed; `.uinit/` present and `.Rbuildignore`'d at line 22 | adaptive | — |
| Handoff — CI gap | — | OPEN GATES had no "confirm A3/A5 CI" item | **drift** | added as gate #5 |
| Working tree | — | `M AGENTS.md` uncommitted, unexplained by the plan | unclear | the `route.py` LOAD-FIRST manifest regenerating; benign, but was an unexplained loose end |

## Drift → owner

1. **A3/A5 CI unconfirmed at close** → Ada. Added to OPEN GATES; confirm before treating them as closed.
2. **Haiku MECH-VERIFY never ran** → Ada. Remediated by dispatching it for real; `arcs.md` should not carry an unspent budget line as if spent.
3. **Stale evidence anchor + missing V-numbers** → Rose. Fixed in close-out.
4. **`AGENTS.md` loose end** → benign (`route.py` manifest); resolved.

## The lesson worth keeping

The reconciler was right that the *record* did not prove CI discipline, even though the
discipline was in fact followed — commit cadence was the only evidence available to her,
and commit cadence cannot distinguish "pushed and waited" from "pushed and ran on".
A verification claim should be recorded with the artifact that proves it (the run SHA and
its per-platform conclusion), not left to be re-inferred from timestamps.
