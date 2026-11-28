
import os
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

# Load .env from the backend folder
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Supabase URL or Key is missing. Check backend/.env"
    )


def get_supabase_client(access_token: str):
    supabase = create_client(
        SUPABASE_URL,
        SUPABASE_KEY
    )

    supabase.postgrest.auth(access_token)

    return supabase
