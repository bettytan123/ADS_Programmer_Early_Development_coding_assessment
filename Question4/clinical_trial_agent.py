"""Question4: Clinical Data Assistant Agent

Goal: This module exposes a single class, :class:`ClinicalTrialDataAgent`, that takes a
natural-language question about an Adverse Events dataset and returns the
subjects (``USUBJID``) that match the question.

Design in one paragraph
-----------------------
The agent uses an LLM (OpenAI via LangChain) to translate free text into a
structured, machine-checkable query ``{target_column, filter_value}``. The LLM
is shown a schema describing the AE columns, so it can *route* intent
("severity" → ``AESEV``, "Cardiac" → ``AESOC``, "Headache" → ``AETERM``) without
hard-coded keyword rules. A deterministic executor then applies the query as a
case-insensitive substring filter on the pandas dataframe, and returns the
unique subject count and list. If no ``OPENAI_API_KEY`` is found in the
environment the agent transparently falls back to a rule-based *mock* parser so
the logic flow (Prompt → Parse → Execute) stays complete and testable.
"""
from __future__ import annotations


import json
import os
import re
from dataclasses import dataclass, field
from typing import Any

import pandas as pd
from pydantic import BaseModel, Field

# LangChain imports are optional at import time: we only require them when the
# caller actually wants to hit the real LLM. This lets the mock path run in
# restricted environments that don't have LangChain installed.
try:
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_openai import ChatOpenAI
    _LANGCHAIN_AVAILABLE = True
except ImportError:  # pragma: no cover — exercised in minimal environments
    _LANGCHAIN_AVAILABLE = False


# ---------------------------------------------------------------------------
# Schema — how we tell the LLM what each column means
# ---------------------------------------------------------------------------

AE_SCHEMA: dict[str, str] = {
    "USUBJID": "Unique subject identifier. Never used as a filter target.",
    "AETERM": (
        "Reported term for the adverse event as written on the CRF "
        "(e.g. 'HEADACHE', 'NAUSEA', 'APPLICATION SITE PRURITUS'). "
        "Use this column when the user names a specific condition or symptom."
    ),
    "AEDECOD": (
        "Dictionary-derived / MedDRA preferred term for the adverse event. "
        "Often similar to AETERM but standardised."
    ),
    "AESOC": (
        "Primary System Organ Class - the MedDRA body system (e.g. "
        "'CARDIAC DISORDERS', 'SKIN AND SUBCUTANEOUS TISSUE DISORDERS', "
        "'NERVOUS SYSTEM DISORDERS'). Use this column when the user asks "
        "about a body system like 'Cardiac', 'Skin', 'Nervous'."
    ),
    "AESEV": (
        "Severity or intensity of the adverse event. Allowed values: "
        "'MILD', 'MODERATE', 'SEVERE'. Use this column when the user asks "
        "about severity or intensity."
    ),
    "AESER": "Serious event flag ('Y' / 'N').",
    "AEREL": "Relationship to study drug (e.g. 'RELATED', 'NOT RELATED').",
    "AEOUT": "Outcome of the event (e.g. 'RECOVERED/RESOLVED', 'FATAL').",
}


# ---------------------------------------------------------------------------
# Structured output contract
# ---------------------------------------------------------------------------

class AEQuery(BaseModel):
    """Structured JSON returned by the LLM for every natural-language query."""

    target_column: str = Field(
        description=(
            "Exact column name to filter on. Must be one of the keys in the "
            "AE schema, e.g. 'AETERM', 'AESOC', 'AESEV'."
        )
    )
    filter_value: str = Field(
        description=(
            "The value to search for inside that column, extracted from the "
            "user's question. Example: for 'moderate severity events' the "
            "filter_value is 'MODERATE'."
        )
    )


# ---------------------------------------------------------------------------
# Result container
# ---------------------------------------------------------------------------

@dataclass
class QueryResult:
    """Bundled outputs of a single NL → pandas query."""

    question: str
    parsed: AEQuery
    matching_rows: int
    subject_count: int
    subjects: list[str] = field(default_factory=list)
    used_mock: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "question": self.question,
            "parsed": self.parsed.model_dump(),
            "matching_rows": self.matching_rows,
            "subject_count": self.subject_count,
            "subjects": self.subjects,
            "used_mock": self.used_mock,
        }


# ---------------------------------------------------------------------------
# The agent
# ---------------------------------------------------------------------------

