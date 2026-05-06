## Source C idea (recommended): “First Destination” / Career Outcomes PDFs

### What to use
Use **1–3 Ohio schools’** “First Destination”, “Career Outcomes”, or “Post‑Graduation Outcomes” PDF reports (recent year(s)).

Good candidates (choose what you can access quickly):
- Miami University (Farmer / Career Center outcomes)
- Ohio State University outcomes
- University of Cincinnati outcomes
- Ohio University outcomes

### How to acquire (counts as a distinct method)
1. Download PDFs manually from official school/career-center pages.
2. Place them in:
   - `data/raw/first_destination/`

### How we structure it in R
The pipeline step `R/03_extract_first_destination.R`:
- extracts text from each PDF
- produces a normalized table (school/report-level outcomes)
- optionally uses **LLM structured extraction** if `OPENAI_API_KEY` is set

### How to run

```powershell
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" .\run_pipeline.R
```

Outputs:
- `data/final/first_destination.csv` and `.parquet`

