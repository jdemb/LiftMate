# Shared-session Sync Contract - Plan Brief

> Full plan: `context/changes/shared-session-sync-contract/plan.md`

## What & Why

Build the minimal shared active-session sync contract for LiftMate, revised after physical-device Azure testing showed the original tester workflow was too manual and realtime connection handling was not reliable enough. The updated goal is for a trainer to start a session by trainee email and for the trainee to see the active training state automatically, without copying user IDs or session IDs.

## Starting Point

F-03 phases 1-5 already added shared-session tables, REST endpoints, SignalR group updates, mobile clients, and a temporary diagnostic panel. Manual Azure/device testing exposed two issues: session creation required opaque IDs, and the mobile realtime connection could move from `connecting` to `disconnected` immediately after trying to join.

## Desired End State

The API resolves trainee email to the stored trainee user ID, enforces one active session per trainee, and exposes an authenticated active-session lookup. The mobile diagnostic surface has no `Session ID` or manual join path: a trainer creates a session by trainee email, and a trainee who is logged in or logs in later sees the active session automatically through SignalR notification plus REST fallback.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Trainer input | Trainee email | Physical-device testing should use the same identifier humans use to log in. |
| Stored access model | Keep participant user IDs internally | Authorization remains stable even though UI no longer exposes IDs. |
| Active-session cardinality | One active session per trainee | Auto-discovery stays deterministic and no session picker is needed in F-03. |
| Trainee discovery | `sessionStarted` SignalR notification plus `GET /shared-sessions/active` fallback | Covers already-logged-in and newly-logged-in trainees, while tolerating Azure/mobile realtime instability. |
| Realtime failure handling | Treat `connecting` -> `disconnected` as a failing condition | The observed physical-device behavior blocks the product test and must be diagnosed, not ignored. |
| Mobile UI scope | Temporary diagnostic surface without session IDs | Keeps F-03 focused on the shared-state contract before S-04 production UI. |

## Scope

**In scope:**

- API create-by-trainee-email contract.
- `GET /shared-sessions/active` for authenticated active-session discovery.
- One-active-session-per-trainee enforcement and additive migration.
- User-targeted SignalR `sessionStarted` notification.
- Mobile trainer create-by-email UI.
- Mobile trainee waiting/auto-load state with no manual join.
- Azure App Service SignalR transport verification for physical release builds.

**Out of scope:**

- Full trainer-trainee relationship records from S-01.
- Production workout UI from S-04.
- Paid Azure SignalR Service or scale-out backplanes.
- Full workout template assignment, progress saving, or conflict resolution UI.

## Architecture / Approach

REST remains the source of truth for persistence, validation, authorization, lifecycle, and mutations. SignalR gains a user-targeted notification path so the trainee can learn that a session exists before they know the session ID. Mobile treats `GET /shared-sessions/active` as the fallback/recovery path after login or realtime failure, then joins the specific session group internally for value updates.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. API Shared-Session Persistence | Minimal session/value tables and migration. | Already implemented; avoid expanding into workout templates. |
| 2. API REST Contract and Authorization | Initial create/read/update/complete/cancel with participant checks. | Already implemented; now revised by Phase 6. |
| 3. SignalR Hub and Broadcasts | Initial authenticated session group join and updates. | Already implemented; physical devices exposed transport failure. |
| 4. Mobile Shared-Session Client | Typed REST models/client and SignalR wrapper. | Already implemented; now revised by Phase 7. |
| 5. Mobile Diagnostic Surface | Initial manual create/join/update panel. | Manual flow is superseded because it exposed IDs. |
| 6. API Email-Based Active Session Discovery | Email create, active lookup, one-active-session migration. | Data uniqueness must be enforced without breaking closed history. |
| 7. Mobile Auto-Discovery and User-Targeted Realtime | No-ID UI and trainee auto-load/notification. | Realtime failures must be surfaced and recovered. |
| 8. Azure Realtime Hardening and Final Gate | Deploy/migration plus physical-device Azure acceptance. | Free Azure tier and App Service transport settings can still affect latency. |

**Prerequisites:** F-01, F-02, and F-03 phases 1-5 are already present in code and deployed once.
**Estimated effort:** ~2 focused implementation sessions across phases 6-8.

## Open Risks & Assumptions

- Email currently acts as username because registration sets Identity `UserName = Email`.
- Azure Free/App Service settings may still cause cold starts; auth timeout/retry already mitigates login, but SignalR needs explicit verification.
- The active-session uniqueness migration assumes demo data has no duplicate active sessions per trainee.

## Success Criteria (Summary)

- Trainer starts a session by trainee email, not user ID.
- Trainee sees the active session automatically when already logged in or after logging in later.
- Physical release builds against Azure do not require `Session ID` or `Join session`.
- Realtime update delivery works or recovers via active-session fallback without manual ID entry.
