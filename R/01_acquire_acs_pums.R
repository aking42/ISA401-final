source("R/00_config.R")

suppressPackageStartupMessages({
  library(tidycensus)
  library(arrow)
  library(cli)
  library(readr)
})

# No Census API usage here (FTP bulk files), but we keep tidycensus for variable metadata.

vars <- c(
  "AGEP",   # age
  "SCH",    # school enrollment
  "SCHL",   # educational attainment
  "FOD1P",  # field of degree (first)
  "ESR",    # employment status recode
  "PWGTP"   # person weight
)

degree_level_from_schl_label <- function(schl_label) {
  # Keep to clear degree levels for storytelling
  case_when(
    str_detect(schl_label, regex("Associate", ignore_case = TRUE)) ~ "Associate",
    str_detect(schl_label, regex("Bachelor", ignore_case = TRUE)) ~ "Bachelor",
    str_detect(schl_label, regex("Master", ignore_case = TRUE)) ~ "Master",
    str_detect(schl_label, regex("Professional school degree", ignore_case = TRUE)) ~ "Doctoral/Prof",
    str_detect(schl_label, regex("Doctorate", ignore_case = TRUE)) ~ "Doctoral/Prof",
    TRUE ~ NA_character_
  )
}

is_not_enrolled_from_sch_label <- function(sch_label) {
  # SCH labels vary slightly across years; treat anything containing "not enrolled" as not enrolled.
  str_detect(sch_label, regex("not enrolled", ignore_case = TRUE))
}

labor_status_from_esr_label <- function(esr_label) {
  # Collapse to Employed / Unemployed / NILF (not in labor force)
  case_when(
    str_detect(esr_label, regex("^Employed", ignore_case = TRUE)) ~ "Employed",
    str_detect(esr_label, regex("^Unemployed", ignore_case = TRUE)) ~ "Unemployed",
    TRUE ~ "NILF"
  )
}

acs_out_files <- c()

get_pums_retry <- function(..., attempts = 6) {
  wait <- 2
  for (i in seq_len(attempts)) {
    res <- try(tidycensus::get_pums(...), silent = TRUE)
    if (!inherits(res, "try-error")) return(res)
    msg <- as.character(res)
    # Some Census API failures are transient or rate-limit-ish and come back as
    # "Your API call has errors." with an empty message. Back off harder.
    if (stringr::str_detect(msg, "Your API call has errors")) {
      wait <- max(wait, 60)
    }
    cli::cli_alert_warning("get_pums failed (attempt {i}/{attempts}). Retrying in {wait}s.")
    cli::cli_text("{stringr::str_trunc(msg, 200)}")
    Sys.sleep(wait)
    wait <- min(wait * 2, 300)
  }
  stop("ACS PUMS download repeatedly failed after retries.", call. = FALSE)
}

state_abbr <- tidycensus::fips_codes %>%
  distinct(state) %>%
  filter(!is.na(state)) %>%
  filter(!state %in% c("AS", "GU", "MP", "PR", "VI")) %>%
  arrange(state) %>%
  pull(state)

if (!is.null(STATE_SAMPLE_N) && STATE_SAMPLE_N < length(state_abbr)) {
  set.seed(STATE_SAMPLE_SEED)
  forced <- intersect(FORCE_STATES, state_abbr)
  remaining <- setdiff(state_abbr, forced)
  sampled <- sort(sample(remaining, size = max(0, STATE_SAMPLE_N - length(forced))))
  state_abbr <- sort(unique(c(forced, sampled)))
  cli::cli_alert_info("Limiting ACS to {length(state_abbr)} states (forced: {paste(forced, collapse = ', ')}).")
}

fail_log_path <- here::here("data/validation", "acs_download_failures.csv")
log_failure <- function(year, state, error_message) {
  row <- tibble::tibble(
    timestamp = as.character(Sys.time()),
    year = as.integer(year),
    state = as.character(state),
    error_message = as.character(error_message)
  )
  dir.create(dirname(fail_log_path), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(fail_log_path)) {
    readr::write_csv(row, fail_log_path)
  } else {
    readr::write_csv(row, fail_log_path, append = TRUE)
  }
}

