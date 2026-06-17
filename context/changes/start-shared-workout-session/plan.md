# Start Shared Workout Session Implementation Plan

## Overview

Implement roadmap S-03 as the first production shared workout-session flow. A trainer can start a shared session for a linked trainee and assigned workout set, and a trainee can self-start an active session from an assigned set without the trainer being present. Both paths must produce one canonical active session object that can later be joined by the other participant.

The updated mobile design contract is `apps/mobile/design/LiftMate.html`. It supersedes `apps/mobile/design/LiftMate.dc.html` for this plan.

## Current State Analysis

The repo already has the three foundations this slice depends on:

- S-01 relationship flow exists in `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs` and the mobile `relationships/` screens.
- S-02 workout sets exist in `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs` and `apps/mobile/lib/workout_sets/`.
- F-03 shared sessions exist in `apps/api/LiftMate.Api/SharedSessions/` and `apps/mobile/lib/shared_sessions/`.

Important current constraints:

- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:15` currently maps `POST /shared-sessions` for trainer-only create with inline values.
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:16` maps `GET /shared-sessions/active`.
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:67` already checks for another active session for the trainee.
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:121` already has a filtered unique index enforcing one active session per trainee.
- `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs:23` and `:24` expose assigned workout sets to trainees.
- `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart:68` currently leaves the trainee start button disabled with the S-03 placeholder label.
- `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart:94` renders assigned sets in the trainer trainee-detail view, but there is no session start/join action yet.
- `apps/mobile/lib/relationships/trainer_dashboard_screen.dart:76` renders trainee list entries, but summaries do not yet include active-session state.
- `context/changes/shared-session-sync-contract/plan.md` documents the existing F-03 contract: `sessionStarted`, `sessionUpdated`, `GET /shared-sessions/active`, one active session per trainee, and mobile reconnect recovery.

## Desired End State

After this plan:

- A trainer can open a trainee detail screen and start a trainer-led active session from an assigned workout set.
- A trainee can start their own active session from a specific assigned workout set.
- A trainee has at most one active session, regardless of whether it was started by the trainer or trainee.
- Active sessions are snapshots of the workout-set rows at start time, so later template edits do not mutate the live workout.
- A trainer sees a green status dot and "Aktywna sesja" on the trainee list when a trainee has an active session.
- A trainer opening that trainee detail sees "Dołącz do sesji" when an active session exists, otherwise "Rozpocznij wspólny trening" for an assigned set.
- If the trainer started the session, the trainee button says "Dołącz do aktywnego treningu" and opens the limited read-only `c_live` view from the design.
- If the trainee started the session, the trainee sees the full editable live-session view like the trainer, and the trainer can later join it.
- Closing or cancelling a session frees the trainee to start another active session.

### Key Discoveries

- `SharedSession` lacks `WorkoutSetId`, `StartedByUserId`, origin/mode fields, and `ExerciseOrder`, all of which are needed to rebuild workout exercises from session rows.
- `SharedSessionValue` also lacks canonical set completion state. The live UI's done check and completed-set count must be persisted as session value state, not kept only in Flutter.
- Existing shared-session updates allow both participants to update values, but S-03 must narrow that rule: trainees can edit self-start sessions, while trainer-led sessions are editable by the trainer and read-only for the trainee.
- The new design contract says the trainer starts from `t_trainee`, trainer live uses editable set rows, trainee home has a strong "Rozpocznij trening" CTA, and trainee live is read-only for trainer-led sessions.
- Current mobile assigned-set UI already groups rows by exercise and has the exact insertion point for trainee self-start.

## What We're NOT Doing

- No workout history or next-session progress persistence; that remains S-05.
- No trainee self-editing in trainer-led shared sessions; that remains out of scope until a later self-edit slice.
- No separate trainer "active sessions" screen; active state appears in the trainee list and detail view.
- No paid realtime infrastructure or Azure SignalR Service changes.
- No broad redesign of auth, pairing, or workout-set builder screens.
- No removal of the old diagnostic shared-session panel unless it directly conflicts with the new production flow.
- No support for multiple simultaneous active sessions for the same trainee.

## Implementation Approach

