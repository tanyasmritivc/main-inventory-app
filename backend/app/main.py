from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import PlainTextResponse

from app.api.router import api_router
from app.core.config import get_settings


def create_app() -> FastAPI:
    app = FastAPI(title="AI Inventory API", version="1.0.0")

    settings = get_settings()

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
