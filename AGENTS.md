# drmSEM Agent Instructions

`drmSEM` is an R package that adds a **distributional piecewise
structural equation modelling (SEM)** layer on top of the `drmTMB`
fitting engine. The project and paper use the name **DRMSEM**; the R
package is **drmSEM**.

This file is the authoritative operating contract. Codex and Claude Code
read it before doing work. `CLOUD.md` (environment setup) and the
checked-in files under `docs/memory/` and `.agents/skills/` are also
authoritative. Conversation history and Codex local memories are
convenience recall only — never the source of truth for required rules.

This kit was learned from the `drmTMB` agent operating kit and
re-scoped. Do not silently re-architect it.

## Core Scope

- **drmTMB = fitting engine; drmSEM = graph / SEM / d-separation / path
  / effect-decomposition layer.** drmSEM never fits its own likelihoods.
- One `drmTMB` model per endogenous node. The SEM is piecewise.
- Causal paths are **component-labelled**. A path may target any
  modelled distributional component: `mu`, `sigma`, `nu`, `zi`, `hu`,
  `sd(group)`, `rho12`. A path to `sigma` is **not** a path to the mean;
  a path to `zi` is **not** a path to the conditional mean; a path to
  `sd(site)` is a path to among-site heterogeneity. Keep these
  distinctions explicit everywhere.
- Observed-variable SEM only for 0.x. **No** latent variables, **no**
  new likelihoods, **no** full joint multivariate SEM, **no** arbitrary
  brms/glmmTMB/lme4 adapters, **no** unsupported drmTMB surfaces.
- DAGs only: cycles are an error.
- **Never** use coefficient-product mediation for non-Gaussian or
  cross-link paths. Indirect/total effects are simulation-based.

## Locked Decisions (see docs/memory/DECISIONS.md)

