# Mobile-to-API Smoke Path Implementation Plan

## Overview

Build the first verified mobile-to-backend integration for LiftMate. The Flutter app will replace the scaffold `Hello World` screen with a diagnostic API status screen that calls the already deployed ASP.NET Core `GET /health` endpoint and reports whether the API is reachable.

This is the foundation slice F-01 from `context/foundation/roadmap.md`: mobile must be able to verify the deployed API before auth, trainer-trainee flows, shared sessions, or training data depend on cross-system wiring.

## Current State Analysis

### Mobile

- `apps/mobile/lib/main.dart:12` currently renders a scaffold `MaterialApp` with only `Hello World`.
- `apps/mobile/pubspec.yaml:9` has Flutter only as a runtime dependency; there is no HTTP client dependency yet.
- `apps/mobile/pubspec.yaml:14` includes `flutter_test`, so widget and unit tests can be added without changing test tooling.
- `apps/mobile/analysis_options.yaml:1` uses `flutter_lints`, and `flutter analyze` is the existing style gate.

### API

- `apps/api/LiftMate.Api/Program.cs:18` maps `GET /health` and returns `200` with `{"status":"ok"}`.
- `apps/api/LiftMate.Api/Program.cs:26` still exposes the template `/weatherforecast` endpoint; that cleanup is out of scope for this change.
- `apps/api/LiftMate.Api/LiftMate.Api.csproj:4` targets `net10.0`.
- `apps/api/LiftMate.Api/Properties/launchSettings.json` exposes local HTTP at `http://localhost:5257`.

### Deployment

- `deploy-plan.md:12` records the deployed dev API URL as `https://liftmate-api-dev-jdemb.azurewebsites.net`.
- `deploy-plan.md:100` records a successful public smoke check for `GET /health`.
- `.github/workflows/deploy-api-azure.yml:6` deploys only from branch `deploy-2026-05-26`.
- `deploy-plan.md:115` explicitly says not to deploy from `develop` yet.

## Desired End State

The mobile app starts on an API smoke screen. It checks the configured API base URL, calls `/health`, shows a clear `checking`, `online`, `offline`, or `error` state, and lets the user retry. API URL selection uses explicit `--dart-define=API_BASE_URL=...`; the deployed Azure URL stays in docs and run commands, not as a hardcoded app fallback.

The API keeps `/health` as the stable smoke contract for this slice. No auth, database, realtime infrastructure, weather endpoint cleanup, or API test project is added in this change.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Smoke scope | API reachability only through `GET /health` | F-01 exists to verify wiring, not product data, auth, or template endpoints. |
| Mobile placement | First screen diagnostic | The app has no product screen yet, so the first viewport can carry the integration signal. |
| API URL config | Required `--dart-define=API_BASE_URL` | Supports local and deployed testing without secrets, runtime settings UI, or environment-specific URLs baked into app code. |
| Local API mode | Explicit `--dart-define`, not default | Keeps Azure smoke as the default while still allowing local debug loops. |
| Failure states | `checking`, `online`, `offline`, `error` with a short timeout | Prevents hanging UI and separates unreachable API from malformed or unexpected responses. |
| Test surface | Unit tests for client plus widget tests for status screen | Verifies behavior without requiring a live network call in automated tests. |
| Backend contract | Keep `/health` as-is without adding an API test project | The user chose not to add API tests in F-01; backend remains stable but minimally touched. |

## Scope

### In Scope

- Add a Flutter HTTP dependency suitable for Android, iOS, and web.
- Add a small API health client that reads `API_BASE_URL` from compile-time environment config and reports a configuration error when it is missing.
- Model health-check result states so UI and tests do not depend on raw exceptions.
- Replace the placeholder mobile app with a diagnostic smoke screen.
- Add unit tests around health client behavior using a fake HTTP client.
- Add widget tests for loading, success, failure, and retry states where practical.
- Keep `/health` as the backend smoke contract.
- Document local and Azure verification commands in the plan handoff.

### Out of Scope

- Authentication, accounts, trainer-trainee relationships, and authorization.
- Database, EF Core, Azure SQL, migrations, or persistence.
- SignalR, realtime sync, polling for workout sessions, or active-session contracts.
- Removing `/weatherforecast`.
- Adding a backend test project.
- Changing Azure infrastructure or GitHub OIDC setup.
- Mobile release automation, Play Store, or TestFlight delivery.

