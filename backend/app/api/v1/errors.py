import logging
import uuid

import asyncpg
from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)
MAX_BODY_BYTES = 1024 * 1024


class APIError(Exception):
    def __init__(self, status: int, code: str, message: str, headers: dict | None = None):
        self.status = status
        self.code = code
        self.message = message
        self.headers = headers or {}


class IntegrationRoute(APIRoute):
    """Bound streamed bodies before FastAPI parses JSON; scrub only /api/v1 errors."""

    def get_route_handler(self):
        handler = super().get_route_handler()

        async def wrapped(request: Request):
            correlation_id = str(uuid.uuid4())
            request.state.correlation_id = correlation_id
            try:
                if request.method in {"POST", "PATCH", "PUT"}:
                    chunks = []
                    size = 0
                    async for chunk in request.stream():
                        size += len(chunk)
                        if size > MAX_BODY_BYTES:
                            raise APIError(413, "payload_too_large", "Request body exceeds 1 MiB.")
                        chunks.append(chunk)
                    request._body = b"".join(chunks)
                response = await handler(request)
            except Exception as exc:
                if isinstance(exc, APIError):
                    error = exc
                elif isinstance(exc, RequestValidationError):
                    error = APIError(422, "invalid_request", "Invalid request data.")
                elif isinstance(exc, HTTPException):
                    code = "unauthorized" if exc.status_code == 401 else "request_rejected"
                    error = APIError(exc.status_code, code, "Request could not be authorized.")
                elif isinstance(exc, asyncpg.InsufficientPrivilegeError):
                    error = APIError(403, "forbidden", "Access to this resource is not permitted.")
                elif isinstance(exc, asyncpg.IntegrityConstraintViolationError):
                    error = APIError(409, "conflict", "The request conflicts with existing data.")
                else:
                    error = APIError(500, "internal_error", "An unexpected error occurred.")
                # Do not log request bodies, authorization headers, or SQL parameter values.
                # PostgreSQL details can contain a failing api_keys row (including its hash).
                logger.warning("integration_error correlation_id=%s code=%s exception=%s sqlstate=%s",
                               correlation_id, error.code, type(exc).__name__, getattr(exc, "sqlstate", None))
                headers = dict(error.headers)
                if error.status == 401:
                    headers["WWW-Authenticate"] = "Bearer"
                response = JSONResponse(status_code=error.status, headers=headers, content={
                    "error": {"code": error.code, "message": error.message,
                              "correlation_id": correlation_id},
                })
            response.headers["X-Correlation-ID"] = correlation_id
            response.headers["Cache-Control"] = "no-store"
            return response

        return wrapped
