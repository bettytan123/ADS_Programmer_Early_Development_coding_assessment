import os
import json
import pandas as pd
from typing import Literal

from langchain.tools import tool
from langchain.agents import create_agent
from langchain_openai import ChatOpenAI


# --------------------------------------------------
# 1. Load AE dataset
# --------------------------------------------------
ae = pd.read_csv("adae.csv")


# --------------------------------------------------
# 2. Small helper to normalize values
# --------------------------------------------------
def normalize_text(x):
    if pd.isna(x):
        return ""
    return str(x).strip().upper()


# --------------------------------------------------
# 3. Tool: filter the AE dataframe
# --------------------------------------------------
@tool
def filter_adae(
    target_column: Literal["AESEV", "AETERM", "AESOC"],
    filter_value: str
) -> str:
    """
    Filter the adae dataframe using a selected target column and filter value.

    Use:
    - AESEV for severity or intensity questions
    - AETERM for specific adverse event terms like headache, nausea, rash
    - AESOC for body system / organ class questions like cardiac or skin

    Returns JSON containing:
    - selected_column
    - selected_value
    - n_rows
    - preview_rows
    """
    if target_column not in ae.columns:
        return json.dumps({
            "error": f"Column {target_column} not found in adae.csv"
        }, indent=2)

    series = ae[target_column].apply(normalize_text)
    value = normalize_text(filter_value)

    # exact for AESEV, contains for AETERM/AESOC
    if target_column == "AESEV":
        result = ae.loc[series == value].copy()
    else:
        result = ae.loc[series.str.contains(value, na=False)].copy()

    preview = result.head(10).fillna("").to_dict(orient="records")

    return json.dumps({
        "selected_column": target_column,
        "selected_value": filter_value,
        "n_rows": int(len(result)),
        "preview_rows": preview
    }, indent=2)


# --------------------------------------------------
# 4. Build model
# --------------------------------------------------
model = ChatOpenAI(
    model="gpt-5",
    temperature=0
)


# --------------------------------------------------
# 5. System prompt: tell the LLM how to map questions
# --------------------------------------------------
SYSTEM_PROMPT = """
You are a clinical trial AE assistant working with an adverse events dataset called adae.csv.

Relevant columns:
- AESEV: adverse event severity / intensity (examples: MILD, MODERATE, SEVERE)
- AETERM: adverse event term / condition (examples: HEADACHE, NAUSEA, RASH)
- AESOC: adverse event body system / system organ class
  (examples: CARDIAC DISORDERS, SKIN AND SUBCUTANEOUS TISSUE DISORDERS)

Your job:
1. Read the user's question.
2. Decide which ONE column best matches the question.
3. Extract the filter value from the question.
4. Call the tool filter_adae with:
   - target_column
   - filter_value

Mapping rules:
- severity / intensity -> AESEV
- specific symptom, event, or condition -> AETERM
- body system or organ class -> AESOC

Examples:
- "show severe events" -> AESEV, SEVERE
- "show headache events" -> AETERM, HEADACHE
- "show cardiac adverse events" -> AESOC, CARDIAC

Always use the tool when the question asks to filter the dataset.
"""


# --------------------------------------------------
# 6. Create agent
# --------------------------------------------------
agent = create_agent(
    model=model,
    tools=[filter_adae],
    system_prompt=SYSTEM_PROMPT
)


# --------------------------------------------------
# 7. Ask function
# --------------------------------------------------
def ask_ae(question: str):
    response = agent.invoke({
        "messages": [
            {"role": "user", "content": question}
        ]
    })
    return response


# --------------------------------------------------
# 8. Example
# --------------------------------------------------
if __name__ == "__main__":
    questions = [
        "show severe adverse events",
        "find headache events",
        "show cardiac adverse events"
    ]

    while True:
        user_input = input("> ")
        
        if user_input == "QUIT":
            print("Closing...")
            break

        q = user_input
        print("\n" + "=" * 80)
        print("USER QUESTION:", q)
        result = ask_ae(q)
        print(result)

    # for q in questions:
    #     print("\n" + "=" * 80)
    #     print("USER QUESTION:", q)
    #     result = ask_ae(q)
    #     print(result)