# Assign Global Workout Set Implementation Plan

## Overview

Build LiftMate slice S-02: trainers can create reusable global workout sets, define exercise rows inside those sets, assign one set to multiple linked trainees, explicitly unassign when needed, and trainees can see their assigned sets on the mobile home screen.

This plan intentionally stops before S-03. It creates the stable assignment and assigned-set detail contract that S-03 will use to start a shared workout session from a `workoutSetId` that is assigned to the trainee instead of continuing the current ad hoc `CreateSharedSessionRequest.Values` path.

## Current State Analysis

The product foundation is already stronger than the original roadmap baseline:

- Auth, role policies, JWT, Identity storage, and trainer/trainee pairing are present.
- `ApplicationUser.TrainerUserId` is the current relationship source of truth.
- `GET /trainer/relationship` and `GET /trainee/relationship` expose linked users.
- Shared sessions already store exercise value snapshots with `exerciseName`, `exerciseType`, `setIndex`, and type-specific values.
- Flutter has relationship screens and a placeholder "Przypisany zestaw" section in the trainer trainee-detail screen.
- The design file has concrete trainer screens for `t_sets`, `t_builder`, `t_addex`, and `t_assign`, plus a trainee `c_home` screen with assigned-set style content.

The missing piece is a durable workout-set and assignment model. Today, shared sessions can be created only by sending inline values directly to `/shared-sessions`, so assigned templates do not exist as a reusable product object.

## Desired End State

When this plan is complete:

- A trainer can list, create, update, and inspect their global workout sets.
- A workout set stores ordered per-set rows, not only per-exercise defaults.
- Each row uses the existing exercise type vocabulary: `repsWeight`, `repsOnly`, or `time`.
- A trainer can assign one global set to many currently linked trainees in one action.
- A trainer can explicitly unassign a set from a trainee.
- A trainee can see all currently assigned workout sets and their ordered rows.
- Existing assignments continue pointing at the latest global set content until a future session is started.
- The API exposes assigned-set details in a shape S-03 can use as a session-start source.

### Key Discoveries:

- `ApplicationDbContext` already wires Identity, pairing, shared sessions, shared values, indexes, and check constraints in one project: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:15`.
- Pairing endpoints already prove trainer-linked trainees through `TrainerUserId`: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:51`.
- Shared session values already define the type-specific value pattern this slice should reuse: `apps/api/LiftMate.Api/SharedSessions/SharedSessionValue.cs:13`.
- Shared session creation currently accepts raw values directly: `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs:3`.
- Shared session validation already enforces the exercise type matrix: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:314`.
- Trainer trainee detail currently has only a placeholder assigned-set section: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart:89`.
- The UI source of truth is `apps/mobile/design/LiftMate.dc.html`; relevant screens start at `t_sets` line 276, `t_builder` line 306, `t_addex` line 339, `t_assign` line 411, and `c_home` line 539.

## What We're NOT Doing

- No production shared-session start flow from an assigned set. That belongs to S-03.
- No trainer exercise library outside sets. PRD marks trainer exercise libraries as nice-to-have.
- No individual trainee-specific templates. PRD marks them as nice-to-have.
- No progress saving, previous-value carry-forward, history charts, or next-session baseline logic. Those belong to S-05 and later.
- No live workout UI changes beyond preserving future handoff data.
- No rewrite of auth, role, pairing, or relationship screens outside the set-management integration points.
- No full E2E framework. Use API integration tests and Flutter unit/widget tests.

## Implementation Approach

Add a `WorkoutSets` feature area beside `SharedSessions` and `Auth`. The API owns persistence, validation, trainer ownership, relationship access, and assignment rules. Flutter adds a matching `workout_sets` feature area with typed models, an API client, controller state, trainer screens from the design contract, and a trainee assigned-set view on `c_home`.

The backend should treat workout sets as trainer-owned global templates. Assignments are join records between a set and trainee users. Because the user chose multiple assigned sets per trainee, the assignment table must allow many sets per trainee and many trainees per set while preventing duplicate assignment of the same set to the same trainee.

The row model should be S-03-ready: each set row represents one concrete set to perform. Use `exerciseOrder` to group and order exercises, and `setIndex` to order sets inside an exercise. For example, a bench press exercise with three sets becomes three rows sharing `exerciseName`, `exerciseType`, and `exerciseOrder`, with `setIndex` values `1`, `2`, and `3`.