class ClinicalTrialDataAgent:
    """Translate natural-language questions into structured AE filters."""

    DEFAULT_MODEL = "gpt-4o-mini"

    def __init__(
        self,
        dataframe: pd.DataFrame,
        api_key: str | None = None,
        model: str = DEFAULT_MODEL,
        schema: dict[str, str] | None = None,
        force_mock: bool = False,
    ) -> None:
        self.df = dataframe
        self.schema = schema or AE_SCHEMA
        self._validate_dataframe()

        resolved_key = api_key or os.getenv("OPENAI_API_KEY")
        self.use_mock = force_mock or not resolved_key or not _LANGCHAIN_AVAILABLE

        if not self.use_mock:
            self._llm = ChatOpenAI(
                model=model,
                api_key=resolved_key,
                temperature=0,
            ).with_structured_output(AEQuery)
            self._prompt = self._build_prompt_template()
        else:
            self._llm = None
            self._prompt = None

    # -- public API --------------------------------------------------------

    def query(self, question: str) -> QueryResult:
        """Run the full Prompt → Parse → Execute flow for one question."""
        parsed = self.parse_question(question)
        rows, subjects = self.execute(parsed)
        return QueryResult(
            question=question,
            parsed=parsed,
            matching_rows=rows,
            subject_count=len(subjects),
            subjects=subjects,
            used_mock=self.use_mock,
        )

    def parse_question(self, question: str) -> AEQuery:
        """Ask the LLM (or the mock) to structure the user's question."""
        if self.use_mock:
            return self._mock_parse(question)
        messages = self._prompt.format_messages(
            schema=self._schema_as_text(), question=question
        )
        return self._llm.invoke(messages)

    def execute(self, query: AEQuery) -> tuple[int, list[str]]:
        """Apply the structured filter and return (matching_rows, subjects)."""
        col, val = query.target_column, query.filter_value

        if col not in self.df.columns:
            raise KeyError(
                f"LLM chose a column not in the dataframe: {col!r}. "
                f"Available: {list(self.df.columns)[:15]}..."
            )

        series = self.df[col].astype(str)
        mask = series.str.contains(re.escape(val), case=False, na=False)
        filtered = self.df.loc[mask]
        subjects = sorted(filtered["USUBJID"].dropna().unique().tolist())
        return int(mask.sum()), subjects

    # -- internals ---------------------------------------------------------

    def _validate_dataframe(self) -> None:
        required = {"USUBJID"}
        missing = required - set(self.df.columns)
        if missing:
            raise ValueError(
                f"Input dataframe is missing required column(s): {missing}"
            )

    def _schema_as_text(self) -> str:
        return "\n".join(f"- {name}: {desc}" for name, desc in self.schema.items())

    def _build_prompt_template(self) -> "ChatPromptTemplate":
        system = (
            "You are a clinical data routing assistant. You convert a user's "
            "free-text question about an Adverse Events dataset into a "
            "structured filter {{target_column, filter_value}}.\n\n"
            "Rules:\n"
            "1. target_column MUST be one of the exact column names in the "
            "schema below.\n"
            "2. filter_value is a short string to search inside that column. "
            "Use UPPERCASE for AESEV values ('MILD', 'MODERATE', 'SEVERE') "
            "and for AESOC / AETERM values.\n"
            "3. Prefer AESEV for 'severity' or 'intensity' questions, AESOC "
            "for body-system questions ('cardiac', 'skin', 'nervous'), and "
            "AETERM for specific symptom/condition questions ('headache', "
            "'nausea', 'rash').\n\n"
            "Schema:\n{schema}"
        )
        user = "Question: {question}"
        return ChatPromptTemplate.from_messages([("system", system), ("user", user)])

    # -- mock parser -------------------------------------------------------

    _SEVERITY_WORDS = {"mild", "moderate", "severe"}
    _BODY_SYSTEM_HINTS = {
        "cardiac": "CARDIAC",
        "heart": "CARDIAC",
        "skin": "SKIN",
        "dermatol": "SKIN",
        "nervous": "NERVOUS",
        "neuro": "NERVOUS",
        "gastro": "GASTROINTESTINAL",
        "digestive": "GASTROINTESTINAL",
        "respirator": "RESPIRATORY",
        "lung": "RESPIRATORY",
        "eye": "EYE",
        "vascular": "VASCULAR",
        "infect": "INFECTIONS",
        "psychiat": "PSYCHIATRIC",
    }

    def _mock_parse(self, question: str) -> AEQuery:
        """Rule-based stand-in for the LLM so the demo works without a key."""
        q = question.lower()

        if any(w in q for w in ("severity", "intensity")) or any(
            w in q for w in self._SEVERITY_WORDS
        ):
            for w in self._SEVERITY_WORDS:
                if w in q:
                    return AEQuery(target_column="AESEV", filter_value=w.upper())
            return AEQuery(target_column="AESEV", filter_value="MODERATE")

        for hint, token in self._BODY_SYSTEM_HINTS.items():
            if hint in q:
                return AEQuery(target_column="AESOC", filter_value=token)

        # AETERM — last-ditch: pull the most distinctive noun-ish token.
        # We strip filler words and try the remaining longest token.
        filler = {
            "give", "me", "the", "subjects", "who", "had", "have", "with",
            "a", "an", "of", "show", "list", "any", "all", "events",
            "event", "adverse", "patient", "patients", "please", "those",
            "that", "experienced", "find", "which", "their",
        }
        tokens = [t for t in re.findall(r"[A-Za-z]+", q) if t not in filler]
        if tokens:
            pick = max(tokens, key=len)
            return AEQuery(target_column="AETERM", filter_value=pick.upper())

        return AEQuery(target_column="AETERM", filter_value="")


# ---------------------------------------------------------------------------
# Convenience loader
# ---------------------------------------------------------------------------

def load_adae(path: str | os.PathLike = None) -> pd.DataFrame:
    import os
    
    if path is None:
        BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(BASE_DIR, "data", "adae.csv")

    print("Loading from:", path)
    df = pd.read_csv(path, dtype=str, keep_default_na=False, na_values=[""])
    return df


if __name__ == "__main__":  # pragma: no cover — manual smoke test
    df = load_adae()
    agent = ClinicalTrialDataAgent(df)
    print(json.dumps(
        agent.query("Give me subjects with Moderate severity AEs.").to_dict(),
        indent=2, default=str,
    ))