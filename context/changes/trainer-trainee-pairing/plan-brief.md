# Post-onboarding Relationship Management - Plan Brief

> Full plan: `context/changes/trainer-trainee-pairing/plan.md`

## What & Why

This plan adds the relationship management screens and contracts that remain after `dostosowanie` implements onboarding and basic invite-code pairing. Trainers need a permanent place to see trainees and retrieve their invite code; trainees need a post-login home that clearly shows whether they are linked to a trainer.

## Starting Point

`dostosowanie` owns display-name registration, `TrainerUserId`, invite-code generation, initial code claiming, and onboarding screens. This plan assumes those contracts are present and builds the role-specific post-auth experience from `apps/mobile/design/LiftMate.dc.html`.

## Desired End State

Trainer login lands on a `t_dash`-style dashboard with an invite-code card, empty state, trainee list, and trainee detail. Trainee login lands on a `c_home`-style relationship status screen. A trainee can submit a new valid trainer code and the app treats it as a re-pair, replacing the previous trainer and cancelling any active shared session tied to the old trainer.

## Key Decisions Made

| Decision | Choice | Why | Source |
| --- | --- | --- | --- |
| Relationship lifecycle | Re-pair overwrites current trainer and cancels active old-trainer sessions | The user chose overwrite; the review added the access-control closure needed to keep old trainers from retaining session access. | Plan questions / Review |
| Trainer screen | Invite-code card plus trainee list | It maps to `t_dash` and fixes the missing post-onboarding invite surface. | Design / Plan questions |
| Trainee screen | `c_home` relationship status | It gives trainees a useful home before workout slices exist. | Design / Plan questions |
| API shape | Dedicated relationship read endpoints | Keeps `/auth/me` focused and gives dashboards stable contracts. | Plan questions |
| Empty state | Invite-first trainer empty state | A trainer with no trainees needs the invite action, not fake dashboard stats. | Plan questions |
| Testing | API, mobile client, and widget tests | Covers contract and role navigation without heavy E2E. | Plan questions |

## Scope

**In scope:** backend relationship summaries, re-pair overwrite behavior, active-session cancellation for old-trainer access, mobile relationship client/controller, trainer dashboard, trainer trainee-detail view, trainee relationship home, empty states, logout, and tests.

**Out of scope:** rebuilding onboarding, workout plans, set assignment, live sessions, progress charts, invite-code expiration/revocation, in-app sharing, admin recovery, and full E2E.

## Architecture / Approach

Backend keeps `ApplicationUser.TrainerUserId` as the source of truth and adds `GET /trainer/relationship` plus `GET /trainee/relationship`. Re-pairing updates that source of truth and cancels active shared sessions that would otherwise preserve old trainer access. Mobile adds a relationship layer beside auth, then routes authenticated users by role to design-backed screens. The prototype's workout/progress areas are reduced to relationship-backed content or placeholders until later roadmap slices provide real data.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Backend Relationship Read Surface | Relationship summaries, re-pair overwrite, and old-session access cancellation. | Invalid-code failures must not mutate relationship or session state. |
| 2. Mobile Relationship Contract | Typed relationship models, read client, and controller state using existing auth claim mutation. | Controller boundaries must avoid duplicating `AuthApiClient` pairing calls. |
| 3. Post-auth Role Screens | Trainer dashboard, trainee detail, and trainee home/status UI. | Avoiding fake workout/progress data while staying faithful to the design. |

**Prerequisites:** `context/changes/dostosowanie` should be landed or stable enough to rebase on its auth/pairing contracts.
**Estimated effort:** Medium implementation across backend contract, mobile contract, and UI phases.

## Open Risks & Assumptions

- Re-pair overwrite is intentionally allowed even after a trainee already has a trainer, but old active trainer sessions are cancelled during the change.
- No new database table should be needed if `dostosowanie` has already added relationship storage.
- The design is the visual source, but only relationship-backed parts should become real UI in this slice.

## Success Criteria Summary

- Trainers can retrieve an invite code, see no-trainee empty state, and list only their linked trainees.
- Trainees can see linked/unlinked status and can re-pair by entering a new valid trainer code without leaving old trainer session access behind.
- Automated API, mobile client/controller, and widget tests pass, followed by manual phone-sized layout checks.
