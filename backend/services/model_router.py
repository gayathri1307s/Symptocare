import os
import joblib
import pandas as pd

from services.nlp_extractor import (
    extract_diabetes_features,
    extract_ckd_features,
)
from services.feature_engineering import engineer_diabetes_features


BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

diabetes_model = joblib.load(
    os.path.join(BASE_DIR, "models", "diabetes_model.pkl")
)

ckd_model = joblib.load(
    os.path.join(BASE_DIR, "models", "ckd_model.pkl")
)


DIABETES_REQUIRED_FEATURES = [
    "age",
    "hypertension",
    "heart_disease",
    "bmi",
    "HbA1c_level",
    "blood_glucose_level",
    "gender",
    "smoking_history",
]

DIABETES_ENGINEERED_FEATURES = [
    "age",
    "hypertension",
    "heart_disease",
    "bmi",
    "HbA1c_level",
    "blood_glucose_level",
    "gender",
    "smoking_history",
    "age_group",
    "bmi_category",
    "glucose_hba1c_interaction",
    "cardiovascular_risk",
]

CKD_REQUIRED_FEATURES = [
    "age", "bp", "sg", "al", "su", "bgr", "bu", "sc",
    "sod", "pot", "hemo", "pcv", "wc", "rc",
    "rbc", "pc", "pcc", "ba", "htn", "dm", "cad",
    "appet", "pe", "ane",
]


def get_missing_features(data, required_features):
    return [
        feature
        for feature in required_features
        if feature not in data or data[feature] is None or data[feature] == ""
    ]


def prepare_diabetes_input(features):
    missing = get_missing_features(
        features, DIABETES_REQUIRED_FEATURES
    )

    if missing:
        return None, missing

    engineered = engineer_diabetes_features(features)

    missing_engineered = get_missing_features(
        engineered, DIABETES_ENGINEERED_FEATURES
    )

    if missing_engineered:
        return None, missing_engineered

    data = {
        key: engineered[key]
        for key in DIABETES_ENGINEERED_FEATURES
    }

    return pd.DataFrame([data]), []


def prepare_ckd_input(features):
    missing = get_missing_features(
        features, CKD_REQUIRED_FEATURES
    )

    if missing:
        return None, missing

    data = {
        key: features[key]
        for key in CKD_REQUIRED_FEATURES
    }

    return pd.DataFrame([data]), []


def predict_diabetes(features):
    data, missing = prepare_diabetes_input(features)

    if data is None:
        return {
            "status": "insufficient_data",
            "missing_features": missing,
        }

    prediction = diabetes_model.predict(data)[0]

    result = {
        "status": "prediction_available",
        "prediction": int(prediction),
    }

    if hasattr(diabetes_model, "predict_proba"):
        probabilities = diabetes_model.predict_proba(data)[0]

        result["probability"] = {
            str(label): round(float(probability), 4)
            for label, probability in zip(
                diabetes_model.classes_, probabilities
            )
        }

    return result


def predict_ckd(features):
    data, missing = prepare_ckd_input(features)

    if data is None:
        return {
            "status": "insufficient_data",
            "missing_features": missing,
        }

    prediction = ckd_model.predict(data)[0]

    result = {
        "status": "prediction_available",
        "prediction": str(prediction),
    }

    if hasattr(ckd_model, "predict_proba"):
        probabilities = ckd_model.predict_proba(data)[0]

        result["probability"] = {
            str(label): round(float(probability), 4)
            for label, probability in zip(
                ckd_model.classes_, probabilities
            )
        }

    return result


def route_models_from_features(features):
    diabetes_features = dict(features.get("diabetes", {}))
    ckd_features = dict(features.get("ckd", {}))

    diabetes_missing = get_missing_features(
        diabetes_features, DIABETES_REQUIRED_FEATURES
    )

    ckd_missing = get_missing_features(
        ckd_features, CKD_REQUIRED_FEATURES
    )

    predictions = {}

    if not diabetes_missing:
        predictions["diabetes"] = predict_diabetes(
            diabetes_features
        )

    if not ckd_missing:
        predictions["ckd"] = predict_ckd(ckd_features)

    return {
        "status": (
            "prediction_available"
            if predictions
            else "insufficient_data"
        ),
        "extracted_features": {
            "diabetes": diabetes_features,
            "ckd": ckd_features,
        },
        "missing_features": {
            "diabetes": diabetes_missing,
            "ckd": ckd_missing,
        },
        "predictions": predictions,
    }


def route_models(text):
    features = {
        "diabetes": extract_diabetes_features(text),
        "ckd": extract_ckd_features(text),
    }

    return route_models_from_features(features)