Build backend contracts first, because mobile state and UI depend on knowing who started the session and which workout-set snapshot it represents. Keep existing F-03 endpoints backward-compatible where practical, but add a production start-from-workout-set contract instead of overloading the demo create-by-values path. Then add typed Flutter models/controllers and wire the trainer and trainee flows to the updated design.

## Critical Implementation Details

### Session Origin

The session response must carry enough server-owned state for a fresh mobile client after login or reconnect to decide the correct UI mode. Do not infer trainer-led vs trainee-self-start from local navigation history.

### Snapshot Shape

The live UI needs exercises and series. `SetIndex` alone is not enough once multiple exercises exist; the session value snapshot needs an exercise ordering field copied from `WorkoutSetRow.ExerciseOrder`.

### Set Completion

The live UI's checkmark and completed-set count are shared session state. Persist completion on each `SharedSessionValue` as `IsDone` plus nullable `CompletedAt`, and include both fields in responses and updates so reconnecting clients rebuild the same view.

### Edit Rules

The API must enforce origin-specific editability. A trainee cannot update values in a trainer-led session even if the mobile UI is read-only; a trainee can update values in a trainee-self-start session. The trainer can update linked trainee sessions in both modes while the relationship remains current.

### Recovery

Do not rely only on `sessionStarted`. The existing missed-start/reconnect class must keep using canonical active-session fetches when a view is empty.

## Phase 1: Backend Session Origin And Workout-Set Start Contract

### Overview

Extend the shared-session domain so a session can be started from an assigned workout set by either the trainer or the trainee, while preserving the one-active-session-per-trainee invariant.

### Changes Required

#### Shared Session Domain

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`

**Intent**: Store session origin and workout-set identity so clients can reliably choose trainer-led vs self-start behavior after reconnect or fresh login.

**Contract**: Add nullable `WorkoutSetId`, required `StartedByUserId`, required `StartedByRole`, and any needed navigation property to `WorkoutSet`. Existing demo sessions may have no `WorkoutSetId`, but production start-from-set sessions must set it.

#### Shared Session Values

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionValue.cs`

**Intent**: Preserve workout-set exercise grouping in the session snapshot.

**Contract**: Add `ExerciseOrder`, `IsDone`, and nullable `CompletedAt` to `SharedSessionValue`. The production start flow copies `WorkoutSetRow.ExerciseOrder`, `SetIndex`, `ExerciseName`, `ExerciseType`, `Reps`, `Weight`, and `Seconds`; new sessions initialize `IsDone = false` and `CompletedAt = null`.

#### Contracts

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`

**Intent**: Add production start request/response data while keeping existing response fields stable.

**Contract**: Add `StartSharedSessionFromWorkoutSetRequest(Guid WorkoutSetId, string? TraineeUserId)` or equivalent. Extend `SharedSessionResponse` and `SharedSessionValueResponse` with `workoutSetId`, `startedByUserId`, `startedByRole`, `exerciseOrder`, `isDone`, and `completedAt`. Extend `UpdateSharedSessionValueRequest` with `isDone` so value edits and done toggles use the same canonical mutation path.

#### Endpoint Mapping And Start Logic

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`

**Intent**: Add production start-from-workout-set behavior without weakening existing participant access rules.

**Contract**: Add a route that supports both:
- trainer start: authenticated trainer provides `workoutSetId` and linked `traineeUserId`;
- trainee start: authenticated trainee provides `workoutSetId`, and the API derives the trainee from the token.

The endpoint validates:
- user role is trainer or trainee;
- workout set exists;
- workout set is assigned to the trainee;
- trainer start uses a trainee linked to that trainer;
- trainee start uses a set assigned to the authenticated trainee;
- trainee self-start sets `TrainerUserId` from the assigned workout set's trainer and requires the trainee's current `TrainerUserId` to still match that set owner;
- trainee has no active session already.

On success, create an active `SharedSession` with snapshot values ordered by `ExerciseOrder`, then `SetIndex`, broadcast start/update using existing broadcaster behavior, and return `201 Created`.

Value updates must enforce origin-specific editability:
- trainer-led session: the linked trainer can update values and done state; the trainee receives read-only access and update attempts return `403 Forbidden`;
- trainee-self-start session: the trainee can update values and done state, and the linked trainer can update after joining while the relationship remains current.

