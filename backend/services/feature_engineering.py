def engineer_diabetes_features(data):
    """
    Reproduce the exact feature engineering used
    when the Diabetes model was trained.
    """

    data = data.copy()

    # 1. Age group
    age = data.get("age")

    if age is not None:
        if age <= 18:
            data["age_group"] = "0-18"
        elif age <= 30:
            data["age_group"] = "19-30"
        elif age <= 45:
            data["age_group"] = "31-45"
        elif age <= 60:
            data["age_group"] = "46-60"
        elif age <= 75:
            data["age_group"] = "61-75"
        else:
            data["age_group"] = "76+"

    # 2. BMI category
    bmi = data.get("bmi")

    if bmi is not None:
        if bmi <= 18.5:
            data["bmi_category"] = "Underweight"
        elif bmi <= 25:
            data["bmi_category"] = "Normal"
        elif bmi <= 30:
            data["bmi_category"] = "Overweight"
        else:
            data["bmi_category"] = "Obese"

    # 3. Glucose × HbA1c interaction
    glucose = data.get("blood_glucose_level")
    hba1c = data.get("HbA1c_level")

    if glucose is not None and hba1c is not None:
        data["glucose_hba1c_interaction"] = glucose * hba1c

    # 4. Combined cardiovascular indicator
    hypertension = data.get("hypertension")
    heart_disease = data.get("heart_disease")

    if hypertension is not None and heart_disease is not None:
        data["cardiovascular_risk"] = int(
            hypertension == 1 or heart_disease == 1
        )

    return data