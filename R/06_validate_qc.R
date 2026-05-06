source("R/00_config.R")

suppressPackageStartupMessages({
  library(arrow)
  library(cli)
})

cli::cli_h1("Validation / QC")

final <- arrow::read_parquet(here::here("data/final", "recent_grads_state_year.parquet"))

issues <- final %>%
  mutate(
    issue_unemployment_bounds = !(is.na(unemployment_rate) | (unemployment_rate >= 0 & unemployment_rate <= 1)),
    issue_employment_bounds = !(is.na(employment_rate) | (employment_rate >= 0 & employment_rate <= 1)),
    issue_lfp_bounds = !(is.na(lfp_rate) | (lfp_rate >= 0 & lfp_rate <= 1)),
    issue_low_n = !is.na(n_unweighted) & n_unweighted < 30,
    issue_lf_consistency = !(is.na(labor_force_w) | is.na(employed_w) | is.na(unemployed_w) |
      abs(labor_force_w - (employed_w + unemployed_w)) < 1e-6)
  ) %>%
  transmute(
    year, state, degree_level, field_category, fod_label,
    n_unweighted, pop_w, labor_force_w, employed_w, unemployed_w,
    unemployment_rate, employment_rate, lfp_rate, bls_unemployment_rate,
    issue_unemployment_bounds,
    issue_employment_bounds,
    issue_lfp_bounds,
    issue_low_n,
    issue_lf_consistency
  ) %>%
  filter(
    issue_unemployment_bounds |
      issue_employment_bounds |
      issue_lfp_bounds |
      issue_low_n |
      issue_lf_consistency
  )

readr::write_csv(issues, here::here("data/validation", "validation_issues.csv"))
arrow::write_parquet(issues, here::here("data/validation", "validation_issues.parquet"))

cli::cli_alert_success("Wrote validation issues table with {nrow(issues)} flagged rows.")

