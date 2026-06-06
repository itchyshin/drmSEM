# 07 — Bivariate models and covariance edges (rho12, corpairs)

drmSEM must distinguish a **directed path** from a **covariance edge**. The point
of failure this doc closes: `rho12` (pronounced "rho one-two") is *not* a causal
path from response 1 to response 2. It is the **residual correlation between two
responses in a bivariate model** — a double-headed arc, exactly like a residual
covariance in classical SEM, not a causal arrow.

Positioning sentence (paper/package):

> Existing piecewise SEM tools represent a relationship between two responses
> only as a directed path; drmSEM separates the directed causal/distributional
> path from the residual correlation between responses (`rho12`) and from
> higher-level random-effect covariances, so that "does y1 cause y2?" and "do
> y1 and y2 stay coupled after we condition on predictors?" are different,
> separately reported questions.

## What rho12 is

A bivariate Gaussian node models two responses jointly with five components:
`mu1`, `mu2`, `sigma1`, `sigma2`, and `rho12`. The data-generating form is the
bivariate normal

```
[y1, y2] ~ MVN([mu1, mu2], Omega),
Omega = [[ s1^2,           rho12 * s1 * s2 ],
         [ rho12 * s1 * s2, s2^2           ]]
```

with `s1 = sigma1`, `s2 = sigma2`. `rho12` is the **residual** correlation
between `y1` and `y2`: the correlation that remains *after* `mu1`, `mu2`,
`sigma1`, and `sigma2` are accounted for. A path `rho12 ~ x` means a predictor
`x` changes that residual correlation **on the correlation-link scale**, after
the means and scales are conditioned out. It is emphatically:

- **not** a mean effect — it does not move `mu1` or `mu2`;
- **not** `y1 -> y2` — there is no directed arrow between the two responses;
- a statement about how tightly the two residuals co-vary, and how that coupling
  shifts with `x`.

Keep the term stable: `rho12` is the residual response-response correlation
component, listed alongside `mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)` in the
component vocabulary (AGENTS.md).

## When you need a bivariate model (and when you do not)

Most two-response questions are *not* bivariate-covariance questions:

- **Ordinary piecewise directed paths** — `x -> y1 -> y2`. Here `y2` depends on
  `y1` through a directed arrow; each node is a separate drmTMB fit; no bivariate
  model is needed, and `paths()`/`dsep()`/effects already handle it.
- **Bivariate (rho12) model** — the question is "do `y1` and `y2` remain
  *residually* correlated after their predictors, and does that correlation
  *change* with `x`?" That coupling is not a directed path; it is a covariance
  between two responses fitted in one bivariate drmTMB node, surfaced as `rho12`.

Rule of thumb: if you can name a direction ("`y1` causes `y2`"), it is a directed
path. If you only mean "they move together for reasons outside the modelled
means," it is a covariance edge.

## The three edge classes

drmSEM must separate three distinct edge classes. Conflating them is the mistake
this doc exists to prevent.

1. **Directed causal / distributional path** (single solid arrow).
   `y1 -> y2`, `x -> mu(y)`, `x -> sigma(y)`, `x -> zi(y)`, and crucially
   `x -> rho12(y1, y2)`. A predictor that *changes* the residual correlation is
   a **legitimate directed path into the `rho12` component** — it is what drmSEM
   0.1 already extracts from a bivariate drmTMB fit. These edges contribute to
   causal paths and to indirect/total effects.
2. **Residual covariance edge** (double-headed arc), labelled `rho12`.
   `eps_y1 <-> eps_y2`: the two response residuals are allowed to co-vary within
   an observation. This is a covariance, exactly like a residual covariance in
   classical SEM — **not** a causal arrow.
3. **Higher-level random-effect covariance edge** (double-headed arc).
   `u_id,y1 <-> u_id,y2` (group-level), `u_phylo,y1 <-> u_phylo,y2`,
   `u_site,mu <-> u_site,sigma`. A covariance between *random effects* sharing a
   grouping level, surfaced via a `corpairs()`-type accessor.

