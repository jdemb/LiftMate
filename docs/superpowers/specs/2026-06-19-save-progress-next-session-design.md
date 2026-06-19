# Save progress for the next session — Design

## Purpose

S-05 makes a completed workout the source of starting values for the next session and adds a three-level history flow for the trainee and their currently linked trainer. The current session snapshot remains immutable history; a separate per-trainee, per-workout-set projection provides fast starting values.

The mobile UI must follow `apps/mobile/design/LiftMate.html`, which supersedes `LiftMate.dc.html` for the history screens introduced by this change.

## Product Decisions

- Persist all series from the session, including series not marked done.
- Update progress only through **Zakończ i zapisz trening**.
- Cancelled sessions never update progress and are not visible in history.
- Sessions without a workout set can be completed but do not update progress.
- Progress belongs to the trainee–workout-set pair, not to the global template or the removable assignment row.
- Unassigning and reassigning the same set preserves progress.
- Completing a session is idempotent; retrying the same request does not apply progress twice.
- A projection is updated only by a session with a later completion timestamp. A delayed older request cannot roll progress back.
- History lists only completed sessions and loads 20 records per cursor-based page.
- The trainer can read a trainee's history only while their relationship is active.
- There are no personal-record badges or automatic PR detection.

## Data Model

### Stable workout structure

`WorkoutSetRow.Id` is the stable identity of a series. A new stable `ExerciseId` groups the series that represent one exercise.

Workout-set create and update contracts carry optional identifiers:

- a newly created exercise omits `ExerciseId` and receives one from the API;
- a newly created series omits its row ID and receives one from the API;
- editing values, names, ordering, or type preserves supplied IDs;
- adding a series creates a new row ID under the existing exercise ID;
- deleting an exercise or series removes it from the active template without rewriting surviving IDs.

The Flutter builder must preserve these identifiers in its draft model. The API must reject IDs that belong to another set, duplicate IDs, or inconsistent exercise grouping.

### Session snapshots

Sessions started from a workout set copy the following stable references into every `SharedSessionValue`:

- `ExerciseId`;
- `WorkoutSetRowId`.

The value still snapshots exercise name, type, order, set index, reps, weight, and seconds. `SharedSession` also snapshots the workout-set name so renaming the template does not rewrite historical display.

Legacy or ad-hoc session values may have null stable references. They remain readable, but they cannot contribute to per-set progress or cross-session exercise charts.

### Starting-value projection

A projection root is uniquely identified by:

- `TraineeUserId`;
- `WorkoutSetId`.

The root stores:

- `SourceSessionId`;
- `SourceCompletedAt`;
- projection update timestamp.

Projection rows are keyed by `WorkoutSetRowId` and also carry `ExerciseId`, exercise type, reps, weight, and seconds. They do not store assignment IDs, so removing an assignment does not cascade progress.

The source session ID is unique for projection application. Together with the completion-time guard, this makes retries safe and prevents an older session from replacing newer values.

## Completing a Session

The complete endpoint performs the session transition and projection update in one database transaction.

1. Load and authorize the session with its values.
2. If already completed, return its existing representation without applying progress again.
3. If cancelled, return the existing lifecycle conflict.
4. Set `Status = completed`, increment the version, and set one shared `ClosedAt` timestamp.
5. If the session has a workout set and stable row references, upsert the trainee–set projection using every session value.
6. Apply the projection only if `ClosedAt` is later than the current `SourceCompletedAt`.
7. Commit the session and projection atomically.
8. Broadcast the completed session snapshot.

Completing an ad-hoc session or a legacy session without usable stable references succeeds without a projection update. Cancelling a session does not create or modify progress.

## Starting the Next Session

The current workout-set structure is authoritative. Starting from a set loads the latest projection for that trainee and set:

- a current row with a matching `WorkoutSetRowId` uses projected reps, weight, or seconds;
- a new row with no projection uses template defaults;
- a deleted row is absent because session creation iterates current template rows;
- ordering and display data come from the current template;
- progress remains available after unassignment and is reused after reassignment.

The same merge applies to trainer-led and trainee-self-started sessions.

## History API

History endpoints live under a dedicated authenticated history route group and return read-only DTOs rather than active-session mutation contracts.

### Level 1: completed-session list

The request identifies the target trainee:

- a trainee implicitly targets themself;
- a trainer supplies a trainee ID and must still be that trainee's linked trainer.

Results are ordered by `ClosedAt DESC, Id DESC`, limited to 20, and use an opaque cursor containing the final row's ordering keys.

Each item contains:

- session ID;
- snapshotted workout-set name;
- started and completed timestamps;
- duration derived from `CreatedAt` and `ClosedAt`;
- distinct exercise count;
- series count.

Only `completed` sessions are returned.

### Level 2: session details

The endpoint returns one authorized completed session grouped by `ExerciseId` and ordered by snapshotted exercise order. Each exercise includes its type and ordered series values.

The UI derives compact labels such as `60×8`, `15`, or `60s`. The “best” session value uses the same rule as progress:

- `repsWeight`: highest weight;
- `repsOnly`: highest reps;
- `time`: highest seconds.

### Level 3: exercise progress

The endpoint receives a stable `ExerciseId` and target trainee. It returns one point per completed session containing that exercise, ordered chronologically.

Each point includes:

- session ID and completion date;
- selected maximum value;
- delta from the preceding chronological point;
- unit/type metadata for display.

The response provides enough information for the current value, starting value, overall delta, chart, and recent-values list. It does not mark PRs.

## Authorization

- A trainee can access only their own completed sessions and exercise progress.
- A trainer can access a trainee's data only if `trainee.TrainerUserId` currently equals the trainer's user ID.
- Access is checked independently for list, detail, and progress endpoints.
- Ending or changing the relationship immediately removes the former trainer's history access.
- Session history remains owned by and available to the trainee.

## Mobile Architecture

A dedicated history feature contains:

- immutable API models;
- a history API client;
- controller state for list pagination, selected session, and selected exercise progress;
- Level 1, Level 2, and Level 3 screens;
- formatting helpers for dates, durations, values, deltas, and Polish count labels.

The controller keeps pagination state separate from detail/progress state so returning from a nested screen preserves the loaded list and scroll context. Loading, empty, retryable error, and pagination-error states are explicit.

### Navigation

- The trainee's bottom navigation opens Level 1.
- Selecting a session opens Level 2.
- Selecting an exercise opens Level 3.
- The trainer's **Podopieczny** screen gains the design-contract **Historia** button and passes that trainee as the target.
- Trainer and trainee reuse the same history screens and models; only the target and return destination differ.

### Visual contract

The implementation follows `apps/mobile/design/LiftMate.html`:

- Level 1 shows date tile, set name, date label, duration, exercise count, and series count.
- Level 2 shows summary metrics and exercise cards with ordered series chips and a progress affordance.
- Level 3 shows exercise headline values, chart, dates, recent values, and deltas.

The chart is implemented with Flutter-native layout or painting and adds no chart dependency. It must handle one point, equal values, negative deltas, decimal weights, and narrow screens without overflow.

## Completion Feedback

After a successful **Zakończ i zapisz trening** action, the existing live flow closes and displays a clear success confirmation that the values were saved for the next session. If completion fails, the live session remains open and the error remains actionable.

## Testing

### API

- migration and model constraints for stable IDs and projections;
- update-set behavior preserves supplied exercise and series IDs;
- session creation merges projected values with current template structure;
- all series are projected regardless of done state;
- cancellation and ad-hoc completion do not update progress;
- completion is idempotent;
- an older completion cannot overwrite a newer projection;
- unassignment and reassignment preserve progress;
- list pagination is stable and returns only completed sessions;
- detail grouping and maximum-value rules work for all exercise types;
- progress points, ordering, and deltas work for all exercise types;
- trainee ownership and active trainer relationship are enforced at every endpoint.

### Flutter

- API parsing and cursor requests;
- controller initial load, load-more, empty, error, retry, and nested-screen states;
- exact three-level navigation for trainee;
- trainer history entry targets the selected trainee;
- UI follows the new design screens;
- chart handles single/equal/decimal/downward datasets;
- completing a workout shows save confirmation;
- a newly started session displays projected values while newly added template rows use defaults.

## Migration and Compatibility

The migration backfills stable exercise IDs for existing workout-set rows by grouping rows within a set by their current exercise order. Existing row IDs remain stable series IDs.

Existing sessions with a workout-set reference receive a one-time workout-set-name snapshot from the current set name during migration; ad-hoc sessions use a neutral fallback label. Existing shared-session values predate stable source references. They remain valid historical session snapshots and may appear in the completed-session list and details, but cross-session exercise progress and starting-value projection begin with sessions created after stable references are available.

No existing files under `context/archive/` are modified.

## Out of Scope

- editing historical sessions;
- manual reset or editing of saved progress;
- personal-record detection or badges;
- volume, estimated one-rep max, or advanced analytics;
- trainer access after the relationship ends;
- cancelled-session history;
- exporting history;
- redesigning live-session entry beyond completion feedback.
