library(here)

here::i_am("run_pipeline.R")

scripts <- c(
  "R/01_acquire_acs_pums.R",
  "R/02_acquire_bls_laus.R",
  "R/03_extract_first_destination.R",
  "R/04_clean_transform.R",
  "R/05_merge_build_final.R",
  "R/06_validate_qc.R"
)

for (s in scripts) {
  message("Running: ", s)
  source(here::here(s))
}

message("Done.")

