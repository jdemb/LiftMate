# Trainer Connection Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant relationship details from the trainer's trainee-detail screen and replace its static status with grammatically correct Polish connection copy backed by an accurate connection month.

**Architecture:** Persist a nullable `TrainerLinkedAt` timestamp on trainee users for all new and repeated links. The trainer relationship endpoint resolves legacy nulls from the trainee's oldest refresh token and exposes nullable `connectedAt`; Flutter parses that value and delegates Polish gender/month copy to a focused formatter with a neutral fallback.

**Tech Stack:** ASP.NET Core 10 minimal APIs, Entity Framework Core 10, xUnit, Flutter/Dart, `flutter_test`.

---

### Task 1: Persist the trainer connection timestamp

**Files:**
- Modify: `apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs`
- Modify: `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`
- Modify: `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`
- Modify: `apps/api/LiftMate.Api/Auth/ApplicationUser.cs`
- Modify: `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`
- Modify: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`
- Modify: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- Create with EF CLI: timestamped `AddTrainerLinkedAt.cs` migration under `apps/api/LiftMate.Api/Migrations/`
- Create with EF CLI: matching timestamped `AddTrainerLinkedAt.Designer.cs` under `apps/api/LiftMate.Api/Migrations/`
- Modify with EF CLI: `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`

- [x] **Step 1: Write failing persistence tests**

In `AuthEndpointTests.RegisterTraineeWithTrainerCodeCreatesLinkedAccount`, read the newly created user through `ApplicationDbContext` and assert that `TrainerLinkedAt` is between timestamps captured immediately before and after the request:

```csharp
var startedAt = DateTimeOffset.UtcNow;
var response = await client.PostAsJsonAsync(
    "/auth/register/trainee",
    new RegisterTraineeRequest(
        email,
        "Pass123$Strong",
        "Test Trainee",
        TestRegistrationInviteCode,
        invite!.Code.ToLowerInvariant()));
var completedAt = DateTimeOffset.UtcNow;

using var scope = factory.Services.CreateScope();
var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
var persisted = await dbContext.Users.SingleAsync(user => user.Email == email);
Assert.NotNull(persisted.TrainerLinkedAt);
Assert.InRange(persisted.TrainerLinkedAt.Value, startedAt, completedAt);
```

In `PairingEndpointTests.TraineeCanClaimTrainerInviteCodeWithNormalizedInput`, add the same bounded assertion after the claim request. Keep the existing trainer-id assertions.

In `MigrationScriptTests`, add:

```csharp
[Fact]
public void TrainerLinkedAtMigrationAddsNullableUserTimestamp()
{
    var options = new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
        .Options;

    using var dbContext = new ApplicationDbContext(options);
    var script = dbContext.GetService<IMigrator>().GenerateScript(
        options: MigrationsSqlGenerationOptions.Idempotent);

    Assert.Contains("AddTrainerLinkedAt", script, StringComparison.Ordinal);
    Assert.Contains("TrainerLinkedAt", script, StringComparison.Ordinal);
    Assert.Contains("datetimeoffset", script, StringComparison.OrdinalIgnoreCase);
}
```

- [x] **Step 2: Run the tests and verify RED**

Run from `apps/api`:

```powershell
dotnet test LiftMate.slnx --filter "FullyQualifiedName~AuthEndpointTests.RegisterTraineeWithTrainerCodeCreatesLinkedAccount|FullyQualifiedName~PairingEndpointTests.TraineeCanClaimTrainerInviteCodeWithNormalizedInput|FullyQualifiedName~MigrationScriptTests.TrainerLinkedAtMigrationAddsNullableUserTimestamp"
```

Expected: compilation fails because `ApplicationUser.TrainerLinkedAt` and the migration do not exist.

- [x] **Step 3: Add the nullable property and write it on every link**

Add to `ApplicationUser`:

```csharp
public DateTimeOffset? TrainerLinkedAt { get; set; }
```

Map it in the existing `ApplicationUser` configuration:

```csharp
entity.Property(user => user.TrainerLinkedAt);
```

In `RegisterTrainee`, capture one timestamp and assign it both to the user and invite-code usage:

```csharp
var linkedAt = DateTimeOffset.UtcNow;
var user = new ApplicationUser
{
    Email = email,
    UserName = email,
    DisplayName = displayName,
    LiftMateRole = UserRole.Trainee,
    TrainerUserId = inviteCode.TrainerUserId,
    TrainerLinkedAt = linkedAt,
};

