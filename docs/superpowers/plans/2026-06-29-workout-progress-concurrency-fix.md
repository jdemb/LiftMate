# Workout Progress Concurrency Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent HTTP 500 when a trainer completes a later shared workout session by replacing an existing `WorkoutProgress` snapshot without EF Core tracked update/delete concurrency checks.

**Architecture:** Keep the existing serializable completion transaction and endpoint sequence unchanged. `WorkoutProgressProjector` will read existing projection metadata without tracking, update the existing parent and delete its prior values through set-based EF Core operations, then enqueue the current values as a fresh snapshot for the caller's existing `SaveChangesAsync`.

**Tech Stack:** ASP.NET Core 10, Entity Framework Core 10, Azure SQL production provider, SQLite integration-test provider, xUnit

---

## File Structure

- Modify `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`: add a persistence-strategy contract regression and an end-to-end trainer completion regression with changed workout-set rows.
- Modify `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs`: replace the tracked existing-progress update/delete branch with `AsNoTracking`, `ExecuteUpdateAsync`, and `ExecuteDeleteAsync` while preserving first projection and stale-completion behavior.
- Do not modify `SharedSessionEndpoints.cs`, mobile files, database migrations, `dc.html`, or any other HTML file.

### Task 1: Add Regressions For Existing Progress Replacement

**Files:**
- Modify: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- Test: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

- [ ] **Step 1: Add a failing persistence-strategy regression after `SecondCompletionForSameAssignedSetReplacesProgress`**

Add this test. It intentionally calls the projector without `SaveChangesAsync`: the existing projection branch must execute set-based parent/value changes immediately and must not leave tracked `Modified` or `Deleted` progress entities that can trigger SQL Server's zero-rows-affected concurrency check.

```csharp
[Fact]
public async Task ExistingProgressProjectionUsesSetBasedReplacement()
{
    using var client = factory.CreateClient();
    var trainer = await AuthEndpointTests.Register(client, "trainer");
    var trainee = await AuthEndpointTests.Register(client, "trainee");
    await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
    var workoutSet = await CreateWorkoutSet(
        client,
        trainer,
        "Set-based progress",
        DefaultWorkoutSetRows());
    await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

    var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
    client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
    var firstComplete = await client.PostAsync(
        $"/shared-sessions/{first.Id}/complete",
        null);
    Assert.Equal(HttpStatusCode.OK, firstComplete.StatusCode);

    var second = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);

    await using var scope = factory.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await using var transaction = await dbContext.Database.BeginTransactionAsync();
    var persistedSession = await dbContext.SharedSessions
        .Include(item => item.Values)
        .SingleAsync(item => item.Id == second.Id);
    var projector = new WorkoutProgressProjector(dbContext);

    await projector.ProjectAsync(
        persistedSession,
        DateTimeOffset.UtcNow.AddMinutes(1),
        CancellationToken.None);

    Assert.DoesNotContain(
        dbContext.ChangeTracker.Entries<WorkoutProgress>(),
        entry => entry.State is EntityState.Modified or EntityState.Deleted);
    Assert.DoesNotContain(
        dbContext.ChangeTracker.Entries<WorkoutProgressValue>(),
        entry => entry.State is EntityState.Modified or EntityState.Deleted);
    Assert.All(
        dbContext.ChangeTracker.Entries<WorkoutProgressValue>(),
        entry => Assert.Equal(EntityState.Added, entry.State));

    await transaction.RollbackAsync();
}
```

- [ ] **Step 2: Add the end-to-end trainer regression immediately after the persistence-strategy regression**

Add this test. It verifies the user-visible production scenario and protects the endpoint response, completion state, unique progress root, latest source session, and exact current-row snapshot.

