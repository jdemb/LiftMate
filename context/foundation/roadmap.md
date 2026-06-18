---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego"
version: 1
status: proposed
created: 2026-06-01
updated: 2026-06-18
prd_version: 2
main_goal: market-feedback
top_blocker: time
---

## Vision recap

LiftMate should let a trainer prepare a workout, guide a trainee through it, and preserve progress between sessions. The roadmap is ordered for market feedback: direct signal from a real trainer-trainee workflow, not completeness of every technical layer.

## North star

North star means the first end-to-end workflow that proves the product is useful. For LiftMate, that is **S-04: Trainer enters values and trainee sees the same active session**, because it tests the guided live-workout promise in `US-03` and `FR-012`.

## At a glance

| ID | Change ID | Outcome | Prerequisites | PRD refs | Status |
|---|---|---|---|---|---|
| F-01 | mobile-api-smoke-path | Mobile app can verify the deployed API is reachable before product flows depend on it. | none | FR-001, US-01 | done |
| F-02 | authenticated-role-boundary | A minimal authenticated identity and role boundary exists for trainer/trainee actions. | F-01 | FR-001, FR-002, FR-003, FR-004, FR-005 | done |
| F-03 | shared-session-sync-contract | A minimal active-session sync contract exists for shared workout state. | F-01 | FR-004, FR-012, US-03 | proposed |
| S-01 | trainer-trainee-pairing | Trainer and trainee can create accounts, choose roles, and form the allowed relationship. | F-02 | FR-001, FR-002, FR-003, FR-004, FR-005 | proposed |
| S-02 | assign-global-workout-set | Trainer can define exercises in a global set and assign that set to a trainee. | S-01 | FR-007, FR-008, FR-010, US-01 | proposed |
| S-03 | start-shared-workout-session | Trainer can start one active workout session for a trainee and assigned set. | S-01, S-02 | FR-004, FR-010, FR-012, US-03 | proposed |
| S-04 | live-trainer-led-entry | Trainer enters exercise values and trainee sees the same active session without manual refresh. | F-03, S-03 | FR-004, FR-011, FR-012, US-03 | proposed |
| S-05 | save-progress-next-session | Values from a completed workout become the starting point for the next session. | S-04 | FR-011, US-02 | proposed |
| S-06 | trainee-self-edit-training-values | Trainee can view and edit own training values when completing a workout without trainer input. | S-02, S-05 | FR-005, FR-011, US-02 | proposed |

## Baseline

- Frontend: partial. Flutter scaffold exists, but the app still shows a placeholder screen.
- Backend/API: partial. ASP.NET Core API exists with health, Swagger, and template weather endpoints.
- Data: absent. No database provider, ORM, schema, migrations, or seed data are wired.
- Auth: absent. No account provider, token/session handling, role guard, or route authorization exists.
- Deploy/infra: partial. API deploy to Azure App Service is wired through GitHub Actions; mobile release automation is not present.
- Observability: absent/implicit. No application telemetry, metrics, or error tracking beyond platform/runtime logs.

## Foundations

### F-01: Mobile-to-API smoke path

- Outcome: Mobile app can verify the deployed API is reachable before product flows depend on it.
- Change ID: `mobile-api-smoke-path`
- PRD refs: FR-001, US-01
- Prerequisites: none
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: Without a verified mobile-to-backend path, later slices can fail on environment wiring instead of product behavior.
- Status: done
- Unlocks: F-02, F-03, and every user-facing slice that crosses mobile/API boundaries.

### F-02: Authenticated role boundary

- Outcome: A minimal authenticated identity and role boundary exists for trainer/trainee actions.
- Change ID: `authenticated-role-boundary`
- PRD refs: FR-001, FR-002, FR-003, FR-004, FR-005
- Prerequisites: F-01
- Parallel with: F-03 after F-01
- Blockers: none
- Unknowns: none
- Risk: Pairing and training-data access rules become unreliable if role identity is not established before user-facing relationship slices.
- Status: done
- Unlocks: S-01, S-03, S-04, S-06.

### F-03: Shared-session sync contract

- Outcome: A minimal active-session sync contract exists for shared workout state.
- Change ID: `shared-session-sync-contract`
- PRD refs: FR-004, FR-012, US-03
- Prerequisites: F-01
- Parallel with: F-02 after F-01
- Blockers: none
- Unknowns:
  - Confirm how much near-real-time behavior is acceptable on the free Azure tier. Block: no. Owner: product/engineering.
- Risk: The shared workout can miss the "same training window" requirement if synchronization is deferred until late implementation.
- Status: proposed
- Unlocks: S-04.

## Slices

### S-01: Trainer-trainee pairing

