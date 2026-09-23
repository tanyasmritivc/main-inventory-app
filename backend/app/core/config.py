
from functools import lru_cache

from pydantic import AnyHttpUrl
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Fail closed as production when a hosting platform omits ENV. Local
    # development explicitly sets ENV=development in backend/.env.
    env: str = "production"
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

    # All language tasks use the self-hosted FTCTools agent gateway. Photo
    # recognition uses FIND below. There is intentionally no external fallback.
    findez_agent_key: str
    findez_agent_base_url: AnyHttpUrl = "https://agent.ftctools.com/v1"
    findez_agent_model: str = "deepseek-v4-flash-agent"
    findez_agent_timezone: str = "America/Los_Angeles"

    # FIND is the server-side inventory-photo ingestion pipeline used by both
    # web and mobile through POST /inventory/extract_from_image. Keep its
    # bearer token out of client bundles and source control.
    find_api_base_url: AnyHttpUrl | None = None
    find_api_key: str | None = None
    # The current FIND appliance exposes HTTP only. Keep this false everywhere
    # except a deployment that has explicitly accepted that transport constraint.
    find_api_allow_insecure_http: bool = False
    find_api_request_timeout_seconds: float = 30.0
    find_api_job_timeout_seconds: float = 90.0
    find_api_poll_interval_seconds: float = 0.75

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

    # APNs provider credentials. The private key is an absolute server-only path.
    apns_key_path: str | None = None
    apns_key_id: str | None = None
    apns_team_id: str | None = None
    apns_topic: str = "com.findez.app"

    brevo_smtp_host: str = "smtp-relay.brevo.com"
    brevo_smtp_port: int = 587
    brevo_smtp_username: str | None = None
    brevo_smtp_password: str | None = None
    smtp_from_email: str = "noreply@findez.ai"
    smtp_from_name: str = "FindEZ"

    # Set PILOT_MODE=true to grant all users unlimited access and disable billing.
    # Does not affect Stripe code or DB data — safe to remove when billing goes live.
    pilot_mode: bool = False
    # ISO-8601 timestamp when the pilot ends, e.g. "2026-09-11T23:59:59Z".
    # Surfaced in /me/limits as pilot_ends_at and pilot_notice. Informational only —
    # limits do not flip automatically; pilot_mode must be toggled manually.
    pilot_ends_at: str | None = None

    # Public integration API limits. Limits are enforced per API key in
    # PostgreSQL so multiple backend workers share the same counters.
    api_key_requests_per_minute: int = 120
    api_key_bulk_requests_per_minute: int = 10
    api_key_bulk_max_items: int = 500

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
