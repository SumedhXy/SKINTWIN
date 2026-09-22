# Milestone 7.4 Implementation Report
**Find Care Integration**

## Objective
Integrate a privacy-first "Find Care" feature into SkinTwin. The scope includes searching for dermatologists, filtering by specialty, and navigating provider details. The most critical aspect is strict adherence to data privacy, guaranteeing that finding a provider never sends or shares SkinTwin health data, nor infers medical diagnoses.

## Scope & Decisions
- **Data Source:** Implemented using **curated mock fixtures** labeled as `[TEST DATA]`. This bypasses BAA compliance hurdles with real external APIs for the MVP, while simulating a production-grade response structure.
- **Location Privacy:** Integrated using **simulated location** inside the MVP. We purposefully avoided `geolocator` bindings to prevent unwarranted privacy tracking on the user's device.
- **Sharing Architecture:** Completely stripped out the "Share Telemetry" feature from the UI to prevent any implication that medical data was being shared behind the scenes.

## Backend Implementation
- Created models in `app/schemas/find_care.py` featuring safe nullable bounds (for missing data like prices or availability) and mandatory `is_test_data` boolean tagging.
- Registered a dedicated APIRouter (`/api/v1/find-care`).
- Implemented `/providers`, `/providers/{id}`, and `/specialties` with pagination offsets, specialty filtering, and geographical coordinate boundaries.
- **Security Control:** Enforced authentication boundaries via the global `get_current_user` dependency, ensuring APIs can't be scraped freely, even for mock data.

## Flutter Architecture
- **Models:** Generated `ProviderResponse` in `provider_models.dart`. Handled potential `null` JSON payloads for `distance_km`, `fee_range`, `availability`, and `booking_url`.
- **State Management:** Wrote a `ChangeNotifier` called `FindCareProvider`. It tracks filter parameters (specialty, consultation type), coordinates pagination offsets, and wraps fetching states inside a standard state machine logic (`idle -> loading -> results -> empty`).
- **Network Layer:** Configured `FindCareService.dart` to inherit from the authenticated `DioClient`. Intercepts standard FastAPI outputs mapping to UI-friendly exception strings (e.g., mapping HTTP 422 to "Invalid location or search parameters.").
- **FindCareScreen:** Replaced the hardcoded static `_locationProviders` list with our dynamic Provider. Placed a distinct warning banner indicating "Development location — simulated coordinates" to uphold UI trust.
- **ProviderDetailsScreen:** Engineered a dedicated deep dive screen. Implemented emergency warning disclaimers advising users that this list is not an urgent medical triage platform. Supported direct URL launching for booking links.

## Test Results
### Backend Tests (`pytest`)
- `test_get_providers_pagination`: Passed. Validated limit bounds.
- `test_get_providers_invalid_lat_lon`: Passed. Validated 422 extraction for bounds exceeding (-90,90) and (-180,180).
- `test_get_providers_filter`: Passed. Validated substring match queries.
- `test_unauthorized_access`: Passed. Rejected unauthenticated API calls cleanly with HTTP 401.

### Frontend Tests (`flutter test`)
- `Find Care Model Parsing Tests`: Passed. Safely ignored missing fields in truncated server responses.
- `FindCareProvider State Transitions`: Passed. Validated logical flows between idle, loaded, and location simulation overrides.

## Future Improvements & Known Limitations
1. **Real Data Integration:** In a future milestone, the `FindCareService` can be bound to a real provider index (e.g., NPI registry or Google Places API) once legal boundaries are established.
2. **Native Geolocation:** When upgrading to a production release, the simulated GPS coordinate injector can be safely replaced by a `permission_handler` wrapper without refactoring the state machine.
