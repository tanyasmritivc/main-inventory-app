"""Shared, hermetic setup for the backend test suite."""

import os
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

# Unit tests must never depend on developer or production credentials. Individual
# tests can override these values explicitly when exercising configuration.
os.environ.update(
    {
        "ENV": "development",
        "SUPABASE_URL": "https://placeholder.supabase.co",
        "SUPABASE_PUBLIC_URL": "https://placeholder.supabase.co",
        "SUPABASE_ANON_KEY": "placeholder-anon",
        "SUPABASE_SERVICE_ROLE_KEY": "placeholder-service",
        "SUPABASE_JWKS_URL": (
            "https://placeholder.supabase.co/.well-known/jwks.json"
        ),
        "OPENAI_API_KEY": "placeholder-openai",
        "PILOT_MODE": "true",
    }
)
