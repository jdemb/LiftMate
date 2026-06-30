# Save Progress for the Next Session — Plan Brief

> Full plan: `context/changes/save-progress-next-session/plan.md`
> Design: `docs/superpowers/specs/2026-06-19-save-progress-next-session-design.md`

## What & Why

Completed workout values will become trainee-specific starting values for the next session without changing a global template shared by multiple trainees. The same immutable completed sessions will power the approved three-level history flow for trainees and their currently linked trainers.

## Starting Point

Shared sessions already snapshot editable workout values and support completion, but completion only changes lifecycle status. Workout-set edits currently replace every row with new IDs, and there is no progress projection or history API/UI.

## Desired End State

After **Zakończ i zapisz trening**, every series is saved atomically and the next session starts from those values. Trainees and current trainers can browse completed sessions, session details, and per-exercise maximum-value progress through screens matching `apps/mobile/design/LiftMate.html`.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Value ownership | Trainee + workout set projection | Keeps global templates safe for multiple trainees. |
| History source | Completed session snapshots | Preserves exactly what happened at the time. |
| Save trigger | Complete only | Cancelled or abandoned work cannot change future targets. |
| Saved values | Every series | Next session reproduces the final saved workout. |
| Stable identity | Exercise ID + series row ID; new identity on type change | Supports compatible template edits without mixing progress units. |
| Retry/order | Idempotent source session; latest completion wins | Prevents duplicate application and rollback. |
| Template merge | Current structure + projected matching rows | New rows get defaults; deleted rows stay deleted. |
| History | Completed only, cursor pages of 20 | Clear semantics and bounded payloads. |
| Chart point | Maximum type-specific value per session | Matches the approved detail/progress design. |
| Trainer access | Active relationship only | Preserves current privacy boundary. |
| Chart library | Flutter-native | Avoids unnecessary dependency cost. |

## Scope

**In scope:**

- stable exercise and series IDs;
- immutable session snapshots plus a per-trainee/per-set projection;
- atomic, idempotent completion and next-session merge;
- completed-session list, detail, and exercise-progress APIs;
- trainee and current-trainer authorization;
- three Flutter history levels, navigation, and save confirmation;
- migrations and full automated/manual verification.

**Out of scope:**

- PR badges or detection;
- cancelled-session history;
- historical editing, export, advanced analytics, or manual progress reset;
- trainer access after relationship termination.

## Architecture / Approach

The current template defines which rows exist, while the projection supplies values for matching stable row IDs. Snapshot row identifiers are scalar values rather than foreign keys to mutable template rows. Completion runs through EF Core's execution strategy in a serializable transaction, reloading the session and projection on every attempt. Completed sessions remain immutable history. History APIs read those snapshots directly; the mobile history controller preserves paginated list state while users drill into details and progress.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Stable identities | Durable IDs through migrations, API, builder, and session snapshots | Existing set update currently recreates every row |
| 2. Progress projection | Atomic completion and next-session merge | Older retry must not replace newer progress |
| 3. History API | Cursor list, details, progress, authorization | Stable pagination and privacy boundaries |
| 4. Flutter data layer | Models, client, controller, target scoping | Nested navigation must preserve loaded pages |
| 5. History UI | Three approved screens, both role entries, full verification | Visual fidelity and cross-stack regressions |

**Prerequisites:** S-04 complete; current design contract in `apps/mobile/design/LiftMate.html`.
**Estimated effort:** five phase commits across roughly 5–8 focused implementation sessions.

## Open Risks & Assumptions

- Legacy session values cannot be safely linked to stable exercises; they remain readable but do not seed charts/projections.
- Existing workout-set row IDs can remain the stable series IDs through migration.
- Workout-set deletion remains restricted while history/progress references it.
- Migration verification requires both an idempotent SQL Server script check and a disposable SQL Server smoke test with representative legacy rows.

## Success Criteria (Summary)

- Completing a workout saves every series once and the next session starts from those values.
- Template edits, unassignment/reassignment, retries, and delayed older completions cannot corrupt trainee progress.
- Trainee and current trainer can browse the design-approved three-level completed history, while former trainers cannot.
