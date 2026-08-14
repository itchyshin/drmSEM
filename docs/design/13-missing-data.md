# 13 — Missing data: row alignment, and imputation models derived from the graph

Two things, in dependency order. The first is a correctness fix that had to land
before the second could be safe.

- **S5 — row alignment.** A piecewise SEM must describe *one* sample.
- **S6 — graph-derived imputation.** When a node's parent is incomplete, the DAG
  already specifies the imputation model.

drmSEM fits nothing here. Both features assemble arguments that `drmTMB` fits
inside a single node's likelihood, so the charter (`00-charter.md`: drmSEM never
fits its own likelihoods) is unchanged.

---

## S5 — Row alignment

### The defect

drmSEM had **no missing-data policy at all** — no `na.omit`, `complete.cases` or
`na.action` anywhere in `R/`. `drm_sem()` handed one data frame to every node and
each `drmTMB` fit then dropped incomplete rows by its own rules. Reproduced live
with NAs in two different columns of a 300-row frame:

```
drm_sem() SUCCEEDED silently.  nobs: node m = 270, node y = 240
indirect_effects() -> "number of items to replace is not a multiple of replacement length"
```

Two distinct problems.

**1. Silent divergence.** Nodes fitted on different samples are not the model the
user asked for: path coefficients come from different row sets, and the
d-separation basis set is tested against yet another. Nothing warned.

**2. Undiagnosed crash — and a worse silent case.** `drm_fixed_design()`
(`R/extractors.R`) built its design matrix with `stats::model.matrix()`, which
honours `getOption("na.action")` — i.e. `na.omit`. With any NA present,
`nrow(mm) < nrow(newdata)` and the assignment `out[, shared] <- mm[, shared]`
mis-filled.

The error above is the *lucky* case. When `nrow(newdata)` is an exact multiple of
`nrow(mm)` — 300 against 150, say — R **recycles silently** and returns a
scrambled design matrix: a wrong number, with no condition raised at all. Any fix
that only prevents the error would leave the worse bug in place, so the
regression test asserts the recycling case explicitly.

### The policy

`drm_sem(na_action = )`, resolved **before** fitting:

| value | behaviour |
|---|---|
| `"warn"` (default) | fit anyway, report which node used how many rows |
| `"common"` | fit every node on the shared complete-case set |
| `"fail"` | abort |

The default warns rather than aborting so existing models keep fitting — but it
converts a silent wrong answer into a loud one, which is the actual defect.

`"common"` intersects the **per-node** row sets rather than running
`complete.cases()` over the whole frame, because `data` may carry columns no node
models and dropping rows for those would discard usable observations.

The finding is attached as `attr(x, "alignment_issues")`: a typed, zero-row-safe
data frame with machine-readable issue codes (`"rows_dropped"`,
`"row_set_mismatch"`), following the `drm_effect_draw_issues()` contract already
used for `uncertainty_issues`. It is surfaced in `print.drm_sem()` and as an
`nobs` column in `check_sem()`.

### d-separation

`drm_refit_augmented()` refits a node with `+ add_var`, so an incomplete
`add_var` made the likelihood ratio compare **two different samples**. This
produced a wrong number rather than an error, and the existing `df_diff <= 0`
guard could not catch it because the models are still nested. Such claims now get
`status = "n_mismatch"` and are excluded from Fisher's C.

---

## S6 — Imputation models derived from the graph

### The idea

In `x → m → y` with `m` incomplete:

- node `m` (`m ~ x`) fits with drmTMB's missing-**response** masking;
- node `y` (`y ~ m + x`) needs a missing-**predictor** model for `m` — and
  drmSEM already knows it: **it is node `m`'s own formula and family**.

So `drm_sem(..., impute = "auto")` emits

```r
drmTMB(bf(y ~ mi(m) + x), family = gaussian(), data = d,
       impute  = list(m = impute_model(m ~ x, family = gaussian())),
       missing = miss_control(predictor = "model"))
```

The user never writes an `impute_model()`.

### Why this is a contribution, not plumbing

