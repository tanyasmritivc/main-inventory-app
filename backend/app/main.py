from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from app.core.config import get_settings
from app.api.router import api_router


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(title="AI Inventory API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.backend_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.options("/{full_path:path}")
    async def preflight_handler(full_path: str, request: Request):
        return Response(status_code=200)

    app.include_router(api_router)

    return app


app = create_app()