#### EF Model And Migration

**File**: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`

**Intent**: Persist the new origin and snapshot fields safely.

**Contract**: Configure max lengths for `StartedByRole`, optional FK/index for `WorkoutSetId`, required `StartedByUserId`, `ExerciseOrder`, `IsDone`, and nullable `CompletedAt` on values. Generate a SQL Server migration and update the model snapshot.

#### API Tests

**File**: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Lock the new start contract and keep F-03 behavior intact.

**Contract**: Add tests for trainer start from assigned set, trainee self-start from assigned set, snapshot rows, completion state, one active session across both start modes, forbidden unassigned/wrong-trainer starts, trainer-led trainee update rejection, self-start trainee update allowance, and preserved access to existing create-by-values behavior.

### Success Criteria

#### Automated Verification

- API tests cover trainer start from an assigned workout set.
- API tests cover trainee self-start from an assigned workout set.
- API tests prove unassigned or wrong-trainer starts are rejected.
- API tests prove one active session per trainee across trainer-led and self-start paths.
- API tests prove value completion state persists and is returned to both participants.
- API tests prove trainer-led sessions reject trainee value updates while trainee-self-start sessions allow trainee updates.
- `dotnet test LiftMate.slnx --no-build` passes after build.

#### Manual Verification

- API response shape is understandable enough for mobile implementation: session origin, workout-set identity, and exercise grouping are present.

---

## Phase 2: Backend Active-Session Discovery For Trainer And Trainee

### Overview

Expose active-session state where the mobile trainer and trainee screens need it: trainer list/detail and trainee home.

### Changes Required

#### Relationship Contracts

**File**: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

**Intent**: Let the trainer dashboard show which trainees have active sessions without adding a separate screen.

**Contract**: Extend the trainer trainee summary records currently defined in `PairingEndpoints.cs` with an optional active-session summary containing at minimum `sessionId`, `workoutSetId`, `workoutSetName`, `startedByUserId`, `startedByRole`, and `updatedAt`.

#### Relationship Endpoint

**File**: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

**Intent**: Include active-session summary for each linked trainee.

**Contract**: The trainer relationship response should join or query active sessions for the trainer's linked trainees. It must not expose sessions for unlinked or re-paired trainees.

#### Shared Session Retrieval

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`

**Intent**: Support joining a specific active session from trainer detail and trainee home.

**Contract**: Keep `GET /shared-sessions/active` for the authenticated participant. Ensure `GET /shared-sessions/{sessionId}` works for the current linked trainer and trainee according to existing `SharedSessionAccess` rules. If a trainee re-pairs, stale trainer access remains forbidden as in existing tests.

#### Broadcaster

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionBroadcaster.cs`

**Intent**: Make trainer clients able to discover or refresh active-session status after a trainee self-starts.

**Contract**: Keep `sessionStarted` and send it to both relevant users: the trainee and the linked trainer. The trainer mobile client treats `sessionStarted` as an invalidation signal and performs a canonical refresh of trainer relationship data before updating the dashboard badge/detail action.

#### API Tests

**Files**:
- `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Prove active-session state is visible only to the correct trainer and trainee.

**Contract**: Tests cover trainer relationship summaries with and without active session, self-start visibility to trainer, trainer join/read of trainee self-start, `sessionStarted` delivery to the linked trainer, and no visibility for another trainer.

### Success Criteria

#### Automated Verification

- API tests prove trainer relationship summary includes active-session state for linked trainees.
- API tests prove self-start sessions are joinable by the linked trainer.
- API tests prove unrelated trainers cannot see or join active sessions.
- API/SignalR tests prove trainee self-start emits `sessionStarted` to the linked trainer.
- `dotnet test LiftMate.slnx --no-build` passes after build.

#### Manual Verification

- The active-session summary maps directly to the planned trainer "Aktywna sesja" list badge and detail "Dołącz do sesji" button.

---

## Phase 3: Mobile Shared-Session Models And Controllers

### Overview

Make Flutter understand production session starts, session origin, grouped live rows, and active-session state.

### Changes Required

#### Shared Session Models

