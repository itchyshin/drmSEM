---
title: "drmSEM: Distributional Piecewise Structural Equation Modelling for Ecology, Evolution, and Environmental Sciences"
tags:
  - R
  - structural equation modelling
  - causal mediation
  - distributional regression
  - phylogenetics
  - latent constructs
  - missing data
  - cyclic feedback
authors:
  - name: Shinichi Nakagawa
    orcid: 0000-0002-7765-5182
    affiliation: 1
affiliations:
  - name: Evolution & Ecology Research Centre, School of Biological, Earth and Environmental Sciences, UNSW Sydney, Sydney, NSW 2052, Australia
    index: 1
date: 28 August 2026
bibliography: paper.bib
---

# Summary

`drmSEM` is an R package for **distributional piecewise structural equation modelling (SEM)**. In standard ecological and evolutionary SEM, structural paths are constrained to target only the *conditional mean* of downstream response variables. In natural systems, however, environmental drivers, genetic architectures, and ecological interventions frequently alter other facets of a trait's probability distribution: its variability or scale ($\sigma$), shape or tail weight ($\nu$), zero-inflation probability ($\text{zi}$), hurdle transition probability ($\text{hu}$), among-group random-effect heterogeneity ($\text{sd}(\text{group})$), or the residual correlation between multivariate responses ($\rho_{12}$). `drmSEM` elevates these distributional components into first-class causal targets within a unified, piecewise structural equation framework.

The package is engineered as an SEM, graph-theoretic, and causal mediation **layer** built on top of the `drmTMB` fitting **engine** [@drmTMB]. `drmSEM` never estimates its own likelihoods directly: each endogenous node in the structural graph is fitted as a generalized additive or linear mixed distributional regression model in `drmTMB` [@Brooks2017; @Rigby2005]. On top of this foundation, `drmSEM` provides a comprehensive suite of theoretical and computational capabilities:

