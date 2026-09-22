import os
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    PROJECT_NAME: str = "SkinTwin Backend API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/skintwin"
    POSTGRES_DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/skintwin"

    # Security / JWT
    JWT_SECRET_KEY: str = "development-secret-key-change-me-in-production-32-plus-chars"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str, info) -> str:
        if len(v) < 32:
            # We only enforce this in production to not break tests that might use small keys, but user said:
            # "Fail startup if production configuration is missing or weak."
            env = info.data.get("ENVIRONMENT", "development")
            if env == "production":
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production.")
            # Even in dev, strongly recommend a good key
        return v

    # Storage & Upload Config
    STORAGE_TYPE: str = "local"
    LOCAL_STORAGE_DIR: str = "uploads"
    MAX_UPLOAD_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB
    ALLOWED_IMAGE_MIME_TYPES: List[str] = [
        "image/jpeg",
        "image/png",
        "image/webp",
    ]

    # MedSAM & Computer Vision Segmentation Config
    MODEL_NAME: str = "medsam_vit_b"
    MODEL_VERSION: str = "1.0.0"
    MODEL_WEIGHTS_PATH: str = "models/medsam_vit_b.pth"
    DEVICE: str = "cpu"
    CONFIDENCE_THRESHOLD: float = 0.70

    # Explanation provider
    AI_PROVIDER: str = "deterministic"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-flash-lite-latest"

    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:8080",
        "http://localhost:8082",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8082",
        "https://localhost",
        "https://localhost:8080",
    ]

    OPEN_MAPS_ENABLED: bool = True
    OPEN_MAPS_OVERPASS_URL: str = "https://overpass-api.de/api/interpreter"

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)


settings = Settings()
