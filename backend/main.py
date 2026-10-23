from pydantic import BaseModel, Field
from fastapi import (
    FastAPI,
    UploadFile,
    File,
    HTTPException,
    Form,
    Header,
)
from services.report_service import extract_text_from_report
from services.medical_value_extractor import extract_medical_values
from services.chat_service import ChatService
from services.model_router import (
    predict_diabetes as run_diabetes_prediction,
    predict_ckd as run_ckd_prediction,
)
from services.firebase_admin_service import (
    verify_firebase_token,
    get_user_profile,
)

app = FastAPI(title="SymptoCare API")

# Temporary in-memory conversations
chat_sessions = {}

def get_authenticated_user(authorization: str | None) -> str:
    """Verify the Firebase ID token and return the authenticated UID."""

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Authentication required. Please sign in again.",
        )

    id_token = authorization.split(" ", 1)[1].strip()

    if not id_token:
        raise HTTPException(
            status_code=401,
            detail="Missing Firebase ID token.",
        )

    try:
        decoded_token = verify_firebase_token(id_token)
        uid = decoded_token.get("uid")

        if not uid:
            raise HTTPException(
                status_code=401,
                detail="Invalid authentication token.",
            )

        return uid

    except Exception as e:
        print(
            f"Firebase token verification failed: "
            f"{type(e).__name__}: {e}",
            flush=True,
        )
        raise HTTPException(
            status_code=401,
            detail="Your session could not be verified. Please sign in again.",
        )

    
def build_profile_context(uid: str) -> str:
    """Load this user's saved profile and format it for the chatbot."""

    try:
        profile = get_user_profile(uid)
    except Exception as e:
        print(f"Firebase token verification failed: {type(e).__name__}: {e}")
        raise HTTPException(
            status_code=401,
            detail="Your session could not be verified. Please sign in again.",
        )

    personal = profile.get("personal_details", {})
    health = profile.get("health_profile", {})

    fields = {
        "Name": personal.get("name"),
        "Age": personal.get("age"),
        "Gender": personal.get("gender"),
        "Height (cm)": health.get("heightCm"),
        "Weight (kg)": health.get("weightKg"),
        "Blood group": health.get("bloodGroup"),
        "Allergies": health.get("allergies"),
        "Existing conditions": health.get("conditions"),
        "Medications": health.get("medications"),
    }

    lines = [
        f"{label}: {value}"
        for label, value in fields.items()
        if value is not None and value != "" and value != []
    ]

    if not lines:
        return "No saved personal or health profile details are available."

    return "Saved profile details (use only when relevant):\n" + "\n".join(lines)


class DiabetesInput(BaseModel):
    gender: str
    age: float = Field(gt=0, le=120)
    hypertension: int = Field(ge=0, le=1)
    heart_disease: int = Field(ge=0, le=1)
    smoking_history: str
    bmi: float = Field(gt=0, le=100)
    HbA1c_level: float = Field(gt=0, le=30)
    blood_glucose_level: float = Field(gt=0, le=1000)


class CKDInput(BaseModel):
    age: float
    bp: float
    sg: float
    al: float
    su: float
    rbc: str
    pc: str
    pcc: str
    ba: str
    bgr: float
    bu: float
    sc: float
    sod: float
    pot: float
    hemo: float
    pcv: float
    wc: float
    rc: float
    htn: str
    dm: str
    cad: str
    appet: str
    pe: str
    ane: str



class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=5000)
    conversation_id: str = "demo"
    medical_values: dict | None = None


class ResetRequest(BaseModel):
    conversation_id: str = "demo"