Workout-set access must follow the current trainer-trainee relationship, not only historical assignment rows. Existing re-pairing already updates `ApplicationUser.TrainerUserId` and cancels active shared sessions; this slice must extend that boundary so old-trainer workout assignments cannot remain visible after a trainee links to a new trainer.

The Flutter UI should stay close to `apps/mobile/design/LiftMate.dc.html`. Treat that file as the visual and interaction contract for screen hierarchy, labels, dark theme, spacing, bottom navigation, set cards, builder rows, type segmented controls, steppers, multi-select assignment rows, and trainee assigned-set card content.

## Phase 1: API Workout Set Persistence

### Overview

Create the persistent workout-set model, assignment model, EF wiring, migration, and validation rules that all API endpoints will share.

### Changes Required:

#### 1. Workout set domain entities

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSet.cs`

**Intent**: Add the trainer-owned global template aggregate.

**Contract**: `WorkoutSet` has `Id`, `TrainerUserId`, `TrainerUser`, `Name`, `CreatedAt`, `UpdatedAt`, `Rows`, and `Assignments`. `Name` is required and trimmed by endpoint code. Trainer ownership is always the authenticated trainer user ID.

#### 2. Workout set row domain entity

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetRow.cs`

**Intent**: Store one concrete set row per exercise set, so future shared-session creation can copy exact ordered rows.

**Contract**: `WorkoutSetRow` has `Id`, `WorkoutSetId`, `WorkoutSet`, `ExerciseOrder`, `SetIndex`, `ExerciseName`, `ExerciseType`, `Reps`, `Weight`, and `Seconds`. It uses the same wire values and validation matrix as shared session values: `repsWeight`, `repsOnly`, `time`.

Implementation should reuse or extract the existing API `ExerciseValueType` constants from `apps/api/LiftMate.Api/SharedSessions/ExerciseValueType.cs` where practical. If the constants remain in the shared-session namespace for this slice, tests must still prove workout-set rows use the exact same wire values.

#### 3. Workout set assignment domain entity

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetAssignment.cs`

**Intent**: Represent many-to-many current assignments from global sets to linked trainees.

**Contract**: `WorkoutSetAssignment` has `Id`, `WorkoutSetId`, `WorkoutSet`, `TraineeUserId`, `TraineeUser`, `AssignedAt`, and `AssignedByTrainerUserId`. The same `(WorkoutSetId, TraineeUserId)` pair is unique.

#### 4. DbContext wiring

**File**: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`

**Intent**: Register the new DbSets, relationships, indexes, precision, and constraints in the existing EF Core model.

**Contract**:

- Add DbSets for `WorkoutSets`, `WorkoutSetRows`, and `WorkoutSetAssignments`.
- `WorkoutSet.TrainerUserId` references `ApplicationUser` with restricted delete.
- `WorkoutSetRow.WorkoutSetId` cascades on workout-set delete.
- `WorkoutSetAssignment.WorkoutSetId` cascades on workout-set delete.
- `WorkoutSetAssignment.TraineeUserId` references `ApplicationUser` with restricted delete.
- Add indexes on trainer user ID, workout set ID, trainee user ID, and unique `(WorkoutSetId, TraineeUserId)`.
- Add check constraint for row `ExerciseType` using the same allowed values as shared-session rows.
- Use `decimal(8,2)` precision for `Weight`.

#### 5. Migration

**File**: `apps/api/LiftMate.Api/Migrations/<timestamp>_AddWorkoutSets.cs`

**Intent**: Create SQL Server-ready tables for workout sets, rows, and assignments.

**Contract**: Migration and model snapshot reflect the DbContext contract. It must not modify existing auth, pairing, or shared-session semantics.

