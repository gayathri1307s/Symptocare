
import os
from pathlib import Path
from dotenv import load_dotenv
from groq import Groq

load_dotenv(Path(__file__).resolve().parent / ".env")

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

try:
    models = client.models.list()
    print("Available models:")
    for model in models.data:
        print(model.id)
except Exception as e:
    print(type(e).__name__ + ":", str(e))
