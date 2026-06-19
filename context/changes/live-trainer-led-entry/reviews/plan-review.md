<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Live Trainer-Led Entry Implementation Plan

- **Plan**: `context/changes/live-trainer-led-entry/plan.md`
- **Mode**: Deep
- **Date**: 2026-06-19
- **Verdict**: SOUND
- **Findings**: 0 critical, 0 warnings, 0 observations after triage

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | PASS |
| Plan Completeness | PASS |

## Grounding

Grounding: 7/7 paths ✓, 6/6 symbols ✓, brief↔plan ✓, Progress↔phases ✓. The `signalr_netcore` 1.4.4 source confirms automatic reconnect emits `Reconnecting` followed by `Connected`.

## Findings

### F1 — Event innej sesji może zastąpić otwarty trening

- **Severity**: ❌ CRITICAL
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: End-State Alignment
- **Location**: Phase 1 — Realtime Snapshot Guard
- **Detail**: `sessionStarted` and `sessionUpdated` share one controller handler. A trainer can have multiple trainees, so a start event for session B could replace currently open session A without a user decision.
- **Fix**: When a local active session exists, an event with another session ID must not replace it. For trainers it invalidates relationship data only; switching sessions requires leaving the current live view and explicitly joining through UI.
- **Decision**: FIXED — explicit user-directed session switching added to plan and brief, including controller and manual tests.

### F2 — Błąd rejoin nie jest widoczny przy zachowanej sesji

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Plan Completeness
- **Location**: Phase 1 — Reconnect State Tracking
- **Detail**: `LiveSessionScreen` renders `state.message` only when no session is loaded, while the plan promises a visible realtime error without clearing the session.
- **Fix**: Add a non-blocking realtime error banner above the active-session content. Preserve values and navigation; clear the banner automatically after successful rejoin.
- **Decision**: FIXED — Fix A selected and added to plan, brief, widget tests, success criteria, and Progress.

## Final Assessment

The revised plan is safe to implement. It preserves the currently open session, keeps session switching user-directed, makes degraded realtime state visible without interrupting the workout, and covers both behaviors with targeted tests.
