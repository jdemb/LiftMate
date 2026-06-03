# Authenticated Role Boundary Implementation Plan

## Overview

Build the first real authentication and authorization boundary for LiftMate. The API will support account registration, login, refresh/logout, current-user lookup, and role-protected trainer/trainee probe endpoints. The Flutter app will replace the smoke-test-first experience with a minimal auth flow while preserving the API health check as a diagnostic signal.

This is foundation slice F-02 from `context/foundation/roadmap.md`: a minimal authenticated identity and role boundary must exist before trainer-trainee pairing, shared sessions, or training-data permissions can be implemented reliably.

## Current State Analysis

### API

- `apps/api/LiftMate.Api/Program.cs:1` is still a single top-level minimal API file.
- `apps/api/LiftMate.Api/Program.cs:18` maps public `GET /health` and returns `{"status":"ok"}`.
- `apps/api/LiftMate.Api/Program.cs:26` still exposes template `/weatherforecast`; cleanup is out of scope unless it interferes with auth routing.
- `apps/api/LiftMate.Api/LiftMate.Api.csproj:4` targets `net10.0` with nullable reference types and implicit usings.
- There is no auth provider, JWT bearer setup, role policy, EF Core DbContext, migration, database connection string, or API test project.

### Mobile

- `apps/mobile/lib/main.dart:10` loads `AppConfig`, creates `ApiHealthClient`, and renders `ApiSmokeScreen`.
- `apps/mobile/lib/app_config.dart:10` reads `config/app_config.json` and allows `API_BASE_URL` override.
- `apps/mobile/lib/api_health_client.dart:43` builds `GET {baseUrl}/health` and classifies online/offline/error states.
- `apps/mobile/lib/api_smoke_screen.dart:24` runs the health check on startup and shows the endpoint plus retry.
- Mobile tests already cover config loading, health client behavior, and smoke screen states under `apps/mobile/test/`.

### Foundation Context

- `context/foundation/prd.md` defines accounts with exactly two roles: trainer and trainee.
- `context/foundation/prd.md` narrows trainer access to training data only; personal/account data edits by a trainer are out of scope.
- `context/foundation/roadmap.md` says auth is absent and F-02 unlocks S-01, S-03, S-04, and S-06.
- `context/foundation/infrastructure.md` recommends Azure App Service Free F1 plus Azure SQL Database Free for the MVP data layer.
- `AGENTS.md` requires a separate API test project when endpoint logic gains authorization or trainer-trainee permission checks.

## Desired End State

The API has a persistent ASP.NET Core Identity-backed account model using EF Core and a SQL Server-ready migration. Users can register with a single immutable role, log in, refresh tokens, log out, call `GET /auth/me`, and hit role-protected probe endpoints only when the JWT role matches.

Registration is not open to arbitrary internet users. For this MVP, `POST /auth/register` requires an invitation code supplied through secure API configuration. The mobile app is the intended client, but the plan does not pretend an app-embedded secret is a strong boundary; any value shipped inside the app can be extracted. The real MVP gate is the invite code plus rate-limited, monitored registration behavior later.

