import os
import logging
from pathlib import Path
from typing import Optional
from app.core.config import settings
from app.services.storage.base import BaseStorageAdapter

logger = logging.getLogger(__name__)


class LocalStorageAdapter(BaseStorageAdapter):
    """
    Local filesystem storage adapter.
    Saves files securely outside public static web directories.
    Prevents path traversal attacks by validating resolved real paths.
    """

    def __init__(self, base_dir: Optional[str] = None):
        self.base_dir = Path(base_dir or settings.LOCAL_STORAGE_DIR).resolve()
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _resolve_path(self, object_key: str) -> Path:
        """Resolve object key to an absolute filesystem path and enforce path bounds."""
        target_path = (self.base_dir / object_key).resolve()
        if not str(target_path).startswith(str(self.base_dir)):
            raise ValueError(f"Security error: Path traversal attempt blocked for key: {object_key}")
        return target_path

    def save_file(self, file_bytes: bytes, object_key: str) -> str:
        target_path = self._resolve_path(object_key)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        with open(target_path, "wb") as f:
            f.write(file_bytes)
        return object_key

    def delete_file(self, object_key: str) -> bool:
        try:
            target_path = self._resolve_path(object_key)
            if target_path.exists():
                target_path.unlink()
                # Clean up empty parent directories if any
                parent = target_path.parent
                while parent != self.base_dir and parent.exists() and not any(parent.iterdir()):
                    parent.rmdir()
                    parent = parent.parent
            return True
        except Exception as e:
            logger.warning(f"Failed to delete file for object_key {object_key}: {e}")
            return False

    def get_file(self, object_key: str) -> bytes:
        target_path = self._resolve_path(object_key)
        if not target_path.exists():
            raise FileNotFoundError(f"Storage file not found: {object_key}")
        with open(target_path, "rb") as f:
            return f.read()

    def exists(self, object_key: str) -> bool:
        try:
            target_path = self._resolve_path(object_key)
            return target_path.exists()
        except Exception:
            return False
