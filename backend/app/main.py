import os
import time
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.responses import JSONResponse, PlainTextResponse
import logging

from app.api.router import api_router
from app.core.config import get_settings
from app.core.limiter import limiter
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)


def _client_ip(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for", "")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def create_app() -> FastAPI:
    _is_production = os.getenv("ENV", "production") == "production"
    app = FastAPI(
        title="AI Inventory API",
        version="1.0.0",
        docs_url=None if _is_production else "/docs",
        redoc_url=None if _is_production else "/redoc",
        openapi_url=None if _is_production else "/openapi.json",
    )
    app.state.limiter = limiter

    # ── Rate limiting (most specific — registered first so it wins over HTTPException) ──
    async def _rate_limit_handler(request: Request, exc: RateLimitExceeded):
        logger.warning(
            "[SECURITY] rate_limit_exceeded | ip=%s | path=%s",
            _client_ip(request), request.url.path,
        )
        return JSONResponse(
            status_code=429,
            content={"detail": "Rate limit exceeded. Please slow down."},
        )

    # ── HTTPException — pass through status + detail, but scrub any internal leak ──
    _INTERNAL_MARKERS = ("Traceback", 'File "', "/app/", "/home/", "/usr/")

    async def _http_exception_handler(request: Request, exc: HTTPException):
        detail = exc.detail
        if isinstance(detail, str) and any(m in detail for m in _INTERNAL_MARKERS):
            logger.error(
                "HTTPException %d with internal detail suppressed on %s %s",
                exc.status_code, request.method, request.url.path,
                exc_info=exc,
            )
            detail = "An unexpected error occurred."
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": detail},
            headers=getattr(exc, "headers", None),
        )

    # ── RequestValidationError — hide Pydantic internals, keep generic 422 ──
    async def _validation_exception_handler(request: Request, exc: RequestValidationError):
        logger.error(
            "Validation error on %s %s",
            request.method, request.url.path,
            exc_info=exc,
        )
        return JSONResponse(status_code=422, content={"detail": "Invalid request data."})

    # ── Catch-all — prevents raw tracebacks ever reaching the client ──
    async def _generic_exception_handler(request: Request, exc: Exception):
        logger.error(
            "Unhandled exception on %s %s",
            request.method, request.url.path,
            exc_info=exc,
        )
        return JSONResponse(status_code=500, content={"detail": "An unexpected error occurred."})

    app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)
    app.add_exception_handler(HTTPException, _http_exception_handler)
    app.add_exception_handler(RequestValidationError, _validation_exception_handler)
    app.add_exception_handler(Exception, _generic_exception_handler)
    app.add_middleware(SlowAPIMiddleware)

    settings = get_settings()

    @app.on_event("startup")
    async def startup_health_check():
        logger.info("FindEZ API starting — ENV=%s", os.getenv("ENV", "production"))
        try:
            supabase = get_supabase_admin()
            # Simple health check - try to select from a known table
            result = supabase.table("items").select("item_id").limit(1).execute()
            logger.info("Supabase health check: SUCCESS")
        except Exception as e:
            logger.error("Supabase health check: FAILED - %s", e)
            # Don't raise - let the app start anyway

    @app.middleware("http")
    async def _log_requests(request: Request, call_next):
        request_id = str(uuid.uuid4())[:8]
        start = time.time()
        response = await call_next(request)
        duration_ms = round((time.time() - start) * 1000)
        logger.info(
            f"[{request_id}] {request.method} {request.url.path} → {response.status_code} ({duration_ms}ms)"
        )
        return response

    @app.middleware("http")
    async def _ensure_cors_headers(request: Request, call_next):
        origin = request.headers.get("origin")
        try:
            response = await call_next(request)
        except Exception:
            response = PlainTextResponse("Internal Server Error", status_code=500)

        if origin and (
            origin in settings.backend_cors_origins
            or origin in {
                "https://findez.ai",
                "https://www.findez.ai",
                "https://findezapp.openstack.ftctools.com",
            }
        ):
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
        allow_origin_regex=(
            r"https://(www\.)?findez\.ai"
            r"|https://findezapp\.openstack\.ftctools\.com"
        ),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router)

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    @app.get("/health/db")
    async def health_db():
        try:
            sb = get_supabase_admin()
            sb.table("items").select("item_id").limit(1).execute()
            return {"status": "ok", "database": "reachable"}
        except Exception:
            logger.exception("Health check failed")
            return JSONResponse(
                status_code=503,
                content={"status": "degraded", "database": "unreachable"},
            )

    return app


app = create_app()
