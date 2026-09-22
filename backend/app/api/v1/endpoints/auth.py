from fastapi import APIRouter, Depends, status, Request
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.user import UserRegisterRequest, UserLoginRequest, UserResponse, TokenResponse
from app.services.auth_service import AuthService
from app.core.rate_limit import limiter

router = APIRouter()


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
@limiter.limit("5/minute")
def register(request: Request, user_request: UserRegisterRequest, db: Session = Depends(get_db)):
    """Register a new user account with email and password."""
    user = AuthService.register_user(db, user_request)
    return UserResponse.model_validate(user)


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Authenticate user and return JWT token",
)
@limiter.limit("10/minute")
def login(request: Request, user_request: UserLoginRequest, db: Session = Depends(get_db)):
    """Authenticate with email and password to receive a JWT access token."""
    return AuthService.authenticate_user(db, user_request)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current authenticated user profile",
)
def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Return the profile of the currently authenticated user."""
    return UserResponse.model_validate(current_user)


@router.post(
    "/logout",
    summary="Logout the current session",
    status_code=status.HTTP_200_OK,
)
def logout(current_user: User = Depends(get_current_user)):
    """
    Signals intent to log out the current session.

    IMPORTANT — JWT Limitation:
    This API uses stateless JWT access tokens without a server-side token blacklist.
    Calling this endpoint does NOT immediately invalidate the client's JWT token on the server.
    The token remains cryptographically valid until it expires (up to 30 minutes).

    The client MUST delete the stored JWT token locally upon receiving this response.
    This is the effective security boundary for logout in the current architecture.
    """
    return {
        "message": "Session logout acknowledged. Delete your local token to complete sign-out.",
        "notice": (
            "This system uses stateless JWT tokens. Your token remains valid on the server "
            "until it expires. Delete it from local storage immediately."
        ),
    }
