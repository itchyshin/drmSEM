# Handover to Claude — drmSEM — 2026-08-14

You are Claude, picking up the drmSEM lane. You inherit **no chat context**; this document plus
`AGENTS.md` is authoritative. Read both before acting.

**Repo:** `/Users/z3437171/Dropbox/Github Local/drmSEM` · branch `main` · ~~2 commits unpushed~~ **all pushed**
**Author of this handover:** Claude Code · **Supersedes:** nothing; *extends*
`docs/memory/HANDOVER-2026-08-09.md` (still valid for the arc it describes)

---

## ⚠️ STATUS UPDATE — 2026-08-14, later the same day (read before §0; §0 is now partly STALE)

**The recipient is still correct: the drmSEM lane is CLAUDE**, confirmed by Shinichi. If you are a
Claude session, this document is yours. What changed is the *state*, not the ownership — and two of the
three blockers §0 raises are now **resolved**. Do not re-triage them.

| §0 item | State now | Evidence |
|---|---|---|
| 23 uncommitted tracked files on `main` | ✅ **LANDED** | the *maturity hardening* arc (`0db2591`), then `3e799ef docs(agents): commit the LOAD-FIRST brain manifest` |
| 2 unpushed Shannon commits | ✅ **LANDED and PUSHED** | `e75d810`, `2401d9e` are on `origin/main`; `main` is 0 ahead / 0 behind |
| 5 branches with unpushed commits | ⏳ **still open** | `claude/status-check-v0.5-OjpdI` (9), `codex/oq1-sampler-fix` (3), `chore/worktree-house-rule` (1), `codex/issue-2-hero-dag` (1), `codex/live-drmtmb-closeout` (1) |

**The SHAs in §0 are dead.** It names `085c175` and `b249396`; those objects still exist but are
unreachable — a rebase-on-push rewrote them to **`e75d810`** and **`2401d9e`**. Do not `git show` the old
ones and conclude the work went missing.

**Provenance of those two commits, since §0 flagged them as an unidentified lane:** a Claude session
installing `.claude/agents/shannon.md` + `.codex/agents/shannon-coordinator.toml` across the 14 repos
that carry an agent roster. `tools/lane_preflight.sh` cleared that session, wrongly — drmSEM's lane
commits **straight to `main` under Shinichi's own git identity**, so there is no branch, no PR and no
distinguishable author for any foreign-lane signal to catch. **That blind spot is now fixed:** the
pre-flight treats sustained non-merge commits to `main` plus a dirty tree as a live lane regardless of
authorship, and reads the newest handover to report who it hands to. Re-run it — drmSEM now returns
`FOREIGN LANE ACTIVE (direct-to-main)` instead of all-clear.

**Working tree right now:** no modified tracked files. Untracked only — `.uinit/`,
`man/figures/drmsem-thermal-{dag,2x2}.png`, `tools/render-readme-thermal.R` (a README thermal example in
progress). Leave those unless they are yours.

**Caution that has NOT changed:** this repo has **no coordination board**, so this document is the
channel — and a handover records who was handed the lane *then*, never who holds it *now*. Re-run
`tools/lane_preflight.sh` before claiming anything.

---

## 0. Critical context — read this first

**This repo is multi-lane and you are not the only writer.** Three independent signals:

1. **23 uncommitted tracked files** sit on `main` from a session that is not this one. They look
   like a coherent "maturity hardening" arc (partial-uncertainty diagnostics, a `path_effects()`
   integration test, CRAN-prep hygiene). **They are not yours. Do not stage them.**
2. **Two commits on `main` are unpushed and were authored by another lane** — `085c175` and
   `b249396`, both "install Shannon, the lane coordinator" (one `.codex/agents/`, one
   `.claude/agents/`; a legitimate pair, *not* an accidental duplicate). Dated 2026-08-10, i.e.
   **after** the 2026-08-09 arc below.
3. **Five other branches carry unpushed commits** (see Landing State).

Run `tools/lane_preflight.sh` before claiming anything. On 2026-08-14 it reported
`SHARED LEDGERS CHANGED ON REFS YOU DO NOT HAVE — AGENTS.md (2)`. Diff before appending to any
shared ledger: `tools/lane_preflight.sh --file <path>`.