#### 6. Shared validation helper

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetValidation.cs`

**Intent**: Avoid duplicating type-specific validation logic and keep workout-set rows aligned with shared-session values.

**Contract**: A helper validates exercise type, required fields, forbidden fields, positive row indices, non-empty exercise names, and non-empty set names. It should reuse or extract the existing shared-session exercise type constants where practical; if the validation matrix is mirrored in this slice, tests must assert exact compatibility with shared-session wire values.

### Success Criteria:

#### Automated Verification:

- API migration is generated and included in the project.
- `dotnet build LiftMate.slnx --no-restore` passes from `apps/api`.
- API tests covering entity persistence and validation pass with `dotnet test LiftMate.slnx --no-build`.

#### Manual Verification:

- Inspect migration to confirm only workout-set tables, constraints, and indexes are added.
- Confirm no existing shared-session endpoint behavior is changed by persistence-only work.

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

## Phase 2: API Workout Set Contracts

### Overview

Expose trainer and trainee contracts for creating, updating, listing, assigning, unassigning, and reading assigned workout sets.

### Changes Required:

#### 1. API DTOs

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs`

**Intent**: Define stable camelCase JSON contracts for mobile clients and S-03 handoff.

**Contract**:

- `CreateWorkoutSetRequest(Name, IReadOnlyList<WorkoutSetRowRequest> Rows)`
- `UpdateWorkoutSetRequest(Name, IReadOnlyList<WorkoutSetRowRequest> Rows)`
- `WorkoutSetRowRequest(ExerciseOrder, SetIndex, ExerciseName, ExerciseType, Reps, Weight, Seconds)`
- `AssignWorkoutSetRequest(IReadOnlyList<string> TraineeUserIds)`
- `WorkoutSetSummaryResponse(Id, Name, ExerciseCount, RowCount, AssignedTrainees, CreatedAt, UpdatedAt)`
- `WorkoutSetDetailResponse(Id, Name, Rows, Assignments, CreatedAt, UpdatedAt)`
- `WorkoutSetRowResponse(Id, ExerciseOrder, SetIndex, ExerciseName, ExerciseType, Reps, Weight, Seconds)`
- `WorkoutSetAssignmentResponse(TraineeUserId, TraineeEmail, TraineeDisplayName, AssignedAt)`
- `TraineeAssignedWorkoutSetResponse(Id, Name, TrainerDisplayName, Rows, AssignedAt, UpdatedAt)`

`TraineeAssignedWorkoutSetResponse.Id` is the `workoutSetId`. S-03 should use that `workoutSetId` plus the authenticated trainee context to start a shared session from an assigned set. Do not introduce a separate `assignedSetId` unless a later slice adds assignment history or versioned assignment records.

#### 2. Mapping

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetMapping.cs`

**Intent**: Keep endpoint code readable and make response ordering deterministic.

**Contract**: Responses order rows by `ExerciseOrder`, then `SetIndex`, then row ID. Trainer summaries sort sets by latest update descending. Assignment trainee display uses display name, then email.

#### 3. Trainer endpoints

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`

**Intent**: Give trainers the set-management and assignment operations needed by `t_sets`, `t_builder`, `t_addex`, and `t_assign`.

**Contract**:

- `GET /workout-sets` requires `TrainerOnly`; returns only the trainer's sets.
- `POST /workout-sets` requires `TrainerOnly`; creates a trainer-owned set with at least one valid row.
- `GET /workout-sets/{setId:guid}` requires `TrainerOnly`; returns details only for the owner trainer.
- `PUT /workout-sets/{setId:guid}` requires `TrainerOnly`; replaces the name and rows for the owner trainer.
- `POST /workout-sets/{setId:guid}/assignments` requires `TrainerOnly`; assigns the set to many linked trainees, idempotently keeping existing assignments.
- `DELETE /workout-sets/{setId:guid}/assignments/{traineeUserId}` requires `TrainerOnly`; explicitly removes that assignment.

Every assignment target must be a current trainee linked to the authenticated trainer. Multi-assign is atomic: if any trainee ID is invalid, duplicated in the request, not a trainee, or not currently linked to the authenticated trainer, the endpoint returns a failure and creates no new assignments. Existing assignments remain unchanged on failure.

