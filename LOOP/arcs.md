# arcs — drmSEM defect-and-evidence lane

Slice table. Member · model+effort · dispatch · time · files · dep · status.
Build slices run INLINE on the session model (Opus): they are coupled edits with
live-fit verification, and handing them to a fresh child costs more context than it saves.
Mechanical verification and reconciliation fan out.

| id | slice | member | model+effort | dispatch | est | files | dep | status |
|----|-------|--------|--------------|----------|-----|-------|-----|--------|
| RECON | sizing: vignette tangling + S1 ordinal/spatial | Explore x2 | Sonnet · medium | Agent | 0:07 | — | — | DONE (both landed; one premise refuted) |
| A1 | vignette tangle-safety: 24 headers + drmSEM.Rmd 11 + 2 authoring bugs + CI env gate | Grace | Opus · medium | inline | 1:30 | vignettes/*.Rmd, .github/workflows/R-CMD-check.yaml | — | pending |
| A2 | ordinal evidence + spatial relabel + pin 2 silent-wrong-answer findings | Curie | Opus · high | inline | 2:00 | tests/testthat/test-ordinal.R (new), test-phylo-cov.R | — | pending |
| A3 | check_sem() coverage beyond nobs | Curie | Opus · medium | inline | 1:00 | tests/testthat/test-diagnostics.R (new) | — | pending |
| A4 | drm_nominal_link() gaps (skew_normal + 3 bivariates) | Noether | Opus · low | inline | 0:30 | R/edges.R, tests | — | pending |
| A5 | hu documented-but-unread: document + test the gap | Fisher | Opus · medium | inline | 1:00 | R/simulate_effects.R roxygen, docs | — | pending (FIX is GATED) |
| MECH-VERIFY | per-arc: suite counts, artifact landed, links resolve, CI per-platform | — | Haiku · low | Agent | 0:10 ea | — | each arc | recurring |
| RECONCILE | Melissa: plan vs actual across the 6 axes | Melissa | Sonnet · medium | Agent | 0:15 | docs/dev-log/plan-actual/ | all | pending |

FAN-OUT BUDGET: checkpoint=`defect-lane` · new children ≤6 · scout 1 (MECH-VERIFY, Haiku) ·
  build 0 (inline) · ceiling 0 · reuse: none yet. RECON's 2 children were pre-G0.
LUNA SUITABILITY: yes — MECH-VERIFY is bounded, read-only, mechanical -> Haiku each arc.
ULTRA EFFORT: no.
SEARCH: inline repo + brain greps. Tier-b NotebookLM: not offered — no novelty/priority claim
  in this lane (all five arcs are defect closure, not new method).
PREFLIGHT: FOREIGN LANE ACTIVE reported, investigated, **false positive** — 5 peer sessions live,
  none on drmSEM (2x drmTMB, DRM.jl, pigauto, vault). Lane taken: `defect-and-evidence` on main.
REVIEW: Rose before any capability-surface wording change.
RECONCILE: Melissa (Sonnet, medium) at close -> docs/dev-log/plan-actual/2026-08-15-defect-lane.md