**There is no coordination board in this repo** (checked). So the multi-lane split is recorded
here, in this section, rather than pointed at. **`AGENTS.md` has no Live Phase Snapshot block**
either, so no pointer was refreshed — and `AGENTS.md` is itself one of the 23 uncommitted files,
so touching it would collide with the other lane.

---

## 1. Landing State ledger (the handoff gate FAILS; everything below is declared)

`tools/handoff_gate.sh .` returns **GATE FAIL**. Nothing here is being hidden; each item is
declared CARRIED-OVER with a reason and a resume command.

| Item | State | Why not landed | Resume |
|---|---|---|---|
| 23 modified tracked files on `main` | **CARRIED-OVER** | Another session's in-flight work. Owner unidentified. Discarding is probably wrong (content is coherent); landing needs its author. | `git diff R/effects.R` then identify owner |
| `085c175`, `b249396` on `main` (unpushed) | **CARRIED-OVER** | Another lane's commits, already committed here but never pushed. Pushing another lane's work is the human's call. | `git push origin main` (pushes them **and** nothing of mine — mine are all pushed) |
| `chore/worktree-house-rule` (+1) | **CARRIED-OVER** | Pre-existing branch, not touched this arc | `git log origin/main..chore/worktree-house-rule` |
| `claude/status-check-v0.5-OjpdI` (+9) | **CARRIED-OVER** | Pre-existing branch, not touched this arc | as above |
| `codex/issue-2-hero-dag` (+1) | **CARRIED-OVER** | Pre-existing branch, not touched this arc | as above |
| `codex/live-drmtmb-closeout` (+1) | **CARRIED-OVER** | Pre-existing branch, not touched this arc | as above |
| `codex/oq1-sampler-fix` (+3) | **CARRIED-OVER** | Pre-existing branch, not touched this arc | as above |
| `.uinit/` (untracked) | **CARRIED-OVER** | Phase-0 scratch from an `/ultra-initialize` run started and never resumed. Harmless; regenerated in ~1s. | delete, or resume that skill |
| `man/figures/drmsem-thermal-*.png`, `tools/render-readme-thermal.R` (untracked) | **PROTECTED — do not delete** | An abandoned example that nonetheless carries Darwin's reviewed biology corrections. **Never committed**, so deleting loses them permanently. The instruction was "do not put it back", not "destroy it". | leave as-is |

**Everything this lane authored is committed AND pushed.** The 2 unpushed commits on `main` are
not mine.

---

## 2. What was accomplished (arc of 2026-08-09; verified live)

The landing page was rebuilt from three unrelated examples to **one example, one system**.

- `man/figures/drmsem-dag.png` + `drmsem-spread.png`, built by
  `tools/render-readme-sigma-edge.R`. The DAG shows `temp` reaching `size` **twice** — a solid
  `mu` arrow and a dashed `sigma` arrow — and the second image shows what that dashed arrow does:
  the fitted distribution of `size` slides right (mean −0.57 → 1.06) **and widens** (SD 0.40 →
  1.36). Same seed, n and coefficients as `tools/render-readme-hero.R`, so they are provably one
  example.
- `plot.drm_effect()` brought into Confidence Eye compliance; geometry lives in a new internal
  `drm_confidence_eyes()` shared with the figure so the two cannot drift.
- **A terminology guard**: `docs/memory/FLAGGED-TERMS.tsv` + `tests/testthat/test-flagged-terms.R`
  fails the suite if a reviewer-flagged term reappears in reader-facing text. Verified to **fail**,
  not merely to pass.
- Shipley & Douma (2021) cited — `inst/REFERENCES.bib`, `paper.bib`, the `covary()` /
  `covariances()` roxygen, and the rule's own comment in `R/dsep.R`.
- Nine issue-ready drmTMB asks appended to `docs/memory/DRMTMB_ISSUES.md`.

**Baseline: 745 pass / 0 fail / 3 skips** (`symbolizer` ×2, one `ape` guard) via
`NOT_CRAN=true Rscript -e 'devtools::test()'`. Any new failure is yours.

---

