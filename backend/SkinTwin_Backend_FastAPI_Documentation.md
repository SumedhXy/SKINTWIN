# SkinTwin Backend Development Documentation

## Purpose
This document defines the backend plan for SkinTwin after frontend completion. The backend will support authentication, PostgreSQL storage, SkinTwin records, capture history, secure image references, observable comparisons, AI-result storage, privacy controls, and doctor-care workflows.

## Product Definition
SkinTwin creates a persistent digital representation of one individual skin finding, updated through standardized photographs and longitudinal observable-change tracking. It is not a 3D model, guaranteed diagnosis system, or substitute for a dermatologist.

## Technology Stack
- Python
- FastAPI
- Uvicorn
- PostgreSQL
- SQLAlchemy
- Alembic
- Pydantic
- JWT authentication
- Argon2 or bcrypt password hashing
- Private object storage for images
- Pytest

## Recommended Structure
```text
skintwin-backend/
├── app/
│   ├── main.py
│   ├── core/              # config, security, exceptions
│   ├── database/          # session, base, migrations
│   ├── models/            # SQLAlchemy models
│   ├── schemas/           # Pydantic schemas
│   ├── api/routes/        # auth, users, skintwins, captures, comparisons, AI, sharing
│   ├── services/          # business logic and processing
│   ├── dependencies/      # authentication and database dependencies
│   └── tests/
├── .env
├── .env.example
├── requirements.txt
└── alembic.ini
```

## Implementation Phases

### 1. FastAPI Foundation
- Create the FastAPI app.
- Add `/health` and `/` endpoints.
- Configure CORS for the existing frontend.
- Add environment-based configuration.
- Use API versioning such as `/api/v1`.

### 2. PostgreSQL Setup
- Create a PostgreSQL database.
- Configure SQLAlchemy.
- Add a database session dependency.
- Configure Alembic migrations.
- Keep credentials and secrets in `.env`.

Example environment values:
```env
DATABASE_URL=postgresql+psycopg://username:password@localhost:5432/skintwin
JWT_SECRET_KEY=replace_with_a_secure_random_secret
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
FRONTEND_ORIGIN=http://localhost:3000
```

### 3. Database Tables

#### users
Stores account information:
- id
- email (unique)
- password_hash
- full_name
- is_active
- created_at
- updated_at
- last_login_at

#### skintwins
Represents one individual skin finding:
- id
- user_id
- public_id
- name
- body_location
- body_side
- description
- status
- created_at
- updated_at
- last_capture_at

#### captures
Stores every capture connected to a SkinTwin:
- id
- skintwin_id
- user_id
- image_object_key
- image_hash
- captured_at
- uploaded_at
- body_location
- device and lighting metadata
- quality_status
- quality_score
- reference_scale_available
- measurement_status

#### comparisons
Stores comparison results:
- id
- skintwin_id
- user_id
- earlier_capture_id
- latest_capture_id
- comparison_status
- alignment_status
- observable_change_summary
- size and area changes
- color, shape, border, and texture observations
- created_at

#### ai_results
Stores AI or rule-based processing outputs:
- capture_id
- model_name
- model_version
- task_type
- result_status
- predicted_category
- confidence_value
- uncertainty_message
- explanation
- created_at

#### notes
Stores user-entered information:
- user_id
- skintwin_id
- capture_id
- note_text
- symptoms
- created_at
- updated_at

#### sharing_permissions
Stores user-controlled sharing:
- user_id
- skintwin_id
- recipient identifier
- permission level
- expiry time
- revoked time
- created_at

## Authentication

### Registration
`POST /api/v1/auth/register`

Tasks:
- Validate email and password.
- Hash the password.
- Reject duplicate email.
- Never return password or password hash.

### Login
`POST /api/v1/auth/login`

The endpoint verifies credentials and returns a short-lived access token.

### Current User
`GET /api/v1/users/me`

Returns only the authenticated user's profile.

### Authorization Rules
Every protected endpoint must:
1. Identify the authenticated user.
2. Verify ownership of the requested resource.
3. Check sharing permissions when applicable.
4. Avoid exposing private information in errors.

## Main API Endpoints

### SkinTwins
```text
POST   /api/v1/skintwins
GET    /api/v1/skintwins
GET    /api/v1/skintwins/{skintwin_id}
PATCH  /api/v1/skintwins/{skintwin_id}
DELETE /api/v1/skintwins/{skintwin_id}
```

