# services/nlp_extractor.py

from transformers import pipeline
import re


# ============================================================
# LOAD MEDICAL NER MODEL ONCE
# ============================================================

medical_ner = pipeline(
    "token-classification",
    model="genzeonplatform/healthcare-brain-laboratory-ner",
    aggregation_strategy="simple"
)


# ============================================================
# 1. RAW MEDICAL ENTITY EXTRACTION
# ============================================================

def extract_medical_entities(text):
    """
    Run the medical NER model and return raw entities.
    """

    entities = medical_ner(text)

    results = []

    for entity in entities:
        results.append({
            "type": entity["entity_group"],
            "text": entity["word"],
            "score": float(entity["score"]),
            "start": entity["start"],
            "end": entity["end"]
        })

    return results


# ============================================================
# HELPER: EXTRACT NUMBER FROM ORIGINAL TEXT
# ============================================================

def extract_number_from_entity(text, entity):
    """
    Reconstruct a complete decimal number from the original text.

    Example:
        NER detects:
            7
            .
            2

        This function returns:
            7.2
    """

    start = entity["start"]

    remaining = text[start:]

    match = re.match(
        r"\s*(\d+(?:\.\d+)?)",
        remaining
    )

    if match:
        return float(match.group(1))

    return None


# ============================================================
# 2. NORMALIZE MEDICAL / NUMERICAL ENTITIES
# ============================================================

def normalize_entities(text):
    """
    Convert medical NER output into structured diabetes features.

    Extracts:
        - HbA1c
        - Blood glucose
        - BMI
        - Age
    """

    entities = extract_medical_entities(text)

    result = {}

    # ========================================================
    # 1. HbA1c
    # ========================================================

    for i, entity in enumerate(entities):

        if entity["type"] != "LAB_TEST_NAME":
            continue

        name = entity["text"].lower().replace(" ", "")

        if "hba1c" in name or name == "a1c":

            for next_entity in entities[i + 1:]:

                if next_entity["type"] == "LAB_VALUE":

                    value = extract_number_from_entity(
                        text,
                        next_entity
                    )

                    if value is not None:
                        result["HbA1c_level"] = value

                    break

                elif next_entity["type"] == "LAB_TEST_NAME":
                    break

    # ========================================================
    # 2. Blood Glucose
    # ========================================================

    glucose_terms = [
        "blood glucose",
        "fasting glucose",
        "glucose level",
        "blood sugar",
        "sugar level"
    ]

    for i, entity in enumerate(entities):

        if entity["type"] != "LAB_TEST_NAME":
            continue

        name = entity["text"].lower()

        if any(term in name for term in glucose_terms):

            for next_entity in entities[i + 1:]:

                if next_entity["type"] == "LAB_VALUE":

                    value = extract_number_from_entity(
                        text,
                        next_entity
                    )

                    if value is not None:
                        result["blood_glucose_level"] = value

                    break

                elif next_entity["type"] == "LAB_TEST_NAME":
                    break

    # ========================================================
    # 3. Blood Glucose Fallback
    # ========================================================

    if "blood_glucose_level" not in result:

        glucose_pattern = re.search(
            r"(?:"
            r"blood\s+sugar|"
            r"blood\s+glucose|"
            r"fasting\s+glucose|"
            r"glucose\s+level|"
            r"sugar\s+level"
            r")"
            r"\s*(?:is|was|of|around|at|came\s+back\s+at)?"
            r"\s*(\d+(?:\.\d+)?)",
            text,
            re.IGNORECASE
        )

        if glucose_pattern:

            result["blood_glucose_level"] = float(
                glucose_pattern.group(1)
            )

    # ========================================================
    # 4. BMI
    # ========================================================

    for i, entity in enumerate(entities):

        if entity["type"] != "LAB_TEST_NAME":
            continue

        name = entity["text"].lower().strip()

        if "bmi" in name or "body mass" in name:

            for next_entity in entities[i + 1:]:

                if next_entity["type"] == "LAB_VALUE":

                    value = extract_number_from_entity(
                        text,
                        next_entity
                    )

                    if value is not None:
                        result["bmi"] = value

                    break

                elif next_entity["type"] == "LAB_TEST_NAME":
                    break

    # ========================================================
    # 5. BMI Fallback
    # ========================================================

    if "bmi" not in result:

        bmi_pattern = re.search(
            r"(?:bmi|body\s+mass\s+index)"
            r"\s*(?:is|of|was|around|at)?"
            r"\s*(\d+(?:\.\d+)?)",
            text,
            re.IGNORECASE
        )

        if bmi_pattern:

            result["bmi"] = float(
                bmi_pattern.group(1)
            )

    # ========================================================
    # 6. AGE
    # ========================================================

    # Pattern 1:
    #
    # I am 45
    # I'm 45
    # I am 45 years old
    # I'm 45 yrs old

    age_pattern = re.search(
        r"\b(?:i\s+am|i'm|im)\s+(\d{1,3})"
        r"(?:\s+(?:years?|yrs?)\s*(?:old)?)?\b",
        text,
        re.IGNORECASE
    )

    # Pattern 2:
    #
    # Patient is aged 61
    # aged 61

    age_pattern_2 = re.search(
        r"\b(?:patient\s+is\s+)?aged\s+(\d{1,3})\b",
        text,
        re.IGNORECASE
    )

    # Pattern 3:
    #
    # 45 years old
    # 45 yrs old

    age_pattern_3 = re.search(
        r"\b(\d{1,3})\s+(?:years?|yrs?)\s+old\b",
        text,
        re.IGNORECASE
    )

    if age_pattern:

        result["age"] = float(
            age_pattern.group(1)
        )

    elif age_pattern_2:

        result["age"] = float(
            age_pattern_2.group(1)
        )

    elif age_pattern_3:

        result["age"] = float(
            age_pattern_3.group(1)
        )

    return result