The Flutter app has a minimal auth screen for register/login, stores tokens in platform secure storage, calls `/auth/me`, verifies trainer/trainee probe access, and keeps the `/health` smoke signal available as diagnostics. Automated API integration tests and mobile tests verify the core boundary without relying on the live Azure service.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Auth provider | ASP.NET Identity + JWT | Fits the .NET stack, keeps role and account control in the trusted API, and avoids external-provider setup during the MVP. |
| Persistence | EF Core + SQL Server-ready schema | F-02 should become a durable foundation for S-01 and later training data instead of an in-memory prototype. |
| Registration scope | Register, login, refresh/logout, and me | Covers FR-001 and proves the mobile/API token flow end to end. |
| Role model | Single immutable role | Matches the PRD and keeps permission rules simple: one user is either `trainer` or `trainee`. |
| Registration gate | Invite code required | Prevents random public registration during private MVP testing without pretending the mobile app can hold an unextractable secret. |
| Token sessions | Short access token plus refresh token | Gives a normal mobile UX and a revocation point while keeping access tokens short-lived. |
| Logout contract | Bearer-authenticated refresh-token revocation | Keeps logout tied to the authenticated user, makes repeated logout safe, and gives mobile a clear token-clearing rule. |
| Mobile token storage | `flutter_secure_storage` | Uses the platform secure store instead of plain local preferences. |
| Protected probe | `/auth/me`, `/trainer/probe`, `/trainee/probe` | Separates token validity from role policy behavior and makes tests obvious before real training resources exist. |
| API tests | `WebApplicationFactory` integration tests with test database | Verifies routing, middleware, policies, claims, JSON contracts, and Identity wiring through the real HTTP pipeline. |
| Migration and Azure | Local migration plus manual Azure DB gate | Keeps code, secrets, and infrastructure operations separated; Azure SQL setup requires human approval. |
| Mobile UX | Minimal auth flow first, health preserved as diagnostic | Validates real product auth while keeping F-01's smoke signal available for debugging. |

## Scope

### In Scope

- Add ASP.NET Core Identity with an `ApplicationUser` model and one immutable role per user.
- Add EF Core DbContext, SQL Server provider, and initial migration for Identity plus refresh-token storage.
- Add JWT bearer authentication and role policies for `trainer` and `trainee`.
- Add registration invite code validation from API configuration.
- Add `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, and `GET /auth/me`.
- Add `GET /trainer/probe` and `GET /trainee/probe` as temporary role-boundary endpoints.
- Add a separate API integration test project to `apps/api/LiftMate.slnx`.
- Add mobile auth client, secure token store wrapper, auth state handling, and minimal auth UI.
- Preserve health diagnostics from F-01 in the mobile app.
- Add mobile unit/widget tests for auth client, token storage abstraction, and auth screen states.
- Document local verification and the manual Azure SQL/App Service configuration gate.

### Out of Scope

- Trainer-trainee pairing, invitations between users, or relationship records.
- Workout templates, exercise sets, active sessions, training values, or progress persistence.
- Social login, passkeys, email verification, password reset, MFA, or production account recovery.
- Real production registration hardening such as CAPTCHA, device attestation, abuse detection, or rate limiting.
- A full app navigation shell beyond the minimal auth/probe success surface.
- Realtime sync, SignalR, or polling.
- Automatic Azure SQL provisioning, App Service secret changes, firewall changes, or production migration execution by the agent.
- Removing `/weatherforecast`, unless a later review explicitly scopes API cleanup.

## Architecture

```text
Flutter app
  -> AppConfig(apiBaseUrl)
  -> AuthScreen(register/login + invite code)
  -> AuthApiClient
  -> SecureTokenStore
  -> GET /auth/me and role probe

