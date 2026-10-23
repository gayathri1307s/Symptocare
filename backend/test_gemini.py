from services.gemini_service import generate_chat_response

if __name__ == "__main__":
    reply = generate_chat_response(
        "Hello! Briefly introduce yourself as SymptoCare."
    )
    print("\nGemini response:\n")
    print(reply)