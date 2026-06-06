# 10 — Cyclic / feedback graphs (0.5)

drmSEM is **DAG-only** today: `drm_toposort()` rejects any cycle as an error, and
the whole effect/d-separation stack assumes a topological order. The 0.5 milestone
lifts that restriction **for specific, explicitly-declared feedback motifs with a
defined estimand and propagation rule** — not for arbitrary cyclic graphs. This
doc is the design of record before any code; it is deliberately honest that
feedback in a *piecewise, distributional* SEM is genuinely hard and partly a
research question, and it proposes a minimal, defensible first increment rather
than a general cyclic solver.

## Why this is hard (two distinct problems)

A feedback motif — the canonical case is a **reciprocal pair** `y1 ⇄ y2`
(`y1 -> y2` and `y2 -> y1`) — breaks two things at once:

1. **Fitting.** drmSEM is piecewise: each node is one `drmTMB` fit of a response
   on its parents. In a non-recursive system a node's parent is also its
   descendant, so the regressor is correlated with the error
   (**simultaneity bias**); ordinary node-wise ML is inconsistent. Consistent
   estimation needs either **instrumental variables / 2SLS** (an exogenous
   predictor of `y1` that is excluded from `y2`'s equation, and vice versa) or a
   **joint** likelihood that estimates the whole system at once — neither of which
   the current one-fit-per-node engine provides.
2. **Effect propagation.** The simulation engine walks nodes in topological order;
   a cycle has no such order. "The effect of `x` on `y1`" must instead be defined
   as the system's **equilibrium / fixed point**, which only exists and is unique
   under a stability condition.

These are separable: (2) can be designed and prototyped in pure R against
*supplied* structural coefficients; (1) is the engine/identification problem.

## The estimand: equilibrium, not a path product

Write the structural form for the endogenous vector `y` with direct-effect matrix
`B` (`B[i,j]` = direct effect of `y_j` on `y_i`, zero on the diagonal) and
exogenous design `Gamma x`:

```
y = B y + Gamma x + e
```

The **reduced form** (the equilibrium response of `y` to `x`) is

```
y = (I - B)^{-1} (Gamma x + e),   total-effect matrix  T = (I - B)^{-1} Gamma
```

which exists iff `(I - B)` is invertible, and is the **stable equilibrium** iff
the spectral radius `rho(B) < 1` (otherwise the feedback diverges and no
population-average equilibrium effect is defined). `(I - B)^{-1} = I + B + B^2 +
...` is exactly the sum over **all walks** (including cycles) from `x` to `y` —
the feedback generalization of the acyclic path sum. This is the **linear**
estimand; it is exact for identity-link Gaussian feedback.

For **nonlinear / distributional** feedback (drmSEM's reason to exist), there is
no closed-form inverse. The estimand is instead the **fixed point of the
propagation map**: set `x` to its contrast value, then iterate
`y^{(t+1)} = g(B-propagated y^{(t)} + Gamma x)` (each node re-predicted from the
current working values of its parents, with the inverse link `g`) until
convergence, and read the equilibrium response. This reuses the existing
`drm_propagate()` machinery, replacing the single topological sweep with an
**iterate-to-fixed-point** loop guarded by a contraction/`max_iter` check. When
the map is not a contraction (no stable equilibrium), the effect is reported as
**non-convergent**, not a number — the honest analogue of the
`interaction_remainder` / `identified = FALSE` flags elsewhere.

## d-separation under feedback

DAG basis sets do not apply: a cyclic graph's conditional-independence structure
is given by **sigma-separation** (the cyclic generalization of d-separation;
Forré & Mooij 2017), which differs from d-separation precisely around the
feedback loop. The any-component LRT machinery is unaffected (it tests a node's
sub-models), but **`basis_set()` must not emit the standard claims across a
declared cycle**. The first increment will *suppress* independence claims among
the nodes of a declared feedback motif (parallel to how covariance edges drop the
`y1 _||_ y2` claim) rather than implement full sigma-separation — and document
that the goodness-of-fit test is scoped to the acyclic part until sigma-separation
lands.

## Proposed staged plan

**0.5.0 — declared linear feedback, reduced-form effects.**
- A `drm_cycle()` / `feedback =` declaration that *explicitly* names the motif
  (e.g. `feedback(y1, y2)`), so cycles remain a hard error unless declared. This
  keeps the "cycles are a bug" safety for everyone else.
- Relax `drm_toposort()` to accept a declared motif (order the rest of the graph;
  treat the motif as a single super-node in the topological layer).
- Effect engine: a `propagate_fixedpoint()` that iterates to equilibrium, with a
  `rho(B) < 1` / max-iter stability guard; report non-convergence honestly.
- `basis_set()` drops independence claims among the motif's nodes.
- Estimation stays the user's responsibility for now: the structural coefficients
  must come from a **consistent** fit (an IV/2SLS fit, or a joint fit the user
  supplies via `drm_psem()`). drmSEM does not silently fit a feedback system with
  biased node-wise ML — it warns when a declared cycle is fitted naively.

**0.5.x / engine — consistent estimation.** IV/2SLS support (exclusion
restrictions) or a joint drmTMB feedback likelihood, so drmSEM can *fit* a
declared cycle, not only propagate supplied coefficients. This needs the engine
and is out of scope for the pure-R lane.

**Deferred beyond 0.5:** full sigma-separation, automatic instrument discovery,
nonlinear stability proofs, and cycles of length > 2 with mixed links (supported
in principle by the fixed-point engine, validated incrementally).

## Current state (0.5.0 shipped)

The pure-R grammar and equilibrium engine now ship (`R/feedback.R`,
`test-feedback.R`):

- **`drm_cycle()` / `feedback =`** declaration, validated against the node
  records; `drm_sem()` / `drm_psem()` accept it and **warn** that node-wise ML is
  inconsistent under simultaneity. `cycles()` lists the declared motifs.
- **Relaxed toposort** (`drm_toposort_feedback()`): a declared motif is condensed
  into one layer; every *undeclared* cycle is still a hard error.
- **`basis_set()` suppression** of independence claims among a motif's nodes.
- **Effect-API refusal**: `direct_effects()` / `total_effects()` /
  `indirect_effects()` / `path_effects()` abort on a feedback SEM rather than
  return a misleading single-sweep number.
- **`propagate_fixedpoint()`** (internal): iterate-to-equilibrium with a
  spectral-radius / max-iter guard and honest non-convergence; `drm_reduced_form()`
  / `drm_spectral_radius()` give the linear `(I − B)^{-1} Gamma` estimand. A
  closed-form test confirms the simulated equilibrium equals the reduced form.

Remaining (next increments): wiring equilibrium effects into the public effect
API, full sigma-separation, and **consistent estimation** (IV/2SLS or a joint
likelihood) — the engine part.

## What is pure-R vs engine

- **Pure-R (designable/prototypable now):** the `drm_cycle()`/`feedback`
  declaration grammar, the relaxed toposort, the `propagate_fixedpoint()` engine
  with the stability guard and non-convergence reporting, the basis-set
  suppression, and closed-form recovery tests (a linear 2-cycle where the
  simulated equilibrium equals `(I - B)^{-1} Gamma`).
- **Engine / research:** consistent estimation of a feedback system (IV / joint
  likelihood), full sigma-separation, and identification conditions.

## Scope and non-goals

- Cycles remain an **error unless explicitly declared** — drmSEM does not guess
  feedback.
- drmSEM still never fits its own likelihoods; consistent feedback estimation is
  an engine capability (IV or joint), not a drmSEM solver.
- This is **not** a general structural-cyclic-causal-model solver; it is a defined
  set of feedback motifs with an equilibrium estimand.

## References

- Spirtes P (1995). Directed cyclic graphical representations of feedback models.
  *UAI 1995.*
- Forré P, Mooij JM (2017). Markov properties for graphical models with cycles
  and latent variables (sigma-separation). *arXiv:1710.08775.*
- Bollen KA (1989). *Structural Equations with Latent Variables* — reduced form
  `(I - B)^{-1}` and the simultaneity / instrumental-variables treatment.
- Fisher FM (1970). A correspondence principle for simultaneous equation models.
  *Econometrica* 38(1):73-92 (equilibrium interpretation of feedback systems).
