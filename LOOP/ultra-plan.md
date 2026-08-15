```
🎯 GOAL — drmSEM defect-and-evidence lane (~10 h, semi-autonomous)
Solo platform: Claude Code (this session)
Deliverable:   The latent defects this session surfaced are fixed and evidenced, and the
               capability surface stops claiming things no test backs.
HEADLINE:      Close the silent-wrong-answer class. Every arc here is a case where drmSEM
               returns a plausible number, or claims a capability, with nothing checking it.
IN SCOPE:      A1 vignette tangling · A2 ordinal evidence + spatial relabel · A3 check_sem
               coverage · A4 drm_nominal_link gaps · A5 hu / model_type keying
DEFER (fenced): S2 m-separation · S3 scale-aware d-sep · the 9 drmTMB engine issues ·
               anything needing a new estimand or a charter change
DISCIPLINE:    verify = full suite + R CMD check locally, THEN push, THEN CI green on all
               three platforms before the next arc starts · compute = local · gates below
```

**Run mode:** L2 arc-loop. Re-read this file at the top of every arc; overwrite `LOOP/checkpoint.md`
after each; pause only at a gate.

---

## Context

Nine commits landed today (maturity pass, S5 row alignment, S6 graph-derived imputation, S1b
samplers, two CI fixes, the manifest, a peer handover update). `origin/main` is at `5b4f322`,
CI green on Windows/Ubuntu/macOS.

That work surfaced a consistent defect class, and this lane closes it: **places where drmSEM
returns a plausible-looking number, or advertises a capability, with nothing verifying it.**
The silent-recycling design matrix (S5) and the probability-where-counts-belong sampler (S1b)
were both instances. The arcs below are the remaining known ones.

Two sizing agents found root causes that changed this plan, including one refuted premise —
recorded per arc rather than discovered mid-run.

---

## Arcs

### A1 — Vignette code-tangling (6 files) · ~1.5 h · no gate

**Root cause, verified against knitr 1.51 source and a live in-memory tangle.**
`knitr:::tangle_block` never executes chunks, so `knitr::opts_chunk$set(eval = has_engine)` —
which lives *inside* the setup chunk — **has not run** when purl decides what to emit. Only a
**per-header** `eval` is consulted:

| header form | tangle result |
|---|---|
| `eval = has_engine` | `eval_lang` errors → `purl = FALSE` → chunk **dropped** |
| literal `eval = FALSE` | kept, but commented out |
| **no `eval` in the header** | inherits default `TRUE` → **emitted and executed** |

So the passing vignettes pass because every chunk carries an explicit `eval`; the failing ones
have chunks that carry none.

**Why CI is green and `devtools::check()` is not:** `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_` defaults
to `TRUE`, and CI re-builds vignettes, so the tangle-run step is skipped there. Not a CI
misconfiguration — a real latent defect that CI simply cannot see.

**Fix:** add an explicit `eval = has_engine` to the 24 headers that lack one, across
`covariance-edges-and-composites.Rmd` (4), `drmSEM-overview.Rmd` (6),
`equations-via-symbolizer.Rmd` (2), `latent-variables.Rmd` (2), `model-selection.Rmd` (4, which
has no `has_engine` — use literal `eval = FALSE`, matching calibration/validation),
`phylogenetic-sem.Rmd` (6). Do **not** touch setup chunks: they must stay purled and runnable.

Two genuine authoring bugs to fix while there, both currently hidden by the tangling failure:
`latent-variables.Rmd` uses a `fitness` column its `dat` never defines, and
`covariance-edges-and-composites.Rmd:126,137` reference an undefined `sem3`.

**Adjacent risk, in scope because it is the same defect:** `drmSEM.Rmd` has **11** unguarded
chunks that tangle *and* run real TMB fits inside check. It passes only because `dat` happens to
be defined by an `eval = TRUE` chunk and `drmTMB` happens to be installed. On any machine without
`drmTMB` — a GitHub `Remotes` entry, not on CRAN — it fails. +11 headers.

**Then make CI able to see it:** add `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_: false` to the workflow
`env:`. Order matters — fix first, verify locally, enable the gate last, confirm green.

### A2 — Ordinal evidence, and correcting the spatial claim · ~2 h · no gate

**A premise was refuted, so the arc is rescoped.** The prior plan said ordinal *and* spatial
"carry no retained evidence". Half wrong: `tests/testthat/test-phylo-cov.R:199-243` already
live-fits `relmat(1 | species, K = K)` and asserts marker stripping and finite estimates. Spatial
needs a **relabel and extend**, not a build.

Measured live, so this is cheap: an ordinal SEM (gaussian mediator → `cumulative_logit` outcome,
n = 800) fits in **0.73 s**; `dsep()` + `fisher_c()` in 0.045 s. No family whitelist exists
anywhere, and `cumulative_logit` already has its link label at `R/edges.R:42`.