for (yr in YEARS) {
  cli::cli_h1("ACS PUMS pull: {yr}")

  out_year_path <- here::here("data/intermediate", glue("acs_pums_state_year_{yr}.parquet"))
  if (file.exists(out_year_path)) {
    cli::cli_alert_success("Year {yr} already aggregated; skipping.")
    acs_out_files <- c(acs_out_files, out_year_path)
    next
  }

  # NEW ACQUISITION METHOD (reliable): download state zip(s) from Census FTP and parse locally.
  # Example directory: https://www2.census.gov/programs-surveys/acs/data/pums/2023/5-Year/
  ftp_dir <- glue::glue("{ACS_PUMS_FTP_BASE}/{yr}/5-Year")

  # Map state abbreviations -> FTP zip filename
  zip_for_state <- function(st) {
    glue::glue("csv_p{tolower(st)}.zip")
  }

  col_keep <- c("STATE", "AGEP", "SCH", "SCHL", "FOD1P", "ESR", "PWGTP")

  read_state_pums <- function(st) {
    zip_name <- zip_for_state(st)
    url <- glue::glue("{ftp_dir}/{zip_name}")
    zip_path <- here::here("data/raw", glue::glue("ftp_{ACS_SURVEY}_{yr}_{st}.zip"))

    if (!file.exists(zip_path)) {
      cli::cli_text("Downloading {st} zip…")
      tryCatch(
        {
          utils::download.file(url, destfile = zip_path, mode = "wb", quiet = TRUE)
        },
        error = function(e) {
          log_failure(yr, st, paste0("FTP download failed: ", conditionMessage(e)))
          return(NULL)
        }
      )
    }

    # Identify the person CSV inside the zip (psam_p??.csv)
    zlist <- tryCatch(utils::unzip(zip_path, list = TRUE), error = function(e) NULL)
    if (is.null(zlist) || !"Name" %in% names(zlist)) {
      log_failure(yr, st, "Could not list zip contents.")
      return(NULL)
    }

    person_csv <- zlist$Name[stringr::str_detect(tolower(zlist$Name), "^psam_p.*\\.csv$")]
    if (length(person_csv) < 1) {
      log_failure(yr, st, "No psam_p*.csv found in zip.")
      return(NULL)
    }
    person_csv <- person_csv[[1]]

    tmp_dir <- here::here("data/raw", "tmp_unzip")
    dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

    csv_path <- file.path(tmp_dir, basename(person_csv))
    if (!file.exists(csv_path)) {
      utils::unzip(zip_path, files = person_csv, exdir = tmp_dir, overwrite = TRUE)
    }

    cli::cli_text("Reading {st} person CSV…")
    # Read only required columns for speed/memory
    df <- readr::read_csv(
      csv_path,
      col_select = dplyr::all_of(col_keep),
      show_col_types = FALSE,
      progress = FALSE
    ) %>%
      janitor::clean_names() %>%
      dplyr::mutate(state = st)

    df
  }

  p <- purrr::map_dfr(state_abbr, read_state_pums) %>%
    filter(!is.na(agep)) # drop any empty binds

  state_col <- dplyr::case_when(
    "state" %in% names(p) ~ "state",
    "st" %in% names(p) ~ "st",
    TRUE ~ NA_character_
  )
  if (is.na(state_col)) {
    stop("Could not find state column (expected `state` or `st`) in ACS PUMS output.", call. = FALSE)
  }

  # Build value-label lookups from tidycensus::pums_variables (avoids recode() issues on some years)
  pv <- tidycensus::pums_variables %>%
    filter(survey == ACS_SURVEY, year == as.character(yr))

  lookup_for <- function(code) {
    pv %>%
      filter(var_code == code) %>%
      transmute(val = val_min, label = val_label)
  }

  fod_lu <- lookup_for("FOD1P")

  p2 <- p %>%
    mutate(
      sch_val = as.character(sch),
      schl_val = as.character(schl),
      esr_val = as.character(esr),
      fod1p_val = as.character(fod1p)
    ) %>%
    left_join(fod_lu, by = c("fod1p_val" = "val")) %>%
    rename(fod1p_label = label) %>%
    mutate(
      year = yr,
      age = as.integer(agep),
      state = as.character(.data[[state_col]]),
      weight = as.numeric(pwgtp),
      not_enrolled = sch_val == "1",
      degree_level = dplyr::case_when(
        schl_val == "20" ~ "Associate",
        schl_val == "21" ~ "Bachelor",
        schl_val == "22" ~ "Master",
        schl_val %in% c("23", "24") ~ "Professional/Doctorate",
        TRUE ~ NA_character_
      ),
      labor_status = dplyr::case_when(
        esr_val %in% c("1", "2") ~ "Employed",
        esr_val == "3" ~ "Unemployed",
        TRUE ~ "Not in labor force"
      ),
      fod_label = fod1p_label
    ) %>%
    filter(
      !is.na(age),
      age >= AGE_MIN,
      age <= AGE_MAX,
      not_enrolled,
      !is.na(degree_level)
    )

  agg <- p2 %>%
    mutate(
      in_labor_force = labor_status %in% c("Employed", "Unemployed"),
      employed = labor_status == "Employed",
      unemployed = labor_status == "Unemployed"
    ) %>%
    group_by(year, state, degree_level, fod_label) %>%
    summarise(
      n_unweighted = dplyr::n(),
      pop_w = sum(weight, na.rm = TRUE),
      employed_w = sum(weight[employed], na.rm = TRUE),
      unemployed_w = sum(weight[unemployed], na.rm = TRUE),
      labor_force_w = sum(weight[in_labor_force], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      employment_rate = dplyr::if_else(pop_w > 0, employed_w / pop_w, NA_real_),
      lfp_rate = dplyr::if_else(pop_w > 0, labor_force_w / pop_w, NA_real_),
      unemployment_rate = dplyr::if_else(labor_force_w > 0, unemployed_w / labor_force_w, NA_real_)
    )

  arrow::write_parquet(agg, out_year_path)
  acs_out_files <- c(acs_out_files, out_year_path)
}

acs_all <- purrr::map_dfr(acs_out_files, arrow::read_parquet)
arrow::write_parquet(acs_all, here::here("data/intermediate", "acs_pums_state_year.parquet"))

