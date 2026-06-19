# Save Progress for the Next Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use `superpowers:test-driven-development` for every production change and `superpowers:verification-before-completion` before completion claims.

**Goal:** Persist completed workout values as trainee-specific starting values for the next session and expose the approved three-level workout history flow to trainees and their currently linked trainers.

**Architecture:** Completed `SharedSession` records remain immutable history. A separate trainee–workout-set projection stores the latest starting values, while stable exercise and series IDs connect current templates, session snapshots, history charts, and future sessions without mutating global templates.

**Tech Stack:** ASP.NET Core 10 minimal APIs, EF Core 10, SQL Server, SQLite integration tests, Flutter/Dart, `http`, `flutter_test`, Flutter-native painting/layout.

---

## Overview

S-05 extends the existing workout-set and shared-session flow in four connected directions:

- preserve exercise and series identity when global sets are edited;
- atomically project every series from a completed session into trainee-specific next-session values;
- expose completed-session history, details, and exercise progress through authorized APIs;
- implement the three approved mobile screens from `apps/mobile/design/LiftMate.html`.

The feature must not overwrite `WorkoutSetRow` values globally because one set can be assigned to multiple trainees. It must also preserve completed session snapshots when templates are renamed, reordered, or edited later.

## Current State Analysis

- `WorkoutSetRow.Id` exists, but `WorkoutSetEndpoints.Update` removes every row and recreates it with new IDs (`apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs:106`).
- Workout-set request contracts do not carry row or exercise identity (`apps/api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs`).
- `WorkoutSetDraftExercise` reconstructs exercises from `ExerciseOrder` and uses temporary draft IDs (`apps/mobile/lib/workout_sets/workout_set_draft.dart`).
- Starting a shared session copies current template values but no source row/exercise IDs (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:274`).
- Completing a session currently changes only lifecycle fields; it creates no progress projection (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:415`).
- Completed sessions already retain values and timestamps, so they can remain the history source.
- There are no history endpoints, mobile history models, or history controller.
- The trainee shell currently exposes home/live flows only; the trainer trainee-detail screen has no functional history navigation.
- `apps/mobile/design/LiftMate.html` defines the authoritative Level 1–3 history flow and supersedes `LiftMate.dc.html` for this change.

## Desired End State

- Surviving exercises and series keep stable IDs when a workout set is edited.
- Every new set-backed session snapshots `ExerciseId`, `WorkoutSetRowId`, and workout-set name.
- **Zakończ i zapisz trening** atomically completes the session and updates the trainee-specific projection using all series.
- Repeated completion is idempotent, and an older completion cannot overwrite a newer projection.
- Cancelled and ad-hoc sessions never update starting values.
- The next trainer-led or trainee-started session merges projected values with the current template by stable row ID.
- Completed-session history is cursor-paginated by 20 and accessible only to the trainee or their currently linked trainer.
- Mobile users can navigate History → Session details → Exercise progress using the approved visual contract.
- No PR badges, export, historical editing, or trainer access after relationship termination are introduced.

## Key Decisions

| Area | Decision | Rationale |
|---|---|---|
| Projected series | Persist every series | The next session should reproduce the final saved workout, regardless of done-state. |
| Save trigger | Complete only | Cancellation and partial abandonment must not change future targets. |
| Ownership | Trainee + workout set | Global templates can serve multiple trainees safely. |
| Template changes | Stable exercise and row IDs; new identity on type change | Preserves progress across rename/reorder without mixing incompatible chart units. |
| Unassignment | Preserve projection | Removing an assignment must not destroy history or future restoration. |
| Retry safety | Source-session idempotency | A lost response can be retried without applying progress twice. |
| Ordering | Latest completion wins | Delayed requests cannot roll progress back. |
| History scope | Completed sessions only | History and progression represent deliberately saved workouts. |
| Chart point | Maximum value per exercise/session | Matches the approved “best value” session-detail presentation. |
| Trainer access | Active relationship only | Matches current privacy and authorization boundaries. |
| Pagination | Opaque cursor, 20 rows | Stable performance and deterministic ordering. |
| Chart implementation | Flutter-native | Avoids a new dependency for a compact bar chart. |

## What We're NOT Doing

- No changes inside `context/archive/`.
- No personal-record detection or badges.
- No history export.
- No editing or deleting completed sessions.
- No manual reset/edit UI for projected values.
- No volume, estimated 1RM, or advanced analytics.
- No cancelled-session history.
- No trainer history access after relationship termination.
- No replacement of the active-session realtime transport.
- No broad redesign of existing live-session entry.

## Implementation Approach

Implement bottom-up so each phase leaves a stable contract for the next:

