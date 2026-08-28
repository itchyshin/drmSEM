# 09 — Latent & MIMIC Measurement Blocks (0.3)

The 0.3 milestone expands `drmSEM`'s latent-construct capabilities to support **MIMIC (Multiple Indicators, Multiple Causes)**, **formative**, and **reflective** constructs while strictly preserving `drmSEM`'s core architectural tenets:
- Observed-variable, piecewise estimation (one `drmTMB` model per endogenous node; no joint full-information likelihood).
- Causal paths are **component-labelled** (`mu`, `sigma`, `nu`, `zi`, etc.).
- Direct, indirect, and total effects are simulation-based Monte-Carlo propagations over the fitted DAG.
- Honest separation between measurement model loadings (`loadings(sem)`) and causal path structure (`paths(sem)`).

Code: `R/latents.R`, `R/composite.R`, `R/drm_sem.R`, `R/effects.R`.

---

## 1. Construct Specification & Grammar

Users specify latent and composite constructs via `drm_latent()`, `drm_indicator()`, and `drm_composite()`:

```r
# Reflective construct (unit-variance or marker-indicator identified)
eta_refl <- drm_latent(
  name = "eta",
  indicators = c("y1", "y2", "y3"),
  type = "reflective",
  identification = "marker", # or "unit_variance"
  marker = "y1"
)

# MIMIC model: Multiple Causes (x1, x2) -> Latent (eta) -> Multiple Indicators (y1, y2, y3)
eta_mimic <- drm_latent(
  name = "eta",
  indicators = c("y1", "y2", "y3"),
  causes = c("x1", "x2"),
  type = "mimic",
  identification = "marker",
  marker = "y1"
)

# Formative construct (indicators define the construct)
eta_form <- drm_latent(
  name = "index",
  indicators = c(drm_indicator("x1", loading = 0.5), drm_indicator("x2", loading = 0.5)),
  type = "formative"
)
```

### Identification Rules

1. **Marker Indicator (`identification = "marker"`):**
   - The designated marker indicator (default: first indicator) is constrained to have a unit loading ($\lambda_1 = 1$).
   - Other indicator loadings are estimated or extracted relative to the marker.
2. **Unit Variance (`identification = "unit_variance"`):**
   - The latent construct is constrained to have unit variance ($\mathrm{Var}(\eta) = 1$).
   - Loadings reflect the standard deviation of each indicator explained by the common factor.

---

## 2. Piecewise Estimation & Score Materialization

In the piecewise SEM framework:
1. **Measurement Scoring:** Indicators are summarized into latent scores ($\hat{\eta}$) via principal components (`method = "pca"`), factor-analytic weighting (`method = "fa"`), or fixed user-specified weights (`method = "fixed"`).
2. **Sign Alignment:** The principal component / factor score is sign-aligned so that the dominant loading (or the marker indicator) is strictly positive.
3. **Data Materialization:** Before any `drmTMB` node models are fitted, `drm_apply_latents()` materializes the latent construct columns into the analysis dataset.
4. **Structural Node Estimation:** Structural equations treat the materialized construct $\eta$ as an endogenous node or predictor (e.g. `eta ~ x1 + x2`, `z ~ eta`, `sigma ~ eta`).
5. **Separation of Measurement and Structural Paths:**
   - `loadings(sem)` returns the measurement loadings matrix ($\lambda_k$, standardized loadings, construct type, identification rule).
   - `paths(sem)` returns solely the causal paths among variables, preserving the distinction between measurement definition and structural causal effects.

---

## 3. Reliability Metrics

`drmSEM` provides internal-consistency and composite reliability metrics:

- **Cronbach's $\alpha$ (`drm_cronbach_alpha(M)`):** Classical lower bound on reliability under tau-equivalence:
  $$\alpha = \frac{k}{k-1} \left( 1 - \frac{\sum_{i=1}^k \sigma_i^2}{\sum_{i,j} \sigma_{ij}} \right)$$
- **Raykov's $\rho$ / Composite Reliability (`drm_raykov_rho(M, loadings, error_variances)`):** Factor-analytic composite reliability:
  $$\rho = \frac{\left(\sum \lambda_i\right)^2 \mathrm{Var}(\eta)}{\left(\sum \lambda_i\right)^2 \mathrm{Var}(\eta) + \sum \theta_i}$$
- **`reliability(sem)` Accessor:** Returns construct-level reliability diagnostics ($\alpha$, $\rho$, average variance extracted AVE, and proportion of variance explained).

---

## 4. Distributional Effect Propagation & Interventions

`drmSEM`'s simulation-based effect engine seamlessly supports interventions involving latent nodes:
- **Intervention on Latent Node:** $do(\eta = a)$ propagating downstream to response components (e.g., $do(\eta) \to \mu_z$, $do(\eta) \to \sigma_z$).
- **Intervention on Structural Causes:** $do(x_1 = a) \to \eta \to z$, propagating through the latent construct and decomposing into:
  - Total path effect
  - Direct effect ($x_1 \to z$)
  - Indirect effect ($x_1 \to \eta \to z$)
  - Mean-mediated vs. Distribution-mediated channels.

---

## 5. MAG Anterior Projection for Marginalized Latents

When unobserved confounding is represented by marginalized latent variables in `drm_sem(..., latents = c("L1", "L2"))`, `basis_set()` projects the DAG to a Maximal Ancestral Graph (MAG) using Richardson & Spirtes (2002) Corollary 5.3:
- Condition on anteriors: $\mathrm{ant}(\{X, Y\}) \setminus \{X, Y\}$.
- Ensures no spurious bidirected cycles or invalid collider conditioning between observed indicators and downstream nodes.

---

## 6. Validation Summary (V-130 .. V-134)

- **V-130:** Grammar, input validation, and specification for `drm_indicator()` and `drm_latent()` across formative, reflective, and MIMIC constructs with marker and unit-variance identification.
- **V-131:** Exact recovery of Cronbach's $\alpha$ and Raykov's $\rho$ across tau-equivalent and congeneric indicator configurations.
- **V-132:** End-to-end 2-cause, 3-indicator MIMIC model parameter recovery ($\beta_{x1}, \beta_{x2}, \lambda_1, \lambda_2, \lambda_3$) and construct reliability reporting.
- **V-133:** Interventions on latent constructs ($do(\eta) \to z$) and structural causes ($do(x_1) \to \eta \to z$) propagating through both $\mu$ and $\sigma$ distributional channels.
- **V-134:** MAG m-separation projection preserving Richardson & Spirtes Corollary 5.3 independence claims without cycles.

---

## References

- Bollen KA, Bauldry S (2011). Three Cs in measurement models: causal indicators, composite indicators, and covariates. *Psychol. Methods* 16(3):265–284.
- Grace JB, Bollen KA (2008). Representing general theoretical concepts in structural equation models: the role of composite variables. *Environ. Ecol. Stat.* 15:191–213.
- Raykov T (1997). Estimation of composite reliability for congeneric measures. *Appl. Psychol. Meas.* 21(2):173–184.
- Richardson T, Spirtes P (2002). Ancestral graph Markov models. *Ann. Statist.* 30(4):962–1030.
