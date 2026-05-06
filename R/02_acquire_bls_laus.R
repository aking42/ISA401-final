source("R/00_config.R")

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(arrow)
  library(tidycensus)
  library(cli)
})

bls_key <- get_env("BLS_API_KEY", required = FALSE)

# Build state FIPS list from tidycensus dataset
states <- tidycensus::fips_codes %>%
  distinct(state, state_code) %>%
  filter(!is.na(state), !is.na(state_code)) %>%
  mutate(state_fips2 = stringr::str_pad(state_code, width = 2, side = "left", pad = "0")) %>%
  distinct(state, state_fips2)

# LAUS state unemployment rate series:
# LASST + state_fips(2) + 0000000000003  (13 digits)
states <- states %>%
  mutate(series_id = paste0("LASST", state_fips2, "0000000000003"))

fetch_bls <- function(series_ids, start_year, end_year) {
  req <- request("https://api.bls.gov/publicAPI/v2/timeseries/data/") %>%
    req_method("POST") %>%
    req_headers(`Content-Type` = "application/json") %>%
    req_body_json(compact(list(
      seriesid = series_ids,
      startyear = as.character(start_year),
      endyear = as.character(end_year),
      registrationKey = if (!identical(bls_key, "")) bls_key else NULL
    )))

  resp <- req_perform(req)
  txt <- resp_body_string(resp)
  jsonlite::fromJSON(txt, simplifyVector = FALSE)
}

cli::cli_h1("BLS LAUS pull: state unemployment rate")

chunks <- split(states$series_id, ceiling(seq_along(states$series_id) / 50))

results <- purrr::map_dfr(chunks, function(ids) {
  j <- fetch_bls(ids, min(YEARS), max(YEARS))
  if (!identical(j$status, "REQUEST_SUCCEEDED")) {
    stop(glue("BLS API failed: {j$status} - {j$message}"), call. = FALSE)
  }
  # Flatten series -> observations
  purrr::map_dfr(j$Results$series, function(s) {
    purrr::map_dfr(s$data, function(d) {
      tibble(
        series_id = s$seriesID,
        year = as.integer(d$year),
        period = d$period,
        value = as.numeric(d$value)
      )
    })
  })
})

laus_monthly <- results %>%
  filter(period %in% paste0("M", stringr::str_pad(1:12, 2, pad = "0"))) %>%
  mutate(month = as.integer(stringr::str_remove(period, "^M"))) %>%
  filter(year %in% YEARS)

laus_annual <- laus_monthly %>%
  group_by(series_id, year) %>%
  summarise(unemp_rate_overall = mean(value, na.rm = TRUE), .groups = "drop") %>%
  left_join(states %>% select(state, state_fips2, series_id), by = "series_id") %>%
  transmute(
    year,
    state,
    state_fips2,
    bls_unemployment_rate = unemp_rate_overall / 100
  )

arrow::write_parquet(laus_annual, here::here("data/intermediate", "bls_laus_state_year.parquet"))

