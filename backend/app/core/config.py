from __future__ import annotations

from functools import lru_cache

from pydantic import AnyHttpUrl
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    backend_cors_origins: list[str] = ["http://localhost:3000"]

    supabase_url: AnyHttpUrl
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_jwt_audience: str = "authenticated"
    supabase_jwks_url: AnyHttpUrl

    supabase_storage_bucket: str = "item-images"
    supabase_storage_public: bool = True
    supabase_storage_signed_url_ttl_seconds: int = 3600

    openai_api_key: str
    openai_model: str = "gpt-4.1-mini"
    openai_vision_model: str = "gpt-4.1-mini"

    max_image_mb: int = 10

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
