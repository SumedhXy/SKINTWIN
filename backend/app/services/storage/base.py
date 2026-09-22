from abc import ABC, abstractmethod
from typing import Optional


class BaseStorageAdapter(ABC):
    """Abstract base class for storage adapters (Local, S3, GCS, etc.)."""

    @abstractmethod
    def save_file(self, file_bytes: bytes, object_key: str) -> str:
        """
        Save binary content to storage using object_key.
        Returns object_key.
        """
        pass

    @abstractmethod
    def delete_file(self, object_key: str) -> bool:
        """
        Delete file from storage using object_key.
        Returns True if deleted or already absent, False on error.
        """
        pass

    @abstractmethod
    def get_file(self, object_key: str) -> bytes:
        """
        Retrieve binary content of file from storage.
        """
        pass

    @abstractmethod
    def exists(self, object_key: str) -> bool:
        """
        Check if file exists in storage.
        """
        pass
