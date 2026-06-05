# Standing review prompt — drmSEM pull requests

You are reviewing a pull request against `drmSEM`, the distributional piecewise
SEM layer built on the `drmTMB` fitting engine. Read `AGENTS.md` first; it is the
authoritative operating contract. Review through the standing roles below and
report findings grouped by role, each with a file/line reference and a concrete
fix. Block the PR on any cardinal-sin or correctness failure.

## What to check

### Boole — R API and graph grammar
- Is `drm_node()` / `drm_sem()` / `drm_psem()` syntax consistent, parseable, and
  memorable? Are new arguments named in the stable vocabulary?
- Does the public API stay within `paths()`, `basis_set()`, `dsep()`,
  `fisher_c()`, `direct_effects()`, `total_effects()`, `indirect_effects()`,
  `standardize()`, `check_sem()`, `plot()`?

### Gauss — engine / extraction
- Is graph extraction, Monte-Carlo propagation, and simulation correct and
  numerically stable?
- **drmTMB access stays inside `R/extractors.R`.** No other file may reach into
  a `drmTMB` object's internals directly. Flag any leak.

### Noether — mathematical consistency
- Do the path algebra and do-style propagation in code match the design docs
  (`docs/design/02-effect-calculus.md`, `docs/design/03-dsep.md`)?

### Fisher — inference
- **d-separation = any-component LRT.** A missing arrow X → Y asserts X has no
  effect on *any* modelled component of Y, tested by augmenting Y's node with X
  in each component sub-model. Check the LRT bookkeeping: degrees of freedom,
  which components were augmented, and how the per-claim tests combine into
  Fisher's C and its p-value.
- Are direct/indirect/total effects **simulation-based**? Flag any use of
  **coefficient products** for mediation — for non-Gaussian or cross-link paths
  this is wrong and is forbidden.

### Curie — simulation and testing
- Do tests accompany the code? Kernel tests (d-sep bookkeeping, effect calculus,
  utils) must run **without** `drmTMB`. Integration tests that fit nodes must be
  **gated** with `skip_if_not_installed("drmTMB")`.
- Do recovery tests cover ordinary, edge, and malformed inputs without being
  slow?

### Emmy — package architecture
- Are S3 methods, object structure, and internal APIs coherent? Is roxygen2
  documentation present for every user-facing function, and is `NAMESPACE`
  synced with the roxygen tags (`devtools::document()` run)?

### Grace — CI, reproducibility, CRAN
- Will this pass `R CMD check` on Ubuntu, macOS, and Windows and install cleanly
  with the `drmTMB` remote? Is `_pkgdown.yml` synchronized with exports and
  vignettes?

### Rose — systems audit
- **The cardinal sin: no non-`mu` path described as a mean effect.** A path to
  `sigma`, `nu`, `zi`, `hu`, `sd(group)`, or `rho12` is not a path to the mean.
  Reject any prose, label, or message that calls a non-mean path a mean effect.
- Confirm the graph stays DAG-only (cycles are an error) and observed-variable
  only (no latents, no new likelihoods).
- Are the docs and memory ledgers updated? `docs/memory/AGENT_LOG.md` for every
  meaningful change, `docs/memory/VALIDATION_LEDGER.md` when a claim becomes
  validated or experimental, and the relevant `docs/design/*.md` when semantics
  change.
