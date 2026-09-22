from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.security import decode_access_token
from app.core.errors import UnauthorizedException
from app.database.session import get_db
from app.models.user import User

security_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> User:
    if not credentials or not credentials.credentials:
        raise UnauthorizedException(message="Authentication token is missing.", code="TOKEN_MISSING")

    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload:
        raise UnauthorizedException(message="Authentication token is invalid or expired.", code="INVALID_TOKEN")

    user_id = payload.get("sub")
    if not user_id:
        raise UnauthorizedException(message="Invalid token payload.", code="INVALID_TOKEN")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise UnauthorizedException(message="User account not found.", code="USER_NOT_FOUND")

    if not user.is_active:
        raise UnauthorizedException(message="User account is deactivated.", code="USER_INACTIVE")

    return user