### Captures
```text
POST /api/v1/skintwins/{skintwin_id}/captures
GET  /api/v1/skintwins/{skintwin_id}/captures
GET  /api/v1/captures/{capture_id}
DELETE /api/v1/captures/{capture_id}
```

### Comparisons
```text
POST /api/v1/skintwins/{skintwin_id}/comparisons
GET  /api/v1/skintwins/{skintwin_id}/comparisons
GET  /api/v1/comparisons/{comparison_id}
```

### AI Results
```text
GET /api/v1/captures/{capture_id}/ai-results
GET /api/v1/comparisons/{comparison_id}/ai-results
```

### Sharing
```text
POST   /api/v1/skintwins/{skintwin_id}/shares
GET    /api/v1/skintwins/{skintwin_id}/shares
DELETE /api/v1/shares/{share_id}
```

## Capture Workflow
```text
Frontend camera
→ authenticated upload
→ ownership check
→ file validation
→ private image storage
→ capture metadata record
→ image quality check
→ AI processing when available
→ store result
→ update SkinTwin timeline
```

Use private object storage for images. PostgreSQL should generally store the image reference and metadata, not large image binaries.

## Measurement and Digital Twin Logic
Possible stored values:
- Estimated width and height
- Estimated area
- Pixel dimensions
- Reference-scale status
- Measurement confidence
- Measurement availability

Exact physical measurements require calibration, such as a known reference object or validated camera setup. If calibration is unavailable, show that physical measurement is unavailable rather than inventing an exact value.

Suggested measurement statuses:
```text
measured
estimated
not_calibrated
unavailable
requires_review
```

Historical captures must remain unchanged. New captures create new records and update the timeline.

## AI Strategy

### Initial MVP
Start with:
- Image quality checks
- Basic image normalization
- Observable image comparison
- Timeline storage
- Rule-based care guidance
- Explicit uncertainty states

### Later Modules
- Image quality model
- Skin region segmentation
- Observable change detection
- Disease classification
- Longitudinal progression research model

Disease classification and progression prediction require expert-verified labels, diverse skin tones and devices, patient-level data splits, sensitivity/specificity, calibration, subgroup evaluation, false-negative analysis, clinical validation, and regulatory assessment. Model confidence must not automatically be presented as a confirmed diagnosis or medically validated probability.

## Privacy and Security
- Hash passwords with a modern password-hashing algorithm.
- Use HTTPS in production.
- Keep secrets outside source control.
- Apply ownership checks to every private resource.
- Keep images private.
- Use short-lived signed URLs when required.
- Validate file type and size.
- Never trust client-supplied user IDs.
- Do not log passwords or image contents.
- Support deletion and permission revocation.
- Configure CORS narrowly in production.
- Add authentication rate limiting.
- Define retention and deletion policies.

## Consistent Error Format
```json
{
  "error": {
    "code": "CAPTURE_NOT_FOUND",
    "message": "The requested capture could not be found.",
    "request_id": "unique-request-id"
  }
}
```

Do not expose SQL queries, stack traces, secrets, internal paths, or another user's data.

## Testing Plan
- Registration and duplicate-email tests
- Login and invalid-credential tests
- Protected-route tests
- Token expiry tests
- Ownership and permission tests
- SkinTwin CRUD tests
- Upload type and size validation
- Private image access tests
- Comparison unavailable/error-state tests
- Sharing and revocation tests
- Data deletion tests

## Recommended Roadmap
1. FastAPI app and health endpoint
2. Configuration and CORS
3. PostgreSQL connection
4. SQLAlchemy and Alembic
5. Users table
6. Authentication and JWT
7. SkinTwin CRUD
8. Capture metadata and private image upload
9. Image quality checks
10. Observable comparison and timeline
11. AI-result interface
12. Sharing and care guidance
13. Frontend integration
14. Security and automated testing

## AI Coding Agent Rules
- Inspect the repository before editing.
- Preserve the existing frontend.
- Implement one milestone at a time.
- Keep SQLAlchemy models separate from Pydantic schemas.
- Keep business logic in service modules.
- Use dependency injection.
- Write tests for every endpoint.
- Never hardcode credentials.
- Never claim medical accuracy without evidence.
- Preserve historical records.
- Represent uncertainty and unavailable states explicitly.
- Run formatting, linting, and tests after changes.
- Summarize changed files and remaining issues after every milestone.

## First Task
Start only with:
1. FastAPI application
2. `/health` endpoint
3. `.env` configuration
4. PostgreSQL connection
5. SQLAlchemy session
6. Alembic setup
7. Users table
8. Database connection test

Do not implement disease prediction, segmentation, or progression prediction during the initial setup.
