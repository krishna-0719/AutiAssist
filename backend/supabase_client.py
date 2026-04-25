"""
Supabase client for the Python ML backend.
Uses the SERVICE_ROLE key to bypass RLS for server-side operations.
"""

import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")


def get_client() -> Client:
    """Create and return a Supabase client with service_role privileges."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise ValueError(
            "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. "
            "Set them in backend/.env"
        )
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


# ─── Data Access Functions ──────────────────────────────────


def fetch_behavior_logs(client: Client, family_id: str) -> list[dict]:
    """Fetch all behavior logs for a family."""
    response = (
        client.table("behavior_logs")
        .select("*")
        .eq("family_id", family_id)
        .order("created_at", desc=True)
        .execute()
    )
    return response.data or []


def upsert_prediction(client: Client, prediction: dict) -> None:
    """Insert or update a behavior prediction row."""
    client.table("behavior_predictions").upsert(
        prediction,
        on_conflict="family_id,room,hour_bucket",
    ).execute()


def get_training_status(client: Client, family_id: str) -> dict | None:
    """Get the training status for a family."""
    response = (
        client.table("behavior_training_status")
        .select("*")
        .eq("family_id", family_id)
        .maybe_single()
        .execute()
    )
    return response.data


def upsert_training_status(client: Client, family_id: str, data: dict) -> None:
    """Insert or update the training status for a family."""
    data["family_id"] = family_id
    client.table("behavior_training_status").upsert(
        data,
        on_conflict="family_id",
    ).execute()


def insert_behavior_log(client: Client, log_data: dict) -> None:
    """Insert a behavior log entry."""
    client.table("behavior_logs").insert(log_data).execute()


def count_behavior_logs(client: Client, family_id: str) -> int:
    """Count total behavior logs for a family."""
    response = (
        client.table("behavior_logs")
        .select("id", count="exact")
        .eq("family_id", family_id)
        .execute()
    )
    return response.count or 0


def get_earliest_log(client: Client, family_id: str) -> dict | None:
    """Get the earliest behavior log for a family."""
    response = (
        client.table("behavior_logs")
        .select("created_at")
        .eq("family_id", family_id)
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None