## Architecture

The Flutter app owns the smoke check. A lightweight client builds `GET {baseUrl}/health`, applies a short timeout, validates the response status and JSON body, and returns a typed state to the UI. A dedicated smoke screen widget receives an injectable health-check function or client so widget tests can drive states without network calls. The API remains the existing ASP.NET Core minimal API with `/health` as the stable public contract.

```text
Flutter first screen
  -> ApiSmokeScreen with injected health check
  -> ApiHealthController / state holder
  -> ApiHealthClient
  -> GET {API_BASE_URL}/health
  -> ASP.NET Core /health -> {"status":"ok"}
```

## Phase 1: Confirm Backend Smoke Contract

### Goal

Keep the deployed `/health` endpoint as the explicit contract for mobile smoke checks and avoid unnecessary backend scope.

### Changes Required

#### `apps/api/LiftMate.Api/Program.cs`

**Intent**: Preserve `GET /health` as the stable reachability endpoint returning `{"status":"ok"}`. Do not add auth, persistence, versioning, or new status endpoints in this phase.

**Contract**: `GET /health` returns HTTP `200` and JSON with `status` equal to `ok`.

#### `apps/api/LiftMate.Api/LiftMate.Api.http`

**Intent**: Point the existing manual HTTP scratch file at `/health` instead of only the template weather endpoint, so local API smoke checks match the mobile contract.

**Contract**: Include a request for `GET {{LiftMate.Api_HostAddress}}/health` while preserving any useful existing request blocks.

### Automated Verification

- `dotnet restore LiftMate.slnx` from `apps/api`.
- `dotnet build LiftMate.slnx --no-restore` from `apps/api`.

### Manual Verification

- Start the API locally with `dotnet run --project LiftMate.Api\LiftMate.Api.csproj` when needed.
- Confirm `GET http://localhost:5257/health` returns `200` and `{"status":"ok"}`.
- Confirm `GET https://liftmate-api-dev-jdemb.azurewebsites.net/health` returns `200` and `{"status":"ok"}` before marking the smoke path manually verified.

## Phase 2: Add Mobile API Health Client

### Goal

Create a testable Flutter client layer for the API smoke check without coupling the UI directly to HTTP calls.

### Changes Required

#### `apps/mobile/pubspec.yaml`

**Intent**: Add a cross-platform HTTP dependency for Flutter.

**Contract**: Add the `http` package under runtime dependencies, then refresh `pubspec.lock` with `flutter pub get`.

#### `apps/mobile/lib/api_health_client.dart`

**Intent**: Encapsulate the `/health` request, timeout, response parsing, and failure classification.

**Contract**:
- Expose a client that accepts an injectable HTTP client for tests.
- Resolve the base URL from `String.fromEnvironment('API_BASE_URL')`.
- Return an error result when `API_BASE_URL` is empty instead of baking an environment URL into app code.
- Request `/health` without duplicating slashes when the base URL has a trailing slash.
- Treat HTTP `200` with JSON `{"status":"ok"}` as online.
- Treat timeout, socket/client failures, non-2xx responses, invalid JSON, or unexpected status bodies as non-online results with enough detail for UI diagnostics.

#### `apps/mobile/test/api_health_client_test.dart`

**Intent**: Verify client behavior without real network calls.

**Contract**: Cover at least success, non-200, malformed JSON, unexpected status, thrown client exception, and URL construction with a trailing slash.

### Automated Verification

- `flutter pub get` from `apps/mobile`.
- `flutter test test/api_health_client_test.dart` from `apps/mobile`.
- `flutter analyze` from `apps/mobile`.

### Manual Verification

- None required for this phase beyond automated tests; live network behavior is verified in Phase 3.

## Phase 3: Replace Placeholder With Smoke Screen

### Goal

Make API reachability visible as the app's first user-facing screen, with clear states and retry behavior.

### Changes Required

#### `apps/mobile/lib/main.dart`

**Intent**: Replace the placeholder `Hello World` with a small Material app that composes the API smoke status screen on startup.

**Contract**:
- Keep `main.dart` responsible for app composition and production dependency wiring.
- Pass the production health-check client/function into the smoke screen.

#### `apps/mobile/lib/api_smoke_screen.dart`

**Intent**: Provide the first-screen UI and state transitions while keeping health-check execution injectable for widget tests.

