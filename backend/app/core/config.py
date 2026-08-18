
from functools import lru_cache

from pydantic import AnyHttpUrl
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    backend_cors_origins: list[str] = [
        "https://www.findez.ai",
        "https://findez.ai",
    ]


    supabase_url: AnyHttpUrl
    # The browser-reachable Supabase origin. Backend traffic may use a local
    # URL, so signed links must not inherit that internal hostname.
    supabase_public_url: AnyHttpUrl | None = None
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_jwt_audience: str = "authenticated"
    supabase_jwks_url: AnyHttpUrl
    # Only set against a self-hosted Supabase stack (which signs HS256 with a shared
    # JWT_SECRET). Unset on cloud — never set it for the cloud Supabase project.
    supabase_jwt_secret: str | None = None

    supabase_storage_bucket: str = "item-images"
    supabase_storage_public: bool = True
    supabase_storage_signed_url_ttl_seconds: int = 3600

    openai_api_key: str
    openai_model: str = "gpt-5-mini"
    openai_vision_model: str = "gpt-4o"

    go_upc_api_key: str | None = None
    upcitemdb_user_key: str | None = None
    upcitemdb_key_type: str = "3scale"

    max_image_mb: int = 10

    stripe_secret_key: str | None = None
    stripe_webhook_secret: str | None = None
    # Legacy individual-plan prices (kept for env-file tolerance; no longer used in checkout)
    stripe_price_monthly: str | None = None
    stripe_price_yearly: str | None = None
    stripe_price_pro_monthly: str | None = None
    stripe_price_pro_annual: str | None = None
    stripe_price_team_season: str | None = None
    # Team season one-time payment prices (set by stripe_setup.py)
    stripe_price_team_ftc: str | None = None      # $99 — FTC/VEX/FLL
    stripe_price_team_frc: str | None = None      # $199 — FRC
    stripe_price_district: str | None = None      # $499 — School Bundle (10 teams)

    frontend_url: str = "https://www.findez.ai"

    @field_validator("backend_cors_origins", mode="before")
    @classmethod
    def _parse_cors_origins(cls, v):
        if v is None:
            return ["http://localhost:3000"]
        if isinstance(v, str):
            parts = [p.strip() for p in v.split(",")]
            return [p for p in parts if p]
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()
