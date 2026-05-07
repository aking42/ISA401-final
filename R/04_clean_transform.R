source("R/00_config.R")

suppressPackageStartupMessages({
  library(arrow)
  library(cli)
})

cli::cli_h1("Clean/transform")

acs <- arrow::read_parquet(here::here("data/intermediate", "acs_pums_state_year.parquet"))
laus <- arrow::read_parquet(here::here("data/intermediate", "bls_laus_state_year.parquet"))
fds <- arrow::read_parquet(here::here("data/intermediate", "first_destination_extracted.parquet"))

field_category_from_fod_label <- function(fod_label) {
  x <- tolower(dplyr::coalesce(fod_label, ""))
  case_when(
    x == "" ~ "Unknown/NA",
    stringr::str_detect(x, "computer|information|software|data science|statistics|math|mathematics") ~ "CS/Math/Stats",
    stringr::str_detect(x, "engineering") ~ "Engineering",
    stringr::str_detect(x, "biology|biological|chemistry|physics|geology|earth science|Environment") ~ "NaturalSciences",
    stringr::str_detect(x, "health|nursing|pharmacy|medicine|public health|Fitness|Therapy|Bio") ~ "Health",
    stringr::str_detect(x, "business|accounting|finance|economics|marketing|management|Logistics|Acturial") ~ "Business/Econ",
    stringr::str_detect(x, "education|teaching") ~ "Education",
    stringr::str_detect(x, "psychology|sociology|political|international|anthropology|social") ~ "SocialSciences",
    stringr::str_detect(x, "english|history|philosophy|religion|languages|literature|humanities|Journalism|Media|Archeology") ~ "Humanities",
    stringr::str_detect(x, "art|music|theatre|film|design|visual|Architecture|Drama|Arts") ~ "Arts/Design",
    TRUE ~ "Other"
  )
}

acs_clean <- acs %>%
  mutate(
    field_category = field_category_from_fod_label(fod_label),
    degree_level = factor(degree_level, levels = c("Associate", "Bachelor", "Master", "Doctoral/Prof"))
  )

# Keep LAUS as a clean context table
laus_clean <- laus %>%
  mutate(state = as.character(state))

fds_clean <- fds %>%
  mutate(
    field_category = ifelse(is.na(field_category) | field_category == "", "Unknown/NA", field_category),
    school = as.character(school)
  )

arrow::write_parquet(acs_clean, here::here("data/intermediate", "acs_pums_state_year_clean.parquet"))
arrow::write_parquet(laus_clean, here::here("data/intermediate", "bls_laus_state_year_clean.parquet"))
arrow::write_parquet(fds_clean, here::here("data/intermediate", "first_destination_clean.parquet"))