**File**: `apps/mobile/lib/shared_sessions/shared_session_models.dart`

**Intent**: Parse the expanded server response and provide enough typed state for role-specific live views.

**Contract**: Add fields matching API response: `workoutSetId`, `startedByUserId`, `startedByRole`, and `exerciseOrder`, `isDone`, and `completedAt` on values. Add helpers or computed predicates for trainer-led vs trainee-self-start if that matches local style.

#### Shared Session API Client

**File**: `apps/mobile/lib/shared_sessions/shared_session_api_client.dart`

**Intent**: Add production start-from-workout-set operations.

**Contract**: Add methods for trainer start and trainee self-start using the new API route. Keep existing create-by-email diagnostic method unless removed by explicit cleanup.

#### Relationship Models

**File**: `apps/mobile/lib/relationships/relationship_models.dart`

**Intent**: Parse active-session summaries for trainer trainees.

**Contract**: Extend `TrainerTraineeSummary` with optional active-session summary fields matching backend contract.

#### Shared Session Controller

**File**: `apps/mobile/lib/shared_sessions/`

**Intent**: Move production live-session orchestration out of the diagnostic panel and into a reusable controller/state object.

**Contract**: Controller handles start-from-set, load active session, load by session ID, update values, toggle done state, complete/cancel, realtime connect/join, `sessionStarted`/`sessionUpdated`, canonical relationship refresh after trainer-visible start events, and reconnect recovery. It must support both role modes and expose clear loading/error states for screens.

#### App Dependency Wiring

**Files**:
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent**: Provide the shared-session API client and realtime client factory to post-auth screens.

**Contract**: Follow the existing dependency-injection pattern used for auth, relationship, and workout-set clients.

#### Mobile Tests

**Files**:
- `apps/mobile/test/shared_session_models_test.dart`
- `apps/mobile/test/shared_session_api_client_test.dart`
- new or updated shared-session controller tests

**Intent**: Lock parsing and client contracts before UI phases depend on them.

**Contract**: Tests cover response parsing, start-from-workout-set payloads, active-session summaries, done-state parsing/toggling, trainer relationship refresh after `sessionStarted`, and controller transitions for start/join/reconnect.

### Success Criteria

#### Automated Verification

- Shared-session model tests cover new origin and grouping fields.
- Shared-session API client tests cover trainer and trainee start-from-set requests.
- Controller tests cover self-start, trainer-led join, active-session fetch, and reconnect recovery.
- Controller tests cover done-state toggles and trainer relationship refresh after trainee self-start events.
- `flutter test` passes.
- `flutter analyze` passes.

#### Manual Verification

- Controller state names and failure messages are usable by the planned trainer and trainee screens.

---

## Phase 4: Mobile Trainer Flow

### Overview

Wire trainer dashboard and trainee detail into active-session status, start, and join behavior.

### Changes Required

#### Trainer Dashboard

**File**: `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`

**Intent**: Show active-session state on the list of trainees.

**Contract**: For trainees with active-session summary, render a green dot and "Aktywna sesja" in the list item. Preserve existing trainee-list navigation and empty/error states.

#### Trainer Trainee Detail

