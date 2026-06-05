---
name: r-package-engineer
description: R package craft for drmSEM — roxygen2 on every export, S3 conventions, the document/test/check dev loop, NAMESPACE sync, cli messaging, tests shipped with implementation, small focused commits.
---

# R package engineer (drmSEM)

Apply this whenever you add or change R code in `drmSEM`. drmSEM is a pure-R
graph/SEM layer; the fitting engine is `drmTMB`. Keep the package CRAN-shaped and
the API memorable.

## Dev loop (run in this order; never skip document)
```r
devtools::document()      # regenerate NAMESPACE + man/ from roxygen
devtools::test()          # testthat
devtools::check()         # target 0 errors / 0 warnings / 0 notes
pkgdown::check_pkgdown()  # reference/article sync
lintr::lint_package()
styler::style_pkg()
```
- `NAMESPACE` is generated. Never hand-edit it; add `@export` / `@importFrom`
  roxygen and re-run `document()`. Importing a new function means an
  `@importFrom` tag (see `R/drmSEM-package.R` for the central `@importFrom`
  block), not a bare `::`-free call.

## Documentation
- Every exported function gets a roxygen block: `@param` for each arg,
  `@return`, `@export`, and at least one `@examples`. Examples that need a fit
  go in `if (requireNamespace("drmTMB", quietly = TRUE)) { ... }` or `\dontrun{}`.
- S3 generic + method docs use `@rdname` to share one help page (see `paths`,
  `dsep`, `fisher_c`, `standardize`, `check_sem`).
- Name the purpose before the mechanics; pair equation + R syntax + interpretation.

## S3 conventions (match existing code)
- Public verbs are S3 generics with `UseMethod()` and a `.drm_sem` method:
  `paths`, `basis_set`, `dsep`, `fisher_c`, `standardize`, `check_sem`.
- Return classed data frames (`drm_paths`, `drm_dsep`, `drm_effect`,
  `drm_diagnostics`) with `c("drm_xxx", "data.frame")` and a `print.drm_xxx`.
- Constructors stay internal (`new_drm_sem`); validate inputs there with `cli`.
- Internal helpers are prefixed `drm_` and tagged `@keywords internal` / `@noRd`.

## Messaging — use cli, not base
- Errors: `cli::cli_abort(c("headline", "x" = "detail", "i" = "what to try"))`.
- Warnings: `cli::cli_warn`; info: `cli::cli_inform`; progress:
  `cli::cli_progress_step`. Use `{.fn}`, `{.arg}`, `{.val}`, `{.code}`, `{.pkg}`.
- When a path/family/feature is unsupported, the message must tell the user the
  next thing to try (install drmTMB, refit with `se = TRUE`, choose another
  family, etc.).

## Tests and commits
- Ship tests with the implementation in the same change. Pure-logic kernels
  (links, propagation, basis-set construction, edge typing) must run WITHOUT
  drmTMB; gate any fit-dependent test with `skip_if_not_installed("drmTMB")`.
- Keep commits small and focused (one concern each). Update
  `docs/memory/AGENT_LOG.md` for meaningful changes.

## Don't
- Don't reach into a `drmTMB` object outside `R/extractors.R`.
- Don't add a public effect type / estimand / d-sep rule without a recovery test.
- Don't add compiled code; drmSEM has none and must stay pure R.
