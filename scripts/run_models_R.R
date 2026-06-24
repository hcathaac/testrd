# R auxiliary replication script for the R&D regional econometrics dashboard
# Run from the project root:
#   Rscript scripts/run_models_R.R

`%||%` <- function(a, b) if (!is.null(a)) a else b

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(fixest)
  library(MASS)
  library(broom)
})

base_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "scripts/run_models_R.R"), ".."), mustWork = FALSE)
if (!dir.exists(file.path(base_dir, "data"))) base_dir <- getwd()

data_path <- file.path(base_dir, "data", "rd_projects_clean.csv")
outputs_dir <- file.path(base_dir, "outputs")
dir.create(outputs_dir, showWarnings = FALSE, recursive = TRUE)

df <- read_csv(data_path, show_col_types = FALSE)

# --------------------------
# Project-level model examples
# --------------------------
project_df <- df %>%
  mutate(
    ln_new_research_jobs = log1p(indicator_6_num_of_research_job_ipa),
    ln_budget = log1p(final_projects_budget_at_the_end_of_the_project),
    ln_public = log1p(final_public_expenditure_at_the_end),
    ln_rd_exp_start = log1p(r_d_exp_region_start_year),
    ln_researchers_start = log1p(researchers_number_region_start_year)
  ) %>%
  filter(is.finite(ln_new_research_jobs), is.finite(ln_budget), is.finite(ln_public))

m1 <- feols(
  ln_new_research_jobs ~ ln_budget + ln_public + ln_rd_exp_start + ln_researchers_start + project_duration_year |
    region + project_start_year,
  data = project_df,
  cluster = ~ region
)

# Count model robustness. fixest::fepois is generally more stable than glm with many FE dummies.
m2 <- fepois(
  indicator_6_num_of_research_job_ipa ~ ln_budget + ln_public + ln_rd_exp_start + ln_researchers_start + project_duration_year |
    region + project_start_year,
  data = project_df,
  cluster = ~ region
)

write_csv(tidy(m1), file.path(outputs_dir, "R_project_FEOLS_new_research_jobs.csv"))
write_csv(tidy(m2), file.path(outputs_dir, "R_project_FEPoisson_new_research_jobs.csv"))

# --------------------------
# Region-year panel builder: start-year allocation
# --------------------------
panel <- df %>%
  group_by(region, nuts_id, region_el, project_start_year) %>%
  summarise(
    year = first(project_start_year),
    project_count = n(),
    absorption_rate_budget_mean = mean(pct_absorption_rate_per_budget, na.rm = TRUE),
    total_budget = sum(final_projects_budget_at_the_end_of_the_project, na.rm = TRUE),
    total_public_expenditure = sum(final_public_expenditure_at_the_end, na.rm = TRUE),
    mean_budget = mean(final_projects_budget_at_the_end_of_the_project, na.rm = TRUE),
    mean_duration = mean(project_duration_year, na.rm = TRUE),
    patents = sum(indicator_3115_num_of_patent, na.rm = TRUE),
    spin_offs = sum(indicator_3111_num_spin_off_spin_outs, na.rm = TRUE),
    smes_benefited = sum(indicator_3110_num_of_smes_benef, na.rm = TRUE),
    gdp_region_start_year = mean(gdp_region_start_year, na.rm = TRUE),
    researchers_number_region_start_year = mean(researchers_number_region_start_year, na.rm = TRUE),
    r_d_exp_region_start_year = mean(r_d_exp_region_start_year, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    ln_gdp = log1p(gdp_region_start_year),
    ln_researchers = log1p(researchers_number_region_start_year),
    ln_rd_exp = log1p(r_d_exp_region_start_year),
    ln_mean_budget = log1p(mean_budget)
  )

p1 <- feols(
  absorption_rate_budget_mean ~ ln_gdp + ln_researchers + ln_rd_exp + ln_mean_budget + mean_duration |
    region + year,
  data = panel,
  cluster = ~ region
)

p2 <- fepois(
  project_count ~ ln_gdp + ln_researchers + ln_rd_exp + ln_mean_budget + mean_duration |
    region + year,
  data = panel,
  cluster = ~ region
)

write_csv(panel, file.path(outputs_dir, "R_region_year_panel_start_allocation.csv"))
write_csv(tidy(p1), file.path(outputs_dir, "R_panel_FEOLS_absorption.csv"))
write_csv(tidy(p2), file.path(outputs_dir, "R_panel_FEPoisson_project_count.csv"))

cat("R models completed. Outputs written to:", outputs_dir, "\n")
