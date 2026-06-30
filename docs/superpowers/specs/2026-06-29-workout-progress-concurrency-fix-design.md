# Workout Progress Concurrency Fix

## Problem

Completing an active shared session can return HTTP 500 on Azure SQL. Production logs show `DbUpdateConcurrencyException` at the second `SaveChangesAsync` in `SharedSessionEndpoints.Complete`, immediately after `WorkoutProgressProjector.ProjectAsync`.

The failure existed before weekly streak integration. A first completion can insert `WorkoutProgress`, while a later completion for the same trainee and workout set enters the tracked update/delete path. The current SQLite regression covers repeated completion with unchanged workout-set rows but does not reproduce SQL Server's zero-rows-affected failure for an existing projection whose row composition changed.

## Scope

Keep shared-session completion atomic. Do not move progress projection, weekly streak calculation, or guidance evaluation outside the existing serializable transaction.

Change only the existing-progress branch of `WorkoutProgressProjector`. Do not change mobile synchronization behavior, endpoint response contracts, database schema, or HTML files.

## Design

Read the existing progress metadata without tracking. If the incoming completion is not newer, return without changes.

For a newer existing projection, update the parent metadata with `ExecuteUpdateAsync`, delete its prior `WorkoutProgressValues` with `ExecuteDeleteAsync`, and add a fresh value snapshot using the existing progress identifier. For a first projection, keep the current insert behavior.

Check the affected-row count of the parent update. A missing parent is a real invariant violation and must fail explicitly; do not swallow concurrency failures or report a successful completion with missing projected progress.

The caller retains its existing `SaveChangesAsync`, transaction commit, weekly streak calculation, guidance evaluation, and SignalR broadcast sequence.

## Verification

Add an endpoint regression in which a trainee first completes an assigned set, the trainer changes the set's row composition, and the trainer completes the next session. Verify HTTP 200, completed session state, one `WorkoutProgress` row, the latest source session, and values matching only the current workout-set rows.

Run the targeted shared-session endpoint tests, the complete API test suite, and a clean API build. No mobile or HTML changes are required.