- Outcome: Trainer and trainee can create accounts, choose roles, and form the allowed relationship.
- Change ID: `trainer-trainee-pairing`
- PRD refs: FR-001, FR-002, FR-003, FR-004, FR-005
- Prerequisites: F-02
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: Access boundaries are central to the product; mistakes here leak or mix training data between users.
- Status: proposed

### S-02: Assign global workout set

- Outcome: Trainer can define exercises in a global set and assign that set to a trainee.
- Change ID: `assign-global-workout-set`
- PRD refs: FR-007, FR-008, FR-010, US-01
- Prerequisites: S-01
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: If exercise values are modeled too loosely, later progress and shared-session slices will need rework.
- Status: proposed

### S-03: Start shared workout session

- Outcome: Trainer can start one active workout session for a trainee and assigned set.
- Change ID: `start-shared-workout-session`
- PRD refs: FR-004, FR-010, FR-012, US-03
- Prerequisites: S-01, S-02
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: The product can drift into separate trainer and trainee copies unless the active session is a single shared object.
- Status: proposed

### S-04: Trainer enters values and trainee sees the same active session

- Outcome: Trainer enters exercise values and trainee sees the same active session without manual refresh.
- Change ID: `live-trainer-led-entry`
- PRD refs: FR-004, FR-011, FR-012, US-03
- Prerequisites: F-03, S-03
- Parallel with: none
- Blockers: none
- Unknowns:
  - Decide whether the first MVP accepts light polling before paid realtime infrastructure. Block: no. Owner: product/engineering.
- Risk: This is the product's highest-feedback slice and the main place where free-tier infrastructure can constrain UX.
- Status: proposed

### S-05: Save progress for the next session

- Outcome: Values from a completed workout become the starting point for the next session.
- Change ID: `save-progress-next-session`
- PRD refs: FR-011, US-02
- Prerequisites: S-04
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: Incorrect overwrite rules can destroy progress history or show stale values at the next workout.
- Status: proposed

### S-06: Trainee self-edit training values

- Outcome: Trainee can view and edit own training values when completing a workout without trainer input.
- Change ID: `trainee-self-edit-training-values`
- PRD refs: FR-005, FR-011, US-02
- Prerequisites: S-02, S-05
- Parallel with: none
- Blockers: none
- Unknowns: none
- Risk: Self-editing can conflict with trainer-led edits unless it reuses the same training-value ownership rules.
- Status: proposed

## Backlog Handoff

| Roadmap ID | Change ID | Plan input |
|---|---|---|
| F-01 | `mobile-api-smoke-path` | `/10x-plan mobile-api-smoke-path` |
| F-02 | `authenticated-role-boundary` | `/10x-plan authenticated-role-boundary` |
| F-03 | `shared-session-sync-contract` | `/10x-plan shared-session-sync-contract` |
| S-01 | `trainer-trainee-pairing` | `/10x-plan trainer-trainee-pairing` |
| S-02 | `assign-global-workout-set` | `/10x-plan assign-global-workout-set` |
| S-03 | `start-shared-workout-session` | `/10x-plan start-shared-workout-session` |
| S-04 | `live-trainer-led-entry` | `/10x-plan live-trainer-led-entry` |
| S-05 | `save-progress-next-session` | `/10x-plan save-progress-next-session` |
| S-06 | `trainee-self-edit-training-values` | `/10x-plan trainee-self-edit-training-values` |

## Open Roadmap Questions

- How much near-real-time behavior is acceptable on the free Azure tier before upgrading infrastructure? Owner: product/engineering. Unblocks: quality bar for F-03 and S-04. Block: no.
- When should the template `/weatherforecast` endpoint be removed from the public API surface? Owner: engineering. Unblocks: API cleanup before broader sharing. Block: no.
- Should mobile release automation wait until after the core workout flow, or be introduced before external TestFlight/Android testers? Owner: product/engineering. Unblocks: release hardening. Block: no.

## Parked

- FR-006: Trainer exercise library remains nice-to-have and parked until inline exercise definitions stop being enough.
- FR-009: Individual trainee-specific templates remain nice-to-have and parked until global templates prove too rigid.
- Paid realtime infrastructure remains parked until S-04 proves the user value and free-tier behavior becomes insufficient.

## Done

- **F-01: Mobile app can verify the deployed API is reachable before product flows depend on it.** — Archived 2026-06-18 → `context/archive/2026-06-01-mobile-api-smoke-path/`. Lesson: —.
- **F-02: A minimal authenticated identity and role boundary exists for trainer/trainee actions.** — Archived 2026-06-18 → `context/archive/2026-06-02-authenticated-role-boundary/`. Lesson: —.