def extract_ckd_numeric_features(text):
    """
    Extract numerical CKD-related features from natural-language text.

    CKD dataset feature mapping:
        bp  -> blood pressure
        sg  -> specific gravity
        al  -> albumin
        su  -> sugar
        bgr -> blood glucose random
        bu  -> blood urea
        sc  -> serum creatinine
        sod -> sodium
        pot -> potassium
        hemo -> hemoglobin
        pcv -> packed cell volume
        wc  -> white blood cell count
        rc  -> red blood cell count
        age -> age
    """

    result = {}
    text_lower = text.lower()

    # Handle curly apostrophes just in case
    text_lower = text_lower.replace("’", "'")

    # --------------------------------------------------
    # AGE
    # --------------------------------------------------

    age_patterns = [
        r"\bi\s*(?:am|'m)\s+(\d{1,3})\s*(?:years?|yrs?)?(?:\s*old)?\b",
        r"\b(?:patient\s+is\s+)?aged\s+(\d{1,3})\b",
        r"\b(\d{1,3})\s*(?:years?|yrs?)\s*old\b",
        r"\bage\s*(?:is|:|=)?\s*(\d{1,3})\b"
    ]

    for pattern in age_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["age"] = float(match.group(1))
            break

    # --------------------------------------------------
    # BLOOD PRESSURE -> bp
    # --------------------------------------------------

    bp_patterns = [
        r"\bblood\s+pressure\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bbp\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in bp_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["bp"] = float(match.group(1))
            break

    # --------------------------------------------------
    # SPECIFIC GRAVITY -> sg
    # --------------------------------------------------

    sg_patterns = [
        r"\bspecific\s+gravity\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bsg\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in sg_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["sg"] = float(match.group(1))
            break

    # --------------------------------------------------
    # ALBUMIN -> al
    # --------------------------------------------------

    al_patterns = [
        r"\balbumin\s*(?:level\s*)?(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bal\s*(?:level\s*)?(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in al_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["al"] = float(match.group(1))
            break

    # --------------------------------------------------
    # SUGAR -> su
    # --------------------------------------------------

    su_patterns = [
        r"\burine\s+sugar\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bsugar\s*(?:in\s+urine)?\s*(?:is|was|of|around|at|:|=)\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in su_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["su"] = float(match.group(1))
            break

    # --------------------------------------------------
    # RANDOM BLOOD GLUCOSE -> bgr
    # --------------------------------------------------

    bgr_patterns = [
        r"\brandom\s+blood\s+glucose\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\brandom\s+glucose\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bbgr\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in bgr_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["bgr"] = float(match.group(1))
            break

    # --------------------------------------------------
    # BLOOD UREA -> bu
    # --------------------------------------------------

    bu_patterns = [
        r"\bblood\s+urea\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\burea\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bbu\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in bu_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["bu"] = float(match.group(1))
            break

    # --------------------------------------------------
    # SERUM CREATININE -> sc
    # --------------------------------------------------

    sc_patterns = [
        r"\bserum\s+creatinine\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bcreatinine\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bsc\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in sc_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["sc"] = float(match.group(1))
            break

    # --------------------------------------------------
    # SODIUM -> sod
    # --------------------------------------------------

    sod_patterns = [
        r"\bsodium\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bsod\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in sod_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["sod"] = float(match.group(1))
            break

    # --------------------------------------------------
    # POTASSIUM -> pot
    # --------------------------------------------------

    pot_patterns = [
        r"\bpotassium\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bpot\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in pot_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["pot"] = float(match.group(1))
            break

    # --------------------------------------------------
    # HEMOGLOBIN -> hemo
    # --------------------------------------------------

    hemo_patterns = [
        r"\bhemoglobin\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bhaemoglobin\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bhemo\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in hemo_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["hemo"] = float(match.group(1))
            break

    # --------------------------------------------------
    # PACKED CELL VOLUME -> pcv
    # --------------------------------------------------

    pcv_patterns = [
        r"\bpacked\s+cell\s+volume\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bpcv\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in pcv_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["pcv"] = float(match.group(1))
            break

    # --------------------------------------------------
    # WHITE BLOOD CELL COUNT -> wc
    # --------------------------------------------------

    wc_patterns = [
        r"\bwhite\s+blood\s+cell\s+(?:count\s*)?(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bwhite\s+cell\s+count\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bwbc\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bwc\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in wc_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["wc"] = float(match.group(1))
            break

    # --------------------------------------------------
    # RED BLOOD CELL COUNT -> rc
    # --------------------------------------------------

    rc_patterns = [
        r"\bred\s+blood\s+cell\s+(?:count\s*)?(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\bred\s+cell\s+count\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\brbc\s*(?:count\s*)?(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)",
        r"\brc\s*(?:is|was|of|around|at|:|=)?\s*(\d+(?:\.\d+)?)"
    ]

    for pattern in rc_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["rc"] = float(match.group(1))
            break

    return result

def extract_ckd_urine_features(text):
    """
    Extract CKD urine-related categorical features.

    Dataset mappings:
        rbc  -> normal / abnormal
        pc   -> normal / abnormal
        pcc  -> present / notpresent
        ba   -> present / notpresent
    """

    result = {}

    text_lower = text.lower()
    text_lower = text_lower.replace("’", "'")

    # ==========================================
    # 1. RED BLOOD CELLS (rbc)
    # ==========================================

    rbc_abnormal = re.search(
        r"\b("
        r"abnormal\s+(?:urine\s+)?red\s+blood\s+cells?|"
        r"red\s+blood\s+cells?\s+(?:are\s+)?abnormal|"
        r"rbc\s+(?:is|are)?\s*abnormal"
        r")\b",
        text_lower
    )

    rbc_normal = re.search(
        r"\b("
        r"normal\s+(?:urine\s+)?red\s+blood\s+cells?|"
        r"red\s+blood\s+cells?\s+(?:are\s+)?normal|"
        r"rbc\s+(?:is|are)?\s*normal"
        r")\b",
        text_lower
    )

    if rbc_abnormal:
        result["rbc"] = "abnormal"
    elif rbc_normal:
        result["rbc"] = "normal"

    # ==========================================
    # 2. PUS CELLS (pc)
    # ==========================================

    pc_abnormal = re.search(
        r"\b("
        r"abnormal\s+pus\s+cells?|"
        r"pus\s+cells?\s+(?:are\s+)?abnormal|"
        r"pc\s+(?:is|are)?\s*abnormal"
        r")\b",
        text_lower
    )

    pc_normal = re.search(
        r"\b("
        r"normal\s+pus\s+cells?|"
        r"pus\s+cells?\s+(?:are\s+)?normal|"
        r"pc\s+(?:is|are)?\s*normal"
        r")\b",
        text_lower
    )

    if pc_abnormal:
        result["pc"] = "abnormal"
    elif pc_normal:
        result["pc"] = "normal"

    # ==========================================
    # 3. PUS CELL CLUMPS (pcc)
    # ==========================================

    pcc_present = re.search(
        r"\b("
        r"pus\s+cell\s+clumps?\s+(?:are\s+)?present|"
        r"pus\s+cell\s+clumps?\s+detected|"
        r"pcc\s+(?:is|are)?\s*present"
        r")\b",
        text_lower
    )

    pcc_notpresent = re.search(
        r"\b("
        r"no\s+pus\s+cell\s+clumps?|"
        r"pus\s+cell\s+clumps?\s+(?:are\s+)?(?:absent|not\s+present)|"
        r"pcc\s+(?:is|are)?\s*(?:absent|not\s+present|notpresent)"
        r")\b",
        text_lower
    )

    if pcc_present:
        result["pcc"] = "present"
    elif pcc_notpresent:
        result["pcc"] = "notpresent"

    # ==========================================
    # 4. BACTERIA (ba)
    # ==========================================

    bacteria_present = re.search(
        r"\b("
        r"bacteria\s+(?:are\s+)?present|"
        r"bacteria\s+detected|"
        r"ba\s+(?:is|are)?\s*present"
        r")\b",
        text_lower
    )

    bacteria_notpresent = re.search(
        r"\b("
        r"no\s+(?:urine\s+)?bacteria|"
        r"there\s+are\s+no\s+(?:urine\s+)?bacteria|"
        r"there\s+is\s+no\s+(?:urine\s+)?bacteria|"
        r"no\s+bacteria|"
        r"bacteria\s+(?:are\s+)?(?:absent|not\s+present)|"
        r"ba\s+(?:is|are)?\s*(?:absent|not\s+present|notpresent)"
        r")\b",
        text_lower
    )

    if bacteria_present:
        result["ba"] = "present"
    elif bacteria_notpresent:
        result["ba"] = "notpresent"

    return result


def extract_ckd_medical_features(text):
    """Extract CKD medical conditions: htn, dm, cad."""

    text_lower = text.lower().replace("’", "'")
    result = {}

    # Detect a shared negative statement:
    # "I do not have hypertension, diabetes, or coronary artery disease."
    shared_negative = re.search(
        r"\b(?:i\s+)?(?:do\s+not|don't)\s+have\s+(.+?)(?:[.!?]|$)",
        text_lower
    )

    denied = shared_negative.group(1) if shared_negative else ""

    # Hypertension
    if re.search(
        r"\b(no hypertension|no high blood pressure|"
        r"do not have hypertension|don't have hypertension|"
        r"without hypertension)\b", text_lower
    ) or re.search(r"\bhypertension\b", denied):
        result["htn"] = "no"
    elif re.search(
        r"\b(have hypertension|has hypertension|"
        r"history of hypertension|diagnosed with hypertension)\b",
        text_lower
    ):
        result["htn"] = "yes"

    # Diabetes
    if re.search(r"\bdiabetes(?: mellitus)?\b", denied) or re.search(
        r"\b(no diabetes|no history of diabetes|"
        r"do not have diabetes|don't have diabetes|"
        r"without diabetes)\b", text_lower
    ):
        result["dm"] = "no"
    elif re.search(
        r"\b(have diabetes|has diabetes|history of diabetes|diabetic)\b",
        text_lower
    ):
        result["dm"] = "yes"

    # Coronary artery disease
    if re.search(r"\b(coronary artery disease|cad)\b", denied) or re.search(
        r"\b(no coronary artery disease|no cad|"
        r"do not have coronary artery disease|"
        r"don't have coronary artery disease|without coronary artery disease)\b",
        text_lower
    ):
        result["cad"] = "no"
    elif re.search(
        r"\b(have coronary artery disease|"
        r"has coronary artery disease|history of coronary artery disease)\b",
        text_lower
    ):
        result["cad"] = "yes"

    return result


def extract_ckd_condition_features(text):
    """Extract appetite, pedal edema, and anemia features."""

    text_lower = text.lower().replace("’", "'")
    result = {}

    shared_negative = re.search(
        r"\b(?:i\s+)?(?:do\s+not|don't)\s+have\s+(.+?)(?:[.!?]|$)",
        text_lower
    )
    denied = shared_negative.group(1) if shared_negative else ""

    # Appetite
    if re.search(
        r"\b(poor appetite|low appetite|reduced appetite|"
        r"loss of appetite|no appetite|decreased appetite)\b",
        text_lower
    ):
        result["appet"] = "poor"
    elif re.search(
        r"\b(good appetite|normal appetite|healthy appetite|"
        r"my appetite is good|my appetite is normal|appetite is good)\b",
        text_lower
    ):
        result["appet"] = "good"

    # Pedal edema / oedema
    if re.search(r"\b(pedal\s+)?(edema|oedema)\b", denied):
        result["pe"] = "no"
    elif re.search(
        r"\b(no edema|no oedema|no pedal edema|no pedal oedema|"
        r"do not have edema|don't have edema|"
        r"do not have pedal edema|don't have pedal edema)\b",
        text_lower
    ):
        result["pe"] = "no"
    elif re.search(
        r"\b(pedal edema|pedal oedema|have edema|have oedema|"
        r"leg swelling|swelling in my feet|swollen feet|"
        r"swollen legs|swollen ankles)\b",
        text_lower
    ):
        result["pe"] = "yes"

    # Anemia / anaemia
    if re.search(r"\b(anemia|anaemia|anemic|anaemic)\b", denied) or re.search(
        r"\b(no anemia|no anaemia|without anemia|without anaemia|"
        r"not anemic|not anaemic|do not have anemia|"
        r"don't have anemia|do not have anaemia|don't have anaemia)\b",
        text_lower
    ):
        result["ane"] = "no"
    elif re.search(
        r"\b(have anemia|have anaemia|has anemia|has anaemia|"
        r"history of anemia|history of anaemia|anemic|anaemic)\b",
        text_lower
    ):
        result["ane"] = "yes"

    return result


# ============================================================
# 3. CATEGORICAL + BINARY FEATURE EXTRACTION
# ============================================================

def extract_categorical_features(text):
    """
    Extract categorical and binary diabetes features.

    Extracts:
        - gender
        - hypertension
        - heart disease
        - smoking history
    """

    result = {}

    # Normalize text
    text_lower = text.lower()

    # Convert curly apostrophe to normal apostrophe.
    #
    # Example:
    # don't → don't
    # don’t → don't

    text_lower = text_lower.replace("’", "'")

    # ========================================================
    # 1. GENDER
    # ========================================================

    if re.search(
        r"\b(female|woman|women)\b",
        text_lower
    ):
        result["gender"] = "Female"

    elif re.search(
        r"\b(male|man|men)\b",
        text_lower
    ):
        result["gender"] = "Male"

    
    # ========================================================
    # 2. HYPERTENSION
    # ========================================================

    hypertension_negative = re.search(
        r"\b(?:"
        r"no\s+(?:history\s+of\s+)?hypertension|"
        r"no\s+(?:history\s+of\s+)?high\s+blood\s+pressure|"
        r"do\s+not\s+have\s+(?:hypertension|high\s+blood\s+pressure)|"
        r"don't\s+have\s+(?:hypertension|high\s+blood\s+pressure)|"
        r"have\s+not\s+been\s+diagnosed\s+with\s+(?:hypertension|high\s+blood\s+pressure)|"
        r"haven't\s+been\s+diagnosed\s+with\s+(?:hypertension|high\s+blood\s+pressure)|"
        r"not\s+diagnosed\s+with\s+(?:hypertension|high\s+blood\s+pressure)|"
        r"without\s+(?:hypertension|high\s+blood\s+pressure)"
        r")\b",
        text_lower
    )

    hypertension_positive = re.search(
        r"\b(?:"
        r"have\s+hypertension|"
        r"has\s+hypertension|"
        r"history\s+of\s+hypertension|"
        r"have\s+high\s+blood\s+pressure|"
        r"has\s+high\s+blood\s+pressure|"
        r"diagnosed\s+with\s+hypertension|"
        r"diagnosed\s+with\s+high\s+blood\s+pressure"
        r")\b",
        text_lower
    )

    if hypertension_negative:
        result["hypertension"] = 0
    elif hypertension_positive:
        result["hypertension"] = 1


    
    # ========================================================
    # 3. HEART DISEASE
    # ========================================================

    heart_negative = re.search(
        r"\b(?:"
        r"no\s+(?:history\s+of\s+)?heart\s+disease|"
        r"do\s+not\s+have\s+(?:a\s+)?heart\s+disease|"
        r"don't\s+have\s+(?:a\s+)?heart\s+disease|"
        r"have\s+not\s+been\s+diagnosed\s+with\s+heart\s+disease|"
        r"haven't\s+been\s+diagnosed\s+with\s+heart\s+disease|"
        r"not\s+diagnosed\s+with\s+heart\s+disease|"
        r"without\s+heart\s+disease"
        r")\b",
        text_lower
    )

    heart_positive = re.search(
        r"\b(?:"
        r"have\s+(?:a\s+)?heart\s+disease|"
        r"has\s+(?:a\s+)?heart\s+disease|"
        r"history\s+of\s+heart\s+disease|"
        r"diagnosed\s+with\s+heart\s+disease"
        r")\b",
        text_lower
    )

    if heart_negative:
        result["heart_disease"] = 0
    elif heart_positive:
        result["heart_disease"] = 1


    # ========================================================
    # 4. SMOKING HISTORY
    # ========================================================

    # --------------------------------------------------------
    # Never smoked
    # --------------------------------------------------------

    if re.search(
        r"\b("
        r"never smoked|"
        r"never smoke|"
        r"have never smoked"
        r")\b",
        text_lower
    ):

        result["smoking_history"] = "never"

    # --------------------------------------------------------
    # Former smoker
    # --------------------------------------------------------

    elif re.search(
        r"\b("
        r"used to smoke|"
        r"used to be a smoker|"
        r"quit smoking|"
        r"stopped smoking|"
        r"smoked before"
        r")\b",
        text_lower
    ):

        result["smoking_history"] = "former"

    # --------------------------------------------------------
    # Not currently smoking
    # --------------------------------------------------------

    elif re.search(
        r"\b("
        r"don't smoke anymore|"
        r"do not smoke anymore|"
        r"not smoking anymore|"
        r"no longer smoke|"
        r"don't smoke now|"
        r"do not smoke now"
        r")\b",
        text_lower
    ):

        result["smoking_history"] = "not current"

    # --------------------------------------------------------
    # Currently smoking
    # --------------------------------------------------------

    elif re.search(
        r"\b("
        r"currently smoke|"
        r"currently smoking|"
        r"i smoke|"
        r"i am a smoker|"
        r"i'm a smoker"
        r")\b",
        text_lower
    ):

        result["smoking_history"] = "current"

    # --------------------------------------------------------
    # IMPORTANT:
    #
    # "I don't smoke" is intentionally NOT classified.
    #
    # It could mean:
    #   - never smoked
    #   - used to smoke
    #
    # Therefore we leave it missing rather than guessing.
    # --------------------------------------------------------

    return result


# ============================================================
# 4. COMBINED EXTRACTION
# ============================================================

def extract_diabetes_features(text):
    """
    Run both numerical/medical extraction and
    categorical extraction.

    Returns one combined dictionary.
    """

    numerical_features = normalize_entities(text)

    categorical_features = extract_categorical_features(text)

    result = {}

    result.update(numerical_features)
    result.update(categorical_features)

    return result

def extract_ckd_features(text):
    """
    Extract all CKD features from natural-language input.

    Combines:
        - Numeric CKD features
        - Urine findings
        - Medical conditions
        - Other categorical conditions
    """

    result = {}

    # 1. Numeric features
    result.update(
        extract_ckd_numeric_features(text)
    )

    # 2. Urine features
    result.update(
        extract_ckd_urine_features(text)
    )

    # 3. Medical conditions
    result.update(
        extract_ckd_medical_features(text)
    )

    # 4. Other categorical conditions
    result.update(
        extract_ckd_condition_features(text)
    )

    return result