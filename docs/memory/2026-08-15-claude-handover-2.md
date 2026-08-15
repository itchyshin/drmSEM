# Handover to Claude — drmSEM — 2026-08-15 (second, lane closed)

You are picking up drmSEM. You inherit **no chat context**; this document plus `AGENTS.md` is
authoritative.

**Repo:** `/Users/z3437171/Dropbox/Github Local/drmSEM` · branch `main` · **everything pushed**
**Author:** Claude Code · **Supersedes:** `docs/memory/2026-08-15-claude-handover.md`

> Read that predecessor for the defect-lane detail, but **do not act on its §6 Step 4** — three
> of its four items were already covered when it was written. Corrected below and in
> `AGENT_LOG.md`. It is kept as the historical record at Shinichi's explicit instruction.

> Filed in `docs/memory/`, not `docs/dev-log/handover/`, because `.gitignore:43` makes
> `docs/dev-log` invisible to git. A handover the next session cannot read is not a handover.

---

## 0. The headline

**drmSEM has no unblocked work left.** That is the single most important fact here. Everything
remaining is gated on Shinichi's judgement, on the drmTMB engine, or on upstream `Remotes:`.
If you arrive looking for the next task, there isn't one — there is a *decision*.

Do not manufacture work to fill the gap. The one designed-and-ready arc is read-only and is
described in §5.

## 1. Landing state — everything declared

`git status` is clean; `main` == `origin/main`. Nothing carried over from this session.

| Item | State | Notes |
|---|---|---|
| `main` | **LANDED** | `376f187` (test + ledgers), `1a53855` (after-task report) |
| `man/figures/drmsem-thermal-*.png`, `tools/render-readme-thermal.R` | **PROTECTED** | never delete, never commit; gitignored at `.gitignore:61-62`. Verified present and ignored |
| `chore/worktree-house-rule`, `codex/issue-2-hero-dag`, `claude/status-check-v0.5-OjpdI`, `codex/live-drmtmb-closeout`, `codex/oq1-sampler-fix` | **CARRIED-OVER, STALE** | untouched by this session. Independently re-confirmed stale: their `VALIDATION_LEDGER.md` tops out at **V-76 or lower** against main's V-116 |
| `LOOP/` | **CLOSED** | `checkpoint.md` rewritten to current truth; no arc in progress |

## 2. What this session did

One item, the last unblocked one from the predecessor's §6: **`average(method = "latent")` had
no test.**

The gap was narrower than the handover implied and worse in shape. `standardize()`'s latent
scaling was *already* validated live (V-44, V-65). What nothing checked was that
`average.drm_compare()` **forwards** `method` to it (`R/model_set.R:592,610`). Had that
forwarding broken, `average(cmp, method = "latent")` would still have returned a well-formed
`drm_average` — right columns, right paths, right `weight_sum` — carrying `"sd_x"` numbers
inside. Nothing in the package or the suite would have objected.

V-116 rebuilds the CBIC-weighted mean by hand from `attr(cmp, "fits")` and asserts equality;
asserts the two methods actually differ; and pins the path-key set and `weight_sum` as
properties of the graph. **Seen red before it was believed:** stub `method` to `"sd_x"` → 2
assertions fail; revert → pass.

**Measurements:** suite 982 → **987 pass / 0 fail / 3 skip / 10 warn**. `R CMD check`
**0E / 0W / 2N**, both notes pre-existing and verified verbatim. Vignette tangling exit 0.
CI on `376f187`: **R-CMD-check success, pkgdown success** (awaited, not assumed).

Full detail: `docs/memory/2026-08-15-after-task-v116.md`.

## 3. Corrections you must not undo

1. **The predecessor's §6 Step 4 is stale.** Already covered when written:
   `rho12()`/`corpairs()` NA-by-construction (`test-pair.R:101,109,185,189`);
   `population = "marginal"` abort (`test-effect-api.R:174`); `uncertainty = "bootstrap"`
   abort (`test-effect-api.R:173`). Do not re-do them.
2. **`drmTMB` moved 0.6.0 → 0.7.0** under us. The suite reproduces the 0.6.0 baseline exactly,
   so it is benign — but anything reading `imputed()$std_error` must branch on
   `uncertainty_status`, **never** on `is.na(std_error)`. That semantic differs between versions.
   Re-check `packageVersion("drmTMB")` each arc; it has now moved twice.

## 4. The one open residual

