# Ultra-plan — S6 generality: multi-`mi()` imputation

G0 approved 2026-08-26 (all 10 checklist items; standing approval for
push / PR / issue comments / new drmTMB lane / Totoro smoke). A2
comments posted. Frozen detail below is still the contract.
Cursor / Grok worker. Structured as Fable
would: destination first, two-repo contract, slice table, gates, reviewers.
**Not** executed against the Fable API.

```
🎯 GOAL
Solo platform: Cursor (this session; Grok). After G0, hand execution to /goal
  in a fresh chat — do not run Phase 3 in the planning thread.
Deliverable: an approved two-repo programme that makes graph-derived
  imputation work for nodes with k ≥ 2 incomplete endogenous parents,
  without claiming FIML.
HEADLINE: drmTMB items 2+5 (independent multi-mi + ledger), then item 1
  (per-family C++), then drmSEM lifts the abort.
IN PARALLEL: A2 issue comments and A3 joint-mi recon can fan out after G0;
  A4/A5 pair on the engine lane.
DEFER: FIML; item 3 option (a); exogenous imputation; impute_joint as the
  emit shape; MAG / S3 / rho12; drmSEM R/ before G1.
DISCIPLINE: verify=log+artefact · compute=Totoro for recovery (ask again
  before any grid) · closure=G0 this kickoff; G2 for the programme
```

ARC PROGRAM: N/A (no Arc Card). Charter:
`docs/memory/2026-08-26-next-arc-s6-imputation.md`.

---

## Phase 0.2 — Shannon pre-flight

```
PLATFORM: cursor | ON BRANCH: main @ 0852f9f at kickoff | LANE: s6-imputation
OTHER LANES: claude/lane-mag-completeness (DO NOT TOUCH);
  claude/lane-mag-wire (merged PR #43); claude/lane-s3-grouping (merged PR #44)
VERDICT: FOREIGN LANE ACTIVE (claude). Concurrency allowed; this lane owns
  docs/memory/ + LOOP/ for S6 only. Lease GRANTED:
  cursor:drmSEM-s6-imputation [docs/memory/,LOOP/]
```

Silence is weak evidence. MAG-completeness remains live; do not claim its
files. S3 LOOP on `main` is a **closed** kit — this lane replaced it rather
than inheriting it.

---

## Phase 0.25 — Sweep receipt (required before decompose)

| Surface | Evidence | Finding | Call |
|---|---|---|---|
| **repo git** | `git status -sb`; `git worktree list`; `branch_drift_check.sh` | `main` clean, 0/0 vs origin @ `0852f9f`. Worktrees: mag-completeness, mag-wire, s3-grouping. LOOP on main was Step 2 S3 grouping (closed). | **build-the-gap** on a new lane; do not resume those branches |
| **sister / engine** | drmTMB local path exists; `gh issue list`; clone `drmTMB-joint-mi` | Issues **#963** (item 2), **#962** (item 1 = C++ wiring, not a whitelist), **#964** (item 3; drmSEM already did option b). Engine abort still `length(mi_calls) != 1L` at `R/missing-data.R:628`. Ledger has rich `missing_response` G5 rows; **no `missing_predictor` axis** in the live TSV skim. `drmTMB-joint-mi` @ `codex/joint-mi-two-predictor` is 3 ahead / **207 behind** `origin/main` and implements **`impute_joint`** (correlated pair), not independent multi-`mi()`. Primary drmTMB checkout is on a **foreign** ledger branch. | **reuse** #963/#962 text; **co-opt** joint-mi as recon input only; **new engine lane from `origin/main`** |
| **brain** | MCP `search_notes` `S6 imputation multi-mi drmSEM drmTMB missing data` + `search_all_projects: true`; grep `memory/DECISIONS.md`, `OPEN_QUESTIONS.md`, `AGENT_LOG.md` for imputation / S6 | Hub D-27 is TabPFN (unrelated). Repo D-21 is last drmSEM ID. No OQ for multi-`mi()`. AGENT_LOG 2026-08-15 names Step 3 as the drmTMB lane. | **reuse** handover Step 3 + `13-missing-data.md`; **build** the programme kit |
| **deterministic grep** | `docs/memory/AGENT_LOG.md` S6; `DRMTMB_ISSUES.md`; `13-missing-data.md`; `R/imputation.R` one-parent abort | Prototype + V-77–V-81 exist. Binding abort is real user-facing behaviour. | do not rebuild S6 prototype |
| **Verdict** | | Genuinely new: two-repo execution plan, independence-vs-joint contract, G1 before drmSEM `R/`. | **reuse prototype + issues; resume nothing; build the gap** |

