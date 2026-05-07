source("R/00_config.R")

suppressPackageStartupMessages({
  library(pdftools)
  library(arrow)
  library(cli)
  library(httr2)
  library(jsonlite)
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
  # - If OPENAI_API_KEY is set, runs an LLM JSON extraction to major-level rows (preferred)
  # - Otherwise, keeps a regex-based fallback so the pipeline still runs

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

  openai_key <- get_env("OPENAI_API_KEY", required = FALSE)

  llm_extract_one <- function(text, school, source_file) {
    # Uses OpenAI Responses API if available.
    # Returns a tibble with: school, grad_year, major, placement_rate, continuing_ed_rate, salary_median
    prompt <- glue::glue(
      "Extract a table of outcomes by major from the following First Destination report text.\n",
      "Return JSON only, as an array of objects with keys:\n",
      "major (string), grad_year (number or null), placement_rate (0-1 or null), continuing_ed_rate (0-1 or null), salary_median (number or null).\n",
      "If the report only has college-level (not major-level) outcomes, return a single object with major=null.\n\n",
      "REPORT_TEXT_START\n{text}\nREPORT_TEXT_END\n"
    )

    req <- request("https://api.openai.com/v1/responses") %>%
      req_method("POST") %>%
      req_headers(
        Authorization = paste("Bearer", openai_key),
        `Content-Type` = "application/json"
      ) %>%
      req_body_json(list(
        model = "gpt-4o-mini",
        input = prompt,
        temperature = 0
      ))

    resp <- req_perform(req)
    raw <- resp_body_string(resp)
    j <- jsonlite::fromJSON(raw, simplifyVector = FALSE)

    # Responses API: gather text output chunks
    out_text <- ""
    if (!is.null(j$output) && length(j$output) > 0) {
      for (o in j$output) {
        if (!is.null(o$content) && length(o$content) > 0) {
          for (c in o$content) {
            if (!is.null(c$text)) out_text <- paste0(out_text, c$text)
          }
        }
      }
    }

    # Some models may wrap JSON in ```json fences; strip fences if present.
    cleaned <- out_text %>%
      stringr::str_replace("^\\s*```json\\s*", "") %>%
      stringr::str_replace("^\\s*```\\s*", "") %>%
      stringr::str_replace("\\s*```\\s*$", "") %>%
      stringr::str_trim()

    # Try to parse the JSON array robustly.
    # If the model returns extra text, extract the first [...] block.
    bracketed <- cleaned
    if (!stringr::str_detect(bracketed, "^\\s*\\[") && stringr::str_detect(bracketed, "\\[")) {
      bracketed <- stringr::str_extract(bracketed, "\\[[\\s\\S]*\\]")
    }
    if (is.na(bracketed) || is.null(bracketed) || stringr::str_trim(bracketed) == "") {
      bracketed <- "[]"
    }

    parsed <- jsonlite::fromJSON(bracketed, simplifyVector = TRUE)
    out <- tibble::as_tibble(parsed) %>%
      mutate(
        school = school,
        source_file = source_file
      ) %>%
      relocate(school, source_file)

    # Ensure stable column types even if everything is NA / empty.
    if (!"major" %in% names(out)) out$major <- NA_character_
    if (!"grad_year" %in% names(out)) out$grad_year <- NA_integer_
    if (!"placement_rate" %in% names(out)) out$placement_rate <- NA_real_
    if (!"continuing_ed_rate" %in% names(out)) out$continuing_ed_rate <- NA_real_
    if (!"salary_median" %in% names(out)) out$salary_median <- NA_real_

    out %>%
      mutate(
        major = as.character(major),
        grad_year = suppressWarnings(as.integer(grad_year)),
        placement_rate = suppressWarnings(as.numeric(placement_rate)),
        continuing_ed_rate = suppressWarnings(as.numeric(continuing_ed_rate)),
        salary_median = suppressWarnings(as.numeric(salary_median))
      )
  }

  # Very lightweight regex heuristics as a fallback. This will be refined per chosen schools.
  extract_rate <- function(txt, pattern) {
    m <- stringr::str_match(txt, pattern)[, 2]
    val <- suppressWarnings(as.numeric(m))
    val / 100
  }

  extracted <- NULL
  if (!identical(openai_key, "")) {
    cli::cli_alert_info("OPENAI_API_KEY detected. Running LLM extraction (major-level if present).")
    extracted <- raw_text %>%
      mutate(school = stringr::str_remove(source_file, "\\.pdf$")) %>%
      mutate(rows = purrr::pmap(list(text, school, source_file), llm_extract_one)) %>%
      select(rows) %>%
      tidyr::unnest(rows) %>%
      mutate(
        field_category = map_major_to_field(major),
        grad_year = suppressWarnings(as.integer(grad_year))
      )
  } else {
    cli::cli_alert_warning("OPENAI_API_KEY not set. Using coarse report-level fallback extraction (not major-level).")
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
  }

  arrow::write_parquet(extracted, here::here("data/intermediate", "first_destination_extracted.parquet"))
}

