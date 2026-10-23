
import re
from copy import deepcopy
from services.nlp_extractor import (
    extract_diabetes_features,
    extract_ckd_features,
)
from services.conversation import ConversationState
from services.model_router import route_models_from_features
from services.gemini_service import generate_chat_response


class ChatService:
    """
    Coordinates natural-language chat, medical-value extraction,
    report mapping, conversation state, and ML model routing.

    NLP extraction and the ML router remain responsible for
    structured inputs and predictions. Groq generates conversational
    responses; it does not invent medical values or predictions.
    """

    DIABETES_QUESTIONS = {
        "age": "How old are you?",
        "gender": "What is your gender?",
        "hypertension": "Have you been diagnosed with hypertension?",
        "heart_disease": "Have you been diagnosed with heart disease?",
        "bmi": "Do you know your BMI?",
        "HbA1c_level": "Do you know your latest HbA1c result?",
        "blood_glucose_level": "Do you know your latest blood glucose result?",
        "smoking_history": "What is your smoking history?",
    }

    
    FEATURE_LABELS = {
        # Diabetes
        "age": "age",
        "gender": "gender",
        "hypertension": "history of hypertension",
        "heart_disease": "history of heart disease",
        "bmi": "BMI",
        "HbA1c_level": "HbA1c result",
        "blood_glucose_level": "blood glucose result",
        "smoking_history": "smoking history",

        # CKD
        "bp": "blood pressure",
        "sg": "urine specific gravity",
        "al": "urine albumin",
        "su": "urine sugar",
        "bgr": "random blood glucose",
        "bu": "blood urea",
        "sc": "serum creatinine",
        "sod": "sodium",
        "pot": "potassium",
        "hemo": "haemoglobin",
        "pcv": "packed cell volume (PCV)",
        "wc": "white blood cell count",
        "rc": "red blood cell count",
        "rbc": "urine red blood cells",
        "pc": "urine pus cells",
        "pcc": "urine pus cell clumps",
        "ba": "urine bacteria",
        "htn": "history of hypertension",
        "dm": "history of diabetes",
        "cad": "history of coronary artery disease",
        "appet": "appetite",
        "pe": "swelling in the feet or legs",
        "ane": "history of anaemia",
    }


    CKD_QUESTIONS = {
        "age": "How old are you?",
        "bp": "Do you know your blood pressure reading?",
        "sg": "Do you have a urine specific gravity result?",
        "al": "Do you know your urine albumin result?",
        "su": "Do you know your urine sugar result?",
        "bgr": "Do you know your random blood glucose result?",
        "bu": "Do you know your blood urea result?",
        "sc": "Do you know your serum creatinine result?",
        "sod": "Do you know your sodium result?",
        "pot": "Do you know your potassium result?",
        "hemo": "Do you know your haemoglobin result?",
        "pcv": "Do you know your packed cell volume (PCV)?",
        "wc": "Do you know your white blood cell count?",
        "rc": "Do you know your red blood cell count?",
        "rbc": "Is your urine red blood cell result normal or abnormal?",
        "pc": "Is your urine pus cell result normal or abnormal?",
        "pcc": "Does your urine report mention pus cell clumps?",
        "ba": "Does your urine report mention bacteria?",
        "htn": "Have you been diagnosed with hypertension?",
        "dm": "Have you been diagnosed with diabetes?",
        "cad": "Have you been diagnosed with coronary artery disease?",
        "appet": "How is your appetite: good or poor?",
        "pe": "Have you experienced swelling in your feet or legs?",
        "ane": "Have you been diagnosed with anaemia?",
    }

    NUMERIC_FEATURES = {
        "age", "bmi", "HbA1c_level", "blood_glucose_level",
        "bp", "sg", "al", "su", "bgr", "bu", "sc",
        "sod", "pot", "hemo", "pcv", "wc", "rc",
    }

    BINARY_FEATURES = {
        "hypertension", "heart_disease", "htn", "dm", "cad",
        "pe", "ane", "pcc", "ba",
    }

    SKIP_ANSWERS = {
        "skip", "unknown", "don't know", "dont know",
        "i don't know", "i dont know", "not sure",
        "i'm not sure", "im not sure",
        "prefer not to say", "not available",
    }

    def __init__(self):
        self.state = ConversationState()

        # Remember the latest uploaded report for this chat session.
        self.last_medical_values = {}
        self.last_report_text = ""
        self.last_report_filename = None
        # Remember the latest assessment sent from the result screen.
        self.last_screening_context = ""

        self.pending_question = None
        self.active_screening = None
        self.skipped_features = {
            "diabetes": set(),
            "ckd": set(),
        }

    # ---------------------------------------------------------
    # General helpers
    # ---------------------------------------------------------

    @staticmethod
    def _empty_features():
        return {"diabetes": {}, "ckd": {}}

    @staticmethod
    def _has_features(features):
        return any(
            features.get(disease)
            for disease in ("diabetes", "ckd")
        )

    @staticmethod
    def _merge_features(target, source):
        for disease in ("diabetes", "ckd"):
            values = source.get(disease, {})
            if isinstance(values, dict):
                target[disease].update(values)
        return target

    def extract_all_features(self, text):
        """Extract all supported features from the complete message."""
        if not text:
            return self._empty_features()

        try:
            diabetes = extract_diabetes_features(text) or {}
        except Exception:
            diabetes = {}

        try:
            ckd = extract_ckd_features(text) or {}
        except Exception:
            ckd = {}

        return {
            "diabetes": diabetes if isinstance(diabetes, dict) else {},
            "ckd": ckd if isinstance(ckd, dict) else {},
        }

    
    

    
    
    @staticmethod
    def _intent(text):
        """Detect an explicit screening request and its target disease."""
        lowered = (text or "").lower()

        # Is the user asking to start or perform a screening?
        screening = bool(re.search(
            r"\b(screen|screening|risk assessment|assess my risk|"
            r"check my risk|check my health|check for|test my risk|"
            r"evaluate my risk|find out if i have|check whether i have|"
            r"do i have|am i at risk|check my chances)\b",
            lowered,
        ))

        # Detect an explicit CKD screening request.
        ckd_request = bool(re.search(
            r"\b(?:start|begin|want|need|request|initiate)\b"
            r".{0,40}\b(?:ckd|chronic kidney disease|"
            r"kidney disease|renal disease)\b"
            r"|\b(?:screen|screening|check|assess|test|evaluate)\b"
            r"\s+(?:my\s+)?(?:risk\s+)?(?:for\s+)?"
            r"(?:ckd|chronic kidney disease|kidney disease|renal disease)\b"
            r"|\b(?:ckd|chronic kidney disease|kidney disease|"
            r"renal disease)\s+(?:risk\s+)?"
            r"(?:screening|risk assessment)\b",
            lowered,
        ))

        # Detect an explicit diabetes screening request.
        diabetes_request = bool(re.search(
            r"\b(?:start|begin|want|need|request|initiate)\b"
            r".{0,40}\b(?:diabetes screening|diabetes risk|"
            r"diabetic risk)\b"
            r"|\b(?:screen|screening|check|assess|test|evaluate)\b"
            r"\s+(?:my\s+)?(?:risk\s+)?(?:for\s+)?"
            r"(?:diabetes|diabetic risk|diabetes risk)\b"
            r"|\b(?:diabetes risk|diabetic risk)\s+"
            r"(?:screening|risk assessment)\b",
            lowered,
        ))

        if ckd_request and not diabetes_request:
            return True, False, True

        if diabetes_request and not ckd_request:
            return False, True, True

        if ckd_request and diabetes_request:
            return True, True, True

        return False, False, screening


    @staticmethod
    def _safe_number(value, minimum, maximum):
        if isinstance(value, bool):
            return None
        try:
            number = float(value)
        except (TypeError, ValueError):
            return None

        if not minimum <= number <= maximum:
            return None
        return number

    # ---------------------------------------------------------
    # Medical report mapping
    # ---------------------------------------------------------

    def map_report_values(self, medical_values):
        """
        Map only recognized report fields with appropriate types.
        Do not infer a value from a missing field or an ambiguous unit.
        """
        result = self._empty_features()

        if not isinstance(medical_values, dict):
            return result

        def read_value(*keys):
            for key in keys:
                value = medical_values.get(key)
                if isinstance(value, dict):
                    value = value.get("value")
                if value is not None:
                    return value
            return None

        def read_numeric(target, source_keys, low, high):
            raw = read_value(*source_keys)
            number = self._safe_number(raw, low, high)
            if number is not None:
                target[source_keys[0]] = number

        # Diabetes glucose is accepted only when its unit is explicit.
        fasting = medical_values.get("fasting_glucose")
        if isinstance(fasting, dict):
            value = self._safe_number(
                fasting.get("value"), 0, 1500
            )
            unit = str(fasting.get("unit", "")).strip().lower()
            if value is not None and unit == "mg/dl":
                result["diabetes"]["blood_glucose_level"] = value

        hba1c = medical_values.get(
            "hba1c", medical_values.get("HbA1c_level")
        )
        if isinstance(hba1c, dict):
            value = self._safe_number(hba1c.get("value"), 0, 30)
            unit = str(hba1c.get("unit", "")).strip()
            if value is not None and unit == "%":
                result["diabetes"]["HbA1c_level"] = value
        elif hba1c is not None:
            value = self._safe_number(hba1c, 0, 30)
            if value is not None:
                result["diabetes"]["HbA1c_level"] = value

        age = self._safe_number(medical_values.get("age"), 1, 120)
        if age is not None:
            result["diabetes"]["age"] = age
            result["ckd"]["age"] = age

        gender = medical_values.get("gender")
        if isinstance(gender, str):
            normalized = gender.strip().lower()
            if normalized in {"male", "female"}:
                result["diabetes"]["gender"] = normalized.capitalize()

        # Additional CKD report values. These aliases should be
        # aligned with the keys produced by medical_value_extractor.py.
        ckd_numeric_aliases = {
            "sg": ("sg", "specific_gravity", "urine_specific_gravity"),
            "al": ("al", "albumin", "urine_albumin"),
            "su": ("su", "urine_sugar"),
            "bgr": ("bgr", "random_glucose", "blood_glucose"),
            "bu": ("bu", "blood_urea", "urea"),
            "sc": ("sc", "serum_creatinine", "creatinine"),
            "sod": ("sod", "sodium"),
            "pot": ("pot", "potassium"),
            "hemo": ("hemo", "hemoglobin", "haemoglobin"),
            "pcv": ("pcv", "packed_cell_volume"),
            "wc": ("wc", "white_blood_cell_count", "wbc"),
            "rc": ("rc", "red_blood_cell_count", "rbc_count"),
        }

        ranges = {
            "sg": (0.0, 2.0),
            "al": (0.0, 10.0),
            "su": (0.0, 10.0),
            "bgr": (0.0, 1500.0),
            "bu": (0.0, 2000.0),
            "sc": (0.0, 200.0),
            "sod": (0.0, 250.0),
            "pot": (0.0, 30.0),
            "hemo": (0.0, 40.0),
            "pcv": (0.0, 100.0),
            "wc": (0.0, 1000000.0),
            "rc": (0.0, 20.0),
        }

        for feature, aliases in ckd_numeric_aliases.items():
            raw = read_value(*aliases)
            low, high = ranges[feature]
            number = self._safe_number(raw, low, high)
            if number is not None:
                result["ckd"][feature] = number

        # Map categorical values only when the report extractor
        # provides a recognizable, unambiguous value.
        category_aliases = {
            "rbc": ("rbc", "urine_rbc"),
            "pc": ("pc", "pus_cells"),
            "pcc": ("pcc", "pus_cell_clumps"),
            "ba": ("ba", "bacteria"),
            "htn": ("htn", "hypertension"),
            "dm": ("dm", "diabetes"),
            "cad": ("cad", "coronary_artery_disease"),
            "appet": ("appet", "appetite"),
            "pe": ("pe", "pedal_edema", "swelling"),
            "ane": ("ane", "anemia", "anaemia"),
        }

        positive_negative = {
            "yes": "yes",
            "positive": "yes",
            "present": "yes",
            "true": "yes",
            "no": "no",
            "negative": "no",
            "absent": "no",
            "false": "no",
        }

        for feature, aliases in category_aliases.items():
            raw = read_value(*aliases)
            if not isinstance(raw, str):
                continue

            value = raw.strip().lower()

            if feature in {"htn", "dm", "cad", "pe", "ane"}:
                if value in positive_negative:
                    result["ckd"][feature] = positive_negative[value]

            elif feature in {"pcc", "ba"}:
                if value in {"yes", "positive", "present"}:
                    result["ckd"][feature] = "present"
                elif value in {"no", "negative", "absent"}:
                    result["ckd"][feature] = "notpresent"

            elif feature in {"rbc", "pc"}:
                if value in {"normal", "abnormal"}:
                    result["ckd"][feature] = value

            elif feature == "appet":
                if value in {"good", "poor"}:
                    result["ckd"][feature] = value

        return result

    # ---------------------------------------------------------
    # Report explanation
    # ---------------------------------------------------------

    def explain_report(self, medical_values):
        """
        Explain extracted values without diagnosing the user.
        Groq can provide a more conversational explanation elsewhere.
        """
        if not isinstance(medical_values, dict) or not medical_values:
            return (
                "I couldn't identify readable medical values in that "
                "report. Please check the file or share the values "
                "shown on it."
            )

        lines = ["Here are the values I could identify in your report:"]

        for key, label in (
            ("fasting_glucose", "Fasting blood glucose"),
            ("post_meal_glucose", "Post-meal blood glucose"),
            ("hba1c", "HbA1c"),
            ("HbA1c_level", "HbA1c"),
            ("serum_creatinine", "Serum creatinine"),
            ("creatinine", "Creatinine"),
            ("blood_urea", "Blood urea"),
            ("hemoglobin", "Hemoglobin"),
            ("haemoglobin", "Haemoglobin"),
            ("specific_gravity", "Urine specific gravity"),
            ("urine_albumin", "Urine albumin"),
        ):
            if key not in medical_values:
                continue

            item = medical_values[key]
            if isinstance(item, dict):
                value = item.get("value")
                unit = item.get("unit", "")
            else:
                value = item
                unit = ""

            if value is not None:
                lines.append(f"- {label}: {value} {unit}".rstrip())

        if len(lines) == 1:
            lines.append(
                "The report extractor did not return any of the "
                "recognized fields. The report may need manual review."
            )

        lines.append(
            "\nExtracted values can contain errors and need to be "
            "checked against the original report. These values alone "
            "do not establish a diagnosis. Please discuss your results "
            "with a qualified healthcare professional."
        )

        return "\n".join(lines)

    # ---------------------------------------------------------
    # Pending-answer interpretation
    # ---------------------------------------------------------

    def _interpret_pending_answer(self, text):
        if not self.pending_question:
            return None, None

        screening, feature = self.pending_question
        answer = (text or "").strip().lower().rstrip(".!?")

        if answer in self.SKIP_ANSWERS:
            self.skipped_features[screening].add(feature)
            self.pending_question = None
            return {screening: {}}, None

        if feature in self.NUMERIC_FEATURES:
            # Avoid using an arbitrary unrelated number where possible.
            patterns = (
                r"\b(?:my age is|age is|aged|i am|i'm|im)\s*"
                r"(-?\d+(?:\.\d+)?)\b",
                r"\b(?:bmi|hba1c|blood glucose|glucose|"
                r"blood pressure|creatinine|urea|sodium|potassium|"
                r"haemoglobin|hemoglobin|specific gravity|albumin)"
                r"\s*(?:is|of|:|=)?\s*(-?\d+(?:\.\d+)?)\b",
                r"^\s*(-?\d+(?:\.\d+)?)\s*$",
            )

            match = None
            for pattern in patterns:
                match = re.search(pattern, answer)
                if match:
                    break

            if not match:
                return None, (
                    "I couldn't identify the requested value. You can "
                    "include the value and its test name, share several "
                    "results together, or say 'skip'."
                )

            value = self._safe_number(match.group(1), 0, 100000)
            if value is None:
                return None, "That value looks invalid. Please check it."

            if feature == "age" and not 1 <= value <= 120:
                return None, "Please provide an age between 1 and 120."
            if feature == "bmi" and not 5 <= value <= 100:
                return None, "Please check the BMI value or say 'skip'."
            if feature == "sg" and not 1.0 <= value <= 1.1:
                return None, (
                    "Please check the specific gravity value or say 'skip'."
                )
            if feature == "HbA1c_level" and value > 30:
                return None, "Please check the HbA1c value and units."

            self.pending_question = None
            return {screening: {feature: value}}, None

        if feature in self.BINARY_FEATURES:
            yes = {
                "yes", "y", "yeah", "yep", "true", "present",
                "i have it", "i have",
            }
            no = {
                "no", "n", "nope", "false", "absent",
                "i don't have it", "i dont have it",
            }

            if answer in yes:
                if screening == "diabetes":
                    value = 1
                elif feature in {"pcc", "ba"}:
                    value = "present"
                else:
                    value = "yes"
            elif answer in no:
                if screening == "diabetes":
                    value = 0
                elif feature in {"pcc", "ba"}:
                    value = "notpresent"
                else:
                    value = "no"
            else:
                return None, (
                    "Please clarify whether the answer is yes or no, "
                    "or say 'skip'. You can also provide other known "
                    "medical values in the same message."
                )

            self.pending_question = None
            return {screening: {feature: value}}, None

        if feature == "gender":
            if answer in {"male", "man", "i am male", "i'm male"}:
                value = "Male"
            elif answer in {
                "female", "woman", "i am female", "i'm female"
            }:
                value = "Female"
            else:
                return None, "Please provide your gender or say 'skip'."

            self.pending_question = None
            return {"diabetes": {"gender": value}}, None

        if feature == "smoking_history":
            choices = {
                "never": "never",
                "never smoked": "never",
                "former": "former",
                "former smoker": "former",
                "not current": "not current",
                "not a current smoker": "not current",
                "current": "current",
                "current smoker": "current",
                "ever": "ever",
                "no info": "No Info",
            }
            if answer not in choices:
                return None, (
                    "Please provide your smoking history or say 'skip'."
                )

            self.pending_question = None
            return {
                "diabetes": {
                    "smoking_history": choices[answer]
                }
            }, None

        if feature in {"rbc", "pc"}:
            if answer in {"normal", "yes", "present"}:
                value = "normal"
            elif answer in {"abnormal", "no", "absent"}:
                value = "abnormal"
            else:
                return None, (
                    "Please answer normal or abnormal, or say 'skip'."
                )

            self.pending_question = None
            return {"ckd": {feature: value}}, None

        if feature == "appet":
            if answer in {"good", "normal", "good appetite"}:
                value = "good"
            elif answer in {"poor", "poor appetite"}:
                value = "poor"
            else:
                return None, "Please answer good or poor, or say 'skip'."

            self.pending_question = None
            return {"ckd": {"appet": value}}, None

        return None, "Please provide the requested value or say 'skip'."

    
    @classmethod
    def format_missing_features(cls, features):
        """Convert model feature keys into user-friendly labels."""
        return [
            cls.FEATURE_LABELS.get(feature, feature)
            for feature in features
        ]


    # ---------------------------------------------------------
    # Follow-up selection
    # ---------------------------------------------------------

    def get_follow_up_message(
        self,
        router_result,
        preferred_screening=None,
    ):
        missing = router_result.get("missing_features", {})
        questions = {
            "diabetes": self.DIABETES_QUESTIONS,
            "ckd": self.CKD_QUESTIONS,
        }

        order = (
            [preferred_screening]
            if preferred_screening in {"diabetes", "ckd"}
            else ["diabetes", "ckd"]
        )

        for screening in order:
            for feature in missing.get(screening, []):
                if feature not in questions[screening]:
                    continue
                if feature in self.skipped_features[screening]:
                    continue

                self.pending_question = (screening, feature)
                self.active_screening = screening
                return (
                    f"To continue {screening.upper()} screening, "
                    f"{questions[screening][feature]} You can also "
                    "share other known values together or upload a report."
                )

        self.pending_question = None
        return (
            "I've saved the information you've shared. You can provide "
            "more values together, upload a medical report, or ask me "
            "a question."
        )

    # ---------------------------------------------------------
    # Main message processing
    # ---------------------------------------------------------
   
   
    def process_message(
        self,
        text,
        medical_values=None,
        report_text=None,
        report_filename=None,
        profile_context=None,
    ):
        """
        Process ordinary chat, explicit screening requests, medical
        reports, and ML predictions without exposing technical model
        probabilities in the user-facing screening response.
        """
        text = (text or "").strip()
        empty = self._empty_features()

        # Remember assessment details sent by the Flutter result screen.
        if (
            "completed a diabetes risk assessment" in text.lower()
            or "completed a ckd risk assessment" in text.lower()
        ):
            self.last_screening_context = text

        # Save a newly uploaded report for future messages in this session.
        if isinstance(medical_values, dict) and medical_values:
            self.last_medical_values = deepcopy(medical_values)

        if isinstance(report_text, str) and report_text.strip():
            self.last_report_text = report_text.strip()

        if report_filename:
            self.last_report_filename = report_filename

        if not text and not medical_values:
            current = self.state.get_features()
            return {
                "message": text,
                "assistant_message": "Please enter a message so I can help.",
                "extracted_features": empty,
                "conversation_features": current,
                "router_result": route_models_from_features(current),
            }

        lowered = text.lower()

        # A result-screen message asks for an explanation,
        # not a new screening.
        if (
            "completed a diabetes risk assessment" in lowered
            or "completed a ckd risk assessment" in lowered
        ):
            context = (
                "You are SymptoCare, a friendly health-information assistant. "
                "The user has already completed a health screening. "
                "Explain the result directly to the user in simple, natural, "
                "reassuring language. "
                "Do not expose internal technical details, model implementation, "
                "class labels, prediction codes, or backend processing. "
                "Never say 'Model prediction: 0', 'positive class', or "
                "'negative class'. "
                "If a probability is provided, describe it as an estimated probability "
                "and preserve its numerical value accurately. "
                "Do not invent, recalculate, or alter the screening result. "
                "Briefly explain what the result means, its limitations, and "
                "appropriate next steps. "
                "Never claim that a screening result confirms or rules out disease. "
                "Do not start a new screening or ask which disease the user wants "
                "to check. "
                "FORMATTING RULES: Never use Markdown tables, HTML tables, columns, "
                "or pipe characters to organize information. "
                "Use short headings, plain paragraphs, and concise bullet points. "
                "Keep the entire response easy to read on a mobile phone. "
                "Do not list every input measurement and explain its individual "
                "effect unless the user explicitly asks."
            )

            try:
                answer = generate_chat_response(text, context=context)
            except Exception:
                answer = (
                    "I'm having trouble explaining your screening result right "
                    "now. Please try again in a moment."
                )

            return {
                "message": text,
                "assistant_message": answer,
                "extracted_features": empty,
                "conversation_features": self.state.get_features(),
                "router_result": route_models_from_features(
                    self.state.get_features()
                ),
            }

        explanation_requested = bool(re.search(
            r"\b(?:explain|interpret|summarize|summarise)"
            r".{0,40}\b(?:my|this|the|medical)?\s*"
            r"(?:medical\s+)?report\b"
            r"|\b(?:what does|what do|tell me about)"
            r".{0,50}\b(?:my|the)\s+"
            r"(?:glucose|sugar|hba1c|creatinine|urea|"
            r"haemoglobin|hemoglobin|test result|lab result)\b"
            r"|\breport in simple language\b",
            lowered,
        ))

        # Use the remembered report when the user asks about it again.
        if (
            explanation_requested
            and not medical_values
            and self.last_medical_values
        ):
            medical_values = self.last_medical_values

        ckd_intent, diabetes_intent, screening_intent = self._intent(text)

        # Preserve an active screening during follow-up messages.
        if self.active_screening is None:
            if ckd_intent and not diabetes_intent:
                self.active_screening = "ckd"
            elif diabetes_intent and not ckd_intent:
                self.active_screening = "diabetes"

        # Switch screening when the user explicitly requests another
        # disease-specific screening.
        if ckd_intent and not diabetes_intent:
            self.active_screening = "ckd"
            self.pending_question = None
        elif diabetes_intent and not ckd_intent:
            self.active_screening = "diabetes"
            self.pending_question = None

        # Extract recognized values from the current message.
        extracted = self.extract_all_features(text)

        # Interpret an answer to a previous screening follow-up.
        if self.pending_question:
            interpreted, clarification = self._interpret_pending_answer(text)

            if interpreted is not None:
                self._merge_features(extracted, interpreted)
            elif clarification and not self._has_features(extracted):
                current = self.state.get_features()
                return {
                    "message": text,
                    "assistant_message": clarification,
                    "extracted_features": empty,
                    "conversation_features": current,
                    "router_result": route_models_from_features(current),
                }

        # Map uploaded report values and merge explicitly extracted values.
        if medical_values:
            report_features = self.map_report_values(medical_values)
            self._merge_features(report_features, extracted)
            extracted = report_features

        # Explain a newly uploaded or remembered report without
        # automatically starting a screening.
        
        # Recognize direct questions about a previously uploaded report.
        
        

    

        # Ordinary conversation: store recognized values and respond
        # conversationally. Do not automatically start a screening.
        if (
            not self.active_screening
            and not screening_intent
        ):
            for disease in ("diabetes", "ckd"):
                for feature in extracted[disease]:
                    self.skipped_features[disease].discard(feature)

            self.state.update(extracted)
            current = self.state.get_features()

            context = (
                "You are SymptoCare, a natural health-information assistant. "
                "Respond directly and conversationally to the user's latest "
                "message. Do not automatically start screening or list model "
                "input requirements during general conversation. Do not "
                "diagnose, invent patient details, or claim a screening "
                "prediction was performed when it was not. Explain medical "
                "results cautiously and recommend professional care when "
                "appropriate. For blood glucose, distinguish fasting from "
                "random or post-meal readings. A fasting glucose of "
                "100–125 mg/dL is in the impaired fasting glucose range "
                "when fasting for at least 8 hours; one reading alone does "
                "not establish a diagnosis."
            )

            if profile_context:
                context += (
                    "\n\nSaved profile information for the currently signed-in user:\n"
                    + profile_context
                    + "\n\nUse these details when relevant to the user's question. "
                    "If the user asks about a saved detail, answer from this profile. "
                    "Never invent missing details. If a detail is not saved, say so. "
                    "Treat profile information as context, not as proof of a diagnosis."
                )

            if self.last_screening_context:
                context += (
                    "\n\nPreviously completed screening assessment:\n"
                    + self.last_screening_context
                    + "\n\nWhen the user asks about this assessment, explain "
                    "the recorded prediction and submitted values in simple "
                    "language. Do not run a new prediction or invent missing "
                    "information. Clearly state that the screening result is "
                    "not a medical diagnosis."
                )


            if self.last_medical_values:
                context += (
                    "\n\nContext from the user's latest uploaded medical report:"
                    f"\nFilename: {self.last_report_filename or 'Not available'}"
                    f"\nExtracted values: {self.last_medical_values}"
                )

                if self.last_report_text:
                    context += (
                        "\n\nExtracted report text (may contain OCR errors):\n"
                        + self.last_report_text[:12000]
                    )

                context += (
                    "\nUse this report context only when relevant to the user's "
                    "question. Do not invent missing values or treat extracted "
                    "results as a confirmed diagnosis."
                )

            if profile_context:
                context += (
                    "\n\nSaved profile information for the currently signed-in user:\n"
                    + profile_context
                    + "\nUse these details only when relevant. "
                    "Never invent missing details."
                )

            try:
                answer = generate_chat_response(text, context=context)
            except Exception:
                answer = (
                    "I'm having trouble generating a response right now. "
                    "Please try again in a moment."
                )

            return {
                "message": text,
                "assistant_message": answer,
                "extracted_features": extracted,
                "conversation_features": current,
                "router_result": route_models_from_features(current),
            }

        # If a report was uploaded without a specific active screening,
        # let the user choose the next step.
        
        # Ask which disease the user wants to screen for when the
        # request is generic and no screening is active.
        if (
            screening_intent
            and not ckd_intent
            and not diabetes_intent
            and not self.active_screening
        ):
            self.state.update(extracted)
            current = self.state.get_features()

            return {
                "message": text,
                "assistant_message": (
                    "Which would you like to check: diabetes risk or "
                    "chronic kidney disease (CKD) risk?"
                ),
                "extracted_features": extracted,
                "conversation_features": current,
                "router_result": route_models_from_features(current),
            }

        # Screening path: save the extracted values and run the router.
        for disease in ("diabetes", "ckd"):
            for feature in extracted[disease]:
                self.skipped_features[disease].discard(feature)

        self.state.update(extracted)
        current = self.state.get_features()
        router_result = route_models_from_features(current)

        preferred = self.active_screening

        if preferred is None:
            if ckd_intent and not diabetes_intent:
                preferred = "ckd"
            elif diabetes_intent and not ckd_intent:
                preferred = "diabetes"

        predictions = router_result.get("predictions", {})
        missing = router_result.get("missing_features", {})

        # Use a result only if the selected screening has a prediction.
        preferred_prediction = (
            predictions.get(preferred) if preferred else None
        )

        if preferred_prediction is not None:
            self.pending_question = None
            self.active_screening = None

            prediction = preferred_prediction.get("prediction")

            if preferred == "diabetes":
                positive_label = 1
                negative_label = 0

                if prediction == negative_label:
                    assistant_message = (
                        "Good news! Based on the information you shared, "
                        "your screening result does not indicate a high "
                        "likelihood of diabetes according to our AI model. "
                        "Keep up your healthy habits! This screening cannot "
                        "rule out diabetes completely. If you have symptoms "
                        "or concerns, please consult a healthcare professional."
                    )
                elif prediction == positive_label:
                    assistant_message = (
                        "Your screening result suggests that you may have "
                        "an increased likelihood of diabetes. Please don't "
                        "panic—this result does not mean you definitely have "
                        "diabetes. A healthcare professional can arrange "
                        "appropriate tests and help you understand your result."
                    )
                else:
                    assistant_message = (
                        "I couldn't interpret your diabetes screening result "
                        "reliably. Please consult a healthcare professional "
                        "for further evaluation."
                    )

            else:
                positive_label = "ckd"
                negative_label = "notckd"

                if prediction == negative_label:
                    assistant_message = (
                        "Based on the information you shared, your screening "
                        "result does not indicate a high likelihood of chronic "
                        "kidney disease according to our AI model. This is "
                        "reassuring, but the screening cannot rule out kidney "
                        "disease completely. Please consult a healthcare "
                        "professional if you have symptoms or concerns."
                    )
                elif prediction == positive_label:
                    assistant_message = (
                        "Your screening result suggests that you may have "
                        "an increased likelihood of chronic kidney disease. "
                        "This does not confirm that you have the condition. "
                        "Please arrange an appointment with a healthcare "
                        "professional for appropriate tests and further "
                        "evaluation."
                    )
                else:
                    assistant_message = (
                        "I couldn't interpret your kidney screening result "
                        "reliably. Please consult a healthcare professional "
                        "for further evaluation."
                    )

        elif preferred and missing.get(preferred):
            self.active_screening = preferred

            assistant_message = self.get_follow_up_message(
                router_result,
                preferred_screening=preferred,
            )

            assistant_message += (
                "\n\nThis screening is for informational purposes "
                "and is not a medical diagnosis."
            )

        elif preferred:
            self.active_screening = preferred
            self.pending_question = None
            assistant_message = (
                f"I've started your {preferred.upper()} screening, but "
                "couldn't determine the remaining required inputs. "
                "Please try again or check the model router response."
            )

        else:
            self.pending_question = None
            assistant_message = (
                "Your message has been received. Would you like to check "
                "diabetes risk or chronic kidney disease (CKD) risk?"
            )

        return {
            "message": text,
            "assistant_message": assistant_message,
            "extracted_features": extracted,
            "conversation_features": current,
            "router_result": router_result,
        }
