# SkinTwin

### A Privacy-First Digital Twin for Longitudinal Skin Tracking

> **Analyze. Track. Compare. Understand.**

SkinTwin is a privacy-first, phone-first platform that creates a persistent digital representation of an individual skin finding and maintains its visual history over time.

Instead of treating every skin photograph as an isolated image, SkinTwin connects standardized captures, image analysis, observable measurements, comparisons, notes, and timeline history into a single digital twin for that specific skin finding.

The goal is not to replace a dermatologist or provide a medical diagnosis. The goal is to help users document, organize, and understand observable changes over time, while making that information easier to discuss with healthcare professionals.

## What Makes SkinTwin Different?

Most image-based skin applications focus primarily on answering:

> "What does this image look like?"

SkinTwin focuses on a broader question:

> "What is this specific skin finding, how has it changed over time, and how can I maintain a structured history of it?"

That difference is the foundation of SkinTwin.

### The Digital Twin Concept

A SkinTwin is a persistent digital representation of one specific physical skin finding. It is continuously updated through new photographic captures and observations.

```text
Physical skin finding
	   |
	   v
      SkinTwin
	   |
  +-------+-------+
  |       |       |
Photos  Notes  Measurements
	   |
	   v
    Timeline history
	   |
	   v
 Comparison and change
	   |
	   v
 Understanding and care
```

A SkinTwin can contain:

- Photographic captures and capture dates
- Body/location information and user notes
- Image-quality results
- Computer-vision analysis and segmentation results
- Observable measurements
- Capture-to-capture comparisons
- Reliability and uncertainty
- AI-generated explanations
- Care-discovery information

This allows the user to build a longitudinal visual history rather than maintaining disconnected photographs.

## Problem

Skin findings are often documented informally. A person may notice something on their skin, take a photograph, save it somewhere in their phone gallery, take another photograph weeks later, and then struggle to remember whether it changed.

This creates several problems:

- No structured history
- Inconsistent photographs
- Difficult visual comparison
- Poor organization of previous observations
- Limited context when discussing the finding with a healthcare professional

SkinTwin addresses this by creating a persistent digital history around the finding itself.

## Solution

SkinTwin combines standardized capture, image-quality analysis, computer vision, region segmentation, observable feature extraction, longitudinal tracking, comparison, reliability and uncertainty reporting, AI explanation, and care discovery.

### Core User Journey

```text
Register / Login
	|
	v
Create SkinTwin
	|
	v
Capture / Upload Photograph
	|
	v
Image Quality Check
	|
	v
Alignment -> Segmentation -> Feature Extraction
	|
	v
Store Capture -> Build Timeline
	|
	v
Capture Again Later -> Compare Observations
	|
	v
Reliability + Uncertainty
	|
	v
AI Explanation -> Find Care / Discuss With Professional
```

## Key Features

### Secure Authentication

Users can register, log in, log out, change their password, and manage their account. Authentication protects access to private SkinTwin data.

### Create and Manage SkinTwins

Users can create individual SkinTwins for specific skin findings. Each SkinTwin maintains its own identity, location, captures, timeline, notes, measurements, and comparisons.

### Intelligent Capture and Image Quality Analysis

Users can capture a new photograph or upload an existing image. The system evaluates resolution, blur, lighting, and image suitability before continuing.

### Computer Vision Pipeline

The image-processing pipeline includes quality analysis, preprocessing, alignment, segmentation, feature extraction, and comparison. OpenCV is used for important image-processing operations.

### AI-Assisted Segmentation

SkinTwin supports MedSAM-based segmentation where the required model and weights are available. It also maintains a documented fallback path for environments where the full model cannot run.

### Observable Measurements

The system can extract observable characteristics including area, shape, color, and spatial position. These are observable image measurements, not biological measurements.

### Comparison Engine

Users can select captures from different dates and compare area, shape, color, spatial difference, alignment quality, reliability, and uncertainty.

### Reliability and Uncertainty

Not every image comparison is equally reliable. Lighting, camera distance, camera angle, blur, poor segmentation, and inconsistent capture conditions can affect the result.

> **Observed Difference does not equal Confirmed Biological Change.**

### AI Explanation Layer

The architecture supports deterministic/local explanations, AI provider integration, structured output, validation, fallback responses, error handling, and rate-limit handling. The AI explains available observations rather than inventing medical conclusions.

### Find Care

Users can explore healthcare options using location, specialty, distance, and provider details. This feature is intended for discovery and navigation, not for ranking doctors or claiming medical outcomes.

## Privacy and Safety

Skin photographs are sensitive personal data. SkinTwin is designed around authentication, ownership enforcement, private image access, secure credentials, user-controlled data, and no automatic sharing.

The application follows these principles:

1. No diagnostic certainty
2. Visible uncertainty
3. Human professionals remain central
4. AI is an assistant, not a substitute for clinical judgment
5. Observable image changes are not automatically biological changes

Where an appropriate and validated analysis model is available, SkinTwin may provide contextual information about possible visual patterns or conditions. A possible condition is not a diagnosis.

