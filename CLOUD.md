# CLOUD.md — Cloud / Codex environment for drmSEM

`AGENTS.md` is the authoritative operating contract and is read first;
it references this file for the container/cloud environment setup. This
document describes how to provision a working environment for `drmSEM`
development, review, and CI in a cloud or Codex sandbox.

`drmSEM` is the SEM / graph / d-separation / path / effect-decomposition
layer. It never fits its own likelihoods: each endogenous node is one
`drmTMB` fit, and `drmTMB` is the fitting engine. `drmTMB` depends on
`TMB`, which **compiles from source** and therefore needs a working C++
toolchain. The setup below installs that toolchain plus the R
development stack and the engine itself.

## Setup script

Run this once when the environment is created. Setup scripts have
internet access even when the agent’s own runtime internet is later
turned off, so all network installs must happen here.

``` bash
sudo apt-get update
sudo apt-get install -y \
  build-essential gfortran make cmake git qpdf pandoc \
  libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
  libfreetype6-dev libharfbuzz-dev libfribidi-dev libglpk-dev
Rscript -e 'install.packages("pak", repos="https://cloud.r-project.org")'
Rscript -e 'pak::pak(c(
  "devtools", "roxygen2", "testthat", "rcmdcheck",
  "lintr", "styler", "covr", "knitr", "rmarkdown",
  "igraph", "cli", "rlang", "tibble", "withr"
))'
Rscript -e 'pak::pak("itchyshin/drmTMB")'
Rscript -e 'pak::pak(".")'
```

### What each step does and why

- **`apt-get` system libraries.** `build-essential`, `gfortran`, `make`,
  and `cmake` give `TMB`/`drmTMB` the C++/Fortran toolchain they need to
  compile. `git` is for source installs, `qpdf` and `pandoc` for
  `R CMD check` and vignette/manual building, and the `lib*-dev`
  packages are the system dependencies behind `curl`, `openssl`, `xml2`,
  the `systemfonts`/`textshaping` graphics stack (`ggplot2` plots), and
  `igraph` (`libglpk-dev`).
- **`pak`.** A fast, parallel installer that resolves system and GitHub
  dependencies. Installed from CRAN first, then used for everything
  else.
- **R development stack.** `devtools`, `roxygen2`, `testthat`,
  `rcmdcheck`, `lintr`, `styler`, `covr` for the dev/check/lint/coverage
  loop; `knitr` and `rmarkdown` for the vignette; `igraph`, `cli`,
  `rlang` are runtime imports; `tibble` and `withr` support tests and
  tabular output.
- **`pak::pak("itchyshin/drmTMB")`.** Installs the engine from GitHub.
  This is the slow step: `TMB` and `drmTMB` are compiled from source. Do
  it here, where internet is available.
- **`pak::pak(".")`.** Installs `drmSEM` itself from the working tree,
  picking up the `Remotes: itchyshin/drmTMB` entry in `DESCRIPTION`.

**Internet model.** The setup phase has internet; the agent runtime may
have its internet disabled. Treat the steps above as the only chance to
pull packages, so anything a later task needs must be installed during
setup. If `drmTMB` is not present at runtime, the integration tests and
model-fitting examples are skipped rather than failed (see below).

## Development loop

``` r

devtools::document()          # regenerate Rd + NAMESPACE from roxygen2
devtools::test()              # run testthat suite
devtools::check()             # R CMD check (uses the Remotes for drmTMB)
pkgdown::check_pkgdown()      # validate _pkgdown.yml against exports/vignettes
lintr::lint_package()         # static checks
styler::style_pkg()           # format
```

`devtools::document()` must be run after any roxygen change so
`NAMESPACE` and `man/` stay in sync; CI and review both assume they are
current.

## Test gating without the engine

The kernel tests (`tests/testthat/test-dsep-kernels.R`,
`tests/testthat/test-effect-kernels.R`, `tests/testthat/test-utils.R`)
exercise the d-separation bookkeeping, simulation-based effect calculus,
and utilities **without** fitting anything, so they run even when
`drmTMB` is unavailable.

`tests/testthat/test-integration.R` actually fits `drmTMB` nodes end to
end. It is **skipped when `drmTMB` is not installed** (guarded by
`testthat::skip_if_not_installed("drmTMB")`), so a toolchain-free
machine still gets a green suite on the kernel logic. The integration
path is the one that must run in the cloud/CI environment provisioned
above, where the engine is compiled and present.
