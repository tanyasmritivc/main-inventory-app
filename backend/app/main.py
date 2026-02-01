from fastapi import FastAPI, Request
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router


def create_app() -> FastAPI:
    app = FastAPI(title="AI Inventory API", version="1.0.0")

    # Base CORS (no static origins)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 🔑 HARD STOP for preflight — MUST come before routing
    @app.middleware("http")
    async def cors_and_preflight(request: Request, call_next):
        origin = request.headers.get("origin")

        # Always allow OPTIONS
        if request.method == "OPTIONS":
            response = Response(status_code=200)
        else:
            response = await call_next(request)

        # Dynamically allow Vercel origins
        if origin and origin.endswith(".vercel.app"):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Authorization,Content-Type"

        return response

    app.include_router(api_router)
    return app


app = create_app()