## 3. Next Immediate Steps — narrow, in order

**Step 0 (always).** `tools/lane_preflight.sh`, then reconcile this document against
`git status`. Classify every item above as OWED / DONE / RETRACTED / PROTECTED. The 23 files may
have been landed by their owner since this was written.

**Step 1 — triage the 23 files.** Blocks Steps 2 and 3, which touch the same surface. Identify the
owner; land or discard. This is **not** yours to decide unilaterally.

**Step 2 — fix the row-alignment bug (the only correctness defect on the list).**
drmSEM has **no missing-data policy at all** — no `na.omit`, `complete.cases` or `na.action`
anywhere in `R/`. `drm_sem()` hands one data frame to every node (`R/drm_sem.R:250`) and each
drmTMB fit then drops incomplete rows by its own rules. Reproduced live:

```
NAs in two different columns of a 300-row frame:
drm_sem() SUCCEEDED silently.  nobs: node m = 270, node y = 240
indirect_effects() -> "number of items to replace is not a multiple of replacement length"
```

Two defects: a piecewise SEM whose nodes are fitted on **different samples** is not the model the
user asked for and nothing warns; and the effect engine dies with a raw subscript error instead of
a diagnosis. Fix: compute each node's row set at `drm_sem()`; abort or align when they differ
(user-controllable, safe default); give `indirect_effects()` / `path_effects()` a diagnosed error.
Model it on the existing, much better-behaved `attr(x, "uncertainty_issues")` pathway.
**This gates all missing-data work** — drmTMB's `mi()` and masking change *which rows each node
uses*, and a package with no alignment policy cannot safely consume that.

**Step 3 — un-stale the realized-value sampler list.**
`drm_supported_sampler_families()` (`R/diagnostics.R:7-24`) lists ten families and its comment
claims *"tweedie … has no realized-value sampler"*. `simulate.drmTMB` (`R/methods.R:2800` in
drmTMB) covers **all 18 fitted families**, including `rtweedie_compound()` and an ordinal category
draw. Consequence: a tweedie or ordinal **mediator** silently degrades to mean propagation —
losing the distribution-mediated channel, which is the package's headline claim — because of a
stale vector, not an engine limitation. Reconcile family by family, adding a sampler-moment
recovery test (style of `test-recovery-samplers.R`, V-55..V-64) **before** admitting each. Do not
just widen the vector.

Beyond that, see `~/.claude/plans/warm-launching-crane.md` (m-separation is the flagship slice)
and `docs/memory/DRMTMB_ISSUES.md` (engine lane: open with items 2 + 5 together).

---

## 4. Key decisions & rationale

- **One example, not three.** The canonical `temp/habitat → size/abundance/survival` example
  already contained the demonstration; two extra systems were built to show what figure one
  already showed. Consolidated.
- **The downstream payoff is deliberately NOT claimed.** The distribution-mediated effect of
  `temp` on `survival` here measures **−0.0007 [−0.0034, 0.0014]** — indistinguishable from zero,
  because the survival logit is only mildly curved over the realized range. The page shows a
  variance being *caused* and stops. Making the gap real would need the survival node pushed into
  its saturating region, which edits the canonical DGP shared by the hero script, the intro
  vignette and `paper.md`. Open choice, not an oversight.
- **m-separation is feasible within the charter.** It is a graph operation, not a likelihood one,
  so it needs no joint likelihood. Design is slice S2 of the plan file. Two hard constraints
  recorded there: v1 must support *marginalised* latents only (approximating the *conditioned* /
  selection case produces silently WRONG independence claims), and the step-4 orientation rules
  must be read from Richardson & Spirtes (2002) rather than implemented from memory.

## 5. Files created / modified by THIS lane (all committed and pushed)

```
README.md
R/plotting.R                 R/covariances.R        R/dsep.R
tests/testthat/test-plotting.R
tests/testthat/test-flagged-terms.R          (new)
docs/memory/FLAGGED-TERMS.tsv                (new)
docs/memory/HANDOVER-2026-08-09.md           (new)
docs/memory/DRMTMB_ISSUES.md                 (appended)
docs/memory/2026-08-14-claude-handover.md    (new — this file)
inst/REFERENCES.bib          paper.bib
man/covary.Rd                man/covariances.Rd
man/figures/drmsem-dag.png                   (new)
man/figures/drmsem-spread.png                (new)
tools/render-readme-sigma-edge.R             (new)
deleted: man/figures/drmsem-caused-variance.png, tools/render-readme-variance.R, man/figures/drmsem-main.png
```