**The rule.** `rho12` and `corpair` edges are **covariance allowances**, not
directed paths. They contribute to **neither** causal paths **nor** indirect
effects. Only class (1) — directed edges, including `x -> rho12` — enters the
path algebra and the effect decomposition. Classes (2) and (3) are arcs that say
"these two are permitted to remain associated"; they constrain d-separation (see
below) but carry no direction and no mediated effect.

## Residual vs higher-level correlation

The two arc classes (2) and (3) answer different biological questions and live at
different levels:

- **Residual correlation `rho12` = within-observation** `eps_y1 <-> eps_y2`. "On
  a single occasion, when this individual's `y1` is above its predicted mean, is
  its `y2` also above its predicted mean?" A within-observation deviation
  coupling.
- **Random-effect correlation = between-unit** `u_id,y1 <-> u_id,y2` (e.g. the
  shared-label block `(1|p|id)` in glmmTMB-style syntax). "Do individuals that
  average high on `y1` also average high on `y2`?" A between-individual *average*
  coupling.

These are not interchangeable. An animal-personality study can have a positive
between-individual correlation (bold individuals are on average more active) with
a near-zero within-observation residual correlation, or vice versa. drmSEM must
report them separately and never collapse one into the other.

## Accessors: `rho12()` vs `corpairs()`

Two accessors, querying the *fitted object* (drmSEM never re-solves):

- `rho12(fit)` — the fitted **residual** response-response correlation (class 2),
  i.e. the bivariate node's estimated `rho12`, optionally as a function of `x`
  when `rho12 ~ x` is modelled.
- `corpairs(fit)` — the fitted correlations among **random-effect / structured
  covariance-pair blocks** (class 3): the `u_*,y1 <-> u_*,y2` correlations the
  fit actually contains.

drmSEM must **query** the fitted drmTMB object and expose **only correlations
actually present**. Do not assume every block exists: a fit may have a residual
`rho12` and no random-effect correlation, a random-effect correlation and no
residual `rho12`, both, or neither. The accessors report what is there; they do
not fabricate empty blocks. This mirrors the adapter rule in AGENTS.md — every
assumption about drmTMB return shapes stays in `R/extractors.R`.

## Proposed API

A first-class bivariate node and a covariance accessor that stays out of
`paths()`:

```r
# A bivariate node returns two response sub-nodes PLUS the extra
# covariance structure between them.
pair <- drm_pair(
  activity ~ x + (1 | id),
  boldness ~ x + (1 | id),
  rho12 = ~ x,                 # x -> rho12: directed path INTO the correlation
  family = gaussian()
)
# pair exposes sub-nodes `activity` and `boldness`, plus:
#   rho12(activity, boldness)              # residual covariance edge (class 2)
#   corpair(id: activity, boldness)        # higher-level RE covariance edge (3)

sem <- drm_sem(pair, fitness = drm_node(fitness ~ activity + boldness),
               data = dat)

paths(sem)         # directed-only: x -> mu, x -> rho12, activity -> fitness, ...
covariances(sem)   # covariance edges only, residual and higher-level SEPARATELY
plot(sem, show = "all")
```

- `drm_pair()` — a bivariate node type returning two response sub-nodes (e.g.
  `activity`, `boldness`) plus the extra covariance structure
  (`rho12(activity, boldness)`, `corpair(id: activity, boldness)`).
- `covariances(sem)` — an accessor returning **residual** (`rho12`) and
  **higher-level** (`corpair`) correlation edges, reported separately from
  `paths(sem)`. `paths()` stays **directed-only** (including `x -> rho12`).
- `plot(sem, show = "all")` — **solid arrows** for directed paths, **double-headed
  arcs** for residual covariance (`rho12`), **dashed arcs** for higher-level
  covariance (`corpair`). The three edge classes must be visually distinct.

## Level-compatibility rule

Estimate and report a higher-level correlation **only** among random effects that
share the **same level**, the **same grouping index**, and a **compatible
covariance structure**. Examples:

