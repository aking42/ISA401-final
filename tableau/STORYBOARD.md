## Tableau Storyboard (build from `data/final/recent_grads_state_year.parquet`)

### Data connection
- Connect Tableau to `data/final/recent_grads_state_year.parquet` (preferred) or `data/final/recent_grads_state_year.csv`.
- Recommended extracts: keep as an extract for speed; this dataset is already aggregated.

### Global filters (show on all story points)
- **Year** (`year`)
- **Degree level** (`degree_level`)
- **Field category** (`field_category`)
- Optional: **Minimum unweighted n** (parameter) to filter out very small cells using `n_unweighted`.

### Story point 1 — Macro context (BLS)
**Question:** How does overall unemployment vary across states and over time?\n
- Line chart: `year` on columns, `bls_unemployment_rate` on rows, `state` on color (or highlight action by state).\n
- Add reference band for national median/mean (optional).\n

### Story point 2 — Main KPI by state (ACS subgroup)
**Question:** For 20–25 year-olds, not enrolled, with degrees, where is unemployment highest/lowest?\n
- Map (preferred): `state` as geographic role, `unemployment_rate` as color.\n
- Tooltip: show `employment_rate`, `lfp_rate`, `n_unweighted`, and `pop_w`.\n

### Story point 3 — Field-of-study comparison
**Question:** Which fields perform better/worse within a state?\n
- Heatmap: `state` on rows, `field_category` on columns, `unemployment_rate` as color.\n
- Add `degree_level` as a filter (or rows split by degree).\n
- Consider sorting states by overall subgroup unemployment.\n

### Story point 4 — Within-state dispersion
**Question:** How large is the spread across fields within each state?\n
- For selected year + degree: show a dot/range plot per `state`:\n
  - min(field unemployment), max(field unemployment), and median across fields.\n
- Alternative: box plot of `unemployment_rate` by `state` with `field_category` as detail.\n

### Story point 5 — Supplemental placement outcomes (First Destination)
**Question:** Do “placement rates” from school reports align with macro labor outcomes?\n
- Use `data/final/first_destination.parquet` as a second data source.\n
- Keep this panel clearly labeled **Supplemental (Ohio schools)**.\n
- Build:\n
  - bar chart: `school` vs `placement_rate` (and/or `continuing_ed_rate`).\n

### Publishing checklist
- First story point includes: **Team # and member names**.\n
- Use captions/annotations to define the subgroup: **age 20–25, not enrolled, associate+**.\n
- Add a note about small sample sizes: recommend filtering `n_unweighted >= 30`.\n
- Publish on Tableau Public and paste the link into your submission form.\n