#### 4. Trainee endpoints

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`

**Intent**: Give trainees access to their assigned sets without exposing trainer management operations.

**Contract**:

- `GET /trainee/workout-sets` requires `TraineeOnly`; returns all currently assigned sets for the current trainee.
- `GET /trainee/workout-sets/{setId:guid}` requires `TraineeOnly`; returns one assigned set only if it is assigned to the current trainee.

The detail response is S-03-ready and includes the row IDs, ordering, and value fields needed to seed future shared-session rows. Both trainee endpoints must filter assignments through the current relationship: the set's trainer must still equal the trainee's current `TrainerUserId`. Historical assignment rows from a previous trainer must not be returned.

#### 5. Re-pair assignment cleanup

**File**: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

**Intent**: Keep workout-set assignments aligned with the current trainer relationship when a trainee re-pairs.

**Contract**: During successful `POST /trainee/trainer-link` re-pair to a different trainer, remove workout-set assignments for the trainee where the assigned set belongs to the previous trainer. Invalid claim attempts must not remove assignments. Re-pairing to the same trainer is idempotent and should not remove assignments. This extends the existing active shared-session cancellation behavior without changing the pairing response shape.

#### 6. Program wiring

**File**: `apps/api/LiftMate.Api/Program.cs`

**Intent**: Register the workout-set endpoint group.

**Contract**: Add `app.MapWorkoutSetEndpoints();` near existing domain endpoint mappings. Do not change auth, pairing, or shared-session route behavior.

#### 7. API tests

**File**: `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`

**Intent**: Lock the full API contract and access boundary.

**Contract**: Tests cover trainer create/list/detail/update, validation for each exercise type, non-owner access denial, assignment to multiple linked trainees, duplicate assignment idempotency, atomic rejection of invalid/unrelated/duplicate trainee IDs, unchanged existing assignments after failed multi-assign, unassign, trainee list/detail reads, trainee denial after unassign, updated set content visible through existing assignments, old-trainer assignments hidden after re-pair, old-trainer assignments removed on valid re-pair, and invalid re-pair attempts preserving assignments.

### Success Criteria:

#### Automated Verification:

- `dotnet build LiftMate.slnx --no-restore` passes from `apps/api`.
- `dotnet test LiftMate.slnx --no-build` passes from `apps/api`.
- API tests prove unrelated trainers and unrelated trainees cannot read or mutate workout sets.
- API tests prove assigned trainees see latest global set rows after trainer update.
- API tests prove old-trainer assignments are not visible after trainee re-pairing.

#### Manual Verification:

- Review Swagger/OpenAPI locally and confirm route names and response shapes are understandable.
- Confirm S-03 can rely on `GET /trainee/workout-sets/{setId}` or trainer-owned detail to get ordered rows by assigned `workoutSetId`.

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

## Phase 3: Mobile Workout Set Contract

### Overview

Add typed Flutter models, API client, and controller state for workout-set management, following the existing relationship and shared-session client patterns.

### Changes Required:

#### 1. Mobile models

**File**: `apps/mobile/lib/workout_sets/workout_set_models.dart`

**Intent**: Mirror the API contract in strict Dart models.

**Contract**: Include enums or typed parsing for exercise type wire values, request models for create/update/assign, summary/detail row models, assignment models, and trainee assigned-set response models. JSON parsing is strict for required fields and rejects invalid exercise types.

If a separate workout-set Dart enum is introduced, tests must assert its wire names match `ExerciseValueType` in `apps/mobile/lib/shared_sessions/shared_session_models.dart`.

#### 2. Mobile API client

**File**: `apps/mobile/lib/workout_sets/workout_set_api_client.dart`

**Intent**: Provide authenticated HTTP access without coupling UI directly to `http`.

**Contract**: Match the status/result style of `RelationshipApiClient` and `SharedSessionApiClient`. Include methods for trainer list/create/detail/update/assign/unassign and trainee list/detail. Map HTTP `400`, `401`, `403`, `404`, `409`, offline, timeout, and JSON errors.

#### 3. Mobile controller

**File**: `apps/mobile/lib/workout_sets/workout_set_controller.dart`

**Intent**: Own screen-friendly loading, editing, assignment, and refresh state for trainer and trainee screens.

**Contract**: Controller accepts `WorkoutSetApiClient` and `AuthController`. It exposes trainer set list, selected set detail, draft set state, assignable trainee state supplied from relationship summaries, trainee assigned sets, loading/error status, and operations to create, update, assign, unassign, and reload.

#### 4. App wiring

**File**: `apps/mobile/lib/main.dart`

**Intent**: Instantiate the workout-set client with the same API base URL as auth, relationships, and shared sessions.

**Contract**: Pass the client into the authenticated relationship shell or a new authenticated app shell without changing unauthenticated auth behavior.

#### 5. Shell integration

**File**: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent**: Add workout-set state to the authenticated area while preserving current relationship loading and logout behavior.

**Contract**: Trainer navigation can route to set list/builder/assignment screens. Trainee home can load assigned sets after relationship state is available. The existing relationship controller remains responsible for trainer/trainee identity and code pairing.

#### 6. Mobile contract tests

**Files**:

- `apps/mobile/test/workout_set_models_test.dart`
- `apps/mobile/test/workout_set_api_client_test.dart`
- `apps/mobile/test/workout_set_controller_test.dart`

**Intent**: Lock parsing, request bodies, error mapping, and controller state transitions before UI work.

**Contract**: Tests cover all exercise types, row ordering parse, create/update JSON, multi-trainee assignment JSON, unassign path, trainee assigned list parse, missing API base URL, conflict/forbidden mapping, and missing-token handling.

### Success Criteria:

#### Automated Verification:

- `flutter test test/workout_set_models_test.dart test/workout_set_api_client_test.dart test/workout_set_controller_test.dart` passes from `apps/mobile`.
- `flutter analyze` passes from `apps/mobile`.

#### Manual Verification:

- Review generated request payloads against API DTOs.
- Confirm mobile uses the same exercise type wire names as the API and shared-session models.

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

## Phase 4: Trainer Set Management UI

### Overview

Implement the trainer-facing set-management screens from the design contract and integrate assigned sets into the trainee detail screen.

### Changes Required:

#### 1. Set list screen

**File**: `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart`

**Intent**: Implement the `t_sets` screen from the design contract.

**Contract**: Screen shows title "Moje zestawy", subtitle "Szablony globalne - przypisz je dowolnemu podopiecznemu", set cards with name, global tag, exercise/row meta, assigned trainee names, and a dashed "+ Nowy zestaw" button. It uses the existing dark LiftMate visual system and bottom nav state for "Zestawy".

#### 2. Set builder screen

**File**: `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`

**Intent**: Implement `t_builder` for creating and editing workout sets.

**Contract**: Screen has set name, draft row summary grouped into exercises, "+ Dodaj cwiczenie", and "Zapisz zestaw". Because the selected data model is one row per set, the UI may still show grouped exercise summaries but stores concrete rows for each set.

#### 3. Add exercise screen

**File**: `apps/mobile/lib/workout_sets/add_workout_set_exercise_screen.dart`

**Intent**: Implement `t_addex` while translating design-level exercise defaults into concrete per-set rows.

**Contract**: Screen includes exercise name, segmented exercise type selection, steppers for series, reps, weight, or seconds, and "Dodaj do zestawu". Saving one exercise with `N` series appends `N` concrete rows using the same `exerciseOrder` and `setIndex` values `1..N`.

#### 4. Assignment screen

**File**: `apps/mobile/lib/workout_sets/assign_workout_set_screen.dart`

**Intent**: Implement `t_assign` for one-set-to-many-trainees assignment.

**Contract**: Screen shows selected set card, multi-select list of linked trainees, selected checkboxes, and "Przypisz (N)". It must use relationship trainee summaries as the source for assignable trainees and call the workout-set controller assignment operation.

#### 5. Trainer trainee detail integration

**File**: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`

