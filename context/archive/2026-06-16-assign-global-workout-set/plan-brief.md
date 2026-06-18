# Assign Global Workout Set - Plan Brief

> Full plan: `context/changes/assign-global-workout-set/plan.md`

## What & Why

Build S-02 from the roadmap: trainers can create reusable global workout sets, define concrete set rows, assign one set to multiple linked trainees, and trainees can see assigned sets. This closes US-01 and gives S-03 a stable assigned-set source for starting shared workout sessions.

## Starting Point

Auth, trainer/trainee pairing, relationship screens, and shared sessions already exist. Shared sessions currently accept ad hoc exercise values, but there is no durable workout-set template or assignment model.

## Desired End State

Trainers manage global sets through design-backed screens for set list, builder, add exercise, and assignment. A set can be assigned to many linked trainees and explicitly unassigned. Trainees see all assigned sets and ordered rows on their home screen, while live session start remains S-03.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Assignment cardinality | Multiple assigned sets per trainee | The user chose multiple assignments, so the model must support more than one current set. |
| Template edit behavior | Assigned trainees see latest global set until session start | Keeps trainer corrections simple and avoids frozen per-trainee copies in MVP. |
| Row model | One row per concrete set | S-03 can seed sessions from exact ordered rows instead of expanding defaults later. |
| Trainer UI | Sets tab plus assign action from trainee/detail context | Matches `LiftMate.dc.html` and keeps global set management visible. |
| Trainee visibility | Show assigned sets on `c_home` | Completes US-01 end to end. |
| Assignment action | One set to many trainees | Matches `t_assign` multi-select design. |
| Unassign behavior | Explicit unassign | Lets trainers correct mistakes without deleting templates. |
| S-03 handoff | Assigned set detail is session-start source | Avoids extending the current ad hoc shared-session value path. |
| Design source | `apps/mobile/design/LiftMate.dc.html` is the UI contract | User explicitly requested this file be treated as the design contract. |

## Scope

**In scope:**

- Workout-set, row, and assignment persistence.
- Trainer APIs for create, update, list, detail, assign, and unassign.
- Trainee APIs for assigned-set list and detail.
- Flutter workout-set models, client, controller, and tests.
- Trainer UI for `t_sets`, `t_builder`, `t_addex`, `t_assign`.
- Trainer trainee-detail assigned-set section.
- Trainee `c_home` assigned-set visibility.

**Out of scope:**

- Starting a live workout from a set.
- Progress/history saving.
- Trainer exercise library outside sets.
- Individual trainee-specific templates.
- Full live workout UI or realtime changes.

## Architecture / Approach

Add a new `WorkoutSets` feature area beside `Auth` and `SharedSessions`. The API owns trainer ownership, linked-trainee assignment rules, row validation, and S-03-ready assigned-set details. Flutter adds a matching `workout_sets` area and integrates it into the existing authenticated relationship shell while keeping the visual structure close to `LiftMate.dc.html`.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. API Workout Set Persistence | Tables/entities for sets, rows, and assignments. | Row model must not block S-03/S-05. |
| 2. API Workout Set Contracts | Trainer and trainee endpoints with access tests. | Assignment must only target linked trainees. |
| 3. Mobile Workout Set Contract | Typed Flutter models/client/controller. | Wire types must match API and shared sessions. |
| 4. Trainer Set Management UI | Design-backed set list, builder, add, assign, and trainee detail. | Staying close to design without fake progress data. |
| 5. Trainee Assigned Sets UI and Final Gates | Assigned sets visible on trainee home plus full verification. | Avoid presenting S-03 live-start behavior as done. |

**Prerequisites:** S-01 relationship flow is present enough for linked trainees to exist.
**Estimated effort:** Medium, about 3-5 focused implementation sessions across API, mobile contract, and UI.

## Open Risks & Assumptions

- Editing a global set updates assigned trainee views until S-03 starts and snapshots a session.
- Multiple assigned sets may require a future picker in S-03; this plan only prepares the assigned-set detail contract.
- Per-set rows intentionally duplicate exercise name/type so no trainer exercise library is required.
- Design fidelity matters; `LiftMate.dc.html` should be checked before finalizing UI.

## Success Criteria (Summary)

- Trainer can create a global set with all exercise types and assign it to multiple linked trainees.
- Trainer can unassign a trainee without deleting the set or changing other assignments.
- Trainee can see all assigned sets and ordered rows, while live session start remains explicitly out of scope.
