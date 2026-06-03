# Shared-session Sync Contract - Plan Brief

> Full plan: `context/changes/shared-session-sync-contract/plan.md`

## What & Why

Build the minimal shared active-session sync contract for LiftMate. The goal is to prove that a trainer and trainee can observe and update the same active workout session object through the API and SignalR before the full trainer-led workout slice is built.

## Starting Point

Auth, roles, JWT tokens, EF Core, and API integration tests already exist. There is no shared-session data model, workout state, SignalR hub, mobile session client, or realtime diagnostic surface yet.

## Desired End State

The API can create a small shared session snapshot between an explicit trainer and trainee, authorize only those two users, accept writes from both roles, and broadcast updates through SignalR. The Flutter app has typed session clients and a temporary authenticated diagnostic panel to create/join a session and verify two-way updates without manual refresh.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Sync transport | SignalR | The current free tier is acceptable for MVP validation and this directly tests FR-012. |
| Latency target | Under 1 second | Matches the product expectation for trainer-led live workout feedback. |
| Session data | Minimal exercise value snapshot | Proves shared state without implementing full workout templates. |
| Write roles | Trainer and trainee can both write | Forces the shared contract to support later self-editing behavior. |
| Conflicts | Last write wins | Keeps the MVP contract simple and avoids conflict UI in F-03. |
| Access | Explicit trainer/trainee participant IDs | Preserves isolation before S-01 relationship records exist. |
| Lifecycle | `active`, `completed`, `cancelled` | Covers normal finish and abort paths while keeping state small. |
| Mobile scope | Client plus diagnostic panel | Makes the contract testable on two clients before S-04. |

## Scope

**In scope:**

- API shared-session entities, migration, REST endpoints, and participant access checks.
- SignalR hub and server broadcasts after accepted mutations.
- Last-write-wins updates with server-owned versioning.
- API integration tests for lifecycle, authorization, and hub delivery.
- Flutter shared-session models, REST client, SignalR wrapper, and temporary diagnostic panel.
- Mobile unit/widget tests and manual two-client verification.

**Out of scope:**

- Full workout templates, trainer-trainee relationship records, production workout UI, and progress saving.
- Conflict resolution UI, optimistic concurrency, paid realtime infrastructure, and SignalR scale-out.
- Mobile release automation and unrelated `/weatherforecast` cleanup.

## Architecture / Approach

REST endpoints own validation, persistence, authorization, lifecycle transitions, and accepted writes. SignalR owns session-group membership and update delivery. Mobile clients treat the API response or `sessionUpdated` payload as canonical and receive the same full minimal snapshot after each create/update/complete/cancel mutation.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. API Shared-Session Persistence | Minimal session/value tables and migration. | Accidentally expanding into full workout modeling. |
| 2. API REST Contract and Authorization | Create/read/update/complete/cancel with participant checks. | Access rules are temporary but must not leak data. |
| 3. SignalR Hub and Broadcasts | Authenticated session group join and `sessionUpdated` broadcasts. | Hub auth and test setup can be brittle. |
| 4. Mobile Shared-Session Client | Typed REST models/client and SignalR wrapper. | Raw SignalR details leaking into UI code. |
| 5. Mobile Diagnostic Shared-Session Surface | Authenticated create/join/update verification panel. | Temporary UI drifting into full S-04 scope. |

**Prerequisites:** F-01 mobile/API smoke path and F-02 auth boundary are available in code.
**Estimated effort:** ~3 focused implementation sessions across 5 phases.

## Open Risks & Assumptions

- Azure Free tier may not consistently deliver sub-second updates under cold starts or poor connectivity.
- F-03 assumes a single App Service instance and no SignalR scale-out backplane.
- Last-write-wins can silently overwrite near-simultaneous edits; this is accepted for MVP simplicity.
- Explicit participant IDs are a bridge until S-01 adds real trainer-trainee relationships.

## Success Criteria (Summary)

- Trainer and trainee can join the same session and receive SignalR updates without manual refresh.
- Both roles can write active-session values, while non-participants are denied.
- Completed and cancelled sessions reject further value edits.
- API tests, mobile tests, `dotnet test`, `flutter test`, and `flutter analyze` pass locally.
