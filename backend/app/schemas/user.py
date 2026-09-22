from datetime import datetime
from typing import Optional, List, Any, Dict
from pydantic import BaseModel, EmailStr, Field


class UserRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters.")
    full_name: Optional[str] = Field(None, max_length=150)


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    full_name: Optional[str] = None
    is_active: bool
    account_status: str
    created_at: datetime
    last_login_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user: UserResponse


class UserUpdateRequest(BaseModel):
    """Request body for updating the current user's profile."""
    full_name: Optional[str] = Field(None, max_length=150, description="Display name (max 150 chars).")


class ChangePasswordRequest(BaseModel):
    """Request body for changing the authenticated user's password."""
    current_password: str = Field(..., description="The user's current password.")
    new_password: str = Field(..., min_length=8, description="New password (minimum 8 characters).")


class DeleteAccountRequest(BaseModel):
    """Request body for permanent account deletion. Requires password re-authentication."""
    password: str = Field(..., description="Current password to confirm account deletion.")


class ExportSkinTwinData(BaseModel):
    public_id: str
    name: str
    body_location: str
    status: str
    capture_count: int
    created_at: datetime


class ExportCaptureData(BaseModel):
    id: str
    skintwin_public_id: str
    captured_at: datetime
    quality_status: Optional[str] = None
    comparison_eligible: Optional[bool] = None
    notes: Optional[str] = None


class UserExportResponse(BaseModel):
    """
    Synchronous JSON export of the authenticated user's personal data.
    Does not include password hashes, JWT secrets, or image file contents.
    Image metadata (object keys) are included; raw binary files are not.
    """
    exported_at: datetime
    profile: UserResponse
    skintwins: List[ExportSkinTwinData]
    captures: List[ExportCaptureData]
    total_skintwins: int
    total_captures: int
    export_notes: List[str] = Field(
        default_factory=list,
        description="Human-readable notes about what is and is not included in this export.",
    )