1. introduce and preserve stable template identities;
2. add the projection and transactional completion/start merge;
3. expose read-only history APIs;
4. build typed Flutter history data/controller boundaries;
5. implement the approved screens, navigation, feedback, and full verification.

Each phase follows test-first development and ends with a dedicated commit. Automated checks are completed before requesting manual confirmation. Manual Progress items are checked only after explicit user confirmation.

## Critical Implementation Details

### Atomic completion ordering

The completion timestamp used for `SharedSession.ClosedAt` and projection `SourceCompletedAt` must be the same value inside one transaction. The projection comparison must happen before replacing projection rows; otherwise a delayed older completion could erase newer values even if the root timestamp is later restored.

Because SQL Server is configured with `EnableRetryOnFailure`, the complete operation must run through `dbContext.Database.CreateExecutionStrategy().ExecuteAsync`. Each strategy attempt opens a `Serializable` transaction, reloads the session and projection inside that transaction, applies the state transition once, and commits before broadcasting.

### Stable update semantics

The workout-set update endpoint must distinguish omitted IDs (new exercise/series) from supplied IDs (existing records). It must validate ownership before mutation and update/delete/add rows by ID rather than using `RemoveRange` for the whole set.

Changing exercise type creates a new `ExerciseId` and new row IDs for that exercise. Rename, reorder, and value changes preserve IDs. This prevents one progress series from combining kilograms, repetitions, and seconds.

### Snapshot identifiers are not foreign keys

`SharedSessionValue.WorkoutSetRowId` and `WorkoutProgressValue.WorkoutSetRowId` are indexed snapshot identifiers without EF navigation properties or database foreign keys. Template rows may be removed without deleting history or blocking set edits. The projection root keeps a real restricted foreign key to `WorkoutSet`.

### Legacy compatibility

Existing completed sessions can appear in list/detail history after workout-set-name backfill, but values without stable IDs cannot safely feed cross-session charts or projections. APIs must return a readable detail fallback without inventing identity links.

---

## Phase 1: Stable Workout Structure And Session References

### Overview

Introduce durable exercise/series identity, migrate existing data, and preserve IDs through API and Flutter workout-set editing before progress depends on those identifiers.

### Changes Required

#### 1. Stable Workout-Set Entities And Migration

**Files**:

- `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetRow.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionValue.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddStableWorkoutIdentityAndSessionSnapshots.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddStableWorkoutIdentityAndSessionSnapshots.Designer.cs`
- `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`
- `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`

**Intent**: Make exercise and series identity durable and snapshot enough source information for immutable history.

**Contract**:

- Add required `ExerciseId` to `WorkoutSetRow`; retain `Id` as series ID.
- Add nullable `ExerciseId` and `WorkoutSetRowId` to `SharedSessionValue`.
- Add required `WorkoutSetName` snapshot to `SharedSession`, using a neutral fallback for ad-hoc sessions.
- Index workout rows by `(WorkoutSetId, ExerciseId, SetIndex)` and session values by `ExerciseId` and `WorkoutSetRowId`.
- Treat `SharedSessionValue.WorkoutSetRowId` as a scalar snapshot identifier with no FK/navigation to `WorkoutSetRow`.
- Backfill one `ExerciseId` per existing `(WorkoutSetId, ExerciseOrder)` group.
- Backfill set-backed session names from their current workout set; use `Trening` for sessions without a set.
- Generate an idempotent SQL Server migration script in the migration test and assert that it contains the new columns, indexes, backfill statements, and no destructive FK from session values to workout rows.

#### 2. Stable Workout-Set Contracts And Mapping

**Files**:

- `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs`
- `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetMapping.cs`
- `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetPersistenceTests.cs`

**Intent**: Preserve supplied IDs during edits while allowing the API to allocate IDs for new exercises and series.

**Contract**:

- `WorkoutSetRowRequest` accepts nullable row `Id` and nullable `ExerciseId`.
- `WorkoutSetRowResponse` always returns both IDs.
- Create allocates one exercise ID per request exercise group and one row ID per series when omitted.
- Update validates that supplied row IDs belong to the target set and supplied exercise IDs are internally consistent.
- Update modifies surviving rows, adds omitted-ID rows, and deletes absent existing rows.
- Reorder, rename, and value change preserve supplied IDs.
- Type change is represented as a new exercise: the client omits `ExerciseId` and row IDs for that exercise, and the API allocates replacements while deleting the old rows.
- Duplicate row IDs, foreign row IDs, inconsistent exercise IDs, and duplicate `(ExerciseOrder, SetIndex)` return `400`.

#### 3. Flutter Workout-Set Identity Preservation

**Files**:

- `apps/mobile/lib/workout_sets/workout_set_models.dart`
- `apps/mobile/lib/workout_sets/workout_set_draft.dart`
- `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`
- `apps/mobile/test/workout_set_models_test.dart`
- `apps/mobile/test/workout_set_api_client_test.dart`
- `apps/mobile/test/workout_set_trainer_screens_test.dart`

**Intent**: Keep backend identifiers through model parsing, draft editing, adding/removing series, and save requests.

**Contract**:

- `WorkoutSetRow` parses `id` and `exerciseId`.
- `WorkoutSetRowRequest` serializes nullable `id` and `exerciseId`.
- Existing draft exercises retain one exercise ID and each existing series ID.
- Added exercises/series omit IDs; removed series are absent from the update request.
- Editing exercise metadata does not replace existing identifiers.
- Changing exercise type intentionally clears that exercise's identity so the API creates a new exercise and series identity.

#### 4. Session Snapshot References

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionMapping.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- `apps/mobile/lib/shared_sessions/shared_session_models.dart`
- `apps/mobile/test/shared_session_models_test.dart`

**Intent**: Carry stable template references into new session snapshots without breaking legacy/ad-hoc responses.

**Contract**:

- Set-backed session creation copies row `ExerciseId`, row `Id`, and current set name.
- Ad-hoc session creation uses `WorkoutSetName = "Trening"` and null source references.
- Shared-session DTOs expose workout-set name and nullable stable IDs.
- Flutter models parse the expanded response.

### Success Criteria

#### Automated Verification

- SQLite test model creates successfully with the new schema.
- Idempotent SQL Server migration script contains the required backfills and avoids history-to-template-row foreign keys.
- Workout-set create returns stable exercise and row IDs.
- Workout-set update preserves surviving IDs across rename, reorder, and value edits.
- Update rejects foreign and inconsistent identifiers.
- Type changes allocate new exercise and row IDs instead of extending the old progress series.
- Flutter builder requests preserve identifiers for existing exercises and omit them for new ones.
- New set-backed sessions snapshot name, exercise IDs, and row IDs.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WorkoutSet"` passes.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpointTests"` passes.
- Targeted Flutter workout-set/model tests pass.
- `flutter analyze` passes.

#### Manual Verification

- Migration applies to a disposable SQL Server database with representative pre-S-05 rows and produces the expected backfill.
- Editing an existing set in the trainer UI retains its exercises and series without visible duplication or reset.
- Adding and removing a series produces the expected set after reopening the editor.

---

## Phase 2: Transactional Progress Projection And Next-Session Merge

### Overview

Persist all completed-session series into a trainee-specific projection and use that projection when either role starts the next workout.

### Changes Required

#### 1. Progress Projection Entities And Constraints

**Files**:

- `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgress.cs`
- `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressValue.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddWorkoutProgressProjection.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddWorkoutProgressProjection.Designer.cs`
- `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`
- `apps/api/LiftMate.Api.Tests/TrainingProgress/WorkoutProgressPersistenceTests.cs`

**Intent**: Store the latest saved values independently from removable assignments and global template defaults.

**Contract**:

- One root per `(TraineeUserId, WorkoutSetId)`.
- Root stores `SourceSessionId`, `SourceCompletedAt`, and `UpdatedAt`.
- Source session ID is unique.
- Child rows are unique by `(WorkoutProgressId, WorkoutSetRowId)` and store `ExerciseId`, type, reps, weight, seconds.
- `WorkoutProgressValue.WorkoutSetRowId` is a scalar snapshot identifier with no FK/navigation to `WorkoutSetRow`.
- Deleting an assignment does not cascade to progress.
- Projection root has a restricted FK to `WorkoutSet`; workout-set deletion remains restricted while progress references it.

#### 2. Completion Projection Service

**Files**:

- `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api/Program.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Complete the session and update starting values as one retry-safe operation.

**Contract**:

- `Complete` runs inside `CreateExecutionStrategy().ExecuteAsync`.
- Each strategy attempt opens a `Serializable` transaction and reloads the session and projection inside that transaction before lifecycle mutation.
- Already-completed sessions return unchanged and do not reapply projection rows.
- Cancelled sessions remain conflicts.
- All session values are projected regardless of `IsDone`.
- Ad-hoc or legacy sessions without usable references complete without projection.
- A projection changes only when the incoming `ClosedAt` is later than `SourceCompletedAt`.
- Projection rows are replaced only after the timestamp guard succeeds.
- Commit occurs before realtime broadcast.
- Concurrent complete requests serialize on the session/projection state; one applies the transition, while the other observes the completed session and returns it unchanged.

#### 3. Projection Merge On Session Start

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Apply saved trainee values to the current set structure for trainer-led and self-started sessions.