**Intent**: Replace the "Brak przypisanego zestawu" placeholder with real assigned-set content and unassign affordance.

**Contract**: Detail screen shows multiple assigned sets for the selected trainee. Each assigned set shows name, exercise count or row count, and a clear unassign action. If none are assigned, preserve a design-compatible empty state.

#### 6. Authenticated shell navigation

**File**: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent**: Route trainer bottom nav "Zestawy" into set list, then builder, add exercise, and assignment screens.

**Contract**: Preserve current trainer dashboard, trainee detail back behavior, trainee home, and logout. Avoid introducing a general-purpose router unless the local pattern already calls for it.

#### 7. Trainer widget tests

**Files**:

- `apps/mobile/test/workout_set_trainer_screens_test.dart`
- Update `apps/mobile/test/post_auth_relationship_screen_test.dart` if needed.

**Intent**: Prove trainer workflows render correctly against mocked API responses.

**Contract**: Tests cover set list, empty set list, new set draft, add `repsWeight`, add `repsOnly`, add `time`, create set payload through controller/client seam, assign to multiple trainees, unassign from trainee detail, and relationship screen still logs out.

### Success Criteria:

#### Automated Verification:

- `flutter test test/workout_set_trainer_screens_test.dart test/post_auth_relationship_screen_test.dart` passes from `apps/mobile`.
- `flutter analyze` passes from `apps/mobile`.