New `tests/testthat/test-ordinal.R` (~150 lines): `paths()` component/link labelling, cutpoints
not leaked into `from`, `dsep()`/Fisher's C, and latent-scale recovery. Plus ~40 lines near
`test-phylo-cov.R:199` for a distance-kernel `relmat()` case carrying `dsep()` and effects.

**Two silent-wrong-answer findings this arc must pin as tests — same class as the rest of the lane:**
1. For `cumulative_logit`, `mu` is the **latent linear predictor, not `E[category]`**. Measured
   values sat in ≈(−1.7, 1.6) while the response categories were 1–4. `target = "mean"` therefore
   reports a latent-scale effect **with no warning**. Recovery assertions must be stated on the
   latent scale, and that must be said out loud.
2. `target = "p_gt"` on an ordinal node returns **0.0000 for every quantity** — the mean fallback
   hands it a deterministic latent value so both scenarios collapse. The sampler warning does
   fire, but the *result* is a degenerate zero.

Pin both as known limitations. **Changing either to return `NA` instead is a semantics change →
gate, not this arc.**

Also record the engine constraint: `cumulative_logit` accepts only a `mu` formula, so an ordinal
node cannot be distributional — no ordinal `sigma` path is possible.

**Do not quote the prior audit's 0.518 / 0.875 figures.** They are not reproducible without the
original seed; an independent run gave 0.4877 against a true 0.5. Fix a seed and pin fresh numbers.

### A3 — `check_sem()` test coverage · ~1 h · no gate

Only its `nobs` column is covered (by today's `test-missing-data.R`). `converged`,
`vcov_available`, `sampler`, the `print` method and every warning branch are untested, on an
exported function. Build engines by hand where the mechanism must be deterministic — the lesson
from today's Windows failure, where a live optimizer produced a different covariance outcome per
platform.

### A4 — `drm_nominal_link()` gaps · ~0.5 h · no gate

`R/edges.R:26-43` silently returns `"identity"` for `skew_normal` and the three bivariate
families. Display-only, but a wrong link label in `paths()` misinforms. Add them; test the table.

### A5 — `hu` is documented but never read · ~1 h · **GATE if it changes propagation**

`drm_sample_family()`'s roxygen promises `hu`; the body never uses it, so a `hurdle_nbinom2`
mediator's hurdle zeros vanish while `nbinom2` reports as fully supported. Root cause is
structural: drmTMB folds zi/hurdle into `model_type` while drmSEM keys on the family **name**, so
the list cannot express the distinction.

**Documenting the gap is ungated. Actually honouring `hu` changes what a mediator propagates —
that is a semantics change, so it stops for review.** Default: document + test the gap, gate the fix.

---

## Gates (stop and wait)

Per your instruction, only the genuinely irreversible:
- a **new public capability claim** in README/NEWS/capability-status;
- a change to an **estimand's meaning**, d-separation/effect semantics, or the charter;
- anything **destructive**;
- a **surprise that invalidates this plan** — bring it back here, do not improvise around it.

Everything else proceeds. Every judgement call is recorded in the checkpoint.

## Per-arc verification (all four, in order — no shortcuts)

```bash
NOT_CRAN=true Rscript -e 'devtools::test()'                 # 0 fail; count must rise
NOT_CRAN=true Rscript -e 'devtools::check(error_on="never")' # compare E/W/N to the arc's baseline
git push origin main
gh run list --limit 2                                        # green on all three platforms
```

Baseline entering the lane: **817 pass / 0 fail / 3 skip / 10 warn**; `R CMD check` **1 ERROR
(pre-existing vignette tangling — A1 should clear it), 0 warnings, 3 notes**. `.uinit/` produces
one of those notes and is yours to delete.

**Read the log, not the exit code.** Today a green `devtools::test()` hid a Windows-only CI
failure, and my first fix for it was a guess that failed again.

## LOOP/ kit

`LOOP/{GOAL.md,arcs.md,checkpoint.md,ultra-plan.md}` committed in the repo, `checkpoint.md`
overwritten every arc so a fresh session can resume without this conversation.

**Two declared deviations from arc-loop doctrine, with reasons:**
1. **No isolated worktree lane.** Doctrine scaffolds `lane_launch.sh` with `git push` denied — which
   directly contradicts your "push each arc once green". Running in this checkout on `main` instead.
2. **Same session, not a fresh one.** Doctrine wants a lane in its own session; you asked this one
   to continue. The on-disk kit is what makes that survivable.

**Known risk from (1):** this is a shared checkout — a peer lane committed `5b4f322` mid-session
today. Mitigation: re-check `git status` and the remote SHA at the top of every arc, and never
`git add -A`.
