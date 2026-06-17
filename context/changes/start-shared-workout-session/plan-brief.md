# Start Shared Workout Session — Plan Brief

> Full plan: `context/changes/start-shared-workout-session/plan.md`

## What & Why

Build S-03 as the first production shared workout-session flow. A trainer can start a shared session for a trainee and assigned set, while a trainee can also start their own workout session without trainer involvement. Both paths create one canonical active session so the other participant can join later instead of drifting into a separate copy.

## Starting Point

F-03 already provides shared-session persistence, updates, SignalR delivery, active-session fetch, and reconnect recovery. S-02 already provides assigned workout sets. The gap is connecting those foundations to production trainer/trainee flows and the updated design contract in `apps/mobile/design/LiftMate.html`.

## Desired End State

Trainer-led sessions start from the trainee detail screen and show the trainee a limited read-only live view. Trainee self-start sessions start from an assigned-set card, show the trainee full editable live controls, and make the trainer dashboard show "Aktywna sesja" with a join action in trainee detail. Only one active session is allowed per trainee.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Design source | `apps/mobile/design/LiftMate.html` | The user marked it as the updated design contract. |
| Start modes | Trainer-led and trainee self-start | The product needs both coached and solo workout starts. |
| Active cardinality | One active session per trainee | Keeps discovery deterministic and matches existing backend invariant. |
| Snapshot source | Copy assigned workout-set rows at start | Prevents live sessions changing when a template changes later. |
| Session origin | Persist starter user/role and workout set | Fresh clients must know which UI mode to render. |
| Set completion | Persist done state on session values | Done checks and completed-set counts must survive reconnect and appear on both clients. |
| Edit authority | Enforce trainer-led read-only trainee mode in API | UI-only restrictions are not enough for a product permission boundary. |
| Trainer refresh | Reuse `sessionStarted` as a trainer invalidation signal | Trainer dashboard state stays canonical by refreshing relationship data after the event. |
| Trainer discovery | Badge on trainee list plus join in detail | Matches the user's requested UX without adding a separate sessions screen. |
| Trainer-led trainee UI | Read-only `c_live` | Matches design and keeps trainer-led editing scoped to the trainer. |
| Self-start trainee UI | Full editable live screen | Trainee owns their solo session and trainer can later join. |
| Verification | API + Flutter tests and post-PR manual checklist | The feature crosses auth, assignments, realtime, and UI state. |

## Scope

**In scope:**

- Backend start-from-workout-set contract for trainer and trainee.
- Session origin, workout-set identity, and exercise grouping fields.
- Canonical set completion state on shared-session values.
- API enforcement that trainer-led sessions are read-only for trainees.
- Active-session summary in trainer relationship data.
- Trainer list badge "Aktywna sesja" and detail "Dołącz do sesji".
- Trainee start/join button behavior from assigned workout set cards.
- Editable trainer/self-start live screen and read-only trainer-led trainee live screen.
- API and Flutter tests for both start modes and access boundaries.

**Out of scope:**

- Saving completed values as next-session progress.
- Multiple active sessions for one trainee.
- Separate trainer sessions screen.
- Paid realtime infrastructure.
- Broad redesign of unrelated auth, pairing, or workout-set builder flows.

## Architecture / Approach

Backend owns the canonical active session and validates that the selected workout set is assigned to the target trainee. Starting a session snapshots workout-set rows into shared-session values, marks who started it, persists set completion state, broadcasts updates, and exposes active-session metadata to the trainer relationship summary. Flutter controllers then choose the correct live UI based on server-owned origin fields, not local navigation history.

## Phases At A Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Backend Session Origin And Workout-Set Start Contract | Production start from assigned sets for trainer and trainee | Incorrect access checks or incomplete snapshot shape |
| 2. Backend Active-Session Discovery For Trainer And Trainee | Trainer can see and join active trainee sessions | Leaking session state to the wrong trainer |
| 3. Mobile Shared-Session Models And Controllers | Flutter understands session origin and start/join flows | UI infers state locally instead of from API |
| 4. Mobile Trainer Flow | Trainer badge, start, join, and editable live screen | Regressing existing relationship/workout-set screens |
| 5. Mobile Trainee Flow And Live Screens | Trainee self-start and read-only trainer-led join modes | Mixing self-start editability into trainer-led sessions |
| 6. Verification And Plan Bookkeeping | Full automated checks and manual checklist | Manual Android/design regressions missed before PR |

**Prerequisites:** S-01 trainer-trainee pairing, S-02 assigned workout sets, F-03 shared-session sync contract.  
**Estimated effort:** ~2-3 implementation sessions across 6 phases.

## Open Risks & Assumptions

- Existing `POST /shared-sessions` create-by-values remains for diagnostics unless implementation finds it conflicts with production flow.
- Active-session badge refresh uses `sessionStarted` as an invalidation signal, but the canonical source remains a trainer relationship refresh from the API.
- Mobile live screen may reuse components between trainer and self-start trainee modes, but trainer-led trainee mode must stay read-only.

## Success Criteria Summary

- Trainer-led flow: trainer starts, trainee joins read-only, trainer edits values, both observe the same active session.
- Trainee self-start flow: trainee starts and edits, trainer sees "Aktywna sesja", trainer joins the same active session.
- Backend and mobile tests prove access boundaries, snapshot behavior, one-active-session invariant, and origin-specific UI.