**File**: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`

**Intent**: Give the trainer the correct action from the trainee detail screen.

**Contract**:
- If selected trainee has an active session, show "Dołącz do sesji".
- If no active session and at least one assigned set exists, show "Rozpocznij wspólny trening" for the assigned set.
- Preserve "Przypisz inny zestaw" behavior where applicable.
- Keep unassign controls from S-02 intact.

#### Authenticated Shell Navigation

**File**: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent**: Route trainer start/join actions to the live session screen and refresh relationship/workout-set state when sessions change.

**Contract**: Add a trainer live view state that carries the session ID or start request context. Starting from a set calls the shared-session controller; joining an active session loads by ID. Returning from live refreshes relationship state so active badges update.

#### Trainer Live Screen

**File**: `apps/mobile/lib/shared_sessions/`

**Intent**: Build the editable trainer live session screen from `apps/mobile/design/LiftMate.html`.

**Contract**: Match the design's trainer live structure: trainee/set header, live badge, exercise counter, set rows, value steppers by exercise type, done check, rest timer controls, next exercise, and close/cancel actions. Values and done-state changes update the canonical session through the controller.

#### Mobile Tests

**Files**:
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- new trainer live screen tests

**Intent**: Prove the trainer sees active state and can start/join through real UI entry points.

**Contract**: Tests cover green active badge, "Dołącz do sesji", "Rozpocznij wspólny trening", controller calls, and trainer live rendering with grouped session rows.

### Success Criteria

#### Automated Verification

- Widget tests prove active-session badge renders on trainer trainee list.
- Widget tests prove trainer detail switches between start and join actions.
- Widget tests prove trainer live screen renders editable rows and sends updates.
- `flutter test` passes.
- `flutter analyze` passes.

#### Manual Verification

- Trainer can see "Aktywna sesja" on the trainee list.
- Trainer can open details and join an active trainee session.
- Trainer can start a trainer-led session from an assigned set.

---

## Phase 5: Mobile Trainee Flow And Live Screens

### Overview

Wire trainee assigned-set cards into self-start and join behavior, with role-specific live views based on session origin.

### Changes Required

#### Assigned Workout Set View

**File**: `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart`

**Intent**: Replace the disabled S-03 placeholder with real session behavior.

**Contract**:
- If no active session exists, show "Rozpocznij trening" on each assigned set and start a self-session for that set.
- If an active session exists for the trainee, the relevant action becomes "Dołącz do aktywnego treningu".
- If the active session belongs to another set, prevent starting a second session and route the trainee to the active session with a clear state.

#### Trainee Home

**File**: `apps/mobile/lib/relationships/trainee_home_screen.dart`

**Intent**: Load active session state alongside assigned sets and keep the design's strong CTA.

**Contract**: Use controller state to choose start vs join labels. On mount/reconnect, fetch canonical active session if the view is empty.

#### Trainee Live View

**File**: `apps/mobile/lib/shared_sessions/`

**Intent**: Render the right trainee experience for session origin.

**Contract**:
- Trainer-led session: read-only `c_live` view from `apps/mobile/design/LiftMate.html`, with current exercise, current set, prominent current value, completed-set count, rest timer display, and "values update live" message.
- Trainee self-start session: full editable live view equivalent to trainer live, including steppers and done controls.

#### Realtime And Join Behavior

**Files**:
- `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart`
- shared-session controller files

**Intent**: Preserve F-03 discovery guarantees for both start modes.

**Contract**: A trainer-started session changes trainee CTA to "Dołącz do aktywnego treningu" through `sessionStarted` or active-session fetch fallback. A trainee self-start sends `sessionStarted` to the linked trainer; the trainer client then refreshes relationship data canonically before showing "Aktywna sesja". Both participants join the session group after loading a session.

#### Mobile Tests

**Files**:
- `apps/mobile/test/trainee_assigned_workout_sets_screen_test.dart`
- trainee home/live tests
- shared-session controller tests

**Intent**: Prove trainee start/join and origin-specific UI modes.

**Contract**: Tests cover self-start button, trainer-led join label, self-start editable live UI, trainer-led read-only live UI, and active-session fetch fallback.

### Success Criteria

#### Automated Verification

- Widget tests prove trainee can start a self-session from a concrete assigned set card.
- Widget tests prove trainer-led active sessions show "Dołącz do aktywnego treningu".
- Widget tests prove trainee self-start opens editable live UI.
- Widget tests prove trainer-led join opens read-only `c_live` UI.
- `flutter test` passes.
- `flutter analyze` passes.

#### Manual Verification

- Trainee can start an assigned workout without trainer involvement.
- Trainee sees full editable live controls for self-start.
- Trainee sees read-only live view when trainer started the session.
- Trainer can later join a self-started trainee session.

---

## Phase 6: Verification And Plan Bookkeeping

### Overview

Run the full automated verification set and record manual verification expectations clearly for post-PR checks.

### Changes Required

#### API Verification

**File**: `apps/api/LiftMate.slnx`

**Intent**: Ensure migrations, endpoint contracts, authorization, and tests are coherent.

**Contract**: Run restore/build/test from `apps/api` using repo commands.

#### Mobile Verification

**File**: `apps/mobile`

**Intent**: Ensure Flutter models, controllers, and screens pass tests and analysis.

**Contract**: Run `flutter test` and `flutter analyze` sequentially.

#### Change Artifacts

**Files**:
- `context/changes/start-shared-workout-session/plan.md`
- `context/changes/start-shared-workout-session/change.md`

**Intent**: Keep repo workflow state explicit.

**Contract**: During implementation, `/10x-implement` should flip only `## Progress` rows as verification completes, append phase commit SHAs, and set `change.md` to `implemented` only after all automated and manual acceptance is complete or the user explicitly confirms deferred manual checks.

