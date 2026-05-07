source("R/00_config.R")

suppressPackageStartupMessages({
  library(pdftools)
  library(arrow)
  library(cli)
})

pdf_dir <- here::here("data/raw/first_destination")
dir.create(pdf_dir, recursive = TRUE, showWarnings = FALSE)

pdfs <- list.files(pdf_dir, pattern = "\\.pdf$", full.names = TRUE)

cli::cli_h1("First Destination extraction")

if (length(pdfs) == 0) {
  cli::cli_alert_warning("No PDFs found in {pdf_dir}. Skipping; writing empty table.")
  empty <- tibble(
    school = character(),
    grad_year = integer(),
    major = character(),
    field_category = character(),
    placement_rate = numeric(),
    continuing_ed_rate = numeric(),
    salary_median = numeric(),
    source_file = character()
  )
  arrow::write_parquet(empty, here::here("data/intermediate", "first_destination_extracted.parquet"))
} else {
  # Extraction scaffold:
  # - Always reads PDF text into a cacheable tibble
  # - Uses lightweight pattern matching to extract a few common outcome metrics

  raw_text <- purrr::map_dfr(pdfs, function(p) {
    tibble(
      source_file = basename(p),
      text = paste(pdftools::pdf_text(p), collapse = "\n")
    )
  })

  map_major_to_field <- function(major) {
    x <- tolower(dplyr::coalesce(major, ""))
    dplyr::case_when(
      x == "" ~ "Unknown/NA",
      stringr::str_detect(x, "computer|informatics|software|data science|statistics|math") ~ "CS/Math/Stats",
      stringr::str_detect(x, "engineering") ~ "Engineering",
      stringr::str_detect(x, "biology|chemistry|physics|geology|environment") ~ "NaturalSciences",
      stringr::str_detect(x, "nursing|health|medicine|pharmacy|public health") ~ "Health",
      stringr::str_detect(x, "business|accounting|finance|economics|marketing|management") ~ "Business/Econ",
      stringr::str_detect(x, "education|teaching") ~ "Education",
      stringr::str_detect(x, "psychology|sociology|political|international|anthropology|social") ~ "SocialSciences",
      stringr::str_detect(x, "english|history|philosophy|religion|language|literature") ~ "Humanities",
      stringr::str_detect(x, "art|music|theatre|film|design|visual") ~ "Arts/Design",
      TRUE ~ "Other"
    )
  }

  # Very lightweight regex heuristics as a fallback. This will be refined per chosen schools.
  extract_rate <- function(txt, pattern) {
    m <- stringr::str_match(txt, pattern)[, 2]
    val <- suppressWarnings(as.numeric(m))
    val / 100
  }

  extracted <- raw_text %>%
    transmute(
      school = stringr::str_remove(source_file, "\\.pdf$"),
      grad_year = NA_integer_,
      major = NA_character_,
      field_category = "Unknown/NA",
      placement_rate = extract_rate(text, "(?i)placement\\s*rate\\s*[:\\-]?\\s*(\\d{1,3}(?:\\.\\d+)?)\\s*%"),
      continuing_ed_rate = extract_rate(text, "(?i)continuing\\s*education\\s*[:\\-]?\\s*(\\d{1,3}(?:\\.\\d+)?)\\s*%"),
      salary_median = NA_real_,
      source_file = source_file
    )

  arrow::write_parquet(extracted, here::here("data/intermediate", "first_destination_extracted.parquet"))
}

