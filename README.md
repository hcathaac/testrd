# R&D Projects and Regional Development Econometrics Dashboard

This package builds a Python-first dashboard for the uploaded R&D projects and regional development indicators dataset. It is designed to run locally, in Streamlit Cloud, or in Google Colab with a public tunnel.

## What is included

- `app.py` — Streamlit dashboard with six modules: data audit, variable dictionary, region-year panel, econometric models, GIS/spatial diagnostics, and scenario engine.
- `data/rd_projects_raw.xlsx` — the original Excel workbook copied into the app folder.
- `data/rd_projects_clean.csv` — cleaned dataset with machine-safe variable names and NUTS-2 region identifiers.
- `data/variable_catalog.csv` — all identified variables, original names, clean names, level of analysis, role, group, dtype, missingness and recommended transformation.
- `data/model_specifications.csv` — nine research-question model specifications.
- `data/greece_region_lookup.csv` — English region names, Greek labels, NUTS-2 codes and centroid coordinates.
- `outputs/region_summary.csv` — first regional summary table.
- `outputs/data_audit_summary.json` — compact data audit.
- `scripts/run_models_R.R` — auxiliary R replication using `fixest` and `fepois`.
- `notebooks/RD_Regional_Dashboard_Colab.ipynb` — Colab launcher notebook.

## Core data diagnosis

The Excel sheet has 3,259 project-level observations and 83 original variables. The first row of the workbook is column numbering; the actual variable names start on the second row. The cleaned dataset adds four GIS helper fields: `nuts_id`, `region_el`, `lat`, and `lon`, so the analysis file has 87 columns.

Observed regions in the project dataset are 12 Greek NUTS-2 regions. South Aegean is included in the GIS lookup so that a complete Greek regional map can still be displayed, but it has no project observations in the uploaded dataset unless later data are added.

The variable `pct_absorption_rate_per_public_expenditure` is almost entirely missing. For absorption models, the defensible dependent variable in the present file is therefore `pct_absorption_rate_per_budget` or its regional mean `absorption_rate_budget_mean`.

## Recommended environment

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
streamlit run app.py
```

## Colab execution

Open `notebooks/RD_Regional_Dashboard_Colab.ipynb`, upload this folder or the zip archive, run the installation cell, then launch Streamlit. The notebook includes a localtunnel-based approach for exposing the Streamlit app from Colab.

## GIS component

The GIS module is designed around Eurostat GISCO NUTS-2 geometries, using the current NUTS 2024 GeoJSON endpoint:

```text
https://gisco-services.ec.europa.eu/distribution/v1/nuts-2024/geojson/NUTS_RG_01M_2024_4326_LEVL_2.geojson
```

If GeoPandas or the online GeoJSON endpoint is unavailable, the app falls back to a centroid map using the included region lookup.

Spatial diagnostics use PySAL where available. The default spatial weights are KNN weights, because Greek island regions can break strict Queen contiguity. The code can be switched to Queen contiguity inside `spatial_diagnostics()` if a strict border-sharing definition is required.

## Econometric logic

The dashboard supports:

1. Project-level models for new research jobs, research employment, business participation and other outputs.
2. Region-year panel models using start-year, end-year or active-year allocation.
3. OLS with log1p transformations.
4. Poisson and Negative Binomial GLMs for count outcomes.
5. Fractional logit/Binomial GLM for bounded absorption rates.
6. Region and year fixed effects using formula dummies.
7. Cluster-robust standard errors by region or year.
8. VIF diagnostics, actual-vs-fitted plots, AIC/BIC and downloadable coefficient tables.

For production-grade publication tables, the auxiliary R script uses `fixest`, which is usually cleaner for high-dimensional fixed effects and clustered standard errors.

## GAMS-style scenario layer

The scenario engine estimates a reduced-form regional model and applies a percentage shock to a selected driver, such as R&D expenditure, researchers, GDP, innovation rates or budget. It then returns predicted baseline vs scenario outcomes by region and year. This is not a full optimisation solver. It is a decision-support layer that can later be extended to Pyomo or GAMS-style constrained optimisation.

## Suggested model discipline

Do not put all regional indicators into the same regression. The dataset is small at the region-year level and many regional indicators are repeated or mechanically related. Use thematic blocks, limited regressors, log transformations, fixed effects, and robustness checks across allocation modes. For patents and spin-offs, expect sparse counts and instability; report them as exploratory unless counts are sufficient.
