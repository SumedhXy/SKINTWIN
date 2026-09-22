# Find Care Requirements

## Scope
Find Care is a healthcare discovery feature for locating dermatology providers. It is not a diagnostic or medical ranking system.

## Provider source
The current backend uses clearly labeled mock fixtures for Milestone 7.6. Mock records are not verified professionals, and the API does not claim real ratings, fees, availability, booking, or clinical superiority. Unsupported fee filters return no fee-backed providers.

## API behavior
`GET /api/v1/find-care/providers` supports:

- `search`: name, clinic, city, address, or specialty text search.
- `latitude`, `longitude`, and `radius_km`: validated user-selected location inputs.
- `specialty`, `consultation_mode`, and `language` filters.
- `min_fee` and `max_fee` only when reliable fee data exists.
- `sort`: `relevance`, `distance`, `name`, or `fee`.
- `page` and `page_size` with bounded limits.

Authentication and rate limiting remain enabled. Coordinates must be supplied as a pair and are used only for the user-initiated search request.

## Recommendations
Recommendation reasons are rule-based and transparent. They describe matching preferences such as specialty, consultation mode, language, or selected radius. They are not medical quality scores and never identify a provider as the best doctor.

## Privacy
SkinTwin images, comparisons, AI explanations, and health observations are never sent to providers. Background location tracking is not used. Users can continue with the neutral provider list when location permission is denied.

## Known limitations
- Fixtures use representative test records and do not provide live appointment availability.
- Distance values are fixture values until a trusted provider directory with coordinates is connected.
- Manual geocoding is unavailable in the web build because the current geocoding plugin has no web implementation; users can use the neutral list or mobile manual location flow.
- Physical device testing is required for native GPS permission behavior.
