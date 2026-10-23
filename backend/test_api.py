
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_home_endpoint():
    response = client.get("/")
    assert response.status_code == 200


def test_chat_rejects_empty_conversation_id():
    response = client.post(
        "/chat",
        json={
            "message": "I want to check my diabetes risk",
            "conversation_id": "   "
        }
    )
    assert response.status_code == 400


def test_chat_starts_conversation():
    conversation_id = "pytest-new-chat"

    client.post("/chat/reset", params={
        "conversation_id": conversation_id
    })

    response = client.post(
        "/chat",
        json={
            "message": "I want to check my diabetes risk",
            "conversation_id": conversation_id
        }
    )

    assert response.status_code == 200
    data = response.json()
    assert data["conversation_id"] == conversation_id
    assert data.get("message") or data.get("assistant_message")


def test_chat_reset_endpoint():
    response = client.post(
        "/chat/reset",
        params={"conversation_id": "pytest-reset"}
    )

    assert response.status_code == 200
    assert response.json()["status"] == "success"
    assert response.json()["conversation_id"] == "pytest-reset"
def test_report_upload_rejects_unsupported_file():
    response = client.post(
        "/reports/extract",
        files={"file": ("report.txt", b"test content", "text/plain")},
    )
    assert response.status_code == 400


def test_report_upload_rejects_file_over_10mb():
    oversized_content = b"x" * (10 * 1024 * 1024 + 1)

    response = client.post(
        "/reports/extract",
        files={"file": ("report.pdf", oversized_content, "application/pdf")},
    )

    assert response.status_code == 413
def test_chat_with_report_upload():
    conversation_id = "pytest-report-chat"

    response = client.post(
        "/chat/with-report",
        data={
            "message": "Please explain my glucose results",
            "conversation_id": conversation_id,
        },
        files={
            "file": (
                "report.pdf",
                b"not a real pdf",
                "application/pdf",
            )
        },
    )

    assert response.status_code == 422
def test_chat_with_valid_report():
    with open("Z131.pdf", "rb") as report:
        response = client.post(
            "/chat/with-report",
            data={
                "message": "Please explain my glucose results",
                "conversation_id": "pytest-valid-report",
            },
            files={
                "file": (
                    "Z131.pdf",
                    report,
                    "application/pdf",
                )
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["conversation_id"] == "pytest-valid-report"
    assert "report" in data
    assert data["report"]["medical_values"]["fasting_glucose"]["value"] == 120.0
def test_chat_sessions_are_isolated():
    from main import chat_sessions

    id_a = "pytest-isolation-a"
    id_b = "pytest-isolation-b"

    client.post("/chat/reset", params={"conversation_id": id_a})
    client.post("/chat/reset", params={"conversation_id": id_b})

    assert chat_sessions[id_a] is not chat_sessions[id_b]
def test_chat_reset_creates_fresh_session():
    from main import chat_sessions

    conversation_id = "pytest-reset-fresh"

    client.post("/chat/reset", params={"conversation_id": conversation_id})
    old_session = chat_sessions[conversation_id]

    response = client.post(
        "/chat/reset",
        params={"conversation_id": conversation_id},
    )

    assert response.status_code == 200
    assert chat_sessions[conversation_id] is not old_session
