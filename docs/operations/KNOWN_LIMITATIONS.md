# Known Deployment Limitations

## Current platform status

This repository has not been deployed to a live production environment in this workspace. The following constraints remain until a real deployment target is configured and externally tested.

## 1. Cloud database not yet provisioned

The code supports PostgreSQL configuration through environment variables, but a managed cloud database has not been created here. Production database connectivity, migration execution, and SSL verification remain external steps.

## 2. Private storage still local by default

The default storage adapter is a secure local filesystem, which is appropriate for local development but not for a remote deployment that must survive developer laptop shutdown. A private object store or persisted backend storage volume is required for a true production deployment.

## 3. Stateless JWT behavior

The backend uses stateless JWT tokens, so logout does not invalidate already-issued tokens until expiry. This is intentionally documented in the auth responses and UI.

## 4. No live external browser verification yet

The prompt requires testing the application from a device that is not the developer workstation. That cannot be completed without a real frontend URL and backend hosting environment.

## 5. MedSAM remains computationally intensive

MedSAM is a heavy inference model and may fail under resource constraints. The app must surface fallback results or a clear error state instead of claiming successful processing.

## 6. AI provider dependence remains optional, not guaranteed

Gemini configuration is supported via environment variables, but production AI call success still depends on network access, quotas, and external provider availability.

## 7. No provider secrets should be committed

Any real secret values must remain in environment variables, cloud secret stores, or deployment platform configuration and must never be placed in source control.

## 8. Security review is not a formal audit

The repository documents security and privacy measures, but it is not a substitute for a third-party security review or compliance assessment.

## 9. External deployment test is mandatory before shareable status

A URL is only shareable after the frontend and backend are externally reachable, health checks pass, and the full app journey is validated on a non-local browser.
