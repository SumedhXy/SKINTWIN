from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str = "healthy"
    version: str
    database: str
    environment: str