ASP.NET Core API
  -> Identity + EF Core AppDbContext
  -> JWT bearer authentication
  -> role policies: trainer, trainee
  -> /auth/* endpoints
  -> /trainer/probe and /trainee/probe
  -> SQL Server in normal runs, isolated test database for integration tests
```

The API owns all trusted identity and role decisions. Flutter can choose screens and store tokens, but authorization is enforced server-side through JWT validation and role policies. Registration requires an invitation code because requests can come from any HTTP client once the API is public.

## Phase 1: API Data and Identity Foundation

### Goal

Introduce durable account storage and Identity wiring without exposing auth endpoints yet.

### Changes Required

#### `apps/api/LiftMate.Api/LiftMate.Api.csproj`

**Intent**: Add the packages needed for Identity, EF Core SQL Server, migrations, JWT bearer auth, and API testing compatibility.

**Contract**: Runtime packages include Identity EF Core integration, SQL Server EF Core provider, EF Core design-time tooling, and JWT bearer authentication. Package versions should align with the existing `net10.0` target and current ASP.NET Core package train.

#### `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`

**Intent**: Create the persistent database boundary for LiftMate accounts and refresh sessions.

**Contract**: Define an EF Core DbContext that derives from the appropriate Identity DbContext for `ApplicationUser`. It includes a refresh token set and applies model configuration for exactly one user role in the MVP.

#### `apps/api/LiftMate.Api/Auth/ApplicationUser.cs`

**Intent**: Represent the authenticated LiftMate user.

**Contract**: User records include Identity's normal account fields plus a single LiftMate role value constrained to `trainer` or `trainee`. Role is set during registration and has no public update endpoint.

#### `apps/api/LiftMate.Api/Auth/UserRole.cs`

**Intent**: Centralize role names so API endpoints, policies, tests, and mobile response parsing do not drift.

**Contract**: Expose stable string constants `trainer` and `trainee`. These strings are the public API contract returned by `/auth/me` and used in JWT claims.

#### `apps/api/LiftMate.Api/Auth/RefreshToken.cs`

**Intent**: Store refresh token sessions server-side so logout and refresh rotation have a revocation point.

**Contract**: Refresh token records store only a token hash, user id, created timestamp, expiry timestamp, optional revoked timestamp, and replacement-token metadata if refresh rotation is implemented.

#### `apps/api/LiftMate.Api/appsettings.json` and development configuration

**Intent**: Define non-secret config keys for auth while keeping real secrets out of source.

**Contract**: Configuration names are stable, for example `ConnectionStrings:DefaultConnection`, `Jwt:Issuer`, `Jwt:Audience`, `Jwt:SigningKey`, `Auth:RegistrationInviteCode`, `Auth:AccessTokenMinutes`, and `Auth:RefreshTokenDays`. Secret values are supplied by user secrets locally or App Service configuration in Azure.

#### `apps/api/LiftMate.Api/Program.cs`

**Intent**: Wire EF Core, Identity, JWT bearer authentication, authorization policies, and middleware ordering.

**Contract**:
- `AddDbContext<ApplicationDbContext>` uses SQL Server for normal runs.
- Identity is configured with `ApplicationUser`.
- JWT bearer auth validates issuer, audience, signing key, expiry, and role claims.
- Authorization policies exist for trainer-only and trainee-only access.
- Middleware order includes authentication before authorization.
- Existing `GET /health` remains public.

#### `apps/api/LiftMate.Api/Migrations/*`

**Intent**: Create the first database migration for Identity and refresh-token storage.

**Contract**: The migration is additive and SQL Server-ready. It does not include workout, trainer-trainee relationship, or training data tables.

### Automated Verification

- `dotnet restore LiftMate.slnx` from `apps/api`.
- `dotnet build LiftMate.slnx --no-restore` from `apps/api`.
- `dotnet ef migrations list` from the API project once EF tooling is available.

### Manual Verification

- Confirm no real JWT signing key, registration invite code, or connection string is committed.
- Confirm `/health` still returns `200 {"status":"ok"}` with auth services registered.

## Phase 2: API Integration Test Harness

### Goal

Create the separate API test project required by `AGENTS.md` before auth endpoints depend on integration-test verification.

### Changes Required

#### `apps/api/LiftMate.Api.Tests/LiftMate.Api.Tests.csproj`

**Intent**: Add a dedicated test project instead of mixing auth tests into the API project.

**Contract**: The project references `LiftMate.Api`, includes an HTTP integration testing stack such as `Microsoft.AspNetCore.Mvc.Testing`, and uses a normal .NET test framework.

#### `apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs`

**Intent**: Provide isolated test configuration for database, JWT, and invite-code settings.

**Contract**:
- Test runs do not require Azure SQL.
- Test JWT signing key and invite code are local test values only.
- Test database state is isolated per test class or per test run.
- If SQLite in-memory is used, the factory keeps the connection alive for the test scope.

#### `apps/api/LiftMate.Api.Tests/HealthEndpointTests.cs`

**Intent**: Prove the new test host can exercise the existing API before auth endpoints are added.

**Contract**: `GET /health` returns `200` and `{"status":"ok"}` through the `WebApplicationFactory` pipeline.

#### `apps/api/LiftMate.Api/Program.cs`

**Intent**: Make the minimal API entry point discoverable by `WebApplicationFactory`.

**Contract**: Add a partial `Program` type if required by the test host. This is a testing contract only and should not change runtime behavior.

#### `apps/api/LiftMate.slnx`

**Intent**: Include the new test project in the solution.

**Contract**: `dotnet test LiftMate.slnx` discovers and runs the API tests.

### Automated Verification

- `dotnet restore LiftMate.slnx` from `apps/api`.
- `dotnet build LiftMate.slnx --no-restore` from `apps/api`.
- `dotnet test LiftMate.slnx --no-build` from `apps/api`.

### Manual Verification

- Review test output to confirm the API test project is discovered and the health test is not skipped.

## Phase 3: API Auth Endpoints and Role Probes

### Goal

Expose the minimal auth contract and prove role authorization through server-enforced policies.

### Changes Required

#### `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`

**Intent**: Keep auth endpoint registration separate from `Program.cs` so the top-level file does not become the whole application.

**Contract**:
- `POST /auth/register` accepts email, password, role, and invitation code.
- `POST /auth/register` rejects missing or invalid invite codes before creating a user.
- `POST /auth/register` rejects roles outside `trainer` and `trainee`.
- `POST /auth/register` rejects attempts that would create a user without exactly one role.
- `POST /auth/login` validates credentials and returns access token, refresh token, user id, email, role, and expiry metadata.
- `POST /auth/refresh` validates the refresh token, rotates or replaces it, and returns a new token pair.
- `POST /auth/logout` requires a valid bearer access token and a request body containing `refreshToken`.
- `POST /auth/logout` revokes only the hashed refresh token that belongs to the authenticated user.
- `POST /auth/logout` is idempotent for an already-revoked refresh token belonging to the authenticated user.
- `POST /auth/logout` rejects attempts to revoke another user's refresh token.
- `GET /auth/me` requires authentication and returns current user id, email, and role.

#### `apps/api/LiftMate.Api/Auth/AuthContracts.cs`

**Intent**: Define explicit request/response DTOs for mobile and tests.

**Contract**: DTOs use stable camelCase JSON fields: `email`, `password`, `role`, `invitationCode`, `accessToken`, `refreshToken`, `expiresAt`, `user`. Logout request uses `refreshToken`.

#### `apps/api/LiftMate.Api/Auth/TokenService.cs`

**Intent**: Isolate JWT and refresh-token creation from endpoint handlers.

**Contract**:
- Access tokens include subject/user id, email, and exactly one role claim.
- Access tokens use configured issuer, audience, signing key, and short expiry.
- Refresh tokens are generated with sufficient randomness and stored hashed.
- Token refresh checks expiry and revocation before issuing a new pair.
- Logout revokes only the authenticated user's matching refresh-token hash and treats repeated revocation of the same token as success.

#### `apps/api/LiftMate.Api/Auth/RegistrationGate.cs`

**Intent**: Make private MVP registration explicit and testable.

**Contract**: Registration succeeds only when the supplied invitation code matches configuration. The implementation should document that this is an MVP/private beta gate, not a production replacement for abuse controls.

#### `apps/api/LiftMate.Api/Auth/ProbeEndpoints.cs`

**Intent**: Provide temporary role-boundary endpoints that make role policy behavior testable before real trainer/trainee resources exist.

**Contract**:
- `GET /trainer/probe` requires authenticated trainer role and returns a small JSON payload identifying trainer access.
- `GET /trainee/probe` requires authenticated trainee role and returns a small JSON payload identifying trainee access.
- A trainer token receives forbidden/unauthorized behavior on the trainee probe, and a trainee token receives forbidden/unauthorized behavior on the trainer probe.

#### `apps/api/LiftMate.Api/LiftMate.Api.http`

**Intent**: Add manual scratch requests for the auth contract.

**Contract**: Include local examples for register, login, me, refresh, logout, and both role probes without committing real secrets.

#### `apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs`

**Intent**: Cover the public auth contract end to end.

**Contract**: Tests exercise HTTP requests and JSON responses rather than directly calling endpoint methods.

#### `apps/api/LiftMate.Api.Tests/Auth/RoleProbeTests.cs`

**Intent**: Verify trainer/trainee authorization policy behavior.

**Contract**: Tests prove correct-role success and cross-role denial for both probe endpoints.

### Automated Verification

- `dotnet build LiftMate.slnx --no-restore` from `apps/api`.
- `dotnet test LiftMate.slnx --no-build` from `apps/api`.
- `dotnet list LiftMate.slnx package --vulnerable --include-transitive` from `apps/api`.
- API integration tests cover successful registration, login, me, refresh, bearer-authenticated logout, trainer probe, and trainee probe.
- API integration tests cover invalid invite code, duplicate email, invalid role, missing token, expired/invalid token where practical, and cross-role probe denial.
- API integration tests cover logout without bearer token, logout for another user's refresh token, and repeated logout of the same refresh token.

### Manual Verification

- Register a trainer locally with a configured invite code.
- Register a trainee locally with the same configured invite code.
- Confirm each can call `/auth/me`.
- Confirm trainer can call `/trainer/probe` and is denied by `/trainee/probe`.
- Confirm trainee can call `/trainee/probe` and is denied by `/trainer/probe`.
- Review test output to confirm auth tests are executed, not skipped.

## Phase 4: Mobile Auth Client and Secure Session Storage

### Goal

Add a testable Flutter auth layer that can register, log in, persist tokens securely, refresh sessions, and call protected endpoints.

### Changes Required

#### `apps/mobile/pubspec.yaml`

**Intent**: Add secure token storage support.

**Contract**: Add `flutter_secure_storage` as a runtime dependency and refresh `pubspec.lock` with `flutter pub get`.

#### `apps/mobile/lib/auth/auth_models.dart`

**Intent**: Define typed mobile auth models independent of raw JSON maps.

**Contract**: Include request and response models for registration, login, refresh, current user, and role probe results. Role strings remain `trainer` and `trainee`.

#### `apps/mobile/lib/auth/auth_api_client.dart`

**Intent**: Encapsulate auth HTTP requests and token-bearing calls.

**Contract**:
- Builds requests from `apiBaseUrl` without duplicate slashes.
- Calls `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`, `/trainer/probe`, and `/trainee/probe`.
- Sends bearer access tokens on protected requests.
- Sends both bearer access token and refresh token body on logout.
- Classifies common failures into typed results that UI can display without exposing raw exceptions.
- Does not log tokens, passwords, or invitation codes.

#### `apps/mobile/lib/auth/token_store.dart`

**Intent**: Hide platform secure storage behind a small interface so tests can use an in-memory store.

**Contract**: Store, read, and clear access token, refresh token, and token expiry metadata. Production implementation uses `flutter_secure_storage`.

#### `apps/mobile/lib/auth/auth_controller.dart`

**Intent**: Coordinate auth state for the minimal app flow.

**Contract**:
- Loads stored tokens on startup.
- Calls `/auth/me` when an access token exists.
- Attempts refresh when appropriate.
- Clears tokens on logout after the logout request completes, even when the server response is an already-logged-out or recoverable network failure.
- Clears tokens on failed refresh.
- Exposes states such as unauthenticated, loading, authenticated, and error.

#### `apps/mobile/test/auth_api_client_test.dart`

**Intent**: Verify auth request construction, parsing, and failure handling without live network calls.

**Contract**: Use fake HTTP clients to cover register, login, refresh, me, role probe, invalid JSON, non-success HTTP status, and trailing slash URL handling.

#### `apps/mobile/test/token_store_test.dart`

**Intent**: Verify the token-store abstraction without depending on platform secure storage in unit tests.

**Contract**: Cover save, read, overwrite, and clear behavior through an in-memory implementation.

### Automated Verification

- `flutter pub get` from `apps/mobile`.
- `flutter test test/auth_api_client_test.dart test/token_store_test.dart` from `apps/mobile`.
- `flutter analyze` from `apps/mobile`.

### Manual Verification

- None required in this phase beyond automated tests; full app flow is verified in Phase 5.

## Phase 5: Mobile Auth UI and Diagnostics

### Goal

Make the first mobile screen exercise the new auth boundary while preserving API health visibility for debugging.

### Changes Required

#### `apps/mobile/lib/main.dart`

**Intent**: Replace smoke-screen-first app composition with auth-first app composition.

**Contract**:
- Load `AppConfig` as before.
- Wire `ApiHealthClient`, `AuthApiClient`, `TokenStore`, and `AuthController`.
- Render the auth flow as the first screen.
- Preserve API health diagnostics either as a compact status area or an explicit diagnostic action.

#### `apps/mobile/lib/auth/auth_screen.dart`

**Intent**: Provide a minimal register/login experience that supports private beta auth.

**Contract**:
- User can switch between register and login.
- Registration collects email, password, role, and invitation code.
- Login collects email and password.
- Authenticated state shows current user email, role, and probe status.
- UI includes logout.
- Error states avoid exposing secrets and stay readable on phone-sized layouts.

#### `apps/mobile/lib/auth/role_probe_panel.dart`

**Intent**: Make role-boundary verification visible in the prototype app.

**Contract**: After authentication, call the matching role probe and show success/failure. It may also expose a debug action to test the opposite-role denial if that does not complicate UX.

#### `apps/mobile/lib/api_smoke_screen.dart` or diagnostic component

**Intent**: Reuse the existing health-check behavior without keeping it as the primary app experience.

**Contract**: Health diagnostics still call `GET /health`, still show checked endpoint and state, and remain testable with injected health-check behavior.

#### `apps/mobile/test/auth_screen_test.dart`

**Intent**: Verify the auth UI states and user actions.

**Contract**: Cover register form, login form, loading state, authenticated display, logout action, error display, and probe success display with fake auth controller/client behavior.

#### Existing mobile tests

**Intent**: Keep F-01 behavior from regressing.

**Contract**: Existing config, health client, and smoke/diagnostic tests continue to pass, adjusted only if the smoke component is renamed or embedded.

### Automated Verification

- `flutter test` from `apps/mobile`.
- `flutter analyze` from `apps/mobile`.

### Manual Verification

- Run the API locally with configured user-secrets/test settings.
- Run the Flutter app against local API:
  - Flutter web/desktop base URL: `http://localhost:5257`
  - Android emulator base URL: `http://10.0.2.2:5257`
  - Physical device base URL: `http://<developer-machine-lan-ip>:5257`
- Register a trainer using the invite code and confirm `/auth/me` and trainer probe succeed.
- Register a trainee using the invite code and confirm `/auth/me` and trainee probe succeed.
- Restart the app and confirm stored tokens restore the authenticated state or refresh successfully.
- Logout and confirm protected calls no longer succeed.
- Confirm health diagnostics still report the configured API status.

## Phase 6: Local Migration and Azure Manual Gate

### Goal

Prepare the auth boundary for deployed verification without letting code implementation silently mutate Azure infrastructure or secrets.

### Changes Required

#### `context/changes/authenticated-role-boundary/plan.md`

**Intent**: Keep Azure migration and secret setup as an explicit manual gate.

**Contract**: Progress must not mark public Azure auth verification complete until the human confirms Azure SQL, App Service configuration, and migration have been applied.

#### Azure/App Service configuration checklist

**Intent**: Define what the human must configure outside source control.

**Contract**:
- Azure SQL Database exists for the dev API.
- App Service has `ConnectionStrings__DefaultConnection` or equivalent configuration.
- App Service has JWT issuer, audience, signing key, access-token lifetime, refresh-token lifetime, and registration invite code configured.
- No secret values are committed to repo files.

#### Migration execution

**Intent**: Apply the initial auth migration only after the manual infrastructure gate is approved.

**Contract**: Local migration verification happens during implementation; Azure migration execution requires explicit human approval and a rollback note.

### Automated Verification

- `dotnet build LiftMate.slnx --no-restore` from `apps/api`.
- `dotnet test LiftMate.slnx --no-build` from `apps/api`.
- `flutter test` from `apps/mobile`.
- `flutter analyze` from `apps/mobile`.

### Manual Verification

- Human confirms Azure SQL and App Service auth configuration are set.
- Deployed API accepts private-beta registration with valid invite code.
- Deployed API rejects invalid invite code.
- Deployed API login, refresh, `/auth/me`, and both role probes behave correctly.
- Flutter app default config can complete register/login/probe against deployed API after deploy.

## Testing Strategy

### API Integration Tests

- Registration succeeds for trainer with valid invite code.
- Registration succeeds for trainee with valid invite code.
- Registration rejects invalid invite code.
- Registration rejects invalid role.
- Registration rejects duplicate email.
- Login returns token pair for valid credentials.
- Login rejects invalid credentials.
- `/auth/me` requires bearer token and returns id, email, and role.
- Refresh returns a new usable access token and handles revoked/expired refresh tokens.
- Logout revokes the refresh token or session according to the implemented contract.
- Logout requires a bearer token plus refresh token body, is idempotent for repeated logout of the same token, and rejects another user's refresh token.
- Trainer token succeeds on `/trainer/probe` and is denied on `/trainee/probe`.
- Trainee token succeeds on `/trainee/probe` and is denied on `/trainer/probe`.

### Mobile Unit and Widget Tests

- Auth client URL construction and JSON parsing.
- Auth client success and error classification.
- Token store save/read/clear behavior through an in-memory implementation.
- Auth controller startup with no tokens, valid stored tokens, failed refresh, and logout.
- Auth UI register/login mode switching.
- Authenticated state display and role probe display.
- Existing health diagnostics still render and retry.

### Manual Tests

1. Local API register/login as trainer and trainee.
2. Local role probe success and cross-role denial.
3. Local Flutter register/login/probe/logout.
4. App restart restores or refreshes session.
5. Invalid invite code cannot register.
6. Deployed Azure flow after manual DB/config gate.

## Performance Considerations

Auth endpoints are low-QPS for the MVP and should not add meaningful load to Azure Free F1. Access token validation is local JWT validation after configuration is loaded. Refresh-token lookup is a single database read/update. Avoid adding polling or background refresh loops that wake frequently; refresh only near expiry or when a protected request requires it.

## Security Considerations

- Never commit JWT signing keys, invite codes, passwords, refresh tokens, or connection strings.
- Store refresh tokens hashed server-side.
- Store mobile tokens through platform secure storage.
- Keep access tokens short-lived.
- Enforce authorization in API policies, not in mobile UI.
- Treat the invite code as a private beta gate, not as production abuse prevention.
- Do not rely on an app-only static header as a secret; shipped mobile app values can be extracted.
- Avoid logging credentials, invite codes, access tokens, or refresh tokens.
- Use HTTPS for deployed API calls.

## Migration Notes

The first migration introduces Identity and refresh-token tables only. It should be additive. Azure migration is a manual gate because connection strings, SQL firewall/configuration, and production migration execution are infrastructure operations requiring human approval.

## Rollback Notes

Before Azure migration, rollback is a normal code revert. After Azure migration, rollback requires redeploying the previous API build and deciding whether to keep or drop the auth tables. Dropping auth tables would destroy registered MVP accounts and must not be done automatically.

## References

- Roadmap F-02: `context/foundation/roadmap.md`
- PRD access control: `context/foundation/prd.md`
- Shape notes access model: `context/foundation/shape-notes.md`
- Infrastructure recommendation: `context/foundation/infrastructure.md`
- Existing API entry point: `apps/api/LiftMate.Api/Program.cs`
- Existing mobile app composition: `apps/mobile/lib/main.dart`
- Existing health client: `apps/mobile/lib/api_health_client.dart`
- Existing smoke screen: `apps/mobile/lib/api_smoke_screen.dart`
- F-01 plan: `context/changes/mobile-api-smoke-path/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` - <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: API Data and Identity Foundation

#### Automated

- [x] 1.1 `dotnet restore LiftMate.slnx` from `apps/api` - 869aaf2
- [x] 1.2 `dotnet build LiftMate.slnx --no-restore` from `apps/api` - 869aaf2
- [x] 1.3 `dotnet ef migrations list` confirms the initial auth migration is discoverable - 869aaf2

#### Manual

- [x] 1.4 No auth secrets or connection strings are committed - 869aaf2
- [x] 1.5 Public `/health` still returns `200 {"status":"ok"}` - 869aaf2

### Phase 2: API Integration Test Harness

#### Automated

- [x] 2.1 `dotnet restore LiftMate.slnx` from `apps/api` - c5b8339
- [x] 2.2 `dotnet build LiftMate.slnx --no-restore` from `apps/api` - c5b8339
- [x] 2.3 `dotnet test LiftMate.slnx --no-build` from `apps/api` - c5b8339

#### Manual

- [x] 2.4 API test project is present in test output and the health test is not skipped - c5b8339

### Phase 3: API Auth Endpoints and Role Probes

#### Automated

- [x] 3.1 `dotnet build LiftMate.slnx --no-restore` from `apps/api` - 6429c5c
- [x] 3.2 `dotnet test LiftMate.slnx --no-build` from `apps/api` - 6429c5c
- [x] 3.3 `dotnet list LiftMate.slnx package --vulnerable --include-transitive` from `apps/api` - 6429c5c
- [x] 3.4 Integration tests cover register, login, refresh, bearer-authenticated logout, me, and role probes - 6429c5c
- [x] 3.5 Integration tests cover invalid invite code, invalid role, missing token, and cross-role denial - 6429c5c
- [x] 3.6 Integration tests cover logout without bearer token, logout for another user's refresh token, and repeated logout - 6429c5c

#### Manual

- [x] 3.7 Local trainer register/login/me/probe/logout flow succeeds - 6429c5c
- [x] 3.8 Local trainee register/login/me/probe/logout flow succeeds - 6429c5c
- [x] 3.9 Local cross-role probe denial is confirmed - 6429c5c
- [x] 3.10 API auth tests are present in the test output and are not skipped - 6429c5c

### Phase 4: Mobile Auth Client and Secure Session Storage

#### Automated

- [x] 4.1 `flutter pub get` from `apps/mobile` - 40c70d7
- [x] 4.2 `flutter test test/auth_api_client_test.dart test/token_store_test.dart` from `apps/mobile` - 40c70d7
- [x] 4.3 `flutter analyze` from `apps/mobile` - 40c70d7

### Phase 5: Mobile Auth UI and Diagnostics

#### Automated

- [x] 5.1 `flutter test` from `apps/mobile` - b7f1c3d
- [x] 5.2 `flutter analyze` from `apps/mobile` - b7f1c3d

#### Manual

- [ ] 5.3 Flutter app registers and authenticates a trainer against local API
- [ ] 5.4 Flutter app registers and authenticates a trainee against local API
- [ ] 5.5 Flutter app restores or refreshes auth state after restart
- [ ] 5.6 Flutter logout clears stored session and protected calls fail
- [ ] 5.7 Health diagnostics still report configured API status

### Phase 6: Local Migration and Azure Manual Gate

#### Automated

- [x] 6.1 `dotnet build LiftMate.slnx --no-restore` from `apps/api` - 3cfcc6d
- [x] 6.2 `dotnet test LiftMate.slnx --no-build` from `apps/api` - 3cfcc6d
- [x] 6.3 `flutter test` from `apps/mobile` - 3cfcc6d
- [x] 6.4 `flutter analyze` from `apps/mobile` - 3cfcc6d

#### Manual

- [x] 6.5 Human confirms Azure SQL and App Service auth configuration are set - 3cfcc6d
- [x] 6.6 Deployed API accepts valid invite-code registration and rejects invalid invite code - 3cfcc6d
- [x] 6.7 Deployed API login, refresh, `/auth/me`, and role probes behave correctly - 3cfcc6d
- [x] 6.8 Flutter app completes register/login/probe against deployed API after deploy - 3cfcc6d
