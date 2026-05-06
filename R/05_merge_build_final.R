source("R/00_config.R")

suppressPackageStartupMessages({
  library(arrow)
  library(cli)
})

cli::cli_h1("Merge/build final dataset")

acs <- arrow::read_parquet(here::here("data/intermediate", "acs_pums_state_year_clean.parquet"))
laus <- arrow::read_parquet(here::here("data/intermediate", "bls_laus_state_year_clean.parquet"))
fds <- arrow::read_parquet(here::here("data/intermediate", "first_destination_clean.parquet"))

final <- acs %>%
  left_join(laus, by = c("state", "year")) %>%
  mutate(
    # Keep a single “tableau friendly” grain: state-year-degree-field
    bls_unemployment_rate = bls_unemployment_rate
  )

# Supplemental: keep First Destination separately but export for Tableau join if desired
arrow::write_parquet(final, here::here("data/final", "recent_grads_state_year.parquet"))
readr::write_csv(final, here::here("data/final", "recent_grads_state_year.csv"))

arrow::write_parquet(fds, here::here("data/final", "first_destination.parquet"))
readr::write_csv(fds, here::here("data/final", "first_destination.csv"))

