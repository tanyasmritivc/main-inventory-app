from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi import _rate_limit_exceeded_handler
from starlette.responses import PlainTextResponse
import logging

from app.api.router import api_router
from app.core.config import get_settings
from app.core.limiter import limiter
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    app = FastAPI(title="AI Inventory API", version="1.0.0")
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    settings = get_settings()

    @app.on_event("startup")
    async def startup_health_check():
        """Startup health check for Supabase connection"""
        try:
            supabase = get_supabase_admin()
            # Simple health check - try to select from a known table
            result = supabase.table("items").select("item_id").limit(1).execute()
            logger.info("Supabase health check: SUCCESS")
        except Exception as e:
            logger.error(f"Supabase health check: FAILED - {e}")
            # Don't raise - let the app start anyway

    @app.middleware("http")
    async def _ensure_cors_headers(request: Request, call_next):
        origin = request.headers.get("origin")
        try:
            response = await call_next(request)
        except Exception:
            response = PlainTextResponse("Internal Server Error", status_code=500)

        if origin and (origin in settings.backend_cors_origins or origin.startswith("https://findez.ai") or origin.startswith("https://www.findez.ai")):
            response.headers.setdefault("access-control-allow-origin", origin)
            response.headers.setdefault("access-control-allow-credentials", "true")
            response.headers.setdefault("access-control-allow-methods", "*")
            response.headers.setdefault("access-control-allow-headers", "*")
            response.headers.setdefault("vary", "Origin")

        return response

    # Base CORS — explicitly allow production frontend
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.backend_cors_origins,
        allow_origin_regex=r"https://(www\.)?findez\.ai",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router)
    return app


app = create_app()
