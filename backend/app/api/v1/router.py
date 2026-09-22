from fastapi import APIRouter
from app.api.v1.endpoints import health, auth, users, skintwins, captures, timeline, comparisons

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(skintwins.router, prefix="/skintwins", tags=["SkinTwins"])
api_router.include_router(captures.router, tags=["Captures"])
api_router.include_router(timeline.router, tags=["Timeline"])
api_router.include_router(comparisons.router, tags=["Comparisons"])
