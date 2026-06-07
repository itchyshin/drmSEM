## Release summary

drmSEM 0.5.0 closes the cyclic / feedback-graph milestone. It provides a
distributional piecewise structural equation modelling layer over the drmTMB
fitting engine: component-labelled causal paths (mean, scale, zero-inflation,
shape, random-effect scale, residual correlation), d-separation / Fisher's C
goodness-of-fit, phylopath-style model comparison, Monte-Carlo counterfactual
effect decomposition (controlled and natural; outcome functionals; per-mediator
and per-component path attribution), covariance-edge and composite-construct
grammars, declared feedback motifs with an equilibrium estimand and a pure-R
fixed-point propagator, a graph-interchange layer (lavaan syntax / Graphviz DOT),
finalized standardization conventions, and phylogenetic SEM support (fixed-grid
BM / lambda / OU / kappa covariance). The any-component d-separation calibration
study has been run on the live engine for its scoped grid; consistent feedback
estimation and joint bivariate fitting remain engine-dependent and out of this
release's scope.

## Test environments

- Local: R 4.3.x (dev container; pure-logic kernel tests).
- GitHub Actions: ubuntu-latest, macos-latest, windows-latest (R release),
  full R CMD check with the drmTMB engine installed from its repository.

## R CMD check results

0 errors | 0 warnings | 0 notes on the standard CI `R CMD check`.

Note: a full `R CMD check --as-cran` will additionally NOTE the `Remotes:` field
(CRAN forbids it; removed once drmTMB is on CRAN — see Notes below). The full GPL
text is kept in the repo but excluded from the build tarball via `.Rbuildignore`,
consistent with `License: GPL (>= 3)`.

## Notes

- The fitting engine drmTMB is currently distributed from GitHub
  (`Remotes: itchyshin/drmTMB`) and is listed under Suggests; all engine-using
  examples, tests, and vignette chunks are guarded with
  `requireNamespace("drmTMB")` so the package checks cleanly without it. This is
  not intended for CRAN submission until drmTMB is itself on CRAN; the file is
  kept to track release readiness.
- `ape` (phylogenetic covariance) is likewise a guarded Suggests dependency.