#### Manual Verification:

- Compare trainer screens against `apps/mobile/design/LiftMate.dc.html` for `t_sets`, `t_builder`, `t_addex`, and `t_assign`.
- Verify text does not overflow on the current phone-sized layout.
- Verify set creation and assignment states are understandable without fake workout-progress data.

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

## Phase 5: Trainee Assigned Sets UI and Final Gates

### Overview

Expose assigned sets to trainees on `c_home` and complete cross-surface verification.

### Changes Required:

#### 1. Trainee home assigned sets

**File**: `apps/mobile/lib/relationships/trainee_home_screen.dart`

**Intent**: Replace the generic "Plan treningowy nie jest jeszcze przypisany" placeholder with real assigned-set content.

**Contract**: For linked trainees, `c_home` shows assigned workout sets in a design-compatible card. With multiple assigned sets, show a list of cards or a primary card plus additional rows while keeping the "Dzis" bottom nav. Each set shows name, trainer display name, row/exercise meta, and ordered row preview. The "Rozpocznij trening" affordance remains disabled, hidden, or clearly future-scoped until S-03 implements session start.

#### 2. Trainee assigned-set detail or expansion

**File**: `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart`

**Intent**: Let the trainee inspect exercises and rows from assigned sets without starting a session.

**Contract**: Display rows ordered by `exerciseOrder` and `setIndex`, grouped by exercise name/type for readability. Values show according to type: reps and weight, reps only, or seconds.

#### 3. End-to-end mocked widget test

**File**: `apps/mobile/test/trainee_assigned_workout_sets_screen_test.dart`

**Intent**: Prove the S-02 user-visible outcome is complete on mobile.

**Contract**: A trainee with two assigned sets sees both sets, rows are displayed in order, unlinked trainees still see the trainer-code prompt, and API failures preserve a readable error state.

#### 4. Final API/mobile verification

**Files**:

- `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`
- `apps/mobile/test/workout_set_*_test.dart`
- Existing relationship and shared-session tests.

**Intent**: Make sure S-02 did not regress auth, relationship, or shared-session foundations.

**Contract**: Full targeted test run passes for API and mobile. The plan remains explicit that S-03 owns live session start.

### Success Criteria:

#### Automated Verification:

- `dotnet test LiftMate.slnx --no-build` passes from `apps/api`.
- `flutter test` passes from `apps/mobile`.
- `flutter analyze` passes from `apps/mobile`.

#### Manual Verification:

- Trainer can create a global set with each exercise type.
- Trainer can assign the set to multiple linked trainees.
- Trainer can unassign one trainee without deleting the set or removing other assignments.
- Trainee can see all assigned sets and their rows.
- Editing a global set updates the assigned-set view before any S-03 session is started.
- No live workout start is presented as complete in S-02.

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation that the mobile screens match the design contract closely enough for MVP.

---

## Testing Strategy

### Unit Tests:

- Workout-set row validation for all exercise types.
- Dart model parsing for all response shapes and invalid JSON.
- Controller state for loading, saving, assigning, unassigning, and trainee assigned-set load.
- Exercise draft conversion from design-level "series" input to concrete per-set rows.

### Integration Tests:

- API create/list/detail/update set lifecycle.
- API ownership denial for other trainers.
- API trainee assignment only to linked trainees.
- API trainee assigned-set access only for assigned current trainee.
- API unassign removes access but leaves set and other assignments intact.
- API assigned-set details reflect latest global set rows.
- Re-pairing a trainee removes or hides old-trainer workout assignments while preserving assignments after invalid re-pair attempts.

### Manual Testing Steps:

1. Register a trainer and two trainees, then link both trainees to the trainer.
2. Create a workout set with `repsWeight`, `repsOnly`, and `time` rows.
3. Assign the set to both trainees through the multi-select assignment screen.
4. Log in as each trainee and confirm both can see the assigned set rows.
5. Edit the workout set as trainer and confirm both trainees see the updated rows.
6. Unassign one trainee and confirm only that trainee loses access.
7. Confirm no S-02 screen claims a live shared session has started.

## Performance Considerations

