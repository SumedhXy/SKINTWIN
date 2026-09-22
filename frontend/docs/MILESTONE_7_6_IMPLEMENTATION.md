# Milestone 7.6 Find Care Implementation

## Implemented

- Find Dermatologists header with current location state and explicit location action.
- Server-backed search across provider name, clinic/address, city, and specialty.
- Specialty and consultation-mode quick filters.
- Neutral sorting by recommendation relevance, distance, or name.
- Recommendation explanation text based on selected preferences.
- Loading, empty, failed, and retry states.
- Provider cards with test-data labels and kilometer distances.
- Provider details with supported clinic/profile fields and safety notice.
- Booking links are shown only for verified non-test providers.
- Existing authentication, rate limiting, foreground location, and manual-location flow are preserved.

## Recommendation behavior
Recommendations are explainable preference matches. They do not use SkinTwin images, comparison results, diagnoses, or hidden medical quality scores. With no preferences, the list is neutral provider discovery.

## Privacy
Precise location is used only after explicit user action for a provider search. SkinTwin images and comparison results are not shared with providers. No background location tracking is implemented.

## Data limitations
Current providers are mock fixtures and are labeled as test data. They do not represent verified doctors, live availability, real reviews, or reliable fees. The web build cannot use the current native geocoding plugin, so web users can continue with the neutral list.

## Validation
Backend Find Care tests cover listing, pagination, search, recommendation reasons, consultation filtering, sorting, coordinate-pair validation, fee-range validation, details, specialties, and unauthorized access. Flutter model/provider tests and targeted analysis should be run with the repository commands before release.

## Physical testing checklist

- Test camera/location permission prompts on Android.
- Test denied and permanently denied GPS permission.
- Test manual location on a native device.
- Confirm provider cards and details render on a small phone.
- Confirm no location request occurs until the user taps the location action.
- Confirm mock-data labels and booking restrictions remain visible.