// after successful Identity creation
inviteCode.LastUsedAt = linkedAt;
```

In `ClaimTrainerInviteCode`, update the timestamp whenever the claim succeeds, including a claim for the same trainer:

```csharp
var linkedAt = DateTimeOffset.UtcNow;
var previousTrainerUserId = trainee.TrainerUserId;
trainee.TrainerUserId = inviteCode.TrainerUserId;
trainee.TrainerLinkedAt = linkedAt;
inviteCode.LastUsedAt = linkedAt;
```

- [x] **Step 4: Generate the EF migration**

Run from `apps/api`:

```powershell
dotnet ef migrations add AddTrainerLinkedAt --project LiftMate.Api/LiftMate.Api.csproj --startup-project LiftMate.Api/LiftMate.Api.csproj
```

Expected migration behavior:

```csharp
migrationBuilder.AddColumn<DateTimeOffset>(
    name: "TrainerLinkedAt",
    table: "AspNetUsers",
    type: "datetimeoffset",
    nullable: true);
```

Do not backfill this column in the migration; legacy resolution belongs to Task 2.

- [x] **Step 5: Run targeted tests and verify GREEN**

Run the command from Step 2 again. Expected: all three selected tests pass.

- [x] **Step 6: Commit**

```powershell
git add apps/api/LiftMate.Api/Auth/ApplicationUser.cs apps/api/LiftMate.Api/Auth/AuthEndpoints.cs apps/api/LiftMate.Api/Auth/PairingEndpoints.cs apps/api/LiftMate.Api/Data/ApplicationDbContext.cs apps/api/LiftMate.Api/Migrations apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs
git commit -m "api: persist trainer connection timestamp"
```

### Task 2: Expose connection time with a legacy registration fallback

**Files:**
- Modify: `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`
- Modify: `apps/api/LiftMate.Api/Auth/AuthContracts.cs`
- Modify: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

- [x] **Step 1: Write failing endpoint tests for persisted, legacy, and missing dates**

Extend the private test response record with a nullable timestamp after `DisplayName`:

```csharp
private sealed record TrainerTraineeResponse(
    string Id,
    string Email,
    string DisplayName,
    DateTimeOffset? ConnectedAt,
    ActiveSharedSessionSummaryResponse? ActiveSession,
    IReadOnlyList<AssignedWorkoutSetSummaryResponse> AssignedWorkoutSets,
    WeeklyStreakResponse WeeklyStreak);
```

Add `TrainerRelationshipSummaryReturnsPersistedConnectionTimestamp`: pair a trainee, read their persisted `TrainerLinkedAt`, call `/trainer/relationship` as that trainer, and assert `Assert.Single(summary!.Trainees).ConnectedAt` equals the persisted value.

Add `TrainerRelationshipSummaryFallsBackToOldestRefreshTokenForLegacyLink`. Set `TrainerLinkedAt = null`, change the trainee's oldest refresh token to a fixed instant, and assert that instant is returned:

```csharp
var registeredAt = new DateTimeOffset(2026, 3, 8, 10, 0, 0, TimeSpan.Zero);
using (var scope = factory.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    var user = await dbContext.Users.SingleAsync(value => value.Id == trainee.User.Id);
    user.TrainerLinkedAt = null;
    var oldestToken = await dbContext.RefreshTokens
        .Where(token => token.UserId == trainee.User.Id)
        .OrderBy(token => token.CreatedAt)
        .FirstAsync();
    oldestToken.CreatedAt = registeredAt;
    await dbContext.SaveChangesAsync();
}

// GET /trainer/relationship as trainer
Assert.Equal(registeredAt, Assert.Single(summary!.Trainees).ConnectedAt);
```

Add `TrainerRelationshipSummaryReturnsNullConnectionTimestampWithoutLegacyToken`. Null `TrainerLinkedAt`, remove only the trainee's refresh tokens with `dbContext.RefreshTokens.RemoveRange(...)`, save, call the endpoint as trainer, and assert `Assert.Null(Assert.Single(summary!.Trainees).ConnectedAt)`. The trainer's access token remains valid for the GET request.

- [x] **Step 2: Run the endpoint tests and verify RED**

Run from `apps/api`:

```powershell
dotnet test LiftMate.slnx --filter "FullyQualifiedName~PairingEndpointTests.TrainerRelationshipSummary"
```

Expected: new assertions fail because the response does not contain `connectedAt`.

- [x] **Step 3: Extend the API contract and resolve legacy dates in one query**

Add `ConnectedAt` to `TrainerTraineeResponse`:

```csharp
public sealed record TrainerTraineeResponse(
    string Id,
    string Email,
    string DisplayName,
    DateTimeOffset? ConnectedAt,
    ActiveSharedSessionSummaryResponse? ActiveSession,
    IReadOnlyList<AssignedWorkoutSetSummaryResponse> AssignedWorkoutSets,
    WeeklyStreakResponse WeeklyStreak);
```

After loading `traineeUsers`, collect only legacy ids and query their oldest refresh-token timestamps without N+1 calls:

```csharp
var legacyTraineeIds = traineeUsers
    .Where(user => user.TrainerLinkedAt is null)
    .Select(user => user.Id)
    .ToArray();
