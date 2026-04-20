"""Streamlit demo for the Clinical Trial Data Agent (question 4).

Run with:

    streamlit run app.py

in the local terminal and you will be able to use the output to see the interactive page in html format
[browser]
  You can now view your Streamlit app in your browser.

  Local URL: http://localhost:8501
  Network URL: http://172.20.10.2:8501
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
import streamlit as st

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from clinical_trial_agent import AE_SCHEMA, ClinicalTrialDataAgent, load_adae


DEFAULT_CSV = Path(__file__).parent / "data" / "adae.csv"

EXAMPLE_QUESTIONS = [
    "Give me the subjects who had Adverse events of Moderate severity.",
    "Which patients experienced Cardiac disorders?",
    "Find subjects with Headache.",
    "Show me subjects with severe AEs.",
    "List patients with Skin reactions.",
]


# ---------------------------------------------------------------------------
# Data + agent loading (cached)
# ---------------------------------------------------------------------------

@st.cache_data(show_spinner=False)
def _load_dataframe(csv_path: str) -> pd.DataFrame:
    return load_adae(csv_path)


@st.cache_resource(show_spinner=False)
def _build_agent(csv_path: str, force_mock: bool) -> ClinicalTrialDataAgent:
    df = _load_dataframe(csv_path)
    return ClinicalTrialDataAgent(df, force_mock=force_mock)


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

def main() -> None:
    st.set_page_config(
        page_title="Clinical Trial Data Agent",
        layout="wide",
    )
    st.title("Clinical Trial Data Agent")
    st.caption(
        "Ask free-text questions about the Adverse Events dataset. "
        "An LLM routes your question to the right column and returns the "
        "subjects that match."
    )

    # -- Sidebar ---------------------------------------------------------
    with st.sidebar:
        st.header("Configuration")

        csv_path = st.text_input(
            "Path to adae.csv",
            value=str(DEFAULT_CSV),
            help="Export with `Rscript export_adae.R` if missing.",
        )

        api_key_present = bool(os.getenv("OPENAI_API_KEY"))
        if api_key_present:
            st.success("OPENAI_API_KEY detected in environment.")
        else:
            st.warning(
                "No OPENAI_API_KEY found — the agent will use its rule-based "
                "mock parser."
            )

        force_mock = st.checkbox(
            "Force mock parser (no LLM calls)",
            value=not api_key_present,
            help="Useful for offline demos and regression testing.",
        )

        st.divider()
        st.subheader("Schema shown to the LLM")
        for col, desc in AE_SCHEMA.items():
            st.markdown(f"**`{col}`** — {desc}")

    # -- Load data / agent ----------------------------------------------
    if not Path(csv_path).exists():
        st.error(
            f"Could not find `{csv_path}`. Export the dataset first with:\n\n"
            "    Rscript export_adae.R"
        )
        st.stop()

    df = _load_dataframe(csv_path)
    agent = _build_agent(csv_path, force_mock)

    col_info, col_preview = st.columns([1, 2])
    with col_info:
        st.metric("AE records", f"{len(df):,}")
        st.metric("Unique subjects", df["USUBJID"].nunique())
        st.metric(
            "Agent mode",
            "Mock (rule-based)" if agent.use_mock else "LLM (OpenAI)",
        )
    with col_preview:
        with st.expander("Dataset preview (first 10 rows)", expanded=False):
            preview_cols = [c for c in
                            ["USUBJID", "AETERM", "AEDECOD", "AESOC",
                             "AESEV", "AESER", "AEOUT"] if c in df.columns]
            st.dataframe(df[preview_cols].head(10), use_container_width=True)

    st.divider()

    # -- Question input -------------------------------------------------
    st.subheader("Ask a question")

    with st.form(key="question_form", clear_on_submit=False):
        picked_example = st.selectbox(
            "Pick an example (optional):",
            options=[""] + EXAMPLE_QUESTIONS,
            index=0,
        )
        question = st.text_input(
            "Your question:",
            value=picked_example or "Give me the subjects who had Adverse events of Moderate severity.",
        )
        submitted = st.form_submit_button("Run query", type="primary")

    if not submitted:
        st.info("Enter a question above and click **Run query**.")
        return

    if not question.strip():
        st.warning("Please enter a non-empty question.")
        return

    with st.spinner("Routing question and filtering dataset..."):
        try:
            result = agent.query(question)
        except Exception as exc:
            st.error(f"Agent failed: {exc}")
            return

    # -- Results --------------------------------------------------------
    st.subheader("Result")

    meta_left, meta_right = st.columns(2)
    with meta_left:
        st.markdown("**Structured LLM output**")
        st.json(result.parsed.model_dump())
    with meta_right:
        st.metric("Matching AE rows", result.matching_rows)
        st.metric("Unique subjects", result.subject_count)

    if result.subject_count == 0:
        st.warning(
            "No subjects matched. Try rephrasing — the LLM may have mapped "
            "to a different column than you expected."
        )
        return

    st.markdown("**Matching subject IDs**")
    subjects_df = pd.DataFrame({"USUBJID": result.subjects})
    st.dataframe(subjects_df, use_container_width=True, height=260)

    st.download_button(
        "Download subjects as CSV",
        data=subjects_df.to_csv(index=False).encode("utf-8"),
        file_name="matching_subjects.csv",
        mime="text/csv",
    )

    with st.expander("See full matching AE rows"):
        col = result.parsed.target_column
        val = result.parsed.filter_value
        mask = df[col].astype(str).str.contains(val, case=False, na=False)
        st.dataframe(df.loc[mask].head(500), use_container_width=True)


if __name__ == "__main__":
    main()