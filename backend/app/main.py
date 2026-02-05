from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router


def create_app() -> FastAPI:
    app = FastAPI(title="AI Inventory API", version="1.0.0")

    # Base CORS — explicitly allow production frontend
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "https://www.findez.ai",
            "https://findez.ai",
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router)
    return app


app = create_app()
