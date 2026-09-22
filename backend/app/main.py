import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.errors import register_error_handlers
from app.api.v1.router import api_router
from app.api.v1.endpoints import (
    users, 
    auth, 
    health, 
    skintwins, 
    captures, 
    timeline,
    comparisons,
    find_care
)
from app.database.session import engine
from app.database.base import Base
# Import all models so Base.metadata knows about them
import app.models  # noqa: F401


from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.core.rate_limit import limiter

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Local development convenience: do not auto-create tables in production.
    if settings.ENVIRONMENT != "production":
        Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Set request_id on request.state for tracking
@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response

# CORS Configuration
allowed_origins = settings.CORS_ORIGINS if settings.ENVIRONMENT == "production" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register uniform error handlers
register_error_handlers(app)

# Root-level health endpoint (as required by section 1 of docs)
app.add_api_route("/health", health.check_health, methods=["GET"], tags=["Health"])
app.add_api_route("/health/db", health.check_database_health, methods=["GET"], tags=["Health"])

# Root-level welcome endpoint
@app.get("/", tags=["General"])
def root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "version": settings.VERSION,
        "docs_url": f"{settings.API_V1_STR}/docs",
    }

# Include API v1 routes
api_router.include_router(comparisons.router, prefix="/skintwins", tags=["comparisons"])
api_router.include_router(find_care.router, prefix="/find-care", tags=["find-care"])
app.include_router(api_router, prefix=settings.API_V1_STR)