- OK: `id-y1 <-> id-y2` (same `id` grouping, two responses).
- OK: `species-phylo-y1 <-> species-phylo-y2` (same phylo block, two responses).
- OK: `site-mu <-> site-sigma` (same `site` grouping, two components of one
  response).
- NOT generally OK: `site <-> species` (different levels), `phylo <-> spatial`
  (different structured-effect kinds / covariance structures), or any unrelated
  cross-model block.

A correlation is only meaningful where the two random effects are draws from the
same grouping with a shared, compatible covariance. drmSEM must refuse to invent
correlations across incompatible blocks.

## d-separation consequence (important)

Covariance edges change what the basis set is allowed to claim. If a residual or
random-effect covariance edge between two responses is present, the basis set
**must not** generate the independence claim

```
y1 _||_ y2 | predictors
```

because the model has *explicitly allowed* `y1` and `y2` to remain associated
(via `rho12` or a `corpair`). Testing that claim would test an independence the
analyst deliberately did not assume.

This is the same separation of roles as everywhere else in drmSEM:

- **Directed edges** (class 1, including `x -> rho12`) contribute to causal paths,
  indirect/total effects, and adjacency in the usual way.
- **`rho12` / `corpair` edges** (classes 2, 3) are **covariance allowances**:
  they carry no direction and no effect, but the d-separation machinery
  (`basis_set()` / `dsep()`) **must be aware of them** and drop any independence
  claim between two responses joined by such an edge.

This parallels how a residual covariance is handled in classical d-separation
(Shipley): a bidirected edge removes the corresponding independence claim from
the basis set.

## Feature comparison

| Feature | classical SEM | piecewiseSEM | drmSEM current (0.1) | drmSEM roadmap |
| --- | --- | --- | --- | --- |
| Directed path `y1 -> y2` | yes | yes | **yes** | yes |
| `x -> rho12` as directed path into correlation | n/a | no | **yes (from bivariate drmTMB fit via `drm_psem()`)** | yes |
| `drm_pair()` bivariate node type | n/a | no | no | **yes** |
| Residual covariance `eps_y1 <-> eps_y2` (`rho12`) as arc | yes | partial | no | **yes** |
| Higher-level RE covariance (`corpair`) as arc | limited | no | no | **yes** |
| `rho12()` / `corpairs()` accessors | n/a | no | no | **yes** |
| `covariances()` separate from `paths()` | n/a | no | no | **yes** |
| Double-headed / dashed arc plotting | yes (semPaths) | no | no | **yes** |
| Level-compatibility rule for RE correlations | manual | no | no | **yes** |
| d-sep aware of covariance edges (drop `y1 _||_ y2`) | yes (Shipley) | partial | no | **yes** |

## Honest current state (0.1)

drmSEM already extracts `x -> rho12` as a **directed-path component** *if* it is
given a bivariate drmTMB fit through `drm_psem()`: a predictor on the `rho12`
component is treated like any other component-labelled path and flows into
`paths()`/`dsep()`/effects. That much works today.

What does **not** yet exist (the roadmap):

- **No `drm_pair()`** node type; bivariate structure must be built upstream in
  drmTMB and handed in via `drm_psem()`.
- **No `covariances()` / `rho12()` / `corpairs()`** accessors.
- **Residual and RE covariance edges are not represented as double-headed arcs**
  in `plot()`.
- **`dsep()` has no covariance-awareness** — it does not yet drop the
  `y1 _||_ y2 | predictors` claim when a covariance edge is declared.

These are tracked in OQ-14 and require a **live bivariate drmTMB fit** to
validate (the dev container cannot fit one).

## Honest non-goals (0.x)

drmSEM does **not** promise, in 0.x: a joint multivariate SEM likelihood across
all responses (the bivariate node is still one drmTMB fit, not a global joint
model); arbitrary >2-response covariance blocks beyond what drmTMB fits;
estimation of the residual/RE correlation *inside* drmSEM (it is always read back
from the fitted drmTMB object); or treating a covariance edge as if it carried a
direction or a mediated effect. Covariance edges are allowances, not paths, and
that boundary is permanent.