The Rose consistency sweep checked all 26 `match.arg()` sites in `R/` for the same defect class
— *an argument accepted, forwarded, and never checked*. Four candidates are covered
(`effects_api` `method`/`gcomp`, `composite` `method`/`pca`, `effects` `mediation`,
`model_set` `criterion`/`CICc`). One is bare:

**`symbolize.R notation` has zero test mentions** — and cannot get one in this environment,
because the bridge is gated on `symbolizer`, which is not installed (2 of the suite's 3 skips).
This is *uncheckable here*, which is not the same as fine. If `symbolizer` ever gets installed,
this is the first test to write.

## 5. What is left, and what gates each

| Item | Gate | Notes |
|---|---|---|
| **S2 / m-separation completeness** | **Shinichi's judgement** | `drm_dag_to_mag()` works and is verified against S&D's printed MAGs, but is not wired into `basis_set()`/`dsep()`: R&S Cor. 5.3 proves each claim *pairwise* sound; **pairwise ⇒ global was never located**, and that is what a basis set needs. Options (a) find it, (b) implement on Cor. 5.3 and document the gap, (c) leave it. **Do not pick (b) silently.** |
| **S3 correction** | **estimand change** | Detection ships; correcting means refitting *both* base and augmented with the grouping term, which changes what is tested |
| **drmTMB items 2 + 5** | **another repo's lane** | Item 2 (more than one `mi()` per fit) is what blocks S6 for realistic graphs. Coordinate lanes first |
| **`rho12()`/`corpairs()` returning a number** | **engine** | needs a joint bivariate likelihood; 0.4 roadmap milestone |
| **`population="marginal"` (OQ-9), `uncertainty="bootstrap"` (OQ-10)** | **unimplemented by decision** | they abort, and the aborts are tested |
| **CRAN** | **upstream** | not submittable while `drmTMB` and `symbolizer` are GitHub `Remotes:` |

**One arc is designed and ready but NOT started:** the m-separation completeness hunt —
`docs/memory/2026-08-15-next-arc-mag-completeness.md`. It is ~3h, **read-only**, and produces
the cited evidence Shinichi needs to answer S2. It implements nothing. It still needs its own
plan gate before it runs.

## 6. Gotchas that are still live

- **`git add <dir>` is `git add -A` wearing a mask.** Stage explicit file paths, always. Two
  PROTECTED figures were swept in this way once (`4c863de`, corrected in `b27ad01`); only the
  `.gitignore` guard actually prevents it.
- **Two pushes per arc cancels the first CI run.** One push per arc. Honoured this session by
  holding the after-task commit locally until `376f187`'s CI reported.
- **`.github/workflows/` cannot be pushed over HTTPS** — the OAuth token lacks `workflow` scope.
  Use `git push git@github.com:itchyshin/drmSEM.git main`. Nothing this session needed it.
- **`lane_preflight.sh` reports FOREIGN LANE ACTIVE from this lane's own direct-to-main
  commits.** False positive twice on 2026-08-15. Verify against live peers before believing it.
- **`match.arg()` proves a value is legal, not that it is used.** The V-116 lesson: for any
  forwarded option, assert two values give two different answers.
- **Count assertions from the suite delta, not by eye.** "6" went into the ledger; it was 5.
- `tools/check-vignette-tangling.R` prints several `object 'val' not found` eval errors before
  its `OK:` line. Pre-existing, exit 0, uninvestigated.

## 7. How to resume

Working dir `/Users/z3437171/Dropbox/Github Local/drmSEM`. Live R toolchain; `drmTMB` **0.7.0**
installed and fitting; `symbolizer` not installed. No env vars beyond `NOT_CRAN`.

```
NOT_CRAN=true Rscript -e 'devtools::test()'                     # expect 987 / 0 / 3 / 10 warn
NOT_CRAN=true Rscript -e 'devtools::check(error_on = "never")'  # expect 0E / 0W / 2N
Rscript tools/check-vignette-tangling.R                         # expect exit 0
```

`R CMD check` takes substantially longer than the ~2 min suite — budget them separately.

**Must not stage:** `man/figures/drmsem-thermal-*.png`, `tools/render-readme-thermal.R`.

**Review lenses** before any public claim: **Rose** (`systems-auditor`) and, for anything
inferential, **Fisher** (`inference-reviewer`).

### Resume prompt

```text
Read AGENTS.md and docs/memory/2026-08-15-claude-handover-2.md. drmSEM has no unblocked work; do not invent any. Confirm the landing state against git, report CI status for 376f187, and then ask which gated item to open a plan gate on.
```