1. **The conditioning set is derived, not guessed.** Choosing the imputation
   model is normally the error-prone step, governed by folklore ("include the
   outcome", "include everything"). The DAG gives `m`'s parents directly. This
   one is mechanical and is what V-77 tests.
2. **A congeniality argument — argued, not measured.** Imputer and analysis model
   are derived from one graph, which should reduce the uncongeniality risk
   between a separately specified imputer and analyst (Meng 1994). **No test in
   this package measures congeniality and nothing in the code checks it**; it
   carries no V-number. Treat it as a design rationale, not a validated claim,
   until someone builds the comparison against a deliberately uncongenial
   imputer.

### Honest limits — these ship in the docs

- **Not FIML across the SEM.** Piecewise means node `y` **re-estimates** `m`'s
  model inside its own likelihood; it does not share node `m`'s estimates. The
  two will not agree exactly. Uncertainty is **not** propagated across nodes —
  that part is structural and certain.

  The complementary half — that imputation uncertainty *is* propagated **within**
  a node via drmTMB's joint Hessian — is a statement about the **engine**, and
  drmSEM has **no test of its own** backing it. It is also version-sensitive:
  `imputed()$std_error` semantics changed between drmTMB 0.6.0 and 0.7.0 (see
  the version note below). Treat it as the engine's documented behaviour, not as
  something this package has verified.
- **Opt-in.** Imputation asserts a missing-at-random assumption. That is the
  user's call, not a silent default, so `impute = "none"` is the default.
- **Only endogenous parents.** An incomplete *exogenous* predictor has no node
  model in the graph, so the graph cannot specify its imputation model — which is
  the entire premise. Those are left to `na_action`.
- **One incomplete parent per node.** drmTMB models exactly one `mi()` term per
  fit. Two incomplete parents abort with that reason stated. This is the binding
  constraint for realistic graphs, and it is drmTMB Issue 2.

### Legality gate

Refuse rather than emit a call the engine would reject later with less context:

| node `y` family | permitted node `m` family |
|---|---|
| `gaussian` | the full predictor catalogue (gaussian, binomial, ordinal, categorical, beta, zero-one beta, beta-binomial, poisson, nbinom2, truncated nbinom2, lognormal, Gamma, tweedie) |
| `poisson`, `binomial`, `nbinom2`, `beta` | **binary only** |
| anything else | not supported |

`test-imputation.R` (V-80) locks drmSEM's response allow-list to
`drmTMB:::drm_missing_predictor_families()` so the two cannot drift.

`mi()` also has syntactic constraints the engine enforces: only in the `mu`
formula, only a bare symbol, only a simple additive term. A target that is not a
plain additive term is refused with that explanation.

A node with **no** incomplete parent is left completely untouched — zero `mi()`
terms under `predictor = "model"` is itself a hard abort in the engine, so a
blanket application would break every complete node.

### Why derivation runs on unfitted specs

`drm_sem()` fits nodes in **argument order, not topological order** (`$order` is
computed inside `new_drm_sem()`, after every fit). A feature that needs a node's
parents *while deciding how to fit it* therefore cannot wait for the fits.

`drm_build_spec_records()` makes this explicit. It works because every
`drm_fit_*` extractor is duck-typed on `$formula` and `$family` — exactly the two
fields a `drm_node` spec carries — so the fitted-object record builder already
works before anything is fitted.

### Evidence

`tests/testthat/test-imputation.R`.

- **V-77 (load-bearing).** The auto-derived fit is **numerically identical** to
  the hand-written `impute = list(m = ...)` fit. Per this package's convention, a
  public output is compared against quantities recomputed from the same fit
  rather than a hand formula — so a wrong derivation cannot hide behind
  good-looking recovery.
- **V-78.** Bias reduction under **outcome-dependent** missingness, replicated
  across four seeds. This DGP matters: under MCAR complete-case analysis is
  *already unbiased*, so an MCAR fixture would demonstrate plumbing and nothing
  else. Measured at n = 600 (313 complete rows), single seed illustration:

  | | intercept | `m` (truth 0.60) | `x` (truth 0.30) |
  |---|---|---|---|
  | complete-case | −0.194 | 0.513 | 0.274 |
  | graph-derived | 0.000 | 0.643 | 0.246 |

  The honest claim is **"recovers the intercept and reduces mediator-coefficient
  bias under outcome-dependent missingness"** — not "beats complete-case". It is
  slightly *worse* on `x`, and that is reported rather than buried.
- **V-79/V-80/V-81.** The failure boundary fails loud; the family gate matches
  the engine; `mi()` coefficients resolve to the right node.

### Engine dependencies

This works today on a Gaussian chain. It becomes *general* only after drmTMB
Issues 1 and 2 (`docs/memory/DRMTMB_ISSUES.md`) — the response-family gate and
the one-`mi()`-per-fit limit. The working prototype is the evidence to attach to
those asks, which is more persuasive than an abstract request.

**Version note.** `imputed()$std_error` semantics differ between drmTMB 0.6.0 and
0.7.0: on 0.6.0 every non-Gaussian route returns `NA`; on 0.7.0 most routes
compute a posterior SD and a sixth `uncertainty_status` level appears. Any
consumer must branch on `uncertainty_status`, never on `is.na(std_error)`.
