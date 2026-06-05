---
name: cran-readiness
description: Keep drmSEM CRAN-clean — R CMD check 0 errors/0 warnings, examples that need drmTMB wrapped in \dontrun, Remotes for the GitHub engine, no compiled code in drmSEM itself, DESCRIPTION hygiene, ASCII, reasonable file sizes, reproducible RNG. Use before release or when touching DESCRIPTION/examples/CI.
---

# drmSEM CRAN readiness

Goal: `devtools::check()` returns 0 errors, 0 warnings, and notes are explained
or eliminated. drmSEM is a PURE-R layer; the compilation lives in `drmTMB`.

## The drmTMB-from-GitHub problem
- `drmTMB` is not on CRAN; it is `Remotes: itchyshin/drmTMB` in DESCRIPTION and
  `Suggests:` (not `Imports:`) so the package installs and checks without it.
- CRAN check machines will NOT have `drmTMB`. Therefore:
  - Every example that fits or touches a `drmTMB` object must be wrapped in
    `\dontrun{}` (or `\donttest{}` only if it can truly run offline — it cannot
    here, so use `\dontrun{}`).
  - Code paths guard with `requireNamespace("drmTMB")` / `drm_require_drmTMB()`.
  - Vignettes that need the engine must `eval = FALSE` the engine chunks or
    pre-compute, so `R CMD check` builds them without `drmTMB`.
- Integration tests are `skip_if_not_installed("drmTMB")`; pure kernels run
  everywhere (see `validation-harness`).

## No compiled code in drmSEM
drmSEM ships no `src/`, no C/C++/Fortran. If you ever reach for compiled code,
it belongs in `drmTMB`, not here. Keep `SystemRequirements` empty.

## DESCRIPTION hygiene
- Title in Title Case, no trailing period; Description full sentences.
- Correct `Imports`/`Suggests` split: `cli` (messaging) in Imports; `drmTMB`,
  `testthat`, `knitr`, `rmarkdown`, `pkgdown` in Suggests.
- `Authors@R` with valid roles/ORCID; `License` matches the LICENSE file.
- Bump `Version` per change; keep `Remotes` in sync with the engine source.

## ASCII, encoding, file sizes
- Source and man pages ASCII-only; replace curly quotes, arrows (use `->` in
  code/comments not the unicode arrow), Greek letters (write `sigma`, not the
  symbol) outside rendered Rd/vignette math. `desc::desc()` Encoding UTF-8 only
  if genuinely needed.
- Keep installed package and individual files reasonably small; no large data or
  build artifacts checked in.

## Reproducible RNG
- Any example/test/vignette that samples calls `set.seed()`.
- Inside the package, never call `set.seed()` in exported functions (don't clobber
  the user's stream); expose a `seed`/`B`/`n_sim` argument instead and document it.

## Pre-release checklist
- [ ] `devtools::document()` then confirm NAMESPACE matches roxygen.
- [ ] `devtools::check()` -> 0 errors / 0 warnings; notes explained.
- [ ] All engine-dependent examples in `\dontrun{}`; check builds without drmTMB.
- [ ] `lintr::lint_package()` and `styler::style_pkg()` clean.
- [ ] `pkgdown::check_pkgdown()` clean; reference lists all exports.
- [ ] No `src/`; DESCRIPTION version bumped; `Remotes` present.
- [ ] ASCII-clean; seeds set in stochastic examples.
- [ ] `R CMD check --as-cran` simulated locally if a real submission is intended.
