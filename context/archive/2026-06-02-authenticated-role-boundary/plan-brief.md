# Authenticated Role Boundary - Plan Brief

> Full plan: `context/changes/authenticated-role-boundary/plan.md`

## What & Why

Build LiftMate's first real auth boundary: users can register, log in, hold a secure mobile session, and prove whether they are a trainer or trainee through protected API endpoints. This foundation is needed before trainer-trainee pairing and training-data access rules can be trusted.

## Starting Point

The API is scaffold-level with public `/health` and `/weatherforecast`; there is no auth, database, role policy, or API test project. The Flutter app currently starts on a `/health` smoke screen from F-01.

## Desired End State

The API uses ASP.NET Identity, EF Core, SQL Server-ready migrations, JWT access tokens, refresh tokens, and role policies. Registration requires an invite code so public internet users cannot freely create accounts during the MVP. The Flutter app starts with a minimal auth flow, stores tokens in secure storage, calls `/auth/me`, verifies role probes, and keeps health diagnostics available.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Auth provider | ASP.NET Identity + JWT | Fits the .NET stack and keeps role/account control in the API. |
| Persistence | EF Core + SQL Server-ready schema | Durable accounts are needed before S-01 and later training data. |
| Registration | Register, login, refresh/logout, me | Proves the full mobile/API auth loop. |
| Role model | Single immutable role | Matches the PRD and keeps permission rules simple. |
| Registration gate | Invite code required | Limits private beta registration without relying on extractable app secrets. |
| Session model | Short access token + refresh token | Balances mobile UX with revocation capability. |
| Logout contract | Bearer-authenticated refresh-token revocation | Keeps logout tied to the authenticated user and makes repeated logout safe. |
| Mobile storage | `flutter_secure_storage` | Uses platform secure storage for tokens. |
| Boundary proof | `/auth/me`, `/trainer/probe`, `/trainee/probe` | Tests token validity and role guards before real domain resources exist. |
| API tests | WebApplicationFactory integration tests | Verifies middleware, claims, policies, routing, and JSON contracts. |
| Azure rollout | Manual DB/config gate | Keeps secrets and infrastructure changes under human approval. |

## Scope

**In scope:**

- Identity user model with one immutable `trainer` or `trainee` role.
- EF Core DbContext, refresh-token storage, and initial migration.
- JWT bearer auth, role policies, and auth/probe endpoints.
- Invite-code gated registration.
- Dedicated API integration test project.
- Flutter auth client, secure token store, auth controller, auth UI, and role probe display.
- Preserved `/health` diagnostics.

**Out of scope:**

- Trainer-trainee relationship records.
- Workout templates, active sessions, training values, or progress data.
- Social login, email verification, password reset, MFA, and production abuse controls.
- Automatic Azure SQL provisioning or secret configuration.
- Realtime sync and `/weatherforecast` cleanup.

## Architecture / Approach

Flutter calls the trusted API for registration, login, refresh, logout, current-user lookup, and role probes. The API enforces all authorization through JWT validation and trainer/trainee policies backed by Identity and EF Core. Mobile stores tokens in platform secure storage and uses the health check only as diagnostics, not as the primary app flow.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. API Data and Identity Foundation | Identity, EF Core, SQL Server-ready migration, config contracts. | Accidentally committing secrets or over-expanding the data model. |
| 2. API Integration Test Harness | Separate HTTP pipeline test project and isolated test host. | Test DB setup can be brittle if not isolated. |
| 3. API Auth Endpoints and Role Probes | Register/login/refresh/logout/me plus trainer/trainee probes with integration coverage. | Getting role claims or middleware ordering wrong. |
| 4. Mobile Auth Client and Secure Session Storage | Auth client, token store, controller, and unit tests. | Token handling can leak into UI or logs if not isolated. |
| 5. Mobile Auth UI and Diagnostics | Minimal auth-first app with preserved health diagnostics. | Temporary auth UI should not become broad product navigation scope. |
| 6. Local Migration and Azure Manual Gate | Final local verification plus explicit Azure DB/config checklist. | Deployed auth depends on manual secret and migration steps. |

**Prerequisites:** F-01 mobile/API smoke path is implemented; Azure deployed API exists; Azure SQL setup requires human approval.
**Estimated effort:** ~3-5 focused implementation sessions across 6 phases.

## Open Risks & Assumptions

- The invite code is a private beta gate, not a production-grade abuse prevention system.
- Anything embedded in a mobile app can be extracted, so registration security must live server-side.
- Azure verification cannot complete until a human configures Azure SQL, App Service secrets, and approves migration.
- The role probe endpoints are temporary and should be replaced by real domain resources in later slices.

## Success Criteria (Summary)

- Users can register/login as exactly one role and mobile can restore or refresh the session.
- API denies missing-token and cross-role probe requests through server-side policies.
- API integration tests, mobile tests, `dotnet build/test`, `flutter test`, and `flutter analyze` pass locally.
