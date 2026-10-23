
import re


def _extract_number(pattern: str, text: str):
    """Return the first matching numeric value, or None."""
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return None

    try:
        return float(match.group(1))
    except (ValueError, IndexError):
        return None


def extract_medical_values(text: str) -> dict:
    """Extract selected lab values from report text."""
    values = {}

    # Diabetes-related measurements
    tests = {
        "fasting_glucose": (
            r"(\d+(?:\.\d+)?)\s*Glucose\s+Fasting",
            "mg/dL",
        ),
        "post_meal_glucose": (
            r"(\d+(?:\.\d+)?)\s*Glucose\s*\(PP\)",
            "mg/dL",
        ),
        "hba1c": (
            r"(?:HbA1c|Hb A1c|Glycated Hemoglobin)"
            r"[\s:=-]*(\d+(?:\.\d+)?)\s*%?",
            "%",
        ),
        # Kidney-related measurements
        "creatinine": (
            r"(?:Serum\s+)?Creatinine"
            r"[\s:=-]*(\d+(?:\.\d+)?)",
            "check_report",
        ),
        "blood_urea": (
            r"(?:Blood\s+Urea|Urea)"
            r"[\s:=-]*(\d+(?:\.\d+)?)",
            "check_report",
        ),
        "egfr": (
            r"(?:eGFR|Estimated\s+GFR)"
            r"[\s:=-]*(\d+(?:\.\d+)?)",
            "mL/min/1.73 m2",
        ),
    }

    for name, (pattern, unit) in tests.items():
        number = _extract_number(pattern, text)

        if number is not None:
            values[name] = {
                "value": number,
                "unit": unit,
            }

    # Age: supports formats such as "Age: 25 Years" and "25 Years"
    age_match = re.search(
        r"\bAge\s*:\s*(\d{1,3})\s*Years\b"
        r"|\b(\d{1,3})\s*Years\b",
        text,
        re.IGNORECASE,
    )

    if age_match:
        age = age_match.group(1) or age_match.group(2)
        values["age"] = int(age)

    # Gender
    gender_match = re.search(
        r"\bGender\s*:\s*(Male|Female)\b"
        r"|\b(Male|Female)\b",
        text,
        re.IGNORECASE,
    )

    if gender_match:
        gender = gender_match.group(1) or gender_match.group(2)
        values["gender"] = gender.lower()

    return values