var legacyConnectedAt = await dbContext.RefreshTokens
    .Where(token => legacyTraineeIds.Contains(token.UserId))
    .GroupBy(token => token.UserId)
    .Select(group => new
    {
        UserId = group.Key,
        ConnectedAt = group.Min(token => token.CreatedAt),
    })
    .ToDictionaryAsync(item => item.UserId, item => item.ConnectedAt, cancellationToken);
```

Pass the resolved value when mapping trainees, preserving `null` when no legacy token exists:

```csharp
user.TrainerLinkedAt ??
    (legacyConnectedAt.TryGetValue(user.Id, out var registeredAt)
        ? registeredAt
        : null)
```

- [x] **Step 4: Run targeted tests and verify GREEN**

Run the command from Step 2. Expected: all trainer relationship summary tests pass.

- [x] **Step 5: Commit**

```powershell
git add apps/api/LiftMate.Api/Auth/AuthContracts.cs apps/api/LiftMate.Api/Auth/PairingEndpoints.cs apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs
git commit -m "api: expose trainee connection date"
```

### Task 3: Parse and format grammatical Polish connection copy

**Files:**
- Modify: `apps/mobile/lib/relationships/relationship_models.dart`
- Modify: `apps/mobile/lib/relationships/relationship_formatters.dart`
- Modify: `apps/mobile/test/relationship_api_client_test.dart`
- Create: `apps/mobile/test/relationship_connection_formatter_test.dart`

- [ ] **Step 1: Write failing model and formatter tests**

In the trainer relationship API-client test, include:

```dart
'connectedAt': '2026-03-08T10:00:00Z',
```

and assert:

```dart
expect(
  result.data?.trainees.single.connectedAt,
  DateTime.utc(2026, 3, 8, 10),
);
```

Create `relationship_connection_formatter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/relationships/relationship_formatters.dart';

void main() {
  test('formats feminine, masculine and neutral connection status', () {
    final connectedAt = DateTime(2026, 3, 8);

    expect(
      formatTraineeConnectionStatus('Anna Nowak', connectedAt),
      'Połączona od marca 2026',
    );
    expect(
      formatTraineeConnectionStatus('Piotr Kowalski', connectedAt),
      'Połączony od marca 2026',
    );
    expect(
      formatTraineeConnectionStatus('Alex Nowak', connectedAt),
      'Połączono od marca 2026',
    );
    expect(
      formatTraineeConnectionStatus('Alex Nowak', null),
      'Połączono',
    );
  });

  test('uses every Polish genitive month form', () {
    const months = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];

    for (var month = 1; month <= 12; month += 1) {
      expect(
        formatTraineeConnectionStatus('Anna', DateTime(2026, month, 15)),
        'Połączona od ${months[month - 1]} 2026',
      );
    }
  });

  test('handles Polish masculine exceptions ending with a', () {
    expect(
      formatTraineeConnectionStatus('Kuba Nowak', null),
      'Połączony',
    );
  });
}
```

- [ ] **Step 2: Run tests and verify RED**

Run from `apps/mobile`:

```powershell
flutter test --reporter compact test/relationship_api_client_test.dart test/relationship_connection_formatter_test.dart
```

Expected: compilation fails because `connectedAt` and `formatTraineeConnectionStatus` do not exist.

- [ ] **Step 3: Parse nullable `connectedAt`**

Extend `TrainerTraineeSummary`:

```dart
const TrainerTraineeSummary({
  required this.id,
  required this.email,
  required this.displayName,
  this.connectedAt,
  this.assignedWorkoutSets = const <AssignedWorkoutSetSummary>[],
  this.activeSession,
  this.weeklyStreak = WeeklyStreakSummary.zero,
});

final DateTime? connectedAt;
```

In `fromJson`, validate and parse it strictly:

```dart
final connectedAt = json['connectedAt'];

// include in the existing invalid-body condition
(connectedAt != null && connectedAt is! String)

