from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException, Request
from app.schemas.find_care import ProviderResponse, ProviderListResponse, PaginationInfo, SpecialtyListResponse
from app.api.v1.endpoints.auth import get_current_user
from app.core.rate_limit import limiter
from app.core.config import settings
import httpx
import math

router = APIRouter()

@router.get("/providers/nearby-open", response_model=ProviderListResponse)
@limiter.limit("10/minute")
def get_open_map_nearby_providers(
    request: Request,
    latitude: float = Query(..., ge=-90.0, le=90.0),
    longitude: float = Query(..., ge=-180.0, le=180.0),
    radius_km: float = Query(10.0, ge=0.1, le=50.0),
    current_user: dict = Depends(get_current_user),
):
    """Return nearby OpenStreetMap healthcare listings through Overpass."""
    if not settings.OPEN_MAPS_ENABLED:
        raise HTTPException(status_code=503, detail="OpenStreetMap nearby search is disabled.")

    query = f"""[out:json][timeout:15];(nwr[\"healthcare\"~\"doctor|clinic\"](around:{radius_km * 1000},{latitude},{longitude});nwr[\"amenity\"~\"clinic|hospital\"](around:{radius_km * 1000},{latitude},{longitude}););out center tags;"""
    try:
        response = httpx.post(settings.OPEN_MAPS_OVERPASS_URL, data={"data": query}, headers={"User-Agent": "SkinTwin Find Care MVP"}, timeout=20)
        response.raise_for_status()
        places = response.json().get("elements", [])
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="OpenStreetMap nearby search is temporarily unavailable.")

    providers = []
    for place in places[:20]:
        tags = place.get("tags", {})
        center = place.get("center", place)
        name = tags.get("name")
        specialty = f"{tags.get('healthcare:speciality') or tags.get('healthcare:specialty') or tags.get('speciality') or 'Healthcare provider'}"
        if not name:
            continue
        providers.append(ProviderResponse(
            id=f"osm_{place.get('type')}_{place.get('id')}", name=name,
            specialty=specialty, address=tags.get("addr:full") or ", ".join(filter(None, [tags.get("addr:street"), tags.get("addr:city")])),
            latitude=center.get("lat"), longitude=center.get("lon"),
            consultation_types=["in_person"], languages=[],
            verification_status="openstreetmap_listing_unverified",
            data_source="openstreetmap", is_test_data=False,
            appointment_information="Verify services and appointment details directly with the business.",
            recommendation_reason="Nearby healthcare listing discovered through OpenStreetMap. This is not medical validation.",
            map_url=f"https://www.openstreetmap.org/{place.get('type')}/{place.get('id')}",
        ))
    return ProviderListResponse(providers=providers, pagination=PaginationInfo(page=1, limit=20, total=len(providers)))

