from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.core.security import get_password_hash, verify_password, create_access_token
from app.core.errors import DuplicateResourceException, UnauthorizedException
from app.core.config import settings
from app.models.user import User
from app.schemas.user import UserRegisterRequest, UserLoginRequest, TokenResponse, UserResponse


class AuthService:
    @staticmethod
    def register_user(db: Session, request: UserRegisterRequest) -> User:
        # Check if email is already taken
        normalized_email = request.email.lower().strip()
        existing_user = db.query(User).filter(User.email == normalized_email).first()
        if existing_user:
            raise DuplicateResourceException(
                message="An account with this email address already exists.",
                code="EMAIL_ALREADY_REGISTERED",
            )

        hashed_pw = get_password_hash(request.password)
        new_user = User(
            email=normalized_email,
            password_hash=hashed_pw,
            full_name=request.full_name.strip() if request.full_name else None,
            is_active=True,
            account_status="active",
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user

    @staticmethod
    def authenticate_user(db: Session, request: UserLoginRequest) -> TokenResponse:
        normalized_email = request.email.lower().strip()
        user = db.query(User).filter(User.email == normalized_email).first()
        if not user or not verify_password(request.password, user.password_hash):
            raise UnauthorizedException(
                message="Invalid email or password.",
                code="INVALID_CREDENTIALS",
            )

        if not user.is_active:
            raise UnauthorizedException(
                message="Your account has been deactivated. Please contact support.",
                code="USER_INACTIVE",
            )

        # Update last login timestamp
        user.last_login_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user)

        token = create_access_token(subject=user.id)
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            expires_in_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
            user=UserResponse.model_validate(user),
        )
