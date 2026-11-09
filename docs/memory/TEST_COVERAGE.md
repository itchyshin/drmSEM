# Test coverage collection and Codecov upload

**Slice:** first Codecov coding pass (drmSEM lane only)
**Approval:** Shinichi approved the 13-repo First+Next Codecov rollout;
this file records the pipeline, not a coverage percentage.

This is **code-coverage infrastructure** (`covr` + Codecov). It is not a
scientific `VALIDATION_LEDGER` claim, not interval calibration, and not
a change to component-labelled path semantics.

## What runs

| Workflow | Role | Shards | Uploads to Codecov? |
| --- | --- | --- | --- |
| `R-CMD-check.yaml` | package check (ubuntu + macos + windows) | three OS jobs, unchanged | **no** |
| `test-coverage.yaml` | `covr::package_coverage()` then one OIDC upload | ubuntu only | **yes, once** (`flags: ubuntu-covr`) |
| `pkgdown.yaml` | site build/deploy | n/a | no |

Do **not** add covr to the R-CMD-check OS matrix. The three OS jobs run
the same testthat suite; uploading more than once would double-count.

The coverage job installs `drmTMB` from Remotes, matching ubuntu
R-CMD-check, so engine-gated tests run. Existing
`skip_if_not_installed("drmTMB")` (and ggplot2 / ape / symbolizer)
contracts are unchanged. Coverage numbers, when they exist, describe
that suite under covr tracing — not a new scientific test suite.

Auth is documented Codecov OIDC (`use_oidc: true`) with job-scoped
`contents: read` and `id-token: write`. No `CODECOV_TOKEN`, and
`GITHUB_TOKEN` / `GH_TOKEN` is not used as a Codecov token. `GITHUB_PAT`
is only the usual r-lib token for package installs.

## Evidence stages (do not collapse)

Config on a branch is not functioning coverage. Keep these five claims
separate:

| Stage | What would prove it | This first pass |
| --- | --- | --- |
| 1. Local checks / local covr | `devtools::test()` / `covr::package_coverage()` on this host | **NOT_VERIFIED** — no R runtime here |
| 2. CI coverage finish | GitHub Actions `test-coverage` job produced `cobertura.xml` and a covr percent in the log / step summary | **NOT_VERIFIED** until that job completes |
| 3. Upload executed | Codecov action log shows a successful OIDC upload (`fail_ci_if_error: true`) | **NOT_VERIFIED** until that step succeeds |
| 4. Accepted commit report | Codecov commit URL for this SHA shows an accepted report | **NOT_VERIFIED** until Codecov accepts it |
| 5. Main dashboard coverage | https://app.codecov.io/gh/itchyshin/drmSEM (or the GitHub Codecov app) shows `main` | **NOT_VERIFIED**; needs an authorized merge to `main` plus a successful `push` run of `test-coverage.yaml` on `main` |

Stage 5 is why the workflow listens to `push` on `main` as well as
`pull_request`. GitHub Actions will run the PR workflow from this branch
without merging. The **main dashboard** will not exist until someone with
merge authority lands the workflow on `main` and that `push` job uploads.
This lane does not merge.

On `pull_request` events, `actions/checkout` records the **synthetic
merge commit** as `github.sha`. The branch head is
`github.event.pull_request.head.sha`. The workflow logs both. Do not
treat them as the same SHA.

itchyshin/hsquared PR 364 processed an OIDC branch report without owner
action. That does **not** verify drmSEM until this repo's uploader and
Codecov commit report succeed.

## Architecture notes

- PR comments from Codecov, if the GitHub App is installed, can appear
  on this PR after a successful upload. That is stage 4-ish, still not
  stage 5.
- If OIDC upload fails, treat that as an actual uploader failure before
  asking the owner for a Codecov GitHub App grant or a repository token.
  Do not mint or extract tokens; do not put `GH_TOKEN` in the Codecov
  `token:` input.
- Coverage status checks are **informational** (`codecov.yml`). This pass
  does not fail PRs on an unknown baseline percentage.
- README Codecov badge is deferred until stage 4 exists. A badge is not
  evidence.

## Local covr (when R is available)

```r
# Same skip contracts as ubuntu R-CMD-check; install drmTMB first
cov <- covr::package_coverage()
print(cov)
covr::report(cov)
```

Do not treat a local percent as a Codecov dashboard number.
