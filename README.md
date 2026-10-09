# pathfy — Graphical SEM for jamovi

A [jamovi](https://www.jamovi.org/) module for structural equation modeling with a graphical path diagram editor. Models are specified by drawing paths on a canvas and fitted using [lavaan](https://lavaan.ugent.be/).

---

## Features

- **Graphical editor** — drag nodes, add paths via right-click context menu
- **What you draw is what is fitted** — a covariance is estimated only if its path is drawn
- **Model types** — CFA, path models, full SEM, higher-order factors, bifactor models
- **Non-ASCII variable names** — latent variable names in any language (including Japanese)
- **Estimates overlay** — display standardized or unstandardized coefficients on the diagram
- **Error nodes** — residuals shown as `e1`/`d1` nodes with repositioning and error covariance support
- **Parameter constraints** — fix any path to a specific value (e.g., `0` for orthogonality)
- **Fit indices** — CFI, TLI, RMSEA, SRMR, AIC, BIC, χ² test
- **Additional output** — modification indices, residual correlation matrix, a ready-to-run R script for lavaan

---

## Installation

Download the latest `.jmo` file from the [Releases](../../releases) page, then install it as a sideloaded module:

1. Open jamovi
2. Click the **⊞** button (top right)
3. Select **Install from file...**
4. Choose the downloaded `.jmo` file

---

## Usage

### Basic workflow

1. **Add observed variables** — drag variables from the left panel into the *Observed Variables* box
2. **Add latent variables** (for CFA) — type a factor name in the *Latent Variables* box and click 追加 (Add)
3. **Draw paths** — right-click a node on the canvas to add paths:
   - **Add Loading** — latent → observed indicator (`=~`)
   - **Add Regression** — regression or structural path (`~`)
   - **Add Covariance** — double-headed arrow (`~~`)
4. **View estimates** — click the **Estimates** button to overlay coefficients on the diagram
5. **Tidy up** — click **Auto Layout** to arrange the diagram: factors in rows with their indicators below for measurement models, in causal order from left to right when there are regressions. **Undo Layout**, which appears next to it afterwards, puts the nodes (and error terms) back where they were before the last Auto Layout
6. **Move several nodes at once** — drag over the empty canvas to select the nodes inside the rectangle, or shift-click nodes to add them to or remove them from the selection; dragging any selected node moves them all
7. **Use the diagram elsewhere** — the diagram is included when the results are exported from jamovi (e.g. to PDF)

### Edge types

| Line style | Meaning | lavaan operator |
|------------|---------|-----------------|
| Dashed arrow | Factor loading | `=~` |
| Solid arrow | Regression / structural path | `~` |
| Curved double arrow | Covariance | `~~` |
| Blue line | **Fixed parameter** | e.g. `0*` |

### Covariances

Only the covariances drawn in the diagram are estimated. lavaan by default correlates exogenous latent variables, and the residuals of outcomes that predict nothing else, even when the model syntax does not mention them; pathfy fixes each such covariance that is not drawn to zero, and writes it into the model syntax as `A ~~ 0*B`.

- Factors in a CFA are therefore **uncorrelated unless you draw a covariance path** between them (right-click a factor → **Add Covariance**)
- When latent variables are left uncorrelated this way, a notice below the diagram lists the pairs, e.g. *"No covariance path is drawn between the following latent variables, so they are estimated as uncorrelated: F1 <-> F2"*
- Residual covariances between outcomes that are fixed to zero this way are listed in a second notice
- Covariances among observed predictors are not affected: as in lavaan, they are fixed to their sample values

> **Changed in 1.2.0.** Earlier versions let lavaan add these covariances. A file saved with an earlier version in which such covariances were not drawn gives different results when reopened in 1.2.0 or later; draw the covariance paths to get the earlier model back.

### Error nodes

When estimates are displayed, residuals appear as small circles (`e1`, `e2`, … for observed; `d1`, `d2`, … for latent).

- **Right-click an error node** to change its position (above / below / left / right)
- Select **Add Covariance** from the error node menu to add an error covariance between two residuals

### Fixing parameters

To constrain a path to a specific value (e.g., orthogonal factors in a bifactor model):

1. Right-click the path → **Fix value...**
2. Enter the value and click OK. The field opens with `0`, so clicking OK right away fixes the path to zero; an empty field is not accepted
3. The path turns blue to indicate it is constrained
4. To remove the constraint: right-click → **Remove constraint**

### Bifactor model example

Specify the model by adding loading edges only. Because no covariance is drawn between the factors, they are all fixed to be uncorrelated:

```
g  =~ x1 + x2 + x3 + x4 + x5 + x6
s1 =~ x1 + x2 + x3
s2 =~ x4 + x5 + x6
g ~~ 0*s1
g ~~ 0*s2
s1 ~~ 0*s2
```

---

## Options

### Estimator

| Label | Description |
|-------|-------------|
| ML | Maximum likelihood |
| MLR | Robust ML (Huber-White standard errors) |
| MLM | Mean-adjusted ML (Satorra-Bentler) |
| WLSMV | Weighted least squares (ordinal data) |
| ULS | Unweighted least squares |

### Identification constraints

- **Fix factor variance to 1** — standardized latent variables
- **Fix first loading to 1** — marker variable approach

### Additional output

| Option | Description |
|--------|-------------|
| Residual covariances | Residual correlation matrix; highlights cells above the threshold |
| Modification indices | Ranked list of parameters that would most improve fit |
| lavaan syntax | An R script that reproduces the analysis: the model syntax and the `sem()` call with the estimator, missing-data handling, and identification constraint in use (with any proxy name mappings noted). The model syntax on its own, passed to a default `sem()` call, specifies the same model. The script runs as is in R once the data are in a data frame named `data`, and inside jamovi when pasted into the editor of the Rj module (in Rj+, add the variables used in the model to *Variables* first) |

---

## Sample Data

Example datasets in jamovi format (`.omv`) are available in the [`data/omv/`](data/omv/) directory. Download and open them directly in jamovi to try out the module.

## Requirements

- [jamovi](https://www.jamovi.org/) 2.7 or later
- R packages: `lavaan`, `jsonlite`, `jmvcore`, `R6`

---

## License

GPL (>= 2) — see [LICENSE](LICENSE) for details.

---

## Author

**Seiji Shibata**  
Sagami Women's University

Bug reports and feature requests: please use [GitHub Issues](../../issues).