// include in the returned model
connectedAt: connectedAt == null ? null : DateTime.parse(connectedAt).toUtc(),
```

- [ ] **Step 4: Implement the focused formatter**

Append to `relationship_formatters.dart`:

```dart
const _polishGenitiveMonths = <String>[
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

const _masculineNames = <String>{
  'adam', 'adrian', 'aleksander', 'andrzej', 'antoni', 'barnaba',
  'bartosz', 'dawid', 'filip', 'grzegorz', 'jakub', 'jan', 'jarema',
  'jerzy', 'kacper', 'karol', 'kosma', 'krzysztof', 'kuba', 'łukasz',
  'maciej', 'marcin', 'marek', 'mateusz', 'michał', 'mikołaj', 'paweł',
  'piotr', 'przemysław', 'rafał', 'robert', 'sebastian', 'szymon',
  'tomasz', 'wojciech', 'zbigniew',
};

const _neutralNames = <String>{
  'alex', 'andrea', 'ari', 'mika', 'nikita', 'noa', 'sasza',
};

String formatTraineeConnectionStatus(
  String displayName,
  DateTime? connectedAt,
) {
  final trimmed = displayName.trim();
  final normalized = trimmed.isEmpty
      ? ''
      : trimmed.split(RegExp(r'\s+')).first.toLowerCase();
  final status = switch (normalized) {
    final name when _neutralNames.contains(name) || name.isEmpty => 'Połączono',
    final name when _masculineNames.contains(name) => 'Połączony',
    final name when name.endsWith('a') => 'Połączona',
    _ => 'Połączono',
  };

  if (connectedAt == null) {
    return status;
  }

  final localDate = connectedAt.toLocal();
  final month = _polishGenitiveMonths[localDate.month - 1];
  return '$status od $month ${localDate.year}';
}
```

Do not add a package dependency or collection extension for name parsing.

- [ ] **Step 5: Run tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/mobile/lib/relationships/relationship_models.dart apps/mobile/lib/relationships/relationship_formatters.dart apps/mobile/test/relationship_api_client_test.dart apps/mobile/test/relationship_connection_formatter_test.dart
git commit -m "mobile: format trainee connection status"
```

### Task 4: Update the trainer trainee-detail UI

**Files:**
- Modify: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- Modify: `apps/mobile/test/trainer_trainee_detail_screen_test.dart`

- [ ] **Step 1: Write the failing widget regression test**

Add a focused test:

```dart
testWidgets('shows connection status and omits redundant relationship data', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TrainerTraineeDetailScreen(
        trainee: TrainerTraineeSummary(
          id: 'trainee-1',
          email: 'anna@example.test',
          displayName: 'Anna Nowak',
          connectedAt: DateTime(2026, 3, 8),
        ),
        assignedSets: const [],
        onBack: () {},
        onLogout: () async {},
        onOpenWorkoutSets: () {},
        onOpenHistory: () {},
      ),
    ),
  );

  expect(find.text('Połączona od marca 2026'), findsOneWidget);
  expect(find.text('Dane relacji'), findsNothing);
  expect(find.text('E-mail'), findsNothing);
  expect(find.text('Aktywna relacja'), findsNothing);
  expect(find.text('Przypisane zestawy'), findsOneWidget);
  expect(find.text('Historia'), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test --reporter compact test/trainer_trainee_detail_screen_test.dart
```

Expected: the new status is absent and `Dane relacji` is still present.

- [ ] **Step 3: Replace static status and remove the relationship card**

Replace the static `const Text('Połączona')` with:

```dart
Text(
  formatTraineeConnectionStatus(
    trainee.displayName,
    trainee.connectedAt,
  ),
  style: const TextStyle(color: lmMuted, fontSize: 13.5),
),
```

Delete the `RelationshipCard` containing `Dane relacji`, `E-mail`, and `Aktywna relacja`. Keep one `SizedBox(height: 20)` between the preceding guidance/actions area and `RelationshipSectionLabel('Przypisane zestawy')`.

Delete the now-unused private `_DetailRow` widget from the bottom of the file.

- [ ] **Step 4: Run the widget test and verify GREEN**

Run the command from Step 2. Expected: all trainee-detail widget tests pass.

- [ ] **Step 5: Run mobile regression tests**

```powershell
flutter test --reporter compact test/relationship_api_client_test.dart test/relationship_connection_formatter_test.dart test/trainer_trainee_detail_screen_test.dart test/weekly_streak_screen_test.dart test/workout_set_trainer_screens_test.dart
flutter analyze
```

Expected: all selected tests pass and analyzer reports `No issues found!`.

- [ ] **Step 6: Commit**

```powershell
git add apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart apps/mobile/test/trainer_trainee_detail_screen_test.dart
git commit -m "mobile: refine trainee relationship detail"
```

### Task 5: Full verification

**Files:**
- No source changes expected.

- [ ] **Step 1: Verify API build and complete test suite**

Run from `apps/api`:

```powershell
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

Expected: restore, build, and all API tests succeed with zero failures.

- [ ] **Step 2: Verify complete Flutter suite and analysis**

Run from `apps/mobile`:

```powershell
flutter test --reporter compact
flutter analyze
```

Expected: all Flutter tests pass and analyzer reports `No issues found!`.

- [ ] **Step 3: Verify scope and workspace hygiene**

Run from repository root:

```powershell
git diff --check
git status --short
git diff --name-only origin/codex/trainee-weekly-streak...HEAD
```

Confirm that no `.html` file is modified or staged and that all implementation commits are present.
