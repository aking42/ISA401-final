## ISA 401 Final Project — Recorded Technical Presentation (8–12 min)

Assumptions:
- 3 speakers rotate speaking (Speaker 1, 2, 3)
- 1 person operates the screen the whole time (the operator can be any team member)
- Goal: explain the **technical pipeline** and how the dataset was built (not the dashboard story)

---

### Before you start (setup)
- Have these ready to open:
  - `README.md`
  - `run_pipeline.R`
  - `R/01_acquire_acs_pums.R`
  - `R/02_acquire_bls_laus.R`
  - `R/05_merge_build_final.R`
  - `R/06_validate_qc.R`
  - `data/final/recent_grads_state_year.csv` (or `.parquet` in Tableau)
  - `data/validation/validation_issues.csv`
- Optional: have Tableau open with the dataset connected (just to show it loads and fields exist).

---

## Speaker 1 (≈ 0:00–3:30) — Question, why it matters, sources + methods

### 0:00–0:20 — Title + who we are
**Say (verbatim-friendly):**
> “This is our ISA 401 final project: Recent Grads Labor Outcomes. We built a reproducible R pipeline that acquires real-world data, cleans and merges it, validates it, and exports a Tableau-ready dataset.”

**Operator shows:** `README.md` top section (title + research question).

### 0:20–1:20 — Research question / business problem
**Say:**
> “Our research question is: how do labor-market outcomes differ across U.S. states for age 20–25 people who have completed a postsecondary degree and are not currently enrolled—especially by field of study and degree level?”
>
> “We’re trying to quantify where outcomes look strongest or weakest, and whether outcomes vary meaningfully across fields.”

**Operator shows:** `README.md` “Research question” + “Definitions”.

### 1:20–2:00 — Why it’s worth studying
**Say:**
> “This is worth studying because early-career outcomes matter for students and families making education decisions, and for policymakers and schools evaluating workforce pipelines.”
>
> “State labor markets differ a lot, so we want a consistent definition and comparable measures across states.”

### 2:00–3:30 — Data sources + acquisition methods
**Say:**
> “We built the dataset from at least three real-world sources and multiple acquisition methods.”
>
> “Source A is ACS PUMS microdata from the Census. We acquire it via bulk download from the Census FTP directory and compute outcomes for our defined subgroup.”
>
> “Source B is BLS LAUS, which we pull through the BLS public API to get the overall unemployment rate by state as a benchmark.”
>
> “Source C is a set of PDFs placed into `data/raw/first_destination/`, which we process in R using structured extraction to produce a tidy table of report-level outcomes.”

**Operator shows:** `README.md` “Data sources” section, then briefly click into:
- `R/01_acquire_acs_pums.R`
- `R/02_acquire_bls_laus.R`
- `R/03_extract_first_destination.R`

---

## Speaker 2 (≈ 3:30–7:30) — R workflow: cleaning, transform, merge, validate

### 3:30–4:20 — Pipeline overview
**Say:**
> “All core work is done in R: acquisition, cleaning, transformation, merging, and validation.”
>
> “The pipeline is orchestrated by `run_pipeline.R`, which runs the acquisition scripts, then cleaning/transform, then merge/export, then validation.”

**Operator shows:** `run_pipeline.R`.

### 4:20–5:50 — ACS (Source A): subgroup definition + weighted outcomes
**Say:**
> “In the ACS microdata step, we filter to our operational definition of recent grads: age 20–25, not currently enrolled, and associate degree or higher.”
>
> “We then compute weighted counts using the ACS person weight and derive three main rates:
> employment rate = employed / population,
> labor force participation = labor force / population,
> unemployment rate = unemployed / labor force.”
>
> “Finally we aggregate the microdata up to a tidy unit for analysis: state × year × degree level × field-of-degree.”

**Operator shows:** `R/01_acquire_acs_pums.R` around filtering + aggregation logic.

### 5:50–6:40 — BLS (Source B): benchmark series
**Say:**
> “BLS LAUS provides the overall state unemployment rate. The raw data is monthly, so we compute annual averages and store it as a state-year benchmark.”

**Operator shows:** `R/02_acquire_bls_laus.R` and mention output parquet.

### 6:40–7:30 — Merge + validation
**Say:**
> “We standardize categories during cleaning, then merge the ACS subgroup outcomes with the BLS benchmark by state and year.”
>
> “We also generate a validation table that flags rows that violate expected rules—like out-of-range rates or very small sample sizes—so we can explicitly communicate data quality.”

**Operator shows:** `R/05_merge_build_final.R`, then `R/06_validate_qc.R`, then `data/validation/validation_issues.csv`.

---

## Speaker 3 (≈ 7:30–11:30) — Final dataset structure, novelty, challenges/limits, close

### 7:30–8:40 — Structure of final dataset
**Say:**
> “Our main Tableau-ready file is `data/final/recent_grads_state_year.csv`.”
>
> “The grain is state × year × degree_level × field-of-degree (plus a simplified field category).”
>
> “Key measures include weighted population counts, employed/unemployed counts, and the three labor-market rates, plus `bls_unemployment_rate` as a benchmark.”

**Operator shows:** open `data/final/recent_grads_state_year.csv` (or show fields in Tableau).

### 8:40–9:40 — Novelty: not a canned dataset
**Say:**
> “This project isn’t simply analyzing a pre-built dataset. We built a reproducible workflow that acquires multiple sources, harmonizes keys, defines a measurable subgroup, computes weighted outcomes, and produces validation outputs.”
>
> “The deliverable is a clean, documented dataset ready for a dashboard.”

### 9:40–11:00 — Challenges, assumptions, limitations
**Say:**
> “A key assumption is our operational definition of ‘recent grads’: age 20–25, not enrolled, associate+.”
>
> “ACS is survey-based, so estimates depend on weights and sample size. Some state/field/degree cells can be small—so we track `n_unweighted` and recommend filtering out small cells in Tableau.”
>
> “Our current build uses a 25-state subset to keep downloads manageable; expanding is possible but more time-intensive.”

### 11:00–11:30 — Close
**Say:**
> “At this point, the pipeline reliably produces the final merged dataset and validation artifacts. Next we use Tableau Storyboard to communicate the key findings with maps, rankings, and comparisons by field and degree.”

---

## Quick checklist (what you must explicitly say per outline)
- Research question / business problem ✅
- Why it’s worth studying ✅
- Data sources ✅
- Acquisition methods per source ✅
- How cleaned/transformed/merged/validated in R ✅
- Final dataset structure ✅
- Novelty vs canned dataset ✅
- Challenges/assumptions/limitations ✅

