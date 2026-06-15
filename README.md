# pathfy — Graphical SEM for Jamovi

A [Jamovi](https://www.jamovi.org/) module for structural equation modeling with a graphical path diagram editor. Models are specified by drawing paths on a canvas and fitted using [lavaan](https://lavaan.ugent.be/).

---

## Features

- **Graphical editor** — drag nodes, add paths via right-click context menu
- **Model types** — CFA, path models, full SEM, higher-order factors, bifactor models
- **Non-ASCII variable names** — latent variable names in any language (including Japanese)
- **Estimates overlay** — display standardized or unstandardized coefficients on the diagram
- **Error nodes** — residuals shown as `e1`/`d1` nodes with repositioning and error covariance support
- **Parameter constraints** — fix any path to a specific value (e.g., `0` for orthogonality)
- **Fit indices** — CFI, TLI, RMSEA, SRMR, AIC, BIC, χ² test
- **Additional output** — modification indices, residual correlation matrix, lavaan model syntax

---

## Installation

Download the latest `.jmo` file from the [Releases](../../releases) page, then install it as a sideloaded module:

1. Open Jamovi
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

### Edge types

| Line style | Meaning | lavaan operator |
|------------|---------|-----------------|
| Dashed arrow | Factor loading | `=~` |
| Solid arrow | Regression / structural path | `~` |
| Curved double arrow | Covariance | `~~` |
| Blue line | **Fixed parameter** | e.g. `0*` |

### Error nodes

When estimates are displayed, residuals appear as small circles (`e1`, `e2`, … for observed; `d1`, `d2`, … for latent).

- **Right-click an error node** to change its position (above / below / left / right)
- Select **Add Covariance** from the error node menu to add an error covariance between two residuals

### Fixing parameters

To constrain a path to a specific value (e.g., orthogonal factors in a bifactor model):

1. Right-click the path → **Fix value...**
2. Enter the value (e.g., `0`) and click OK
3. The path turns blue to indicate it is constrained
4. To remove the constraint: right-click → **Remove constraint**

### Bifactor model example

Specify the model by adding loading edges, then fix all inter-factor covariances to zero:

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
| Show lavaan syntax | The exact model syntax passed to lavaan (with any proxy name mappings noted) |

---

## Sample Data

Example datasets in Jamovi format (`.omv`) are available in the [`data/omv/`](data/omv/) directory. Download and open them directly in Jamovi to try out the module.

## Requirements

- [Jamovi](https://www.jamovi.org/) 2.3 or later
- R packages: `lavaan`, `jsonlite`, `jmvcore`, `R6`

---

## License

GPL (>= 2) — see [LICENSE](LICENSE) for details.

---

## Author

**Seiji Shibata**  
Sagami Women's University

Bug reports and feature requests: please use [GitHub Issues](../../issues).
