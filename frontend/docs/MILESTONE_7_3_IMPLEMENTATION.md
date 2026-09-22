# Milestone 7.3 Implementation Report
**Comparison + AI Explanation Flutter Integration**

## Overview
This milestone integrated the FastAPI MedSAM and Comparison endpoints into the Flutter application. Users can now seamlessly compare two timeline captures of a SkinTwin, view a visual slider of their differences, read technical reliability indicators, observe telemetry metric changes, and review an AI-generated explanation mapping these measurements to clinical context, while emphasizing strict safety disclaimers.

## Architecture

### `ComparisonService`
Located at `lib/core/services/comparison_service.dart`.
- Manages all CRUD HTTP endpoints.
- Handled the `/skintwins/{public_id}/comparisons` and `/comparisons/{id}/explanation` endpoints.
- Intercepts 429 timeouts and 401 unauthorized errors centrally to throw parsed warnings to the Provider.

### `ComparisonProvider`
Located at `lib/core/providers/comparison_provider.dart`.
- An independent `ChangeNotifier` state machine outside of `AppStore`.
- Managed transitions through `Idle`, `SelectingCaptures`, `Processing`, `ResultsLoaded`, and `ExplanationLoading`.
- Validates capture chronologies inherently (ensuring earliest capture is submitted first).
- Disposes securely from memory upon widget exit.

### `CompareScreen` (UI)
Located at `lib/screens/compare_screen.dart`.
- Built an inline capture selector removing the need for extraneous FAB navigation components.
- Introduced `Slider` visual widget matching baseline and latest images dynamically.
- Rendered numerical comparisons parsing `+` or `-` reliably.
- Explicitly labels MedSAM quality metadata as "Technical Reliability Indicators" instead of "Medical Confidence" to abide by system directives.
- Embedded an explicit safety banner inside the final AI explanation output.

## Automated Testing Coverage
- **Models**: Verified `ComparisonResponse` preserves accurate parsed negative signs (e.g., `-12.4`).
- **States**: Tested `validateSelection` ensuring duplicate comparisons fail and non-chronological pairings are swapped or blocked.
- **Service/Interceptors**: Mocked `DioExceptionType.receiveTimeout`, `401 Unauthorized`, and `429 Too Many Requests` validating robust UI rejection handling without crashing.

## Pending Actions for Milestone Closure
- **Physical Device Test**: Execute standard upload and render pipelines directly on an Android device to confirm `AuthenticatedImage` properly handles the image token fetching during rendering.
- **Security Check**: Double-check that JWT token deletion gracefully bumps the user back into `AuthGuard` instead of producing ghost 401s in `CompareScreen`.