---

## Phase 0.3 / 0.3b — Roster and bars

- Session model: **Cursor Grok** (owner asked for Grok; do not block on
  Fable/Claude API).
- Two-bar glance: **not read this session** (no Settings → Usage access
  from the worker). Do not invent percentages. After G0, `/goal` should
  glance both bars before any long engine work.
- Bar column below: planning/docs = Cursor Models (Grok); engine C++ /
  recovery = hand off to **Codex** (live R/TMB); claim/review gates =
  Other Models or Claude if Shinichi opens that surface.

SCOUT SUITABILITY: yes — A2/A3 are read-only recon.
ULTRA EFFORT: no.
PREFLIGHT: pasted above.
SEARCH: none this kickoff (NotebookLM offered at G0, not run).
RECONCILE: Melissa row at programme close (A12), not at this kickoff.

---

## Phase 0.6 — Route check

1. **Destination (one sentence):** drmSEM can derive k ≥ 2 independent
   `mi()` terms from the DAG on an engine that accepts them and ledgers
   them, without calling that FIML.
2. Slices are **not** "depends what we decide" if G0 locks independence
   (option b) as the consumer contract. The remaining either/or
   (first engine cell: two Gaussian vs Gaussian+discrete) is a **named
   G0 question**, not a hidden map.
3. Every slice names an output path or issue/PR.

**Route is knowable after G0.** Not a decision-map halt.

---

## WHAT THE BRAIN ALREADY KNOWS

- S6 prototype shipped: `drm_sem(impute = "auto")` derives one incomplete
  endogenous parent's model from the DAG (V-77 numeric identity; V-78
  outcome-dependent missingness; V-80 anti-drift).
- Honest limits already written in `13-missing-data.md`.
- Priority order already written: **2 + 5 together, then 1**
  (`DRMTMB_ISSUES.md`, handover §6 Step 3).
- Item 3 option (b) is done in drmSEM; item 4 partly landed upstream
  (`uncertainty_status` on 0.7.0).
- #962 correction: item 1 is **C++ observed-data likelihood**, not a
  gate edit.
- #963 correction: parser + **eight family marginalisers**; option (b)
  independence is the tractable branch; `imputed()` already anticipates
  plurality.

## WHAT SHINICHI TOLD US

Authorised starting the **planning** arc (this kickoff). Use Grok. Do
not implement drmSEM `R/`. Do not block on Claude/Fable. Do not touch
MAG-completeness. Commit on a new lane.

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Gauss  — #963 is eight C++/R marginalisers, not a parser flip. joint-mi
           is a different estimand (correlated pair). · Mixing them would
           ship the wrong likelihood. · Recommend option (b) as the S6
           contract; audit joint-mi in A3 only. · Q: first cell two
           Gaussian independent mi() or Gaussian+discrete? · Default:
           two independent Gaussian mi() matching the S6 emit shape.
  Curie  — Recovery must be MCAR and MAR; MCAR-only is plumbing.
           Sentinel-invariance is already in the engine culture. ·
           Recommend A6 as a load-bearing gate for G1. · Q: Totoro or
           DRAC for the two-predictor grid? · Default: Totoro smoke then
           scale; ask again before a large grid.
  Fisher — Within-node Hessian ≠ cross-node FIML. · A public "SEM
           imputation" sentence will be misread. · Recommend capability
           stays `partial` until two-parent recovery exists; never say
           FIML. · Q: none if honest limits stay in 13-missing-data.md.
           · Default: keep the 2026-08-14 wording.
  Rose   — Foreign Claude lanes live; LOOP path-collides with MAG kit
           by filename only. · Claiming MAG files or inheriting Step 2
           LOOP is bleed-through. · Recommend this lane owns
           docs/memory/ + LOOP/ for S6 only. · Q: none. · Default:
           do not touch MAG-completeness.
  Darwin — Users hit y ~ m1 + m2 + x with NAs in both mediators first.
           · A Gaussian-only lift still helps if the abort message
           names the remaining family limit. · Recommend Darwin review
           of error text at A8. · Q: none. · Default: fail loud with
           the engine reason.
  Ada    — Lock D-22 (order + option b). Stop this chat at G0. Engine
           work is a new drmTMB lane from origin/main, not the dirty
           primary checkout and not the 207-behind joint-mi clone.
