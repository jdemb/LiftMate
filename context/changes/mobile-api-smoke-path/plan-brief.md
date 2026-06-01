# Mobile-to-API Smoke Path - Plan Brief

> Full plan: `context/changes/mobile-api-smoke-path/plan.md`

## What & Why

Build the first verified mobile-to-backend integration for LiftMate. The Flutter app will call the deployed API's `/health` endpoint and show whether the API is reachable before later product flows depend on auth, training data, or realtime sync.

## Starting Point

The mobile app is still a scaffold that renders `Hello World`. The API already exposes `GET /health` and has been deployed to Azure App Service at `https://liftmate-api-dev-jdemb.azurewebsites.net`.

## Desired End State

The app starts on a diagnostic screen that checks `/health`, shows `checking`, `online`, `offline`, or `error`, and supports retry. It uses explicit `--dart-define=API_BASE_URL` so environment URLs are not baked into app code.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Smoke scope | API reachability only through `/health` | F-01 is about wiring, not auth, product data, or template endpoints. |
| Mobile placement | First screen diagnostic | There is no product screen yet, so the first viewport can carry the integration signal. |
| API URL config | Required `--dart-define=API_BASE_URL` | It supports local and deployed checks without adding secrets, settings UI, or environment URLs in app code. |
| Failure states | `checking`, `online`, `offline`, `error` | The screen should not hang and should distinguish reachable API from failures. |
| Tests | Client unit tests plus widget tests | Automated checks can cover behavior without live network dependency. |
| Backend tests | No API test project in this change | The selected scope keeps `/health` stable without expanding backend testing yet. |

## Scope

**In scope:**

- Flutter HTTP dependency and lockfile refresh.
- API health client with injectable HTTP transport.
- Compile-time API base URL config and Azure dev fallback.
- First-screen smoke UI with retry.
- Unit and widget tests for mobile smoke behavior.
- Manual local and Azure smoke verification steps.

**Out of scope:**

- Auth, accounts, trainer-trainee relationships, persistence, and realtime.
- Removing `/weatherforecast`.
- Adding a backend test project.
- Changing Azure infrastructure or GitHub OIDC/deploy setup.
- Mobile release automation.

## Architecture / Approach

The Flutter first screen calls a small `ApiHealthClient`, which resolves the base URL from `API_BASE_URL`, requests `/health`, applies a short timeout, validates `{"status":"ok"}`, and returns a typed state for the UI. If `API_BASE_URL` is missing, the client reports a configuration error instead of using a hardcoded fallback. The backend stays on the existing ASP.NET Core `/health` contract.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Confirm Backend Smoke Contract | `/health` is treated as the stable smoke contract and manual API checks are aligned. | Avoiding backend scope creep while keeping the contract explicit. |
| 2. Add Mobile API Health Client | Testable client layer, URL config, timeout, and result classification. | Keeping failures deterministic enough for tests. |
| 3. Replace Placeholder With Smoke Screen | User-visible smoke screen with retry and automated widget coverage. | Temporary diagnostic UI should stay simple and not become product UX debt. |

**Prerequisites:** Existing Flutter and .NET scaffolds; deployed Azure API URL from `deploy-plan.md`.
**Estimated effort:** ~1 focused implementation session across 3 phases.

## Open Risks & Assumptions

- Azure App Service Free F1 is prototype-only and may occasionally be slow; the client should use a timeout and expose retry.
- Android emulator local API checks may require a host-specific URL instead of plain `localhost`; the plan keeps local URL explicit through `API_BASE_URL`.
- The API deploy workflow only runs from `deploy-2026-05-26`; implementation on `develop` will need a deliberate branch/deploy step before Azure verification if backend behavior changes.

## Success Criteria (Summary)

- The Flutter app can report online against `https://liftmate-api-dev-jdemb.azurewebsites.net/health` when `API_BASE_URL` is provided.
- The same app can report online against a local API when `API_BASE_URL` is provided.
- Automated mobile tests and `flutter analyze` pass.