1. **Component-Labelled Structural Paths**: Directed edges are explicitly tuples $(u, v, c, g)$ specifying source node $u$, target node $v$, distributional component $c \in \{\mu, \sigma, \nu, \text{zi}, \text{hu}, \rho_{12}\}$, and link function $g(\cdot)$.
2. **Any-Component $d$-Separation and Goodness-of-Fit**: Missing path claims $X \perp Y \mid \mathbf{Z}$ test whether $X$ is independent of *all* modelled distributional components of $Y$ via likelihood-ratio tests (LRT), aggregated globally using Shipley's Fisher's $C$ statistic [@Shipley2000; @Shipley2009] and Shipley's CBIC / CICc [@Shipley2013].
3. **Maximal Ancestral Graph (MAG) $m$-Separation**: When latent confounding is declared (`latent =`), `drmSEM` projects the unmeasured confounders onto a Maximal Ancestral Graph (MAG) and derives $m$-separation basis sets using anterior conditioning ($\text{ant}(\{X,Y\}) \setminus \{X,Y\}$) [@RichardsonSpirtes2002; @SadeghiLauritzen2014; @LauritzenSadeghi2018], preventing collider bias without requiring full joint latent likelihoods.
4. **Counterfactual Distributional Mediation & Jensen-Gap Decompositions**: Total causal effects are propagated via Monte-Carlo g-computation [@Pearl2001; @Imai2010; @VanderWeele2015]. Non-Gaussian and cross-link paths decompose additively into direct, mean-mediated, and *distribution-mediated* (Jensen-gap) components, alongside 4-way natural direct and indirect decompositions ($\text{NDE}$, $\text{NIE}$, $\text{INT}_{\text{med}}$).
5. **Outcome Functionals & Tail Risk Analytics**: Causal effects can be evaluated directly on non-mean functionals: exceedance probabilities $\Pr(Y > t)$, structural zero probabilities $\Pr(Y = 0)$, response variance $\text{Var}(Y)$, and quantile curves $Q_p(Y)$ [@Avin2005; @Vansteelandt2017].
6. **Latent, Formative, Reflective, and MIMIC Measurement Blocks**: Multiple Indicators and Multiple Causes (MIMIC) models [@JoreskogGoldberger1975; @Bollen1989] and composite constructs [@Grace2008] are integrated with psychometric reliability estimators (Cronbach's $\alpha$, Raykov's composite $\rho$) [@Cronbach1951; @Raykov1997; @McDonald1999] and downstream distributional effect propagation.
7. **Distributional Cyclic Feedback Equilibria**: Declared reciprocal feedback motifs ($Y_1 \rightleftarrows Y_2$) are solved via multi-component Banach fixed-point iteration [@Banach1922; @ForreMooij2017], accompanied by spectral radius ($\rho(\mathbf{B}) < 1$) and Lipschitz contraction stability diagnostics.
8. **Graph-Derived Missing Data Imputation**: Missing endogenous predictors automatically derive their imputation sub-models directly from the upstream causal DAG across continuous ($\text{Gaussian}$, $\text{Gamma}$, $\text{lognormal}$, $\text{Student-}t$, $\text{Beta}$) and discrete/count ($\text{Poisson}$, $\text{negative binomial}$, $\text{ZIP}$, $\text{Beta-Binomial}$) families [@LittleRubin2019; @Enders2010].
9. **Covariance Cliques & Residual Moderation**: Bivariate joint models support environmentally moderated residual coupling ($X \to \rho_{12}$), and $K \ge 3$ covariance clique partitioning (Bron-Kerbosch) suppresses spurious within-block independence claims.
10. **Phylogenetic and Hierarchical Uncertainty**: Evolutionary relatedness is accommodated via phylogenetic covariance kernels ($\text{BM}$, $\text{OU}$, $\text{Pagel's } \lambda/\kappa$) [@Felsenstein1985; @Pagel1999; @MartinsHansen1997; @vanderBijl2018], parameter uncertainty is evaluated via cluster/block bootstrap refitting [@Morris2019], and population-level predictions are obtained via Gauss-Hermite marginal integration.

# Statement of Need and State of the Art

Structural equation modelling is widely used across ecology, evolution, and environmental sciences to test complex causal networks. However, empirical researchers currently face fragmented methodological silos:

- **Covariance-Structure SEM (`lavaan`)**: Packages like `lavaan` [@Rosseel2012] provide powerful joint estimation and latent-variable measurement models under linear-Gaussian assumptions. However, they cannot accommodate non-Gaussian GLMM families (e.g., zero-inflated negative binomial, Tweedie, Beta, hurdle) or specify causal paths into scale or shape parameters.
- **Mean-Only Piecewise SEM (`piecewiseSEM`)**: `piecewiseSEM` [@Lefcheck2016] revolutionized ecological SEM by enabling local estimation of GLMMs with random effects and testing graph consistency via $d$-separation [@Shipley2000; @Shipley2009]. However, all structural paths in `piecewiseSEM` operate exclusively on the conditional mean $\mu$, treating residual dispersion, zero-inflation, and variance heterogeneity as unmodelled nuisance properties.
- **Single-Response Distributional GLMM Engines (`glmmTMB`, `gamlss`, `brms`)**: While `glmmTMB` [@Brooks2017], `gamlss` [@Rigby2005], and `brms` allow users to predict $\sigma$, $\nu$, or $\text{zi}$ as functions of covariates in isolated single equations, they lack structural equation syntax, DAG validation, $d$-separation testing, and cross-equation mediation calculus.
- **Dynamic and Phylogenetic SEMs (`dsem`, `phylopath`, `phylosem`)**: `dsem` [@dsem] models dynamic time-series structural equations, while `phylopath` [@vanderBijl2018] and `phylosem` [@phylosem] account for phylogenetic covariance. However, all existing implementations restrict path coefficients to the mean location parameter.

Table 1 summarizes the capability matrix of `drmSEM` relative to established SEM tools.

| Capability | `lavaan` | `piecewiseSEM` | `phylopath` | `phylosem` | `dsem` | `drmSEM` |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Piecewise Local GLMM Fitting | No | **Yes** | **Yes** | No | No | **Yes** |
| Distributional Paths ($\sigma, \nu, \text{zi}, \text{hu}, \rho_{12}$) | No | No | No | No | No | **Yes** |
| Any-Component $d$-Separation & Fisher's $C$ | No | Mean only | Mean only | No | No | **Yes** |
| Latent Confounding MAG $m$-Separation | No | No | No | No | No | **Yes** |
| Non-Gaussian Jensen-Gap Mediation | No | No | No | No | No | **Yes** |
| Tail Exceedance / Quantile Target Functionals | No | No | No | No | No | **Yes** |
| MIMIC & Formative Measurement Constructs | **Yes** | No | No | No | No | **Yes** |
| Multi-Component Cyclic Feedback Equilibria | Linear only | No | No | No | Linear only | **Yes** |
| Graph-Derived Non-Gaussian Imputation | FIML (Gauss) | No | No | Joint | No | **Yes** |
| Phylogenetic Covariance Kernels | No | Via `nlme` | **Yes** | **Yes** | No | **Yes** |
| Cluster Bootstrap & Gauss-Hermite Marginalization | Robust SE | No | No | No | No | **Yes** |

*Table 1: Methodological capability matrix comparing `drmSEM` to existing SEM packages in R.*

# Mathematical Formulations and Methodological Architecture

## 1. Component-Labelled Structural Equations

Let $\mathcal{G} = (\mathbf{V}, \mathbf{E})$ be a directed graph over endogenous and exogenous variables $\mathbf{V} = \{Y_1, \dots, Y_P\} \cup \{X_1, \dots, X_Q\}$. For each endogenous node $Y_j$, its conditional distribution belongs to a parametric family $\mathcal{D}_j(\boldsymbol{\theta}_j)$ with parameter vector $\boldsymbol{\theta}_j = (\theta_{j1}, \dots, \theta_{jK})^\top$ (e.g., $\mu, \sigma, \nu, \text{zi}$). Each distributional component $\theta_{jk}$ is related to linear predictors via a monotonic link function $g_{jk}(\cdot)$:
\[
g_{jk}(\theta_{jki}) = \alpha_{jk} + \sum_{U \in \text{pa}_{jk}(Y_j)} \beta_{U \to \theta_{jk}} U_i + \mathbf{z}_i^\top \mathbf{u}_{jk}
\]
where $\text{pa}_{jk}(Y_j)$ denotes the set of causal parents targeting component $\theta_{jk}$, and $\mathbf{u}_{jk} \sim \mathcal{N}(\mathbf{0}, \boldsymbol{\Sigma}_{jk})$ represents optional random effects. Every structural edge is thus a component-labelled tuple $e = (U, Y_j, \theta_{jk}, g_{jk}, \beta)$.

## 2. Any-Component $d$-Separation and MAG $m$-Separation

Under the DAG assumption, a missing arrow $X \not\to Y_j$ asserts that $X$ has no direct effect on *any* modelled component of $Y_j$, conditional on conditioning set $\mathbf{Z} = \text{pa}(Y_j)$:
\[
H_0: \beta_{X \to \mu(Y_j)} = 0 \quad \land \quad \beta_{X \to \sigma(Y_j)} = 0 \quad \land \quad \beta_{X \to \text{zi}(Y_j)} = 0 \quad \land \dots
\]
`drmSEM` tests this joint null hypothesis using an omnibus likelihood-ratio test comparing the base model of $Y_j$ against an augmented fit where $X$ enters all component sub-formulas:
\[
\text{LRT} = 2 \left( \ell(\widehat{\boldsymbol{\theta}}_{j,\text{aug}}) - \ell(\widehat{\boldsymbol{\theta}}_{j,\text{base}}) \right) \sim \chi^2(df = \Delta p)
\]
Global graph fit across the $B$ claims in the basis set is assessed via Shipley's $C$ statistic [@Shipley2000; @Shipley2009]:
\[
C = -2 \sum_{b=1}^B \ln(p_b) \sim \chi^2(df = 2B)
\]

When unmeasured confounding is present among variables $\mathbf{L} \subset \mathbf{V}$, `drmSEM` projects the graph onto a Maximal Ancestral Graph (MAG) $\mathcal{M} = (\mathbf{V}_{\text{obs}}, \mathbf{E}_{\to}, \mathbf{E}_{\leftrightarrow})$ [@RichardsonSpirtes2002; @LauritzenSadeghi2018]. Missing edges in the MAG are evaluated using $m$-separation conditional on anterior sets:
\[
X \perp_{\mathcal{M}} Y \mid \mathbf{Z} \quad \text{where } \mathbf{Z} = \text{ant}(\{X, Y\}) \setminus \{X, Y\}
\]
where $\text{ant}(A)$ denotes the smallest ancestral set closed under directed and bidirected edges. This prevents collider stratification bias on bidirected confounding arcs ($X \leftrightarrow Y$) without requiring explicit joint latent integration.

## 3. Counterfactual Distributional Mediation & Tail Analytics

For non-Gaussian nodes and nonlinear link functions, the classical Baron-Kenny or Wright coefficient product $\beta_{X \to M} \times \beta_{M \to Y}$ fails because $\mathbb{E}[g^{-1}(\eta)] \ne g^{-1}(\mathbb{E}[\eta])$ (Jensen's inequality) and because effects may flow through higher moments [@Pearl2001; @Imai2010; @VanderWeele2015]. `drmSEM` computes causal effects by Monte-Carlo g-computation over the topological sorting of $\mathcal{G}$.

For exposure levels $x_0, x_1$, the total interventional effect on target functional $\theta(Y)$ is decomposed into direct, mean-mediated, and distribution-mediated (Jensen-gap) components:
\[
\Delta_{\text{total}} = \mathbb{E}[Y \mid do(X = x_1)] - \mathbb{E}[Y \mid do(X = x_0)]
\]
\[
\Delta_{\text{direct}} = \mathbb{E}[Y \mid X = x_1, M = m_{\text{obs}}] - \mathbb{E}[Y \mid X = x_0, M = m_{\text{obs}}]
\]
\[
\Delta_{\text{mean}} = \mathbb{E}[Y \mid X = x_0, M = \mathbb{E}[M \mid x_1]] - \mathbb{E}[Y \mid X = x_0, M = \mathbb{E}[M \mid x_0]]
\]
\[
\Delta_{\text{dist}} = \Delta_{\text{total}} - (\Delta_{\text{direct}} + \Delta_{\text{mean}}) = \mathbb{E}_{M \mid x_1}[g(M)] - g(\mathbb{E}_{M \mid x_1}[M])
\]

For cross-world counterfactuals, `indirect_effects(effect = "natural")` computes the 4-way decomposition:
\[
\Delta_{\text{total}} = \text{NDE} + \text{NIE} + \text{INT}_{\text{med}}
\]
where $\text{INT}_{\text{med}}$ captures the mediated exposure-mediator interaction [@VanderWeele2014].

Crucially, `drmSEM` supports mediation analysis targeting **distributional functionals** beyond the mean (`target = c("mean", "p_gt", "p_zero", "var", "quantile")`):
- Exceedance tail probability: $\theta(x) = \Pr(Y > t \mid do(x)) = \int_t^\infty f_Y(y \mid do(x)) \, dy$
- Structural zero probability: $\theta(x) = \Pr(Y = 0 \mid do(x))$
- Response variance: $\theta(x) = \text{Var}(Y \mid do(x))$
- Conditional quantile: $\theta(x) = Q_p(Y \mid do(x)) = \inf \{ y : F_Y(y \mid do(x)) \ge p \}$

## 4. Latent & MIMIC Measurement Models

`drmSEM` supports formative, reflective, and Multiple Indicators and Multiple Causes (MIMIC) blocks [@JoreskogGoldberger1975; @Bollen1989; @Grace2008]. A latent construct $\eta$ is driven by formative predictors $\mathbf{X}$ and reflected by manifest indicators $\mathbf{Y}$:
\[
\eta_i = \boldsymbol{\gamma}^\top \mathbf{x}_i + \zeta_i, \quad \zeta_i \sim \mathcal{N}(0, \psi)
\]
\[
y_{ji} = \nu_j + \lambda_j \eta_i + \epsilon_{ji}, \quad \epsilon_{ji} \sim \mathcal{N}(0, \theta_j)
\]
Model identification is achieved via marker variable ($\lambda_{\text{marker}} = 1$) or unit-variance constraint ($\text{Var}(\eta) = 1$). Construct reliability is quantified via Cronbach's $\alpha$ [@Cronbach1951] and Raykov's composite $\rho$ [@Raykov1997; @McDonald1999]:
\[
\alpha = \frac{k}{k-1} \left( 1 - \frac{\sum_{j=1}^k \text{Var}(y_j)}{\text{Var}\left(\sum_{j=1}^k y_j\right)} \right), \quad \rho_{\text{Raykov}} = \frac{\left(\sum_{j=1}^k \lambda_j\right)^2 \text{Var}(\eta)}{\left(\sum_{j=1}^k \lambda_j\right)^2 \text{Var}(\eta) + \sum_{j=1}^k \theta_j}
\]

## 5. Distributional Cyclic Feedback Equilibria

For reciprocal feedback motifs ($Y_1 \rightleftarrows Y_2$), `drmSEM` formulates the simultaneous system as a multi-component operator $\mathbf{y} = \mathbf{f}(\mathbf{y}, \mathbf{x}, \boldsymbol{\theta})$ across location, scale, shape, and zero-inflation parameters. The equilibrium state $\mathbf{y}^*$ is solved using damped Banach fixed-point iteration [@Banach1922; @ForreMooij2017]:
\[
\mathbf{y}^{(k+1)} = (1 - \omega) \mathbf{y}^{(k)} + \omega \, \mathbf{g}^{-1}\left( \mathbf{B} \mathbf{y}^{(k)} + \boldsymbol{\Gamma} \mathbf{x} + \boldsymbol{\alpha} \right)
\]
Convergence and physical stability are audited via the spectral radius $\rho(\mathbf{B}) < 1$ and empirical Lipschitz contraction constant $L = \sup_{\mathbf{y}_1 \ne \mathbf{y}_2} \frac{\|\mathbf{f}(\mathbf{y}_1) - \mathbf{f}(\mathbf{y}_2)\|}{\|\mathbf{y}_1 - \mathbf{y}_2\|} < 1$. Equilibrium total effects are obtained by perturbing exogenous drivers $\mathbf{x}$ and resolving the fixed-point surface.

# Key Features and Applied R Workflows

## Workflow 1: Distributional Mediation & Tail Exceedance Risk

Consider an ecological study where temperature (`temp`) influences body `size` (both its expected mean and its variance $\sigma$), `size` determines resource `abundance` (a zero-inflated count), and `abundance` drives population `survival` (a Beta-Binomial proportion).

```r
library(drmSEM)

# Define piecewise distributional SEM with component-labelled paths
sem <- drm_sem(
  size      = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
                       family = stats::gaussian()),
  abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
                       family = drmTMB::nbinom2()),
  survival  = drm_node(drmTMB::bf(survival ~ abundance + size),
                       family = drmTMB::beta_binomial()),
  data = eco_data
)

# Component-labelled path table
paths(sem)

# Any-component d-separation test of overall graph consistency
fisher_c(sem)

# Decompose causal mediation into direct, mean-mediated, and distribution-mediated parts
ie <- indirect_effects(sem, from = "temp", to = "survival",
                       effect = "natural", uncertainty = "bootstrap", R = 500)
print(ie)

# Propagate causal effect on extreme tail exceedance risk: Pr(survival > 0.80)
tail_eff <- total_effects(sem, from = "temp", to = "survival",
                          target = "p_gt", threshold = 0.80)
print(tail_eff)
```

## Workflow 2: MIMIC Latent Measurement Blocks & Reliability

When environmental quality is an unobserved construct reflected by multiple bio-indicators:

```r
# Define MIMIC construct: formative habitat causes, reflective water-quality indicators
sem_mimic <- drm_sem(
  quality = drm_latent(
    causes     = ~ canopy_cover + soil_moisture + elevation,
    indicators = drm_indicator(~ macroinvertebrates + dissolved_o2 + clarity,
                               standardize = TRUE)
  ),
  fish_richness = drm_node(
    drmTMB::bf(fish_richness ~ quality, sigma ~ quality),
    family = stats::gaussian()
  ),
  data = river_data
)

# Inspect measurement loadings and construct reliability
loadings(sem_mimic)
reliability(sem_mimic)  # Cronbach's alpha and Raykov's composite rho

# Propagate latent intervention through structural distributional paths
total_effects(sem_mimic, from = "quality", to = "fish_richness")
```

## Workflow 3: Cyclic Feedback Equilibria on Scale & Dispersion

In plant-pollinator or density-dependent interactions with reciprocal feedbacks:

```r
# Specify reciprocal feedback cycle between plant density and pollinator visits
sem_cycle <- drm_sem(
  plants     = drm_node(drmTMB::bf(plants ~ pollinators + rainfall, sigma ~ pollinators),
                        family = stats::gaussian()),
  pollinators = drm_node(drmTMB::bf(pollinators ~ plants + temperature),
                        family = stats::gaussian()),
  feedback   = drm_cycle(plants ~ pollinators, pollinators ~ plants),
  data = field_data
)

# Inspect detected feedback cycles and stability metrics
cycles(sem_cycle)

# Compute simultaneous equilibrium total effects via Banach fixed-point iteration
eff_cycle <- total_effects(sem_cycle, from = "rainfall", to = "pollinators")
print(eff_cycle)
```

## Workflow 4: MAG $m$-Separation Under Unmeasured Confounding

When unmeasured spatial or environmental confounders induce correlated errors between nodes:

```r
# Declare unmeasured confounding between canopy and soil
sem_mag <- drm_sem(
  biomass = drm_node(biomass ~ canopy + nutrients, family = stats::gaussian()),
  growth  = drm_node(growth ~ biomass + soil, family = stats::gaussian()),
  latent  = c("canopy", "soil"),  # Marginalised unmeasured confounders
  data = forest_data
)

# Test m-separation on the implied Maximal Ancestral Graph (MAG)
basis_set(sem_mag, type = "mag")
dsep(sem_mag)
```

## Workflow 5: Graph-Derived Piecewise Imputation

When mediator variables contain missing observations:

```r
# Automatic DAG-derived imputation across non-Gaussian families
sem_imp <- drm_sem(
  biomass   = drm_node(biomass ~ rainfall, family = drmTMB::Gamma_log()),
  herbivory = drm_node(herbivory ~ biomass + temp, family = drmTMB::nbinom2()),
  impute    = "auto",
  data = missing_data
)

# Inspect derived imputation models and imputed observations
imputation(sem_imp)
head(imputed(sem_imp))
```

# Model Diagnostics and Symbolic Equation Export

`drmSEM` provides complete audit diagnostics via `check_sem()`, evaluating node convergence, covariance matrix positive-definiteness, sample size alignment across equations, and realized-sampler availability.

Furthermore, seamless integration with `symbolizer` (`Suggests`) allows automated extraction and LaTeX rendering of the full system of distributional equations directly from fitted objects:

```r
# Generate publication-quality LaTeX system of equations
sym <- symbolize(sem)
as_latex(sym)
```

# Methodological Scope and Boundaries

`drmSEM` maintains strict clarity regarding its scope and assumptions:
1. **Piecewise Architecture**: `drmSEM` performs piecewise local estimation, not joint Full Information Maximum Likelihood (FIML). Imputation uncertainty is propagated within-node but not across nodes.
2. **Directed Acyclic Graphs**: Non-recursive feedback loops require explicit declaration via `drm_cycle()`. Fitting reciprocal cycles with node-wise estimators carries simultaneity bias, which `drmSEM` diagnoses and warns about.
3. **MAG Projection vs Latent Integration**: MAG $m$-separation projects marginalised confounding onto observed independence claims under a compositional graphoid assumption; it does not fit continuous latent variables with FIML.
4. **Honest Effect Bounds**: Mediation decomposition through non-Gaussian mediators relies on exact Monte-Carlo g-computation rather than parametric product approximations.

# Acknowledgements

We thank the developers of `drmTMB`, `TMB`, `glmmTMB`, `piecewiseSEM`, `lavaan`, `phylopath`, and `phylosem`, whose theoretical insights and software architectures laid the foundations for `drmSEM`.

# References