Vault-side (`~/shinichi-brain`, local-only, committed): `2904fe9`, `9f6314c`, `b99bc88`, `7d79ec5`.

## 6. Gotchas & failed approaches — the highest-value section

- **Never sign a figure off from its plot code.** `paste0()` **drops names**, so deriving pale
  fills from outline colours handed `scale_fill_manual()` an unnamed vector; it assigned them
  positionally in alphabetical order and paired the mean-mediated outline with the
  distribution-mediated fill. Every test passed. Only the rendered PNG showed it.
- **`asp = 0` on `plot.igraph` is a trap.** It was used to reclaim canvas width and it silently
  **dropped arrowheads on six of eight edges** (igraph computes arrow geometry assuming
  `asp = 1`; tangential edges lose their heads) and squashed two of five nodes into ellipses. A
  causal diagram with headless arrows reads as undirected. Reverted; use a near-square canvas
  instead.
- **A composite image cannot be made bigger from the inside.** pkgdown scales each *image* to the
  column width, so a square DAG sharing one image with a wide panel is capped at a fraction of it,
  regardless of node size, label size or canvas ratio. Three rounds were wasted tuning inside the
  composite. Splitting into two images fixed it in one step.
- **A hash match is not a deployment check.** "Verified live" was claimed twice on the strength of
  a figure's bytes matching, while the live page still referenced a *different* file. The correct
  check is one line: `curl -s <site> | grep -o 'drmsem-[a-z-]*\.png'`.
- **A recorded warning is not an applied warning.** Darwin's review flagged "bet-hedging" as a
  mislabel; the warning was written into a script header and the label used anyway, on the live
  site. That is why `FLAGGED-TERMS.tsv` exists — the lesson is only binding where something
  measures it.
- **Rapid successive pushes race.** Six pushes in quick succession each cancelled the previous
  pkgdown run, so the site lagged well behind `main`. Batch, then verify.

## 7. Mission control

| repo | branch | CI | what shipped | plan by leverage |
|---|---|---|---|---|
| drmSEM | `main` (2 unpushed, **not mine**) | R-CMD-check + pkgdown green on `c264824` | one-example landing page (live, verified); Confidence Eye compliance; terminology guard; Shipley & Douma cited | 1 triage 23 files · 2 row-alignment bug · 3 sampler list · 4 m-separation |
| drmTMB | — | — | not touched | engine lane: `DRMTMB_ISSUES.md` items 2 + 5 together, then 1 |

## 8. How to resume

**Environment.** Working dir `/Users/z3437171/Dropbox/Github Local/drmSEM`. R toolchain is live
here (drmTMB 0.6.0 installed and fitting). Safe verification command:

```
NOT_CRAN=true Rscript -e 'devtools::test()'      # expect 745 pass / 0 fail / 3 skip
```

Figures: `Rscript tools/render-readme-sigma-edge.R`. Local page preview:
`Rscript -e 'pkgdown::build_home(preview = FALSE)'` → writes `pkgdown-site/` (**not** `docs/`,
which holds tracked design and memory files), then serve that directory and **look at it**.

**Standing rule from the human:** build and review the pkgdown HTML locally **before** any push
that touches reader-facing text.

**Must not stage:** the 23 modified tracked files, `.uinit/`, and the untracked
`man/figures/drmsem-thermal-*.png` / `tools/render-readme-thermal.R`. Stage explicit paths only;
never `git add -A`.

**Review lens:** spawn Rose (`.claude/agents/systems-auditor.md`) before any public claim, and
Florence (`figure-reviewer`) before shipping any figure — she must inspect the **rendered PNG**,
not the plot code, and must check it **downscaled to ~650px**, which is where defects appear.

### Resume prompt

```text
Read AGENTS.md and docs/memory/2026-08-14-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