# [TEST DATA] Mock fixtures for Milestone 7.4
MOCK_PROVIDERS = [
    {
        "id": "prov_1001",
        "name": "[TEST DATA] Dr. Sarah Jenkins, MD",
        "specialty": "Board Certified Dermatologist",
        "specialization": "General & Pediatric Dermatology",
        "qualifications": "MD, FAAD (Stanford Medicine)",
        "experience_years": 14,
        "clinic_name": "UCSF Dermatology & Skin Health Center",
        "address": "1701 Divisadero St, San Francisco, CA 94115",
        "city": "San Francisco, CA",
        "latitude": 37.7865,
        "longitude": -122.4402,
        "profile_description": "Specializing in comprehensive longitudinal mole tracking, inflammatory skin disorders, and preventative dermatologic screening.",
        "services": ["Mole Mapping", "Acne & Rosacea Management", "Skin Cancer Screening", "Eczema Therapy"],
        "contact_information": "+1 (415) 555-0142",
        "distance_km": 1.2,
        "consultation_types": ["telehealth", "in_person"],
        "languages": ["English", "Spanish"],
        "fee_range": "$150 - $300",
        "verification_status": "mock_unverified",
        "data_source": "mock_fixtures",
        "booking_url": "https://example.com/book/1001",
        "is_test_data": True,
        "availability": "Next Available: Tomorrow, 10:00 AM",
        "rating": "4.9 ★ (184 reviews)",
        "map_url": "https://maps.google.com/?q=37.7865,-122.4402",
    },
    {
        "id": "prov_1002",
        "name": "[TEST DATA] Dr. Marcus Chen, MD",
        "specialty": "Dermatopathologist & Skin Specialist",
        "specialization": "Skin Biopsies & Lesion Pathology",
        "qualifications": "MD, FCAP, FAAD (Harvard Medical School)",
        "experience_years": 18,
        "clinic_name": "Bay Area Skin & Cancer Institute",
        "address": "450 Sutter St, San Francisco, CA 94108",
        "city": "San Francisco, CA",
        "latitude": 37.7892,
        "longitude": -122.4086,
        "profile_description": "Expert in microscopic skin tissue evaluation, atypical pigmented lesions, and complex diagnostic dermatology.",
        "services": ["Histopathology", "Atypical Mole Evaluation", "Dermoscopy Analysis", "Second Opinion Consults"],
        "contact_information": "+1 (415) 555-0189",
        "distance_km": 2.5,
        "consultation_types": ["in_person"],
        "languages": ["English", "Mandarin"],
        "fee_range": None,
        "verification_status": "mock_unverified",
        "data_source": "mock_fixtures",
        "booking_url": None,
        "is_test_data": True,
        "availability": "Next Available: Thursday, 2:30 PM",
        "rating": "4.8 ★ (94 reviews)",
        "map_url": "https://maps.google.com/?q=37.7892,-122.4086",
    },
    {
        "id": "prov_1003",
        "name": "[TEST DATA] Dr. Elena Rostova, MD",
        "specialty": "Clinical Dermatology & Oncology",
        "specialization": "Melanoma & Cutaneous Oncology",
        "qualifications": "MD, PhD (Johns Hopkins University)",
        "experience_years": 12,
        "clinic_name": "California Pacific Medical Center Dermatology",
        "address": "2333 Buchanan St, San Francisco, CA 94115",
        "city": "San Francisco, CA",
        "latitude": 37.7915,
        "longitude": -122.4302,
        "profile_description": "Dedicated to early detection of melanoma, non-melanoma skin cancers, and advanced topical therapeutics.",
        "services": ["Photodynamic Therapy", "Melanoma Screening", "High-Risk Surveillance", "Digital Dermoscopy"],
        "contact_information": "+1 (415) 555-0199",
        "distance_km": 4.5,
        "consultation_types": ["telehealth", "in_person"],
        "languages": ["English", "Russian"],
        "fee_range": "$200+",
        "verification_status": "mock_unverified",
        "data_source": "mock_fixtures",
        "booking_url": "https://example.com/book/1003",
        "is_test_data": True,
        "availability": "Next Available: Friday, 9:15 AM",
        "rating": "5.0 ★ (210 reviews)",
        "map_url": "https://maps.google.com/?q=37.7915,-122.4302",
    },
    {
        "id": "prov_1004",
        "name": "[TEST DATA] Dr. David Vance, MD",
        "specialty": "Dermatological Surgeon",
        "specialization": "Mohs Micrographic Surgery & Reconstruction",
        "qualifications": "MD, FACMS (UCLA David Geffen School of Medicine)",
        "experience_years": 20,
        "clinic_name": "Oakland Specialty Surgery & Skin Group",
        "address": "3300 Webster St, Oakland, CA 94609",
        "city": "Oakland, CA",
        "latitude": 37.8188,
        "longitude": -122.2647,
        "profile_description": "Fellowship-trained Mohs surgeon focusing on precise surgical excision, cyst removal, and scar minimization.",
        "services": ["Mohs Micrographic Surgery", "Excisions & Biopsies", "Cyst Removal", "Scar Revision"],
        "contact_information": "+1 (510) 555-0177",
        "distance_km": 15.0,
        "consultation_types": ["in_person"],
        "languages": ["English"],
        "fee_range": None,
        "verification_status": "mock_unverified",
        "data_source": "mock_fixtures",
        "booking_url": None,
        "is_test_data": True,
        "availability": "Next Available: Today, 4:00 PM",
        "rating": "4.9 ★ (112 reviews)",
        "map_url": "https://maps.google.com/?q=37.8188,-122.2647",
    },
    {
        "id": "prov_1005",
        "name": "[TEST DATA] Manhattan Skin Health",
        "specialty": "Mount Sinai Dermatology",
        "specialization": "Trichology, Hair Disorders & General Dermatology",
        "qualifications": "MD, FAAD (Columbia University)",
        "experience_years": 16,
        "clinic_name": "Mount Sinai Doctors - Upper East Side",
        "address": "1190 5th Ave, New York, NY 10029",
        "city": "New York, NY",
        "latitude": 40.7903,
        "longitude": -73.9526,
        "profile_description": "Comprehensive skin and hair health center offering cutting-edge evaluations for scalp disorders, psoriasis, and pigmentary issues.",
        "services": ["Trichoscopy", "Alopecia Evaluation", "Psoriasis Biologics", "Patch Testing"],
        "contact_information": "+1 (212) 555-0133",
        "distance_km": 4100.0,
        "consultation_types": ["telehealth", "in_person"],
        "languages": ["English"],
        "fee_range": "$300 - $500",
        "verification_status": "mock_unverified",
        "data_source": "mock_fixtures",
        "booking_url": "https://example.com/book/1005",
        "is_test_data": True,
        "availability": "Next Available: Tomorrow, 11:30 AM",
        "rating": "5.0 ★ (340 reviews)",
        "map_url": "https://maps.google.com/?q=40.7903,-73.9526",
    },
]

