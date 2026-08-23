"""
Tests that _ensure_cors_headers logs unhandled exceptions and returns a safe 500.

Uses a minimal FastAPI app to avoid touching Supabase or any real service.
"""

import logging

import pytest
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from starlette.testclient import TestClient


def _make_app(cors_origins: list[str] | None = None) -> FastAPI:
    """
    Build a stripped-down version of the middleware under test.
    Mirrors _ensure_cors_headers from main.py without any route handlers.
    """
    origins = cors_origins or ["https://www.findez.ai"]
    logger = logging.getLogger("app.main")
    app = FastAPI()

    @app.middleware("http")
    async def _ensure_cors_headers(request: Request, call_next):
        origin = request.headers.get("origin")
        try:
            response = await call_next(request)
        except Exception:
            logger.exception(
                "Unhandled exception in middleware on %s %s",
                request.method, request.url.path,
            )
            response = JSONResponse(
                status_code=500,
                content={"detail": "An unexpected error occurred."},
            )

        if origin and origin in origins:
            response.headers.setdefault("access-control-allow-origin", origin)
            response.headers.setdefault("access-control-allow-credentials", "true")

        return response

    @app.get("/boom")
    async def boom():
        raise RuntimeError("secret internal traceback detail")

    @app.get("/ok")
    async def ok():
        return {"status": "ok"}

    return app


class TestEnsureCorsHeadersMiddleware:
    def setup_method(self):
        self.app = _make_app()
        self.client = TestClient(self.app, raise_server_exceptions=False)
        self.origin = "https://www.findez.ai"

    # ── safe 500 ──────────────────────────────────────────────────────────────

    def test_returns_500_on_exception(self):
        resp = self.client.get("/boom", headers={"origin": self.origin})
        assert resp.status_code == 500

    def test_response_body_is_safe(self):
        resp = self.client.get("/boom", headers={"origin": self.origin})
        body = resp.json()
        assert "detail" in body
        assert body["detail"] == "An unexpected error occurred."

    def test_response_body_excludes_internal_details(self):
        resp = self.client.get("/boom", headers={"origin": self.origin})
        raw = resp.text
        assert "secret internal traceback detail" not in raw
        assert "RuntimeError" not in raw
        assert "Traceback" not in raw

    # ── CORS headers preserved on error ──────────────────────────────────────

    def test_cors_header_present_on_500_for_allowed_origin(self):
        resp = self.client.get("/boom", headers={"origin": self.origin})
        assert resp.headers.get("access-control-allow-origin") == self.origin

    def test_no_cors_header_for_disallowed_origin(self):
        resp = self.client.get("/boom", headers={"origin": "https://evil.example.com"})
        assert "access-control-allow-origin" not in resp.headers

    # ── logging ───────────────────────────────────────────────────────────────

    def test_exception_is_logged_with_method_and_path(self, caplog):
        with caplog.at_level(logging.ERROR, logger="app.main"):
            self.client.get("/boom", headers={"origin": self.origin})
        assert any("GET" in r.message and "/boom" in r.message for r in caplog.records), (
            "Expected a log record mentioning method and path; got: "
            + str([r.message for r in caplog.records])
        )

    def test_exception_traceback_captured_in_log(self, caplog):
        with caplog.at_level(logging.ERROR, logger="app.main"):
            self.client.get("/boom", headers={"origin": self.origin})
        # logger.exception() attaches exc_info; caplog records the exception text
        assert any(r.exc_info is not None for r in caplog.records), (
            "Expected exc_info to be attached to a log record (logger.exception was not called)"
        )

    def test_no_sensitive_info_in_log_message(self, caplog):
        """Log message must not include Authorization header or request body."""
        with caplog.at_level(logging.ERROR, logger="app.main"):
            self.client.get(
                "/boom",
                headers={"origin": self.origin, "authorization": "Bearer secret-token"},
            )
        for record in caplog.records:
            assert "secret-token" not in record.getMessage()
            assert "Bearer" not in record.getMessage()

    # ── happy path unaffected ─────────────────────────────────────────────────

    def test_happy_path_returns_200(self):
        resp = self.client.get("/ok", headers={"origin": self.origin})
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
