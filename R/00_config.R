library(tidyverse)
library(janitor)
library(glue)
library(here)

here::i_am("R/00_config.R")

# For the 2-hour deadline we use the most recent ACS 5-year PUMS window only.
# Note: "2023" corresponds to the 2019–2023 ACS 5-year file.
YEARS <- 2023:2023
# Use ACS 5-year PUMS to include 2020 (no regular ACS 1-year release)
ACS_SURVEY <- "acs5"
AGE_MIN <- 20
AGE_MAX <- 25

# If not NULL, limit ACS downloads to a subset of states (useful when the Census API is unstable).
# Always include any states listed in FORCE_STATES.
STATE_SAMPLE_N <- 25
FORCE_STATES <- c("OH")
STATE_SAMPLE_SEED <- 401

ACS_PUMS_FTP_BASE <- "https://www2.census.gov/programs-surveys/acs/data/pums"

dir.create(here::here("data/raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("data/intermediate"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("data/final"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("data/validation"), recursive = TRUE, showWarnings = FALSE)

get_env <- function(name, required = FALSE) {
  val <- Sys.getenv(name, unset = "")
  if (required && identical(val, "")) {
    stop(glue("Missing required env var: {name}"), call. = FALSE)
  }
  val
}