1.  **Interface = both.** Core
    [`drm_psem()`](https://itchyshin.github.io/drmSEM/reference/drm_psem.md)
    accepts already-fitted `drmTMB` objects; declarative
    [`drm_sem()`](https://itchyshin.github.io/drmSEM/reference/drm_sem.md) +
    [`drm_node()`](https://itchyshin.github.io/drmSEM/reference/drm_node.md)
    fit internally and delegate to the same core object.
2.  **d-separation = any modelled component.** A missing arrow X → Y
    asserts that X has no effect on *any* modelled component of Y,
    tested by a likelihood-ratio test of Y’s node augmented with X in
    each component sub-model. This is drmSEM’s *definition*, documented
    in `docs/design/03-dsep.md`.
3.  **Effects = simulation.** Direct/indirect/total effects use
    Monte-Carlo propagation over the fitted DAG, reported on link and
    response scales.

## Design Rules

1.  Do not add a public effect type, estimand, or d-separation rule
    without a simulation test that recovers a known data-generating
    process.
2.  Do not add user-facing functions without roxygen2 documentation.
3.  Do not change the graph grammar without updating
    `docs/design/01-semantics.md`.
4.  Do not change effect or d-separation semantics without updating
    `docs/design/02-effect-calculus.md` or `docs/design/03-dsep.md`.
5.  Isolate every assumption about drmTMB’s return shapes in
    `R/extractors.R` (the drmTMB adapter). No other file should reach
    into a drmTMB object directly.
6.  Keep pull requests small and focused.
7.  Every meaningful change updates `docs/memory/AGENT_LOG.md` and, when
    a claim becomes validated or experimental,
    `docs/memory/VALIDATION_LEDGER.md`.
8.  Record durable choices in `docs/memory/DECISIONS.md`; open issues in
    `docs/memory/OPEN_QUESTIONS.md`.
9.  Document provenance when code or text is ported from `drmTMB`.

## Standard Commands

``` r

devtools::document()
devtools::test()
devtools::check()
pkgdown::check_pkgdown()
lintr::lint_package()
styler::style_pkg()
```

See `CLOUD.md` for the container setup that installs R, the toolchain,
and `drmTMB` from GitHub.

## Definition of Done

A feature is done only when implementation, tests, roxygen docs, a
worked example, validation-ledger evidence, an AGENT_LOG entry, and
review are present.

## Writing Style

Write for applied ecology, evolution, and environmental-science users,
plus statistical method developers and R contributors.

- Name the purpose before mechanics.
- Pair symbolic equations, R syntax, and interpretation when explaining
  models.
- Use concrete files, equations, functions, or numbers, not vague
  phrases.
- Keep terms stable: `mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`,
  `rho12`, “component-labelled path”, “distribution-mediated effect”. Do
  not let them drift.
- For tutorials and error messages, tell the reader what to try next
  when a model or path is unsupported.

Use the `drmsem-semantics` skill for any prose or code that describes
what a path *means*; it exists to stop the recurring mistake of treating
every path as a mean effect.

## Standing Review Roles

Shorthand for recurring review perspectives. They do not run
continuously; the orchestrator launches them for bounded tasks. Use
these canonical names; one meaning per name.

| Name | Role | Primary questions |
|----|----|----|
| Ada | Orchestrator and integrator | What happens next; are code, math, docs, tests, and git consistent? |
| Boole | R API and graph-grammar reviewer | Is `drm_node`/`drm_sem` syntax memorable, parseable, consistent? |
| Gauss | Engine reviewer | Is graph extraction, propagation, and simulation correct and stable? |
| Noether | Mathematical consistency reviewer | Do path algebra, do-style propagation, and code match exactly? |
| Darwin | Ecology/evolution audience reviewer | Does the example answer a real biological question? |
| Florence | Scientific figure editor | Are DAG and distributional-SEM plots honest about component and uncertainty? |
| Fisher | Inference reviewer | Do d-separation, Fisher’s C, and effect decompositions support the claim? |
| Pat | Applied PhD-student user tester | Can a new user follow the workflow and interpret component-labelled output? |
| Jason | Landscape scout | What do lavaan, piecewiseSEM, dsem, glmmTMB do, and what should drmSEM learn/avoid? |
| Curie | Simulation and testing specialist | Do recovery tests cover ordinary, edge, and malformed cases without being slow? |
| Emmy | R package architecture reviewer | Are S3 methods, object structure, and internal APIs coherent? |
| Grace | CI, pkgdown, CRAN, reproducibility | Will this pass on all platforms and install cleanly? |
| Rose | Systems auditor | What drift, repeated mistakes, stale wording, or unsupported claims are accumulating? |

## Multi-Agent Collaboration

Codex and Claude Code may both contribute. All agent work must:

- preserve the observed-variable, piecewise, DAG-only scope;
- never call a non-mean path a mean effect;
- update design docs when semantics change;
- add tests with implementation;
- not revert another agent’s or human’s change unless asked;
- prefer small, reviewable commits.

Parallelize read-heavy and separable work (distinct files). Serialize
the write-heavy core (object model, effects engine) to avoid edit
conflicts. When handing work to another agent, leave enough context in
`docs/memory/AGENT_LOG.md` for the next agent to continue without
rediscovering the problem.

Launchable team agents live in mirrored `.codex/agents/` (Codex,
`.toml`) and `.claude/agents/` (Claude Code, `.md`) directories,
one-to-one with verbatim instruction bodies. If you add or change one,
change both in the same commit so the runtimes do not drift. Each
standing role above has exactly one launchable agent, keyed by role
function:

| Standing name | Agent slug                  |
|---------------|-----------------------------|
| Ada           | `orchestrator-integrator`   |
| Boole         | `api-grammar-reviewer`      |
| Gauss         | `engine-reviewer`           |
| Noether       | `math-consistency-reviewer` |
| Darwin        | `audience-reviewer`         |
| Florence      | `figure-reviewer`           |
| Fisher        | `inference-reviewer`        |
| Pat           | `user-tester`               |
| Jason         | `landscape-scout`           |
| Curie         | `simulation-tester`         |
| Emmy          | `architecture-reviewer`     |
| Grace         | `reproducibility-engineer`  |
| Rose          | `systems-auditor`           |

## Team Improvement Loop

When a task exposes a better way for the team to work, record it in
`docs/memory/AGENT_LOG.md`. Low-risk documentation, process, and local
skill improvements can be implemented immediately. Product,
architecture, or validation-policy changes need a normal task, evidence,
and review.

## pkgdown Policy

The pkgdown site is a first-class artifact. User-facing features should
include reference documentation and, when substantial, an article. Keep
`_pkgdown.yml` synchronized with exported functions and vignettes.
