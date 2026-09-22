from app.core.config import settings
from app.services.storage.base import BaseStorageAdapter
from app.services.storage.local import LocalStorageAdapter


def get_storage_adapter() -> BaseStorageAdapter:
    """Factory function returning the configured storage adapter."""
    if settings.STORAGE_TYPE == "local":
        return LocalStorageAdapter()
    # Support for future cloud storage adapters (S3, Cloud Storage, etc.)
    raise NotImplementedError(f"Storage adapter '{settings.STORAGE_TYPE}' is not supported.")


__all__ = ["BaseStorageAdapter", "LocalStorageAdapter", "get_storage_adapter"]
