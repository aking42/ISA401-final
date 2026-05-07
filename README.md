## ISA 401 Final Project — Recent Grads Labor Outcomes
## Andrew King, Anhad Gill, Jack Leinauer

### Research question
How do labor-market outcomes differ across US states for **age 20–25** people who have **completed a postsecondary degree** and are **not currently enrolled**, especially by **field of study** and **degree level**?

### Definitions (what “recent grads” means in this project)
This project uses an operational definition that can be measured consistently in public microdata:
- **Age**: 20–25 (`AGEP`)
- **Not currently enrolled**: `SCH` indicates “not enrolled”
- **Has a degree (associate+)**: derived from `SCHL` (Associate, Bachelor, Master, Doctoral/Professional)
- **Geography**: US **states + DC** (territories excluded)

### Outcome metrics (computed from microdata)
Computed for each **state × year × degree_level × field_of_degree** cell:
- **Employment rate** = employed / population
- **Labor force participation (LFP)** = labor_force / population
- **Unemployment rate** = unemployed / labor_force

### Data sources (3 sources; 2+ acquisition methods)
This project is intentionally built from multiple sources and acquisition methods (per course requirements).

#### Source A — ACS PUMS (Census; FTP bulk files)
- **What**: American Community Survey Public Use Microdata Sample (PUMS)
- **How acquired**: downloaded from the Census **FTP bulk file** directory (more reliable than the API when the API is busy)
- **Why**: This is the main dataset used to compute employment/unemployment outcomes for the defined subgroup.
- **Years currently built**: **2023 only**, which corresponds to the **2019–2023** rolling 5-year window (ACS 5-year PUMS).
  - You can expand to additional years by editing `YEARS` in `R/00_config.R` (each year is still a rolling 5-year window).
- **Key variables used**:
  - `AGEP` (age), `SCH` (enrollment), `SCHL` (education), `ESR` (employment status),
    `FOD1P` (field of degree), `PWGTP` (person weight), plus state identifier (`ST`)
- **Scope note (to keep downloads manageable)**: the pipeline currently uses a **25-state subset** (with **Ohio forced in**) controlled by `STATE_SAMPLE_N`, `FORCE_STATES`, and `STATE_SAMPLE_SEED` in `R/00_config.R`.

#### Source B — BLS LAUS (BLS; API)
- **What**: Local Area Unemployment Statistics (LAUS) overall unemployment rates
- **How acquired**: BLS public API (`https://api.bls.gov/publicAPI/v2/timeseries/data/`)
- **Why**: Provides macro labor-market context and a benchmark trend line alongside the subgroup measures.

#### Source C — First Destination Reports (PDF; structured extraction)
- **What**: First Destination / career outcomes reports for 1–3 Ohio schools (PDFs)
- **How acquired**: PDFs downloaded manually into the repo’s `data/raw/first_destination/` folder
- **How structured**: structured extraction from PDF text into a tidy table (report-level metrics with best-effort parsing)
- **Why**: Adds a “placement rate / continuing education” lens that is not directly measured in ACS/BLS.

### Repository workflow (reproducible in R)
All data acquisition, cleaning, merging, and validation is done in **R**. Tableau is used only for final visuals.

#### Folder structure
- `R/`: pipeline scripts
- `data/raw/`: cached raw downloads (ignored by git)
- `data/intermediate/`: intermediate tables (ignored by git)
- `data/final/`: Tableau-ready exports (ignored by git)
- `data/validation/`: validation issues tables (ignored by git)
- `tableau/`: storyboard build guide (`tableau/STORYBOARD.md`)

#### Scripts (run in this order)
`run_pipeline.R` runs:
1. `R/01_acquire_acs_pums.R` — downloads/caches ACS PUMS state-by-state and aggregates outcomes
2. `R/02_acquire_bls_laus.R` — downloads BLS LAUS and computes annual averages
3. `R/03_extract_first_destination.R` — extracts supplemental outcomes from PDFs
4. `R/04_clean_transform.R` — standardizes categories (degree + field groupings)
5. `R/05_merge_build_final.R` — merges and exports final datasets for Tableau
6. `R/06_validate_qc.R` — writes a validation issues table (bounds checks, low-n flags, etc.)

### How to run (Windows PowerShell)

#### 1) Install R packages (one-time)
From the project root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "install.packages(c('here','tidyverse','tidycensus','httr2','jsonlite','arrow','janitor','stringr','readr','lubridate','glue','cli','pdftools','tibble','purrr','tidyr'), repos='https://cloud.r-project.org')"
```

#### 2) Set required environment variables
Do **not** commit keys. Use user environment variables instead.

```powershell
setx BLS_API_KEY "YOUR_BLS_KEY"           # optional but recommended
```

Restart Cursor (or open a fresh terminal) after `setx`.

#### 3) (Optional) Add First Destination PDFs
Place PDFs here:
- `data/raw/first_destination/*.pdf`

#### 4) Run the full pipeline

```powershell
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" .\run_pipeline.R
```

### Outputs (what you connect Tableau to)
Main dataset for Tableau:
- `data/final/recent_grads_state_year.parquet` (preferred)
- `data/final/recent_grads_state_year.csv` (backup)

Supplemental placement dataset (optional Tableau join):
- `data/final/first_destination.parquet` / `data/final/first_destination.csv`

Validation artifacts (required for submission):
- `data/validation/validation_issues.csv` / `data/validation/validation_issues.parquet`

### Tableau
See `tableau/STORYBOARD.md` for the Storyboard layout, filters, and publishing checklist.