**Contract**:

- Load progress by trainee and workout-set IDs during `StartFromWorkoutSet`.
- Match values only by stable `WorkoutSetRowId`.
- Current template order, name, type, and membership remain authoritative.
- Matching rows use projected reps/weight/seconds.
- New rows use template defaults; removed rows are absent.
- Unassignment followed by reassignment reuses preserved projection.

#### 4. Completion Feedback Contract

**Files**:

- `apps/mobile/lib/shared_sessions/shared_session_controller.dart`
- `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- `apps/mobile/test/shared_session_controller_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`

**Intent**: Make a successful save visible and keep failures inside the active session.

**Contract**:

- Successful completion returns a distinct saved outcome to the shell.
- The shell closes live view and shows a confirmation that values were saved for the next session.
- Failed completion leaves the session visible and presents the API error.
- The existing realtime completed snapshot remains compatible.

### Success Criteria

#### Automated Verification

- Completion persists every series into the projection.
- Repeating completion does not duplicate or rewrite progress.
- A completion with an older timestamp cannot replace newer progress.
- Cancellation and ad-hoc completion leave progress unchanged.
- Unassignment does not delete progress.
- Reassignment restores projected starting values.
- Both trainer-led and trainee-self-started sessions merge projected values.
- New template rows use defaults and removed rows do not reappear.
- Targeted progress/shared-session API tests pass.
- Targeted Flutter completion tests pass.
- `dotnet build LiftMate.slnx --no-restore` passes.
- `flutter analyze` passes.

#### Manual Verification

- Finish a workout with changed values and confirm the success message appears.
- Start the same assigned set again and confirm every series starts with the saved values.
- Add a new series to the template and confirm it starts from the template default while older series retain progress.

---

## Phase 3: Authorized Completed-Session History API

### Overview

Add read-only API contracts for the three history levels with deterministic cursor pagination and active-relationship authorization.

### Changes Required

#### 1. History Contracts And Access Policy

**Files**:

- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryContracts.cs`
- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryAccess.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

**Intent**: Define focused DTOs and one reusable target-trainee authorization rule.

**Contract**:

- Map the route group at `/training-history` with authorization required.
- Trainee requests target the authenticated trainee.
- Trainer requests require `traineeUserId` and current `TrainerUserId` linkage.
- Former/unrelated trainers receive `403` without data leakage.
- List/detail/progress endpoints run the same authorization check independently.
- `GET /training-history/sessions?traineeUserId={optional}&cursor={optional}` returns `TrainingHistoryPageResponse`.
- `GET /training-history/sessions/{sessionId}` derives the target trainee from the session and returns `TrainingHistorySessionResponse`.
- `GET /training-history/exercises/{exerciseId}?traineeUserId={optional}` returns `ExerciseProgressResponse`.
- Missing authenticated user returns `401`; invalid role/relationship returns `403`; malformed cursor returns `400`; inaccessible or absent session/exercise returns `404`.

#### 2. Cursor-Paginated Session List

**Files**:

- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryCursor.cs`
- `apps/api/LiftMate.Api/Program.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

**Intent**: Return newest completed sessions in stable pages of 20.

**Contract**:

- Order by `ClosedAt DESC, Id DESC`.
- Opaque cursor encodes both ordering keys and rejects malformed input with `400`.
- Response includes items plus nullable `nextCursor`.
- `TrainingHistoryPageResponse` contains `IReadOnlyList<TrainingHistorySessionSummaryResponse> Items` and `string? NextCursor`.
- Items contain ID, workout-set name snapshot, start/end timestamps, duration seconds, distinct exercise count, and series count.
- Active and cancelled sessions are excluded.

#### 3. Session Detail Endpoint

**Files**:

- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

**Intent**: Return an immutable grouped snapshot for Level 2.

**Contract**:

- Only completed sessions are returned.
- Group stable values by `ExerciseId`; legacy null-ID values fall back to snapshot exercise order/name grouping for readable detail only.
- Exercises and series retain snapshot ordering.
- Each exercise exposes its type, stable ID when available, all series values, and calculated maximum.
- `TrainingHistorySessionResponse` contains session metadata and ordered `TrainingHistoryExerciseResponse` items; each exercise contains nullable `ExerciseId`, snapshot name/type/order, maximum value, and ordered `TrainingHistorySeriesResponse` values.
- Maximum means weight for `repsWeight`, reps for `repsOnly`, and seconds for `time`.

#### 4. Exercise Progress Endpoint

**Files**:

- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

**Intent**: Supply chronological chart/list points for one stable exercise.

**Contract**:

- Query completed sessions for target trainee containing the requested `ExerciseId`.
- Return one point per session, chronologically ordered.
- Select the maximum type-specific value in each session.
- Return current, start, overall delta, type/unit metadata, and point-level deltas.
- `ExerciseProgressResponse` contains exercise ID, snapshot name/type, start/current/overall-delta values, and ordered `ExerciseProgressPointResponse` items containing session ID, completion timestamp, selected value, and nullable delta.
- Do not emit PR flags.
- Unknown exercise with no accessible points returns `404`.

### Success Criteria

#### Automated Verification

- List returns only completed sessions and exactly 20 items before a cursor.
- Cursor traversal has no duplicates or omissions for equal completion timestamps.
- Malformed cursors return `400`.
- Detail grouping, ordering, counts, duration, and maximum values are correct.
- Progress point selection and deltas are correct for all three exercise types.
- Trainee self-access works.
- Current trainer access works.
- Former and unrelated trainer access fails for all endpoints.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"` passes.
- Full API tests pass.
- `dotnet build LiftMate.slnx --no-restore` passes.

#### Manual Verification

- API responses for a trainee with multiple completed sessions match the visible session values and ordering.
- Removing the trainer relationship immediately prevents trainer history requests while trainee access remains available.

---

## Phase 4: Flutter History Models, API Client, And Controller

### Overview

Create a typed, independently testable mobile data layer for pagination and nested history navigation.

### Changes Required

#### 1. History Models And Formatting

**Files**:

- `apps/mobile/lib/training_history/training_history_models.dart`
- `apps/mobile/lib/training_history/training_history_formatters.dart`
- `apps/mobile/test/training_history_models_test.dart`
- `apps/mobile/test/training_history_formatters_test.dart`

**Intent**: Parse API contracts and centralize Polish display formatting.

**Contract**:

- Models cover paged summaries, session detail, exercise groups/series, and progress points.
- Parsing rejects missing or type-invalid fields.
- Formatters handle local date labels, duration, count labels, decimal weights, series chips, units, and signed deltas.
- No formatter infers PR status.

#### 2. History API Client

**Files**:

- `apps/mobile/lib/training_history/training_history_api_client.dart`
- `apps/mobile/test/training_history_api_client_test.dart`

**Intent**: Provide authenticated methods for all three levels and role-specific targets.

**Contract**:

- List accepts optional cursor and optional trainee ID.
- Detail accepts session ID only; the API derives and authorizes its trainee.
- Progress accepts exercise ID and optional trainee ID.
- Cursor and target parameters are URI encoded.
- Status mapping follows existing API-client conventions.

#### 3. History Controller

**Files**:

- `apps/mobile/lib/training_history/training_history_controller.dart`
- `apps/mobile/test/training_history_controller_test.dart`

**Intent**: Keep list pagination and nested detail/progress state explicit without discarding loaded list state.

**Contract**:

- Initial load replaces list state.
- Load-more appends once, ignores duplicate concurrent calls, and keeps existing items on failure.
- Retry distinguishes initial and pagination failures.
- Opening detail/progress stores nested state while retaining list items and cursor.
- Back navigation clears only the current nested level.
- Target trainee ID is immutable for one controller flow.

#### 4. Application Wiring

**Files**:

- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- relevant auth/shell constructor tests

**Intent**: Inject one history API client and create/dispose history controllers at the authenticated-shell boundary.

**Contract**:

- Production client uses the configured API base URL.
- Trainee history targets self.
- Trainer history creates a flow scoped to the selected trainee.
- Controllers are disposed when the authenticated shell or target flow closes.

### Success Criteria

#### Automated Verification

- Models parse all three response levels and reject invalid JSON.
- Formatters cover all exercise types, decimals, negative/equal deltas, and Polish counts.
- API client sends correct cursor and trainee parameters.
- Controller covers initial, empty, retry, pagination, pagination failure, detail, progress, and back states.
- Existing dependency wiring tests remain compatible.
- Targeted training-history Flutter tests pass.
- Full `flutter test` passes.
- `flutter analyze` passes.

#### Manual Verification

- Slow or failed initial history load shows a readable retry state.
- Pagination failure preserves already loaded sessions and can be retried.

---

## Phase 5: Three-Level History UI, Navigation, And Closure

### Overview

Implement the design-contract screens, connect both role entry points, verify the full save-to-next-session flow, and update change bookkeeping only after manual acceptance.

### Changes Required

#### 1. Level 1 History Screen

**Files**:

- `apps/mobile/lib/training_history/training_history_screen.dart`
- `apps/mobile/test/training_history_screen_test.dart`

**Intent**: Reproduce the approved completed-session list with incremental loading.

**Contract**:

- Follow `LiftMate.html` date tile, title, completed-session count, metadata row, spacing, colors, and typography.
- Selecting a card opens Level 2.
- Near-bottom scrolling requests the next page once.
- Loading, empty, initial error, and load-more error states fit the same layout.
- Trainee bottom navigation marks **Historia** active across all three levels.

#### 2. Level 2 Session Detail Screen

**Files**:

- `apps/mobile/lib/training_history/training_history_session_screen.dart`
- `apps/mobile/test/training_history_session_screen_test.dart`

**Intent**: Show the immutable session snapshot and entry to exercise progress.

**Contract**:

- Header shows snapshot set name and completion date.
- Summary cards show duration, exercise count, and series count.
- Exercise cards show name, series count, maximum label, ordered value chips, and **progres ›**.
- Exercises without stable IDs remain readable but do not expose progress navigation.

#### 3. Level 3 Exercise Progress Screen And Chart

**Files**:

- `apps/mobile/lib/training_history/training_history_progress_screen.dart`
- `apps/mobile/lib/training_history/training_history_chart.dart`
- `apps/mobile/test/training_history_progress_screen_test.dart`
- `apps/mobile/test/training_history_chart_test.dart`

**Intent**: Display maximum-value progression and recent deltas without adding a chart dependency.

**Contract**:

- Follow the approved headline, overall delta, start-to-current summary, bars, date labels, and recent-values list.
- Scale bars safely when there is one point or all values are equal.
- Support decimal weights, negative deltas, and narrow screens without overflow.
- No PR labels or icons.

#### 4. Trainee And Trainer Navigation

**Files**:

- `apps/mobile/lib/relationships/trainee_home_screen.dart`
- `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- `apps/mobile/test/trainee_assigned_workout_sets_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Connect the same history flow from the trainee bottom navigation and trainer's selected-trainee screen.

**Contract**:

- Trainee **Historia** opens self history and returns to **Dziś** correctly.
- Trainer **Historia** button matches `LiftMate.html`, targets the selected trainee, and returns to that trainee detail.
- Level 1–3 back behavior preserves loaded list state.
- Trainer flow does not expose another trainee's cached data after switching target.

#### 5. End-To-End Verification And Bookkeeping

**Files**:

- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- `apps/mobile/test/trainee_assigned_workout_sets_screen_test.dart`
- `context/changes/save-progress-next-session/change.md`
- `context/foundation/roadmap.md`
- `context/changes/save-progress-next-session/plan.md`

**Intent**: Prove the complete user outcome and close S-05 only after explicit manual confirmation.

**Contract**:

- Automated flow proves: complete session → projection updated → history visible → next session starts from saved values.
- Automated role flow proves trainee and current trainer see the same completed session.
- Before manual QA, keep roadmap S-05 non-done and `change.md` in `implementing`.
- After explicit user confirmation, set `change.md` to `implemented`, update roadmap S-05 to `done`, and check manual Progress items.
- Archive remains a separate `/10x-archive save-progress-next-session` action.

### Success Criteria

#### Automated Verification

- Level 1 matches required data, states, and pagination behavior.
- Level 2 renders all exercises and ordered series values.
- Level 3 renders correct bars and deltas without overflow.
- Trainee navigation covers all three levels and back behavior.
- Trainer history targets only the selected currently linked trainee.
- Completion feedback appears after successful save.
- Cross-stack tests prove saved values become the next session's starting values.
- `dotnet restore LiftMate.slnx` succeeds.
- `dotnet build LiftMate.slnx --no-restore` passes.
- Full `dotnet test LiftMate.slnx --no-build` passes.
- Full `flutter test` passes.
- `flutter analyze` passes.
- Roadmap remains non-done before manual confirmation.

#### Manual Verification

- Complete a workout and confirm every saved series becomes the next session's starting value.
- Confirm cancelled and ad-hoc sessions do not affect starting values.
- Confirm trainee Level 1, Level 2, and Level 3 match `LiftMate.html` on a phone-sized viewport.
- Confirm trainer **Historia** opens the selected trainee's same history flow.
- Confirm unassign/reassign preserves progress.
- Confirm ending the relationship removes trainer access but not trainee access.
- Confirm pagination loads sessions beyond the first 20 without duplicates.
- After all checks, approve S-05 roadmap closure.

---

## Testing Strategy

### API Unit And Integration Tests

- Stable ID allocation, preservation, ownership validation, and deletion semantics.
- Migration backfill for exercise IDs and session names.
- Projection schema constraints and assignment-independent lifetime.
- Atomic completion, all-series projection, retry idempotency, and timestamp ordering.
- Current-template merge with matching, added, and removed rows.
- Cursor ordering across identical timestamps.
- History authorization for trainee, current trainer, former trainer, and outsider.
- Detail and progress calculations for `repsWeight`, `repsOnly`, and `time`.

