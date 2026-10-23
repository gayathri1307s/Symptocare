
import firebase_admin
from firebase_admin import credentials, firestore, auth


def initialize_firebase():
    """Initialize Firebase Admin once per backend process."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(
            credentials.ApplicationDefault(),
            options={
                "projectId": "symptocare-ca67a",
            },
        )


def get_firestore_client():
    """Return the Firestore client."""
    initialize_firebase()
    return firestore.client()


def verify_firebase_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return its decoded claims."""
    initialize_firebase()
    return auth.verify_id_token(id_token)


def get_user_profile(uid: str) -> dict:
    """Read the authenticated user's saved profile documents."""
    db = get_firestore_client()

    personal_doc = (
        db.collection("users")
        .document(uid)
        .collection("personalDetails")
        .document("profile")
        .get()
    )

    health_doc = (
        db.collection("users")
        .document(uid)
        .collection("healthProfile")
        .document("profile")
        .get()
    )

    return {
        "personal_details": (
            personal_doc.to_dict() if personal_doc.exists else {}
        ),
        "health_profile": (
            health_doc.to_dict() if health_doc.exists else {}
        ),
    }