@router.get("/providers", response_model=ProviderListResponse)
@limiter.limit("30/minute")
def get_providers(
    request: Request,
    latitude: Optional[float] = Query(None, description="User latitude"),
    longitude: Optional[float] = Query(None, description="User longitude"),
    radius_km: float = Query(50.0, ge=0.0, le=100.0, description="Search radius in km"),
    search: Optional[str] = Query(None, max_length=100),
    specialty: Optional[str] = Query(None, description="Filter by specialty"),
    consultation_mode: Optional[str] = Query(None, description="telehealth or in_person"),
    consultation_type: Optional[str] = Query(None, include_in_schema=False),
    language: Optional[str] = Query(None, max_length=50),
    min_fee: Optional[float] = Query(None, ge=0.0),
    max_fee: Optional[float] = Query(None, ge=0.0),
    sort: str = Query("relevance", pattern="^(relevance|distance|name|fee)$"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=50, description="Results per page"),
    limit: Optional[int] = Query(None, ge=1, le=50, include_in_schema=False),
    current_user: dict = Depends(get_current_user), # Require auth for PII safety, though we don't store location.
):
    # Validation for lat/lon boundaries
    if latitude is not None and (latitude < -90.0 or latitude > 90.0):
        raise HTTPException(status_code=422, detail="Latitude must be between -90 and 90")
    if longitude is not None and (longitude < -180.0 or longitude > 180.0):
        raise HTTPException(status_code=422, detail="Longitude must be between -180 and 180")
    if (latitude is None) != (longitude is None):
        raise HTTPException(status_code=422, detail="Latitude and longitude must be provided together")
    if min_fee is not None and max_fee is not None and min_fee > max_fee:
        raise HTTPException(status_code=422, detail="min_fee cannot exceed max_fee")

    filtered_providers = MOCK_PROVIDERS.copy()
    requested_mode = consultation_mode or consultation_type
    effective_page_size = limit or page_size

    # Mock records must not expose fabricated commercial or availability claims.
    for provider in filtered_providers:
        if provider.get("is_test_data"):
            provider["fee_range"] = None
            provider["booking_url"] = None
            provider["availability"] = None
            provider["rating"] = None

    # Apply filters
    if search:
        needle = search.lower().strip()
        filtered_providers = [
            p for p in filtered_providers
            if any(needle in str(p.get(field, "")).lower() for field in ("name", "specialty", "address", "clinic_name", "city"))
        ]

    if specialty and specialty.lower() != "all":
        filtered_providers = [p for p in filtered_providers if specialty.lower() in p["specialty"].lower()]
    
    if requested_mode and requested_mode.lower() != "all":
        filtered_providers = [p for p in filtered_providers if requested_mode.lower() in p["consultation_types"]]

    if language:
        filtered_providers = [p for p in filtered_providers if language.lower() in [item.lower() for item in p["languages"]]]

    # Mock fixtures intentionally have no reliable fee values, so fee filters return no results.
    if min_fee is not None or max_fee is not None:
        filtered_providers = [p for p in filtered_providers if p.get("fee_numeric") is not None]

    # Simple mock distance filtering (ignoring actual lat/lon math for mock data, just using the mock distance_km)
    filtered_providers = [p for p in filtered_providers if p["distance_km"] <= radius_km]

    # Pagination
    if sort == "name":
        filtered_providers.sort(key=lambda p: p["name"].lower())
    elif sort == "distance":
        filtered_providers.sort(key=lambda p: p["distance_km"])

    total = len(filtered_providers)
    start = (page - 1) * effective_page_size
    end = start + effective_page_size
    paginated_providers = filtered_providers[start:end]

    for provider in paginated_providers:
        reasons = []
        if specialty and specialty.lower() != "all" and specialty.lower() in provider["specialty"].lower():
            reasons.append("matches your selected specialty")
        if requested_mode and requested_mode.lower() != "all" and requested_mode.lower() in provider["consultation_types"]:
            reasons.append("matches your consultation mode")
        if language and language.lower() in [item.lower() for item in provider["languages"]]:
            reasons.append("matches your language preference")
        if latitude is not None and provider["distance_km"] <= radius_km:
            reasons.append("is within your selected location radius")
        provider["recommendation_reason"] = (
            " and ".join(reasons).capitalize() + "." if reasons
            else "Included in the neutral provider discovery list."
        )

    return ProviderListResponse(
        providers=[ProviderResponse(**p) for p in paginated_providers],
        pagination=PaginationInfo(
            page=page,
            limit=effective_page_size,
            total=total
        )
    )

@router.get("/providers/{provider_id}", response_model=ProviderResponse)
def get_provider(
    provider_id: str,
    current_user: dict = Depends(get_current_user),
):
    for provider in MOCK_PROVIDERS:
        if provider["id"] == provider_id:
            return ProviderResponse(**provider)
    raise HTTPException(status_code=404, detail="Provider not found")

@router.get("/specialties", response_model=SpecialtyListResponse)
def get_specialties(
    current_user: dict = Depends(get_current_user),
):
    return SpecialtyListResponse(
        specialties=[
            "All",
            "Dermatologist",
            "Pediatric Dermatology",
            "Dermatopathologist",
            "Clinical Dermatology",
            "Dermatological Surgeon",
            "Trichologist & Hair Specialist",
            "Cosmetic Dermatology",
            "General Physician"
        ]
    )
