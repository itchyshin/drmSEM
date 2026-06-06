## Release summary

drmSEM 0.2.0 is the second release. It provides a distributional piecewise
structural equation modelling layer over the drmTMB fitting engine:
component-labelled causal paths (mean, scale, zero-inflation, shape,
random-effect scale, residual correlation), d-separation / Fisher's C
goodness-of-fit, phylopath-style model comparison, Monte-Carlo counterfactual
effect decomposition (controlled and natural; outcome functionals; per-mediator
and per-component path attribution), covariance-edge and composite-construct
grammars, finalized standardization conventions, and phylogenetic SEM support
(fixed-grid BM / lambda / OU / kappa covariance). The any-component d-separation
calibration study is scaffolded but not yet run, and is documented as
experimental.

## Test environments

- Local: R 4.3.x (dev container; pure-logic kernel tests).
- GitHub Actions: ubuntu-latest, macos-latest, windows-latest (R release),
  full R CMD check with the drmTMB engine installed from its repository.

## R CMD check results

0 errors | 0 warnings | 0 notes (on the CI matrix).

## Notes

- The fitting engine drmTMB is currently distributed from GitHub
  (`Remotes: itchyshin/drmTMB`) and is listed under Suggests; all engine-using
  examples, tests, and vignette chunks are guarded with
  `requireNamespace("drmTMB")` so the package checks cleanly without it. This is
  not intended for CRAN submission until drmTMB is itself on CRAN; the file is
  kept to track release readiness.
- `ape` (phylogenetic covariance) is likewise a guarded Suggests dependency.
