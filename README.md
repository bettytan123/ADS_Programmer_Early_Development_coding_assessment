# ADS Programmer Early Development Coding Assessment

This repository contains my submission for the **ADS Programmer, Early Development** coding assessment (**202509-124623**).

The project is organized into four sections:

1. **Question 1:** SDTM dataset creation  
2. **Question 2:** ADaM dataset derivation  
3. **Question 3:** TLG generation (tables, listings, and figures)  
4. **Question 4:** Generative AI-powered Clinical Trial Data Assistant

## Repository Structure
```
ADS_Programmer_Early_Development_coding_assessment/
├── Question1/
│   ├── question_1_sdtm_01_create_ds_domain.R
│   ├── sdtm_ct.csv
│   └── output/
│       ├── ds_final_20260419.csv
│       └── Question1_run_log.txt
│
├── Question2/
│   ├── question_2_adam_create_adsl.R
│   └── output/
│       ├── adsl_final_20260419.csv
│       └── Question2_run_log.txt
│
├── Question3/
│   ├── question_3_tlg_01_create_ae_summary_table.R
│   ├── question_3_tlg_02_create_visualizations.R
│   └── output/
│       ├── Treatment_Emergent_AEs_table.html
│       ├── AE_Severity_Distribution_by_Treatment_20260419.png
│       ├── Top10_Most_Frequent_AEs_20260419.png
│       ├── Question3_aesummary_run_log.txt
│       └── Question3_visualizations_run_log.txt
│
├── Question4/
│   ├── app.py                                 # Streamlit UI
│   ├── clinical_trial_agent.py                # Core agent logic (LLM + execution)
│   ├── test_queries.py                        # Test script
│   ├── data/
│   │   └── adae.csv                           # Input adae dataset
│   │   └── create_adae.R
│   │
│   └── output/
│       └── output_testscript.txt              # Example output logs
│
├── README.md
└── ADS_Programmer_Early_Development_coding_assessment.Rproj
└── .gitignore

```


---

## Notes

- Each question is **self-contained**, with its own script and `output/` folder  
- Outputs (datasets, tables, plots, logs) are saved for **traceability and reproducibility**  
- HTML outputs (e.g., AE summary table) should be opened in a **web browser**  
- Questions 1–3 are implemented in **R**, while Question 4 is implemented in **Python**  
- No API key is required — Question 4 runs in **mock (rule-based) mode by default**

---

## Requirements

### R Environment (Questions 1–3)

Core packages:

- `sdtm.oak`  
- `pharmaverseraw`  
- `pharmaversesdtm`  
- `admiral`  
- `dplyr`, `tidyr`, `stringr`  
- `gtsummary`, `gt`  
- `ggplot2`, `scales`  
- `binom`  

---

### Python Environment (Question 4)

Core packages:

- `pandas`  
- `streamlit`  
- `pydantic`  
- `python-dotenv` *(optional)*  
- `langchain` + `openai` *(optional for LLM mode)*  

---

## How to Run

### Questions 1–3 (R)

Run the scripts directly in R:

```r
source("Question1/question_1_sdtm_01_create_ds_domain.R")
source("Question2/question_2_adam_create_adsl.R")
source("Question3/question_3_tlg_01_create_ae_summary_table.R")
source("Question3/question_3_tlg_02_create_visualizations.R")

```
#### Questions 4 (Python (mostly))
```bash
# Step 1 — Navigate to folder
cd Question4

# Step 2 — Run core agent
python clinical_trial_agent.py

# Step 3 — Launch Streamlit app
python -m streamlit run app.py

# Step 4 — Run test queries
python test_queries.py --mock
```

- The Streamlit app will provide a local URL — open it in your browser  
- Test results are saved in the `output/` folder  

---

## Design Notes

### Question 1 — SDTM DS Domain

Creates the SDTM **DS (Disposition)** dataset using `{sdtm.oak}`.

**The script:**
- Reads raw disposition data  
- Applies study controlled terminology if available  
- Uses DM reference data to derive variable  

**Outputs:**
- Final DS dataset  
- Run log  

---

### Question 2 — ADSL Dataset

Builds the **ADSL subject-level dataset** using `{admiral}`.

**Key derivations include:**
- `AGEGR9`, `ITTFL`  
- `TRTSDTM`/`TRTSTMF` Treatment start/end dates  
- `LSTAVLDT`  

**Outputs:**
- Final ADSL dataset  
- Run log  

---

### Question 3 — TLG Outputs

Includes two scripts:

- AE summary table (HTML output)  
- Visualizations:
  - AE severity distribution by treatment  
  - Top 10 most frequent AEs (with 95% confidence intervals)  

Each script also generates run logs.

---

### Question 4 — Generative AI Assistant

Implements a clinical trial data assistant that translates natural language into structured queries.

**Components:**
- Core agent (`clinical_trial_agent.py`)  
- Streamlit UI (`app.py`)  
- Test script (`test_queries.py`)  

**Features:**
- Load on `adae.csv` dataset  
- Supports:
  - LLM-based parsing *(optional)*  
  - Rule-based mock mode *(default)*  
- No API key required for mock mode  

Outputs are saved for traceability.

---

## Walkthrough

A brief screen-share walkthrough is provided separately.

**Link:** *(soon link here)*