Expected MVP data volume is small. Use simple relational queries with includes or projections ordered by row fields. Keep list responses summary-shaped so trainer set lists do not fetch all rows unless needed. Add indexes on trainer ownership and assignments to keep dashboard/list queries straightforward as demo data grows.

## Migration Notes

This is additive. No existing user, relationship, or shared-session rows need migration. Rollback is table-drop only if no production set data must be preserved. Because existing shared sessions store ad hoc rows, S-02 should not attempt to backfill old sessions into workout sets.

## References

- Roadmap S-02: `context/foundation/roadmap.md`
- Product requirements FR-007, FR-008, FR-010, US-01: `context/foundation/prd.md`
- Design contract: `apps/mobile/design/LiftMate.dc.html`
- Existing relationship plan: `context/changes/trainer-trainee-pairing/plan.md`
- Existing shared-session plan: `context/changes/shared-session-sync-contract/plan.md`
- Existing shared session contracts: `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`
- Existing relationship endpoints: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` - <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: API Workout Set Persistence

#### Automated

- [x] 1.1 API migration is generated and included in the project - b846fb8
- [x] 1.2 `dotnet build LiftMate.slnx --no-restore` passes from `apps/api` - b846fb8
- [x] 1.3 API tests covering entity persistence and validation pass with `dotnet test LiftMate.slnx --no-build` - b846fb8

#### Manual

- [ ] 1.4 Inspect migration to confirm only workout-set tables, constraints, and indexes are added
- [ ] 1.5 Confirm no existing shared-session endpoint behavior is changed by persistence-only work

### Phase 2: API Workout Set Contracts

#### Automated

- [x] 2.1 `dotnet build LiftMate.slnx --no-restore` passes from `apps/api` - 2d9acb8
- [x] 2.2 `dotnet test LiftMate.slnx --no-build` passes from `apps/api` - 2d9acb8
- [x] 2.3 API tests prove unrelated trainers and unrelated trainees cannot read or mutate workout sets - 2d9acb8
- [x] 2.4 API tests prove assigned trainees see latest global set rows after trainer update - 2d9acb8
- [x] 2.5 API tests prove old-trainer assignments are not visible after trainee re-pairing - 2d9acb8

#### Manual

- [ ] 2.6 Review Swagger/OpenAPI locally and confirm route names and response shapes are understandable
- [ ] 2.7 Confirm S-03 can rely on assigned-set detail to get ordered rows by assigned workoutSetId

### Phase 3: Mobile Workout Set Contract

#### Automated

- [x] 3.1 `flutter test test/workout_set_models_test.dart test/workout_set_api_client_test.dart test/workout_set_controller_test.dart` passes from `apps/mobile` - 112c365
- [x] 3.2 `flutter analyze` passes from `apps/mobile` - 112c365

#### Manual

- [ ] 3.3 Review generated request payloads against API DTOs
- [ ] 3.4 Confirm mobile uses the same exercise type wire names as the API and shared-session models

### Phase 4: Trainer Set Management UI

#### Automated

- [x] 4.1 `flutter test test/workout_set_trainer_screens_test.dart test/post_auth_relationship_screen_test.dart` passes from `apps/mobile`
- [x] 4.2 `flutter analyze` passes from `apps/mobile`

#### Manual

- [ ] 4.3 Compare trainer screens against `apps/mobile/design/LiftMate.dc.html` for `t_sets`, `t_builder`, `t_addex`, and `t_assign`
- [ ] 4.4 Verify text does not overflow on the current phone-sized layout
- [ ] 4.5 Verify set creation and assignment states are understandable without fake workout-progress data

### Phase 5: Trainee Assigned Sets UI and Final Gates

#### Automated

- [ ] 5.1 `dotnet test LiftMate.slnx --no-build` passes from `apps/api`
- [ ] 5.2 `flutter test` passes from `apps/mobile`
- [ ] 5.3 `flutter analyze` passes from `apps/mobile`

#### Manual

- [ ] 5.4 Trainer can create a global set with each exercise type
- [ ] 5.5 Trainer can assign the set to multiple linked trainees
- [ ] 5.6 Trainer can unassign one trainee without deleting the set or removing other assignments
- [ ] 5.7 Trainee can see all assigned sets and their rows
- [ ] 5.8 Editing a global set updates the assigned-set view before any S-03 session is started
- [ ] 5.9 No live workout start is presented as complete in S-02