```csharp
[Fact]
public async Task TrainerCompletionReplacesProgressAfterWorkoutSetRowsChange()
{
    using var client = factory.CreateClient();
    var trainer = await AuthEndpointTests.Register(client, "trainer");
    var trainee = await AuthEndpointTests.Register(client, "trainee");
    await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
    var workoutSet = await CreateWorkoutSet(
        client,
        trainer,
        "Changed progress rows",
        DefaultWorkoutSetRows());
    await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
    var originalRow = Assert.Single(workoutSet.Rows);

    var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
    client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
    var firstComplete = await client.PostAsync(
        $"/shared-sessions/{first.Id}/complete",
        null);
    Assert.Equal(HttpStatusCode.OK, firstComplete.StatusCode);

    client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
    var updateResponse = await client.PutAsJsonAsync(
        $"/workout-sets/{workoutSet.Id}",
        new UpdateWorkoutSetRequest(
            workoutSet.Name,
            [
                new WorkoutSetRowRequest(
                    1,
                    1,
                    "Bench press",
                    "repsWeight",
                    8,
                    45m,
                    null,
                    null,
                    originalRow.ExerciseId),
                new WorkoutSetRowRequest(
                    1,
                    2,
                    "Bench press",
                    "repsWeight",
                    6,
                    50m,
                    null,
                    null,
                    originalRow.ExerciseId),
            ]));
    Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

    var second = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);
    client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
    var secondComplete = await client.PostAsync(
        $"/shared-sessions/{second.Id}/complete",
        null);
    var completed = await secondComplete.Content.ReadFromJsonAsync<SharedSessionResponse>();

    Assert.Equal(HttpStatusCode.OK, secondComplete.StatusCode);
    Assert.NotNull(completed);
    Assert.Equal("completed", completed.Status);

    await using var scope = factory.Services.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    var progressItems = await dbContext.WorkoutProgresses
        .Include(item => item.Values)
        .Where(item =>
            item.TraineeUserId == trainee.User.Id &&
            item.WorkoutSetId == workoutSet.Id)
        .ToListAsync();
    var progress = Assert.Single(progressItems);
    var expectedRowIds = second.Values
        .Select(value => value.WorkoutSetRowId!.Value)
        .Order()
        .ToArray();
    var actualRowIds = progress.Values
        .Select(value => value.WorkoutSetRowId)
        .Order()
        .ToArray();

    Assert.Equal(second.Id, progress.SourceSessionId);
    Assert.Equal(expectedRowIds, actualRowIds);
    Assert.DoesNotContain(originalRow.Id, actualRowIds);
}
```

- [ ] **Step 3: Run the persistence-strategy test and verify the current projector fails**

Run from `apps/api`:

```powershell
dotnet test LiftMate.Api.Tests/LiftMate.Api.Tests.csproj --filter "FullyQualifiedName~ExistingProgressProjectionUsesSetBasedReplacement" --verbosity minimal
```

Expected: FAIL at `Assert.DoesNotContain` because the current projector tracks an existing `WorkoutProgress` as `Modified` and may track old `WorkoutProgressValue` rows as `Modified` or `Deleted`.

- [ ] **Step 4: Run the endpoint regression to establish its pre-fix SQLite result**

Run from `apps/api`:

```powershell
dotnet test LiftMate.Api.Tests/LiftMate.Api.Tests.csproj --filter "FullyQualifiedName~TrainerCompletionReplacesProgressAfterWorkoutSetRowsChange" --verbosity minimal
```

Expected: this may PASS under SQLite because SQLite does not reproduce Azure SQL's affected-row concurrency behavior. Its role is end-to-end behavioral coverage; the persistence-strategy test is the deterministic red test.

- [ ] **Step 5: Commit the regression tests**

```powershell
git add -- apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs
git commit -m "test: cover workout progress replacement"
```

### Task 2: Replace Existing Progress With Set-Based Operations

**Files:**
- Modify: `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs`
- Test: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

- [ ] **Step 1: Replace `WorkoutProgressProjector` with the set-based existing-progress implementation**

Replace the file contents with:

```csharp
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainingProgress;

public sealed class WorkoutProgressProjector(ApplicationDbContext dbContext)
{
    public async Task ProjectAsync(
        SharedSession session,
        DateTimeOffset completedAt,
        CancellationToken cancellationToken)
    {
        if (!session.WorkoutSetId.HasValue ||
            session.Values.Count == 0 ||
            session.Values.Any(value => !value.ExerciseId.HasValue || !value.WorkoutSetRowId.HasValue))
        {
            return;
        }

        var existingProgress = await dbContext.WorkoutProgresses
            .AsNoTracking()
            .Where(item =>
                item.TraineeUserId == session.TraineeUserId &&
                item.WorkoutSetId == session.WorkoutSetId.Value)
            .Select(item => new
            {
                item.Id,
                item.SourceCompletedAt,
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (existingProgress is not null && completedAt <= existingProgress.SourceCompletedAt)
        {
            return;
        }

        Guid progressId;
        if (existingProgress is null)
        {
            progressId = Guid.NewGuid();
            dbContext.WorkoutProgresses.Add(new WorkoutProgress
            {
                Id = progressId,
                TraineeUserId = session.TraineeUserId,
                WorkoutSetId = session.WorkoutSetId.Value,
                SourceSessionId = session.Id,
                SourceCompletedAt = completedAt,
                UpdatedAt = completedAt,
            });
        }
        else
        {
            progressId = existingProgress.Id;
            var updatedProgressCount = await dbContext.WorkoutProgresses
                .Where(item => item.Id == progressId)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(item => item.SourceSessionId, session.Id)
                        .SetProperty(item => item.SourceCompletedAt, completedAt)
                        .SetProperty(item => item.UpdatedAt, completedAt),
                    cancellationToken);

            if (updatedProgressCount != 1)
            {
                throw new InvalidOperationException(
                    $"Workout progress {progressId} disappeared during projection.");
            }

            await dbContext.WorkoutProgressValues
                .Where(value => value.WorkoutProgressId == progressId)
                .ExecuteDeleteAsync(cancellationToken);
        }

        foreach (var value in session.Values)
        {
            dbContext.WorkoutProgressValues.Add(new WorkoutProgressValue
            {
                Id = Guid.NewGuid(),
                WorkoutProgressId = progressId,
                WorkoutSetRowId = value.WorkoutSetRowId!.Value,
                ExerciseId = value.ExerciseId!.Value,
                ExerciseType = value.ExerciseType,
                Reps = value.Reps,
                Weight = value.Weight,
                Seconds = value.Seconds,
            });
        }
    }
}
```

- [ ] **Step 2: Run the focused replacement and ordering regressions**

Run from `apps/api`:

```powershell
dotnet test LiftMate.Api.Tests/LiftMate.Api.Tests.csproj --filter "FullyQualifiedName~ExistingProgressProjectionUsesSetBasedReplacement|FullyQualifiedName~TrainerCompletionReplacesProgressAfterWorkoutSetRowsChange|FullyQualifiedName~SecondCompletionForSameAssignedSetReplacesProgress|FullyQualifiedName~OlderCompletionCannotReplaceNewerProjection" --verbosity minimal
```

Expected: PASS, 4 tests. The stale-completion test confirms `SourceCompletedAt` ordering remains unchanged.

- [ ] **Step 3: Confirm the completion endpoint transaction and sequencing were not edited**

Run from the repository root:

```powershell
git diff -- apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs
```

Expected: no output.

- [ ] **Step 4: Commit the projector fix**

```powershell
git add -- apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs
git commit -m "api: replace workout progress snapshot safely"
```

### Task 3: Verify The API And Scope Boundaries

**Files:**
- Verify: `apps/api/LiftMate.slnx`
- Verify: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- Verify: `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs`

- [ ] **Step 1: Restore API dependencies**

Run from `apps/api`:

```powershell
dotnet restore LiftMate.slnx
```

Expected: restore succeeds with exit code 0.

- [ ] **Step 2: Build the complete API solution**

Run from `apps/api`:

```powershell
dotnet build LiftMate.slnx --no-restore
```

Expected: build succeeds with 0 errors.

- [ ] **Step 3: Run the complete API test suite**

Run from `apps/api`:

```powershell
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

Expected: all tests pass; the suite contains two more tests than the pre-fix baseline of 126.

- [ ] **Step 4: Check patch formatting**

Run from the repository root:

```powershell
git diff --check HEAD~2..HEAD
```

Expected: no output and exit code 0.

- [ ] **Step 5: Confirm no excluded files entered either implementation commit**

Run from the repository root:

```powershell
git diff --name-only HEAD~2..HEAD
```

Expected output contains only:

```text
apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs
apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs
```

- [ ] **Step 6: Inspect final worktree state without staging unrelated files**

Run from the repository root:

```powershell
git status --short
```

Expected: no tracked implementation changes remain. The pre-existing untracked `apps/mobile/design/LiftMate - prototype.html` may still appear and must remain unmodified and unstaged.