## System Architecture

```text
Flutter mobile / web UI
	   |
	  HTTPS
	   |
FastAPI REST API
    |       |       |
 Auth   PostgreSQL  Object Storage
	   |
    Analysis Engine
 OpenCV | Alignment | Segmentation
 MedSAM | Measurements | Comparison
	   |
 AI Explanation Layer
```

## Technology Stack

### Frontend

- Flutter and Dart
- Dio
- Provider
- Flutter Secure Storage

### Backend

- FastAPI and Python
- Pydantic
- SQLAlchemy and Alembic
- JWT authentication
- bcrypt

### Computer Vision and AI

- OpenCV
- MedSAM
- Python-based image processing
- AI explanation provider integration

### Testing

- Pytest
- Flutter Test
- Flutter Analyze

### Deployment

Designed for Android, Flutter Web, cloud-hosted FastAPI, managed PostgreSQL, and private object storage.

## Project Structure

```text
SkinTwin/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── core/
│   │   └── main.py
│   ├── alembic/
│   ├── tests/
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   ├── android/
│   ├── web/
│   └── pubspec.yaml
├── docs/
├── render.yaml
└── README.md
```

## Local Development

### Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
alembic upgrade head
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

API: `http://localhost:8000`

Health check: `http://localhost:8000/health`

### Flutter

```powershell
cd frontend
flutter pub get
flutter run
```

For a specific backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

The repository root also includes `start.bat` for starting the backend and Flutter web app together from the correct project directory.

## Testing

```powershell
cd backend
pytest -q
```

```powershell
cd frontend
flutter analyze
flutter test
```

Build commands:

```powershell
flutter build apk --release
flutter build web --release
```

## Current Limitations

SkinTwin is an engineering prototype and has important limitations:

- Results depend on photograph quality and capture consistency.
- Observable image measurements should not automatically be interpreted as biological changes.
- SkinTwin is not a diagnostic system.
- AI-generated explanations can be imperfect.
- MedSAM performance depends on model availability, compute resources, and image characteristics.
- The application is not clinically validated without appropriate clinical studies and validation datasets.
- Find Care is a discovery and navigation feature, not a medical recommendation or endorsement.

## Future Roadmap

### Phase 1: Core Platform

- Authentication
- SkinTwin creation
- Capture management
- Image quality analysis
- Timeline and comparison
- Privacy controls
- Account management

### Phase 2: Computer Vision

- OpenCV processing
- Image alignment
- Segmentation pipeline
- Observable measurements
- Reliability and uncertainty

### Phase 3: Intelligence

- AI explanation architecture
- Larger validated analysis datasets
- Improved segmentation evaluation
- Improved capture-quality guidance
- Stronger uncertainty estimation

### Phase 4: Product

- Adaptive capture coach
- Ghost/reference overlay
- Clinician-friendly report export
- Expanded care-discovery integrations
- Performance optimization
- Broader device testing

### Phase 5: Validation

- Curated annotated datasets
- Reproducibility evaluation
- Segmentation metrics
- Capture repeatability evaluation
- External expert review
- Appropriate clinical validation

## Evaluation Metrics

Future model and pipeline evaluation should focus on engineering metrics such as:

- IoU and Dice score
- Segmentation failure rate
- Alignment error
- Repeatability
- Image-quality detection accuracy
- Processing time
- False-positive and false-negative behavior where applicable

Clinical claims should only be made after appropriate clinical validation.

## Security Principles

- JWT-based authentication
- Password hashing
- Protected API routes
- Ownership enforcement
- Input and image validation
- Private storage
- Environment-based secrets
- Rate limiting
- Authenticated image retrieval
- Account deletion
- User-controlled data

Secrets such as `DATABASE_URL`, `JWT_SECRET_KEY`, AI API keys, and storage credentials must never be committed to the repository.

## Design Philosophy

1. **Finding-centric:** the application revolves around a specific physical finding, not individual photographs.
2. **Longitudinal:** the value comes from observing the same finding over time.
3. **Observable:** the system focuses on measurable visual characteristics rather than biological claims.
4. **Uncertainty-aware:** the system communicates limitations instead of presenting every result as certain.
5. **Human-centered:** AI and computer vision support the user and healthcare conversation rather than replacing professional judgment.

## Medical Disclaimer

SkinTwin is a technology prototype intended for tracking, documentation, image analysis, and informational support. It is not a medical diagnosis system, does not replace professional medical examination, and should not be used to determine whether a skin finding is harmless or serious.

Any concerning or changing skin finding should be evaluated by an appropriate healthcare professional.

## Project Status

**Current stage:** Engineering prototype / development

The project is being developed toward Android deployment, web deployment, cloud backend deployment, more extensive testing, computer-vision evaluation, and future validation.

> **SkinTwin turns a skin finding into a living digital timeline.**
>
> Capture -> Analyze -> Create Digital Twin -> Track -> Compare -> Understand -> Seek Care