### Success Criteria

#### Automated Verification

- `dotnet restore LiftMate.slnx` passes.
- `dotnet build LiftMate.slnx --no-restore` passes.
- `dotnet test LiftMate.slnx --no-build` passes.
- `flutter test` passes.
- `flutter analyze` passes.

#### Manual Verification

- Trainer-led flow works end to end: trainer starts, trainee joins read-only, trainer edits values, both see the same session.
- Trainee self-start flow works end to end: trainee starts, edits values, trainer sees active badge, trainer joins the same session.
- Closing/cancelling a session allows another session to be started for that trainee.
- Android text and controls match `apps/mobile/design/LiftMate.html` closely enough for the updated design contract.

---

## Testing Strategy

### Unit Tests

- API endpoint tests for start-from-workout-set, access boundaries, one-active-session invariant, and relationship active-session summary.
- Dart model tests for expanded shared-session response parsing and active-session summary parsing.
- Dart client tests for new start routes and error mapping.
- Controller tests for start, join, update, complete/cancel, and reconnect recovery.

### Integration Tests

- Existing API test host should cover trainer/trainee auth, pairing, workout-set assignment, session start, read, update, close, and forbidden access.
- Mobile widget tests should cover the trainer dashboard/detail flow and trainee home/live flow with fake clients/controllers.

### Manual Testing Steps

1. Create trainer and trainee accounts and pair them.
2. Trainer creates a workout set with multiple exercises and assigns it to the trainee.
3. Trainer starts a shared session from trainee detail; trainee joins and sees read-only live values.
4. Trainer changes values and marks series done; trainee view updates to the same session.
5. Complete/cancel the session.
6. Trainee starts the assigned workout alone; trainee sees editable live controls.
7. Trainer dashboard shows green "Aktywna sesja"; trainer opens trainee detail and joins the same session.
8. Complete/cancel the self-start session and verify a new session can be started.

## Performance Considerations

Session lists should not load full session value rows for every trainee on the trainer dashboard. Relationship summaries need only active-session metadata. Full value snapshots should load only when joining or viewing a live session.

## Migration Notes

Adding origin and workout-set fields to existing shared-session rows needs safe defaults:

- Existing historical/demo rows can keep `WorkoutSetId = null`.
- `StartedByUserId` can default to `TrainerUserId` for existing rows.
- `StartedByRole` can default to `trainer` for existing rows.
- `ExerciseOrder` can default to `1` for existing single-value demo rows.
- `IsDone` can default to `false`; `CompletedAt` can default to `null`.

The filtered unique active-session index by trainee should remain in place.

## References

