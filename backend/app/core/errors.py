import uuid
from typing import Optional
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException


class SkinTwinException(Exception):
    """Base exception for all SkinTwin domain errors."""
    def __init__(self, code: str, message: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class NotFoundException(SkinTwinException):
    def __init__(self, message: str = "The requested resource could not be found.", code: str = "NOT_FOUND"):
        super().__init__(code=code, message=message, status_code=status.HTTP_404_NOT_FOUND)


class UnauthorizedException(SkinTwinException):
    def __init__(self, message: str = "Invalid credentials or unauthorized request.", code: str = "UNAUTHORIZED"):
        super().__init__(code=code, message=message, status_code=status.HTTP_401_UNAUTHORIZED)


class ForbiddenException(SkinTwinException):
    def __init__(self, message: str = "You do not have permission to access this resource.", code: str = "FORBIDDEN"):
        super().__init__(code=code, message=message, status_code=status.HTTP_403_FORBIDDEN)


class DuplicateResourceException(SkinTwinException):
    def __init__(self, message: str = "Resource already exists.", code: str = "DUPLICATE_RESOURCE"):
        super().__init__(code=code, message=message, status_code=status.HTTP_409_CONFLICT)


def format_error_response(code: str, message: str, request_id: Optional[str] = None) -> dict:
    return {
        "error": {
            "code": code,
            "message": message,
            "request_id": request_id or str(uuid.uuid4()),
        }
    }


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(SkinTwinException)
    async def skintwin_exception_handler(request: Request, exc: SkinTwinException):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        return JSONResponse(
            status_code=exc.status_code,
            content=format_error_response(code=exc.code, message=exc.message, request_id=req_id),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        code = "HTTP_ERROR"
        if exc.status_code == 404:
            code = "NOT_FOUND"
        elif exc.status_code == 401:
            code = "UNAUTHORIZED"
        elif exc.status_code == 403:
            code = "FORBIDDEN"
        elif exc.status_code == 409:
            code = "CONFLICT"

        detail = exc.detail if isinstance(exc.detail, str) else "An HTTP error occurred."
        return JSONResponse(
            status_code=exc.status_code,
            content=format_error_response(code=code, message=detail, request_id=req_id),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        # Format validation error messages cleanly without leaking internal structures
        messages = []
        for err in exc.errors():
            loc = " -> ".join([str(l) for l in err.get("loc", []) if l != "body"])
            msg = err.get("msg", "Invalid value")
            messages.append(f"{loc}: {msg}" if loc else msg)
        combined_message = "; ".join(messages) if messages else "Request validation failed."
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY if hasattr(status, "HTTP_422_UNPROCESSABLE_CONTENT") else 422,
            content=format_error_response(code="VALIDATION_ERROR", message=combined_message, request_id=req_id),
        )

    @app.exception_handler(Exception)
    async def general_exception_handler(request: Request, exc: Exception):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        # Never leak stack traces or internal errors to client
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=format_error_response(
                code="INTERNAL_SERVER_ERROR",
                message="An unexpected server error occurred. Please try again later.",
                request_id=req_id,
            ),
        )
