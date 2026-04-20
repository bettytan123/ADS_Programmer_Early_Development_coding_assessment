import pandas as pd
import json
import re


class ClinicalTrialDataAgent:
    """
    A simple clinical trial data agent that:
    1. Knows the AE dataset schema
    2. Parses a natural language question into structured JSON
    3. Applies the parsed result to a pandas DataFrame
    """

    def __init__(self, df: pd.DataFrame):
        self.df = df

        # Schema definition given to the LLM / parser
        self.schema = {
            "AESEV": "Adverse event severity or intensity (e.g., MILD, MODERATE, SEVERE)",
            "AETERM": "Reported adverse event term or condition (e.g., HEADACHE, NAUSEA)",
            "AESOC": "Body system / system organ class (e.g., CARDIAC DISORDERS, SKIN DISORDERS)"
        }

        # Helpful known values / synonyms for mock parsing
        self.severity_map = {
            "mild": "MILD",
            "moderate": "MODERATE",
            "severe": "SEVERE",
            "intensity mild": "MILD",
            "intensity moderate": "MODERATE",
            "intensity severe": "SEVERE"
        }

        self.soc_keywords = {
            "cardiac": "CARDIAC DISORDERS",
            "skin": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
            "gastrointestinal": "GASTROINTESTINAL DISORDERS",
            "nervous system": "NERVOUS SYSTEM DISORDERS",
            "respiratory": "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS"
        }

    def get_schema_text(self) -> str:
        """Return schema description as a string, as if sending to an LLM."""
        schema_text = "\n".join([f"- {k}: {v}" for k, v in self.schema.items()])
        return schema_text

    def build_prompt(self, question: str) -> str:
        """
        Create the prompt that would be sent to an LLM.
        """
        prompt = f"""
You are a clinical trial data assistant.

Dataset schema:
{self.get_schema_text()}

Your task:
Convert the user's question into JSON with this format:
{{
  "target_column": "<column name>",
  "filter_value": "<value to search>",
  "operation": "equals"
}}

Rules:
- If the user asks about severity or intensity, use AESEV.
- If the user asks about a specific condition/event term like headache, nausea, fever, use AETERM.
- If the user asks about a body system like cardiac or skin, use AESOC.
- Return JSON only.

User question:
{question}
"""
        return prompt.strip()

    def call_llm_mock(self, question: str) -> dict:
        """
        Mock LLM parser:
        This simulates what an LLM would return.
        It is rule-based only because the assignment allows mocking if no API key exists.
        """
        q = question.lower().strip()

        # 1. Severity / intensity
        for word, mapped in self.severity_map.items():
            if word in q:
                return {
                    "target_column": "AESEV",
                    "filter_value": mapped,
                    "operation": "equals"
                }

        # 2. Body system / AESOC
        for word, mapped in self.soc_keywords.items():
            if word in q:
                return {
                    "target_column": "AESOC",
                    "filter_value": mapped,
                    "operation": "contains"
                }

        # 3. Event terms / AETERM
        # Try to capture common event examples
        common_terms = [
            "headache", "nausea", "vomiting", "fever", "rash",
            "fatigue", "dizziness", "diarrhea", "cough"
        ]
        for term in common_terms:
            if term in q:
                return {
                    "target_column": "AETERM",
                    "filter_value": term.upper(),
                    "operation": "contains"
                }

        # 4. Fallback
        return {
            "target_column": None,
            "filter_value": None,
            "operation": None,
            "error": "Could not confidently map question to a dataset variable."
        }

    def parse_question(self, question: str, use_mock_llm: bool = True) -> dict:
        """
        Parse the user question into structured JSON-like output.
        """
        prompt = self.build_prompt(question)
        print("\n=== PROMPT SENT TO LLM ===")
        print(prompt)

        if use_mock_llm:
            parsed = self.call_llm_mock(question)
        else:
            # Placeholder for real LLM integration
            raise NotImplementedError("Real API call not implemented in this example.")

        print("\n=== STRUCTURED OUTPUT ===")
        print(json.dumps(parsed, indent=2))
        return parsed

    def execute_query(self, parsed_output: dict) -> pd.DataFrame:
        """
        Apply the parsed output to the dataframe.
        """
        if parsed_output.get("error"):
            raise ValueError(parsed_output["error"])

        column = parsed_output["target_column"]
        value = parsed_output["filter_value"]
        operation = parsed_output["operation"]

        if column not in self.df.columns:
            raise ValueError(f"Column '{column}' not found in dataframe.")

        # Convert the target column to string for robust filtering
        series = self.df[column].astype(str)

        if operation == "equals":
            result = self.df[series.str.upper() == str(value).upper()]
        elif operation == "contains":
            result = self.df[series.str.upper().str.contains(str(value).upper(), na=False)]
        else:
            raise ValueError(f"Unsupported operation: {operation}")

        return result

    def ask(self, question: str, use_mock_llm: bool = True) -> pd.DataFrame:
        """
        End-to-end pipeline:
        Prompt -> Parse -> Execute
        """
        parsed_output = self.parse_question(question, use_mock_llm=use_mock_llm)
        result = self.execute_query(parsed_output)
        return result


def main():
    # Replace with your real file path if needed
    file_path = "adae.csv"

    # Load dataset
    df = pd.read_csv(file_path)

    print("=== DATA PREVIEW ===")
    print(df.head())
    print("\n=== COLUMNS ===")
    print(df.columns.tolist())

    # Create the agent
    agent = ClinicalTrialDataAgent(df)

    # Example questions
    questions = [
        "Show me severe adverse events",
        "Find headache events",
        "Show cardiac adverse events",
        "Find skin events"
    ]

    for q in questions:
        print("\n" + "=" * 70)
        print(f"USER QUESTION: {q}")
        try:
            result = agent.ask(q, use_mock_llm=True)
            print("\n=== FILTERED RESULT PREVIEW ===")
            print(result.head())
            print(f"\nNumber of rows returned: {len(result)}")
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()