@app.get("/")
def home():
    return {
        "status": "ok",
        "message": "SymptoCare API is running",
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict/diabetes")
def predict_diabetes(data: DiabetesInput):
    result = run_diabetes_prediction(data.model_dump())

    if result["status"] == "insufficient_data":
        return result

    probabilities = result.get("probability", {})

    return {
        "disease": "Diabetes",
        "prediction": result["prediction"],
        "probability": probabilities.get("1"),
        "probabilities": probabilities,
    }


@app.post("/predict/ckd")
def predict_ckd(data: CKDInput):
    result = run_ckd_prediction(data.model_dump())

    if result["status"] == "insufficient_data":
        return result

    return {
        "disease": "CKD",
        "prediction": result["prediction"],
        "probability": result.get("probability", {}),
    }



@app.post("/chat")
def chat(
    request: ChatRequest,
    authorization: str | None = Header(default=None),
):
    uid = get_authenticated_user(authorization)
    conversation_id = request.conversation_id.strip()

    if not conversation_id:
        raise HTTPException(
            status_code=400,
            detail="conversation_id cannot be empty.",
        )

    # Keep each user's conversations separate.
    session_key = f"{uid}:{conversation_id}"

    if session_key not in chat_sessions:
        chat_sessions[session_key] = ChatService()

    service = chat_sessions[session_key]
    profile_context = build_profile_context(uid)

    result = service.process_message(
        request.message,
        medical_values=request.medical_values,
        profile_context=profile_context,
    )

    result["conversation_id"] = conversation_id
    return result


@app.post("/chat/reset")
def reset_chat(
    request: ResetRequest,
    authorization: str | None = Header(default=None),
):
    uid = get_authenticated_user(authorization)
    conversation_id = request.conversation_id.strip()

    if not conversation_id:
        raise HTTPException(
            status_code=400,
            detail="conversation_id cannot be empty.",
        )

    session_key = f"{uid}:{conversation_id}"
    chat_sessions[session_key] = ChatService()

    return {
        "status": "success",
        "message": "Conversation reset successfully.",
        "conversation_id": conversation_id,
    }

@app.post("/reports/extract")
async def extract_report(file: UploadFile = File(...)):
    filename = file.filename or ""
    extension = "." + filename.rsplit(".", 1)[-1].lower()

    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg"}

    try:
        if extension not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail="Upload a PDF, PNG, or JPG report.",
            )

        file_bytes = await file.read(10 * 1024 * 1024 + 1)

        if not file_bytes:
            raise HTTPException(
                status_code=400,
                detail="The uploaded file is empty.",
            )

        if len(file_bytes) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=413,
                detail="File too large. Maximum size is 10 MB.",
            )

        result = extract_text_from_report(file_bytes, filename)
        medical_values = extract_medical_values(
            result.get("extracted_text", "")
        )

        return {
            "status": "success",
            **result,
            "medical_values": medical_values,
        }

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc

    finally:
        await file.close()


@app.post("/chat/with-report")
async def chat_with_report(
    message: str = Form(...),
    conversation_id: str = Form("demo"),
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
):
    uid = get_authenticated_user(authorization)

    conversation_id = conversation_id.strip()
    message = message.strip()

    if not conversation_id:
        raise HTTPException(
            status_code=400,
            detail="conversation_id cannot be empty.",
        )

    if not message:
        raise HTTPException(
            status_code=400,
            detail="Please enter a message with your report.",
        )

    session_key = f"{uid}:{conversation_id}"
    profile_context = build_profile_context(uid)

    filename = file.filename or ""
    extension = "." + filename.rsplit(".", 1)[-1].lower()

    if extension not in {".pdf", ".png", ".jpg", ".jpeg"}:
        raise HTTPException(
            status_code=400,
            detail="Upload a PDF, PNG, or JPG report.",
        )

    try:
        file_bytes = await file.read(10 * 1024 * 1024 + 1)

        if not file_bytes:
            raise HTTPException(
                status_code=400,
                detail="The uploaded file is empty.",
            )

        if len(file_bytes) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=413,
                detail="File too large. Maximum size is 10 MB.",
            )

        report = extract_text_from_report(file_bytes, filename)
        medical_values = extract_medical_values(
            report.get("extracted_text", "")
        )

        if session_key not in chat_sessions:
            chat_sessions[session_key] = ChatService()

        result = chat_sessions[session_key].process_message(
            message,
            medical_values=medical_values,
            report_text=report.get("extracted_text", ""),
            report_filename=filename,
            profile_context=profile_context,
        )

        result["conversation_id"] = conversation_id
        result["report"] = {
            "filename": filename,
            "extraction_method": report.get("extraction_method"),
            "medical_values": medical_values,
        }

        return result

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc

    finally:
        await file.close()
