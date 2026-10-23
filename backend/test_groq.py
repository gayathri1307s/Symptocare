
from services.gemini_service import generate_chat_response

try:
    reply = generate_chat_response(
        "Hello! Introduce yourself as the SymptoCare health assistant."
    )
    print("\nGroq connection successful!")
    print("Response:", reply)

except Exception as e:
    print("\nGroq test failed.")
    print(type(e).__name__ + ":", str(e))