### Flutter Unit, Controller, And Widget Tests

- JSON parsing and request construction.
- Formatting of session cards, series chips, dates, durations, units, and deltas.
- Pagination state and nested navigation preservation.
- Design-contract rendering for Level 1–3.
- Native chart edge cases.
- Trainer target isolation and trainee self-target flow.
- Completion feedback and next-session projected values.

### Manual Testing Steps

1. Assign one global set to two trainees and give them different completed values.
2. Start the next session for each trainee and verify values remain independent.
3. Edit the template by renaming/reordering an exercise and adding/removing a series.
4. Verify surviving series retain progress, the new series uses defaults, and removed series stay absent.
5. Complete a session with at least one unchecked series and verify all series are saved.
6. Retry the completion request and verify no duplicate/rollback occurs.
7. Browse all three history levels as the trainee.
8. Browse the same trainee history from the trainer's **Podopieczny** screen.
9. Remove the relationship and verify trainer access is rejected.
10. Reassign the set and verify preserved projected values return.
11. Populate more than 20 completed sessions and verify cursor pagination.

## Performance Considerations

- Session-start projection lookup uses the unique trainee/set key and row-ID dictionary merge.
- Completion replaces only one trainee/set projection after a timestamp guard.
- History list projects summary counts server-side and returns at most 20 records.
- Progress queries use trainee, status, exercise ID, and completion-time indexes.
- Flutter retains loaded pages and does not refetch them when navigating Level 1–3.
- The chart renders only returned progress points and uses no animation-heavy dependency.

## Migration Notes

- Generate migrations from the API project after entity/configuration changes.
- Keep SQLite `EnsureCreated()` integration tests for runtime model behavior; they do not prove migrations.
- Add an automated test/command that generates an idempotent SQL Server migration script and checks the expected schema/backfill statements.
- Before deployment, apply the migration to a disposable SQL Server database seeded with representative pre-S-05 rows and verify the backfilled exercise IDs and workout-set names.
- Existing `WorkoutSetRow.Id` values remain series identities.
- Existing exercise IDs are backfilled by set + exercise order.
- Existing set-backed sessions receive a workout-set-name snapshot.
- Existing session values keep null stable references and remain readable.
- Do not synthesize historical stable IDs by name.
- Projection and cross-session chart history begin with stable-reference sessions.
- `Down` removes new projection tables, indexes, and columns; rollback restores the pre-S-05 schema but cannot preserve progress written after deployment.

## References

- Approved design: `docs/superpowers/specs/2026-06-19-save-progress-next-session-design.md`
- Roadmap S-05: `context/foundation/roadmap.md`
- PRD US-02 / FR-011: `context/foundation/prd.md`
- Mobile visual contract: `apps/mobile/design/LiftMate.html`
- Current workout-set update: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`
- Current session start/complete: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- Current workout-set builder: `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`
- Current authenticated navigation: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- Existing shared-session API tests: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- Existing mobile session tests: `apps/mobile/test/shared_session_controller_test.dart`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Stable Workout Structure And Session References

#### Automated

- [x] 1.1 SQLite test model creates successfully with the new schema.
- [x] 1.2 Idempotent SQL Server migration script contains the required backfills and avoids history-to-template-row foreign keys.
- [x] 1.3 Workout-set create returns stable exercise and row IDs.
- [x] 1.4 Workout-set update preserves surviving IDs across rename, reorder, and value edits.
- [x] 1.5 Update rejects foreign and inconsistent identifiers.
- [x] 1.6 Type changes allocate new exercise and row IDs instead of extending the old progress series.
- [x] 1.7 Flutter builder requests preserve identifiers for existing exercises and omit them for new ones.
- [x] 1.8 New set-backed sessions snapshot name, exercise IDs, and row IDs.
- [x] 1.9 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WorkoutSet"` passes.
- [x] 1.10 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpointTests"` passes.
- [x] 1.11 Targeted Flutter workout-set/model tests pass.
- [x] 1.12 `flutter analyze` passes.

#### Manual

- [ ] 1.13 Migration applies to a disposable SQL Server database with representative pre-S-05 rows and produces the expected backfill.
- [ ] 1.14 Editing an existing set in the trainer UI retains its exercises and series without visible duplication or reset.
- [ ] 1.15 Adding and removing a series produces the expected set after reopening the editor.

### Phase 2: Transactional Progress Projection And Next-Session Merge

#### Automated