**Contract**:
- First screen triggers a health check when it initializes.
- UI states include `checking`, `online`, `offline`, and `error`.
- The screen shows the effective base URL being checked.
- The screen includes a retry action.
- The screen remains readable on phone-sized layouts and does not require explanatory onboarding text.
- The screen accepts an injected health-check function or client so tests can return deterministic states without live network calls.

#### `apps/mobile/test/api_smoke_screen_test.dart`

**Intent**: Verify the first screen renders and updates around injected health-check states without calling the network.

**Contract**: Cover initial checking state, online state, offline/error display, and retry triggering a new check.

### Automated Verification

- `flutter test` from `apps/mobile`.
- `flutter analyze` from `apps/mobile`.

### Manual Verification

- Run the Flutter app with `--dart-define=API_BASE_URL=https://liftmate-api-dev-jdemb.azurewebsites.net` and confirm it checks `https://liftmate-api-dev-jdemb.azurewebsites.net/health`.
- Run the Flutter app with a local `API_BASE_URL` override while the local API is running and confirm the screen reports online:
  - Flutter web/desktop: `--dart-define=API_BASE_URL=http://localhost:5257`
  - Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:5257`
  - Physical device: `--dart-define=API_BASE_URL=http://<developer-machine-lan-ip>:5257`
- Run the Flutter app with an intentionally invalid `API_BASE_URL` and confirm the screen reaches an offline/error state quickly and retry does not freeze the UI.

## Testing Strategy

### Unit Tests

- API health client URL construction.
- Success response parsing.
- Non-200 response classification.
- Invalid JSON and unexpected `status` body classification.
- Client exception and timeout classification where the implementation exposes a deterministic test hook.

### Widget Tests

- First screen starts in a checking/loading state.
- Online result is displayed.
- Offline/error result is displayed.
- Retry action calls the check again.

### Manual Tests

1. Verify deployed Azure `/health` directly.
2. Verify local API `/health` directly.
3. Verify Flutter app default Azure smoke path.
4. Verify Flutter app local override smoke path.
5. Verify Flutter app invalid URL failure state and retry.

## Performance Considerations

The smoke check should use a short timeout, targeted around three seconds. It runs once on first screen load and again only on explicit retry, so it should not add meaningful load to Azure Free F1. Do not introduce polling in this change.

## Migration Notes

No data migration is required. The only dependency migration is adding the Flutter HTTP package and refreshing `pubspec.lock`.

## Rollback Notes

The change can be rolled back by reverting the Flutter app/client/test files and the `pubspec` dependency update. The API contract is preserved, so rollback should not require Azure infrastructure changes.

## References

- Roadmap F-01: `context/foundation/roadmap.md`
- API deploy target and smoke evidence: `deploy-plan.md`
- Mobile placeholder: `apps/mobile/lib/main.dart:12`
- API health endpoint: `apps/api/LiftMate.Api/Program.cs:18`
- Azure deploy workflow: `.github/workflows/deploy-api-azure.yml:6`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` - <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Confirm Backend Smoke Contract

#### Automated

- [x] 1.1 `dotnet restore LiftMate.slnx` from `apps/api` - 8971a20
- [x] 1.2 `dotnet build LiftMate.slnx --no-restore` from `apps/api` - 8971a20

#### Manual

- [x] 1.3 Local `/health` returns `200 {"status":"ok"}` - 8971a20
- [x] 1.4 Azure `/health` returns `200 {"status":"ok"}` - 8971a20

### Phase 2: Add Mobile API Health Client

#### Automated

- [x] 2.1 `flutter pub get` from `apps/mobile` - 4ff49d8
- [x] 2.2 `flutter test test/api_health_client_test.dart` from `apps/mobile` - 4ff49d8
- [x] 2.3 `flutter analyze` from `apps/mobile` - 4ff49d8

### Phase 3: Replace Placeholder With Smoke Screen

#### Automated

- [x] 3.1 `flutter test` from `apps/mobile` - aa2b041
- [x] 3.2 `flutter analyze` from `apps/mobile` - aa2b041

#### Manual

- [x] 3.3 Flutter app reports online against configured Azure API URL - aa2b041
- [x] 3.4 Flutter app reports online with local `API_BASE_URL` override - aa2b041
- [x] 3.5 Flutter app reports offline/error quickly for an invalid `API_BASE_URL` - aa2b041