```

## ADA'S RECOMMENDATION

Approve G0 with the defaults above. Do **not** rebase
`codex/joint-mi-two-predictor` onto main as the S6 engine path. After
G0, write the contract (A1) on this lane, then open a drmTMB lane for
A4–A6.

## DECISIONS LOCKED (this kickoff; G0 confirms)

See **D-22**: slice order 2+5 → 1 → consumer; consumer = independent
`impute_model()` per parent; no drmSEM `R/` until G1.

## QUESTIONS STILL OPEN (G0 checklist)

See the G0 block below.

---

## Slice table

| ID | Member | Model+effort | Bar | Dispatch | Time | Output | Dep |
|---|---|---|---|---|---|---|---|
| A0 | Ada | Grok / this session | Cursor Models | parent | done | this kit | — |
| A1 | Ada + Gauss | Grok or Codex Terra-med | Cursor Models | `/goal` after G0 | ~1 h | `docs/design/` addendum or `LOOP/notes/A1-engine-contract.md` | G0 |
| A2 | Ada | scout / Luna-low | Cursor Models | recon | ~30 m | comments on #963/#962 | A1 |
| A3 | Gauss | scout | Cursor Models | recon | ~45 m | `LOOP/notes/A3-joint-mi-verdict.md` | A1 |
| A4 | Gauss | Codex Terra-high | hand off | drmTMB lane | days | drmTMB #963 implementation | A1, A3 |
| A5 | Fisher / Rose | Codex Terra-med | hand off | pairs A4 | hours | ledger axis rows | A4 |
| A6 | Curie | Codex Terra-high | hand off | Totoro smoke first | hours–day | recovery artefacts | A4 |
| A7 | Gauss + Curie | Codex Terra-high | hand off | Phase 2 | per family | C++ `has_mi` + test + ledger | A4–A6 |
| A8 | Ada + Gauss | Codex/Claude after G1 | hand off | drmSEM `R/` | hours | `R/imputation.R` multi-parent | **G1** |
| A9 | Fisher | Terra-med | hand off | drmSEM | ~1 h | `imputation()` tiers | A8 |
| A10 | Curie | Terra-med | hand off | drmSEM | ~2 h | `test-imputation.R` | A8, A9 |
| A11 | Darwin + Rose | Grok / Other Models | Cursor or Other | drmSEM docs | ~1 h | design + ledgers | A10 |
| A12 | Ada + Melissa | Terra-med | Other Models | close | ~45 m | PLAN-ACTUAL + G2 packet | A11 |

PARALLEL after G0: {A2, A3}. SEQUENTIAL: A4+A5 together ← A1,A3;
A6 ← A4; A7 ← A4–A6; A8–A11 ← G1; A12 ← A11.

FAN-OUT BUDGET (post-G0 `/goal`): checkpoint=`s6-g0` · new children ≤ 6
· scout=A2/A3 · build=A4–A11 · ceiling=0 unless G2 claim panel.
D-43 PANEL: only if a public capability claim is proposed (Rose default:
**not** this arc).

ESTIMATE: planning kickoff ~1 session (this). Programme: multi-day,
**needs handoff** to a drmTMB lane + later drmSEM `/goal`. Does **not**
fit one Cursor chat.

REVIEW of this plan (before run): Rose (scope/claims) + Gauss (engine
contract). Written above as TEAM RAISED; G0 is the human lock.

VERIFY: A0 = files exist on the lane branch; later slices = log +
artefact, never exit code. CONSOLIDATE: AGENT_LOG + charter + D-22.

---

## Phases (Fable-shaped)

### Phase 0 — Recon + contract (this lane, docs only)

A0 (this commit) → **G0** → A1 contract → A2/A3 recon.

Success: a colleague can open a drmTMB lane and implement A4 without
re-deriving the emit shape or the independence assumption.

### Phase 1 — drmTMB items 2 + 5 (separate engine lane)

New worktree from drmTMB `origin/main`. Do not use the current primary
checkout (`claude/ledger-biv-gaussian-residual-covered`). Do not fast-
forward the 207-behind joint-mi clone onto the engine lane.

A4 + A5 together, then A6. G1 becomes available when A6's recovery is
real and the contract still matches what drmSEM will emit.

Compute: **Totoro or DRAC?** Default Totoro for a two-predictor smoke;
ask before any replicated grid. Not GitHub Actions.

### Phase 2 — drmTMB item 1 (family gate = C++ work)

A7 family-by-family. First candidates after the Gaussian independent
cell: the families drmSEM already allows as responses
(poisson / binomial / nbinom2 / beta) if they still only admit a
**binary** predictor — only if Phase 1 left that gate honest.

Do not "widen the gate" without `has_mi` wiring (#962).

### Phase 3 — drmSEM consumer

A8–A11 after **G1**. Keep V-77 (auto ≡ hand-written). Add a two-parent
DGP. Fail loud when the engine still cannot. Update
`13-missing-data.md` without calling the result FIML.

---

## Gates

| Gate | Stops | Opens |
|---|---|---|
| **G0** | All Phase 1+ work; all drmSEM `R/` | A1–A3 on this lane; drmTMB lane may be *created* but not written until G0 |
| **G1** | drmSEM `R/` (A8+) | Consumer slices |
| **G2** | push / merge / public claim | Human only |
| **G3** | Surprise (wrong estimand works, independence fails) | Back to G0 |

```
PRE-AUTHORISED AFTER G0: scoped docs/LOOP edits on this worktree; routine
local commands; local commits; reading drmTMB / joint-mi; drafting A1.
OPTIONAL REMOTE AUTHORITY: none (no push, no PR, no issue comment until
Shinichi says so — A2 is post-G0 and still a human-facing GitHub write).
MUST STOP: drmSEM R/ before G1; merge/release/public claim; credentials;
destructive work outside this worktree; MAG-completeness; new compute
beyond a local smoke; switching consumer contract to impute_joint or FIML.
```

Status words after G0: **IN PROGRESS** while A1–A3 run; **PAUSED** only
for a named Shinichi decision; **BLOCKED** only if drmTMB `origin/main`
is unavailable or a foreign lease owns `R/missing-data.R`.

---

## G0 approval checklist (Shinichi)

Confirm or correct each line. Defaults apply if you say "use your
judgment".

1. **Order = D-22:** items **2 + 5, then 1, then drmSEM consumer.**
2. **Consumer contract = independent `impute_model()` per parent**
   (option b). Do not emit `impute_joint`.
3. **First engine cell = two independent Gaussian `mi()` terms**,
   matching `y ~ mi(m1) + mi(m2) + x`. (Alternative: Gaussian +
   discrete, cheaper per #963 — say so if you prefer.)
4. **No drmSEM `R/` until G1.**
5. **New drmTMB lane from `origin/main`**, not the dirty primary
   checkout, not a rebase of `drmTMB-joint-mi` (207 behind).
6. **Honest limits stay:** not FIML; within-node uncertainty;
   exogenous → `na_action`; `impute = "none"` default.
7. **Compute default = Totoro** for A6 smoke; ask before a large grid.
8. **A2 GitHub comments** wait until you allow a public issue write.
9. **NotebookLM prior-art pass** — skip unless you ask (offered, not
   run).
10. **Capability-status stays `partial`** until two-parent evidence
    exists; no "general missing-data SEM" claim at G2 unless you
    reopen that.

---

## Post-G0 `/goal` handoff (paste into a fresh chat opened in the worktree)

```
/goal

Ultra-plan G0 approved. Run this plan to completion via LOOP/.

LANE: s6-imputation   REPO: ~/local-scratch/lanes/drmSEM-s6-imputation
PLAN: LOOP/ultra-plan.md

READ FIRST: LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md → AGENTS.md
  → docs/memory/2026-08-26-next-arc-s6-imputation.md → D-22.

START ARC: A1 (engine contract draft, docs only).
NEXT GATE: G1 before any drmSEM R/. Phase 1 engine work is a separate
  drmTMB lane from origin/main. Do not touch MAG-completeness.
```