- Roadmap: `context/foundation/roadmap.md` S-03.
- PRD: `context/foundation/prd.md` US-03, FR-004, FR-010, FR-012.
- Updated design contract: `apps/mobile/design/LiftMate.html`.
- Existing shared-session plan: `context/changes/shared-session-sync-contract/plan.md`.
- Existing shared-session API: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`.
- Existing workout-set API: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`.
- Existing trainee assigned-set UI: `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart`.
- Existing trainer relationship UI: `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Backend Session Origin And Workout-Set Start Contract

#### Automated

- [x] 1.1 API tests cover trainer start from an assigned workout set — e9bd73b
- [x] 1.2 API tests cover trainee self-start from an assigned workout set — e9bd73b
- [x] 1.3 API tests prove unassigned or wrong-trainer starts are rejected — e9bd73b
- [x] 1.4 API tests prove one active session per trainee across trainer-led and self-start paths — e9bd73b
- [x] 1.5 API tests prove value completion state persists and is returned to both participants — e9bd73b
- [x] 1.6 API tests prove trainer-led sessions reject trainee value updates while trainee-self-start sessions allow trainee updates — e9bd73b
- [x] 1.7 `dotnet test LiftMate.slnx --no-build` passes after build — e9bd73b

#### Manual

- [ ] 1.8 API response shape is understandable enough for mobile implementation: session origin, workout-set identity, exercise grouping, and done state are present

### Phase 2: Backend Active-Session Discovery For Trainer And Trainee

#### Automated

- [x] 2.1 API tests prove trainer relationship summary includes active-session state for linked trainees
- [x] 2.2 API tests prove self-start sessions are joinable by the linked trainer
- [x] 2.3 API tests prove unrelated trainers cannot see or join active sessions
- [x] 2.4 API/SignalR tests prove trainee self-start emits `sessionStarted` to the linked trainer
- [x] 2.5 `dotnet test LiftMate.slnx --no-build` passes after build

#### Manual

- [ ] 2.6 The active-session summary maps directly to the planned trainer "Aktywna sesja" list badge and detail "Dołącz do sesji" button

### Phase 3: Mobile Shared-Session Models And Controllers

#### Automated

- [ ] 3.1 Shared-session model tests cover new origin and grouping fields
- [ ] 3.2 Shared-session API client tests cover trainer and trainee start-from-set requests
- [ ] 3.3 Controller tests cover self-start, trainer-led join, active-session fetch, and reconnect recovery
- [ ] 3.4 Controller tests cover done-state toggles and trainer relationship refresh after trainee self-start events
- [ ] 3.5 `flutter test` passes
- [ ] 3.6 `flutter analyze` passes

#### Manual

- [ ] 3.7 Controller state names and failure messages are usable by the planned trainer and trainee screens

### Phase 4: Mobile Trainer Flow

#### Automated

- [ ] 4.1 Widget tests prove active-session badge renders on trainer trainee list
- [ ] 4.2 Widget tests prove trainer detail switches between start and join actions
- [ ] 4.3 Widget tests prove trainer live screen renders editable rows and sends updates
- [ ] 4.4 `flutter test` passes
- [ ] 4.5 `flutter analyze` passes

#### Manual

- [ ] 4.6 Trainer can see "Aktywna sesja" on the trainee list
- [ ] 4.7 Trainer can open details and join an active trainee session
- [ ] 4.8 Trainer can start a trainer-led session from an assigned set

### Phase 5: Mobile Trainee Flow And Live Screens

#### Automated

- [ ] 5.1 Widget tests prove trainee can start a self-session from a concrete assigned set card
- [ ] 5.2 Widget tests prove trainer-led active sessions show "Dołącz do aktywnego treningu"
- [ ] 5.3 Widget tests prove trainee self-start opens editable live UI
- [ ] 5.4 Widget tests prove trainer-led join opens read-only `c_live` UI
- [ ] 5.5 `flutter test` passes
- [ ] 5.6 `flutter analyze` passes

#### Manual

- [ ] 5.7 Trainee can start an assigned workout without trainer involvement
- [ ] 5.8 Trainee sees full editable live controls for self-start
- [ ] 5.9 Trainee sees read-only live view when trainer started the session
- [ ] 5.10 Trainer can later join a self-started trainee session

### Phase 6: Verification And Plan Bookkeeping

#### Automated

- [ ] 6.1 `dotnet restore LiftMate.slnx` passes
- [ ] 6.2 `dotnet build LiftMate.slnx --no-restore` passes
- [ ] 6.3 `dotnet test LiftMate.slnx --no-build` passes
- [ ] 6.4 `flutter test` passes
- [ ] 6.5 `flutter analyze` passes

#### Manual

- [ ] 6.6 Trainer-led flow works end to end: trainer starts, trainee joins read-only, trainer edits values, both see the same session
- [ ] 6.7 Trainee self-start flow works end to end: trainee starts, edits values, trainer sees active badge, trainer joins the same session
- [ ] 6.8 Closing/cancelling a session allows another session to be started for that trainee
- [ ] 6.9 Android text and controls match `apps/mobile/design/LiftMate.html` closely enough for the updated design contract