- [ ] 2.1 Completion persists every series into the projection.
- [ ] 2.2 Repeating completion does not duplicate or rewrite progress.
- [ ] 2.3 A completion with an older timestamp cannot replace newer progress.
- [ ] 2.4 Cancellation and ad-hoc completion leave progress unchanged.
- [ ] 2.5 Unassignment does not delete progress.
- [ ] 2.6 Reassignment restores projected starting values.
- [ ] 2.7 Both trainer-led and trainee-self-started sessions merge projected values.
- [ ] 2.8 New template rows use defaults and removed rows do not reappear.
- [ ] 2.9 Targeted progress/shared-session API tests pass.
- [ ] 2.10 Targeted Flutter completion tests pass.
- [ ] 2.11 `dotnet build LiftMate.slnx --no-restore` passes.
- [ ] 2.12 `flutter analyze` passes.

#### Manual

- [ ] 2.13 Finish a workout with changed values and confirm the success message appears.
- [ ] 2.14 Start the same assigned set again and confirm every series starts with the saved values.
- [ ] 2.15 Add a new series to the template and confirm it starts from the template default while older series retain progress.

### Phase 3: Authorized Completed-Session History API

#### Automated

- [ ] 3.1 List returns only completed sessions and exactly 20 items before a cursor.
- [ ] 3.2 Cursor traversal has no duplicates or omissions for equal completion timestamps.
- [ ] 3.3 Malformed cursors return `400`.
- [ ] 3.4 Detail grouping, ordering, counts, duration, and maximum values are correct.
- [ ] 3.5 Progress point selection and deltas are correct for all three exercise types.
- [ ] 3.6 Trainee self-access works.
- [ ] 3.7 Current trainer access works.
- [ ] 3.8 Former and unrelated trainer access fails for all endpoints.
- [ ] 3.9 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"` passes.
- [ ] 3.10 Full API tests pass.
- [ ] 3.11 `dotnet build LiftMate.slnx --no-restore` passes.

#### Manual

- [ ] 3.12 API responses for a trainee with multiple completed sessions match the visible session values and ordering.
- [ ] 3.13 Removing the trainer relationship immediately prevents trainer history requests while trainee access remains available.

### Phase 4: Flutter History Models, API Client, And Controller

#### Automated

- [ ] 4.1 Models parse all three response levels and reject invalid JSON.
- [ ] 4.2 Formatters cover all exercise types, decimals, negative/equal deltas, and Polish counts.
- [ ] 4.3 API client sends correct cursor and trainee parameters.
- [ ] 4.4 Controller covers initial, empty, retry, pagination, pagination failure, detail, progress, and back states.
- [ ] 4.5 Existing dependency wiring tests remain compatible.
- [ ] 4.6 Targeted training-history Flutter tests pass.
- [ ] 4.7 Full `flutter test` passes.
- [ ] 4.8 `flutter analyze` passes.

#### Manual

- [ ] 4.9 Slow or failed initial history load shows a readable retry state.
- [ ] 4.10 Pagination failure preserves already loaded sessions and can be retried.

### Phase 5: Three-Level History UI, Navigation, And Closure

#### Automated

- [ ] 5.1 Level 1 matches required data, states, and pagination behavior.
- [ ] 5.2 Level 2 renders all exercises and ordered series values.
- [ ] 5.3 Level 3 renders correct bars and deltas without overflow.
- [ ] 5.4 Trainee navigation covers all three levels and back behavior.
- [ ] 5.5 Trainer history targets only the selected currently linked trainee.
- [ ] 5.6 Completion feedback appears after successful save.
- [ ] 5.7 Cross-stack tests prove saved values become the next session's starting values.
- [ ] 5.8 `dotnet restore LiftMate.slnx` succeeds.
- [ ] 5.9 `dotnet build LiftMate.slnx --no-restore` passes.
- [ ] 5.10 Full `dotnet test LiftMate.slnx --no-build` passes.
- [ ] 5.11 Full `flutter test` passes.
- [ ] 5.12 `flutter analyze` passes.
- [ ] 5.13 Roadmap remains non-done before manual confirmation.

#### Manual

- [ ] 5.14 Complete a workout and confirm every saved series becomes the next session's starting value.
- [ ] 5.15 Confirm cancelled and ad-hoc sessions do not affect starting values.
- [ ] 5.16 Confirm trainee Level 1, Level 2, and Level 3 match `LiftMate.html` on a phone-sized viewport.
- [ ] 5.17 Confirm trainer **Historia** opens the selected trainee's same history flow.
- [ ] 5.18 Confirm unassign/reassign preserves progress.
- [ ] 5.19 Confirm ending the relationship removes trainer access but not trainee access.
- [ ] 5.20 Confirm pagination loads sessions beyond the first 20 without duplicates.
- [ ] 5.21 After all checks, approve S-05 roadmap closure.
