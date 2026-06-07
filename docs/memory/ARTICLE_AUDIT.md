# Article Audit

## 2026-06-07

Scope: all pkgdown articles listed in `_pkgdown.yml`.

Criteria: the article should state its purpose before mechanics, avoid internal
ledger labels in reader-facing headings, keep validation claims scoped to the
cached evidence, avoid stale engine-status wording, and tell readers when a
shown example is illustrative rather than executable.

| Article | Status | Notes |
| --- | --- | --- |
| `drmSEM.Rmd` | patched | Source comment no longer says engine integration is pending; it now explains that chunks are not run during article builds because they need a compiled drmTMB engine. |
| `drmSEM-overview.Rmd` | patched | Removed the public `OQ-6` label from the d-separation summary and roadmap row; kept the scoped calibration claim. |
| `effect-decomposition.Rmd` | patched | Source comment no longer says engine integration is pending; the illustrative figure remains clearly labelled as hand-set. |
| `covariance-edges-and-composites.Rmd` | patched | Updated the bivariate roadmap note: grammar, accessors, d-separation behaviour, and plotting ship; only non-`NA` live-fit read-back remains. |
| `bivariate-nodes.Rmd` | pass | Reader-facing caveat is clear: `drm_pair()` declares a node but never fabricates a fitted correlation. |
| `feedback-cycles.Rmd` | pass | The article leads with the simultaneity limitation and keeps cycle fitting claims honest. |
| `latent-variables.Rmd` | pass | Composite-vs-reflective wording is clear and does not overclaim joint latent measurement support. |
| `comparison.Rmd` | pass | Capability table is conservative and marks the remaining bivariate live-fit read-back as not shipped. |
| `phylogenetic-sem.Rmd` | patched | Replaced the unsupported "only SEM tool" superlative with a scoped niche statement; source comment updated for optional engine/ape dependencies. |
| `calibration.Rmd` | patched | Retitled and rewritten around the reader question, bottom-line results, study design, and scoped claim; internal `OQ-6` / `V-17` labels removed from public prose. |
| `validation.Rmd` | patched | Retitled and rewritten to describe effect-interval coverage and model-selection recovery without exposing internal `C-*` labels in headings. |

