
from services.conversation import ConversationState
from unittest.mock import patch
from services.chat_service import ChatService
def test_conversation_state_starts_empty():
    state = ConversationState()
    features = state.get_features()

    assert features == {
        "diabetes": {},
        "ckd": {},
    }


def test_conversation_state_saves_features():
    state = ConversationState()

    state.update({
        "diabetes": {
            "age": 45,
            "hypertension": 0,
        }
    })

    features = state.get_features()

    assert features["diabetes"]["age"] == 45
    assert features["diabetes"]["hypertension"] == 0


def test_conversation_state_preserves_previous_features():
    state = ConversationState()

    state.update({"diabetes": {"age": 45}})
    state.update({"diabetes": {"hypertension": 0}})

    features = state.get_features()

    assert features["diabetes"] == {
        "age": 45,
        "hypertension": 0,
    }


def test_conversation_state_clear():
    state = ConversationState()
    state.update({"diabetes": {"age": 45}})

    state.clear()

    assert state.get_features() == {
        "diabetes": {},
        "ckd": {},
    }


def test_returned_features_cannot_modify_saved_state():
    state = ConversationState()
    state.update({"diabetes": {"age": 45}})

    features = state.get_features()
    features["diabetes"]["age"] = 99

    assert state.get_features()["diabetes"]["age"] == 45



def make_chat_service():
    chat = ChatService()
    chat.pending_question = ("diabetes", "age")
    chat.active_screening = "diabetes"
    return chat


def test_chat_accepts_numeric_answer():
    chat = make_chat_service()

    interpreted, clarification = chat._interpret_pending_answer("45")

    assert clarification is None
    assert interpreted == {"diabetes": {"age": 45.0}}


def test_chat_rejects_invalid_numeric_answer():
    chat = make_chat_service()

    interpreted, clarification = chat._interpret_pending_answer("hello")

    assert interpreted is None
    assert clarification is not None


def test_chat_accepts_hypertension_no():
    chat = ChatService()
    chat.pending_question = ("diabetes", "hypertension")

    interpreted, clarification = chat._interpret_pending_answer("no")

    assert clarification is None
    assert interpreted == {"diabetes": {"hypertension": 0}}


def test_chat_skip_clears_pending_question():
    chat = make_chat_service()

    interpreted, clarification = chat._interpret_pending_answer("skip")

    assert interpreted == {}
    assert clarification is None
    assert chat.pending_question is None

def test_skipped_feature_is_not_asked_again():
    chat = ChatService()
    chat.skipped_features["diabetes"].add("age")

    message = chat.get_follow_up_message(
        {
            "missing_features": {
                "diabetes": ["age", "gender"],
                "ckd": [],
            }
        },
        preferred_screening="diabetes",
    )

    assert "gender" in message.lower()
    assert "how old are you" not in message.lower()


def test_numeric_answer_with_trailing_text_is_rejected():
    chat = ChatService()
    chat.pending_question = ("diabetes", "age")

    interpreted, clarification = chat._interpret_pending_answer("45abc")

    assert interpreted is None
    assert clarification is not None
