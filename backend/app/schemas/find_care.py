from typing import List, Optional
from pydantic import BaseModel, Field

class ProviderBase(BaseModel):
    name: str = Field(..., description="Provider or clinic name")
    specialty: str = Field(..., description="Primary specialty")
    specialization: Optional[str] = None
    qualifications: Optional[str] = None
    experience_years: Optional[int] = None
    clinic_name: Optional[str] = None
    address: str = Field(..., description="Physical address")
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    profile_description: Optional[str] = None
    services: List[str] = Field(default_factory=list)
    contact_information: Optional[str] = None
    appointment_information: Optional[str] = None
    distance_km: Optional[float] = Field(None, description="Distance from requested location in km")
    consultation_types: List[str] = Field(..., description="e.g., ['in_person', 'telehealth']")
    languages: List[str] = Field(default_factory=list, description="Languages spoken")
    fee_range: Optional[str] = Field(None, description="Estimated fee range, if known")
    verification_status: str = Field("unverified", description="verification status")
    data_source: str = Field("mock_fixtures", description="Data source origin")
    booking_url: Optional[str] = Field(None, description="External booking link")
    is_test_data: bool = Field(True, description="Indicates this is a mock record")
    availability: Optional[str] = Field(None, description="Next available appointment if known")
    rating: Optional[str] = Field(None, description="Rating string, if any")
    recommendation_reason: Optional[str] = None
    map_url: Optional[str] = None

class ProviderResponse(ProviderBase):
    id: str

class PaginationInfo(BaseModel):
    page: int
    limit: int
    total: int

class ProviderListResponse(BaseModel):
    providers: List[ProviderResponse]
    pagination: PaginationInfo

class SpecialtyListResponse(BaseModel):
    specialties: List[str]
