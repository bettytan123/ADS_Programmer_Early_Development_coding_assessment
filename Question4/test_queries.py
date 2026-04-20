"""Smoke-test script for :class:`ClinicalTrialDataAgent`.

Runs three example questions end-to-end (Prompt → Parse → Execute) and prints
the structured LLM output together with the resulting subject count and list.

This produce the test sript for how this openaiagent works.

The CSV path defaults to ``data/adae.csv``; override it with ``--csv``.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from clinical_trial_agent import ClinicalTrialDataAgent, load_adae


EXAMPLE_QUERIES = [
    "Give me the subjects who had Adverse events of Moderate severity.",
    "Which patients experienced Cardiac disorders?",
    "Find subjects with Headache.",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--csv",
        default=str(Path(__file__).parent / "data" / "adae.csv"),
        help="Path to adae.csv (defaults to ./data/adae.csv)",
    )
    parser.add_argument(
        "--mock",
        action="store_true",
        help="Force the rule-based mock parser (ignores OPENAI_API_KEY).",
    )
    parser.add_argument(
        "--max-subjects",
        type=int,
        default=10,
        help="Truncate the printed subject list to at most this many IDs.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not Path(args.csv).exists():
        print(
            f"ERROR: CSV not found at {args.csv}. "
            "Run `Rscript export_adae.R` first to materialise it.",
            file=sys.stderr,
        )
        return 1

    df = load_adae(args.csv)
    agent = ClinicalTrialDataAgent(df, force_mock=args.mock)

    print(f"Loaded {len(df):,} AE records — {df['USUBJID'].nunique()} unique subjects")
    print(f"Agent mode : {'MOCK (rule-based)' if agent.use_mock else 'LLM (OpenAI)'}\n")

    for i, question in enumerate(EXAMPLE_QUERIES, start=1):
        print("=" * 72)
        print(f"Query {i}: {question}")
        result = agent.query(question)
        payload = result.to_dict()

        # Truncate the subject list for readability
        if len(payload["subjects"]) > args.max_subjects:
            shown = payload["subjects"][: args.max_subjects]
            payload["subjects"] = shown + [f"... (+{result.subject_count - args.max_subjects} more)"]

        print(json.dumps(payload, indent=2, default=str))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())