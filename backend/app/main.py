from fastapi import FastAPI, Request
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router


def create_app() -> FastAPI:
    app = FastAPI(title="AI Inventory API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[],  # handled dynamically
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def dynamic_cors(request: Request, call_next):
        origin = request.headers.get("origin")
        response: Response = await call_next(request)

        if origin and origin.endswith(".vercel.app"):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"

        return response

    app.include_router(api_router)
    return app


app = create_app()
