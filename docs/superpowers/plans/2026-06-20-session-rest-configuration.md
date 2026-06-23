# Configurable Session Rest Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać konfigurowalny czas odpoczynku zestawu, kopiować go do sesji oraz poprawić nagłówek i przypięty timer aktywnego treningu.

**Architecture:** `WorkoutSet.RestSeconds` jest źródłem konfiguracji, a `SharedSession.RestSeconds` jej niezmienną migawką utworzoną przy starcie sesji. Flutter przenosi konfigurację przez modele i kreator, natomiast `LiveSessionScreen` utrzymuje wyłącznie lokalny stan bieżącego odliczania i uruchamia go dopiero po potwierdzonym zapisie ukończenia serii.

**Tech Stack:** ASP.NET Core 10, Entity Framework Core 10, SQL Server, xUnit, Flutter/Dart, `flutter_test`.

---

## File map

- Modify `apps/api/LiftMate.Api/WorkoutSets/WorkoutSet.cs` — trwała konfiguracja odpoczynku zestawu.
- Modify `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs` — migawka konfiguracji w sesji.
- Modify `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs` — wartości wymagane i ograniczenia zakresu.
- Create generated `AddWorkoutSetRestSeconds` migration files under `apps/api/LiftMate.Api/Migrations/` — migracja obu tabel z domyślną wartością 90.
- Modify `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs` — `RestSeconds` w żądaniach i odpowiedziach.
- Modify `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetValidation.cs` — walidacja 15–600 sekund.
- Modify `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs` — zapis konfiguracji.
- Modify `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetMapping.cs` — mapowanie konfiguracji do odpowiedzi.
- Modify `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs` — `RestSeconds` w odpowiedzi sesji.
- Modify `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs` — kopiowanie konfiguracji przy starcie.
- Modify `apps/api/LiftMate.Api/SharedSessions/SharedSessionMapping.cs` — mapowanie migawki.
- Modify `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs` — zapis, odczyt i walidacja.
- Modify `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs` — migawka i niezależność od późniejszej edycji.
- Modify `apps/mobile/lib/workout_sets/workout_set_models.dart` — kontrakty mobilne z fallbackiem 90.
- Modify `apps/mobile/test/workout_set_models_test.dart` — parsowanie i serializacja.
- Modify `apps/mobile/test/workout_set_api_client_test.dart` — payload tworzenia i edycji.
- Modify `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart` — kontrolka `−15 s / +15 s`.
- Modify `apps/mobile/test/workout_set_trainer_screens_test.dart` — tworzenie i edycja czasu odpoczynku.
- Modify `apps/mobile/lib/shared_sessions/shared_session_models.dart` — `SharedSession.restSeconds`.
- Modify `apps/mobile/lib/shared_sessions/live_session_screen.dart` — imię, nazwa zestawu, przypięty pasek i automatyczny start.
- Modify `apps/mobile/lib/relationships/authenticated_relationship_shell.dart` — przekazanie nazwy podopiecznego.
- Modify `apps/mobile/test/live_session_screen_test.dart` — zachowanie timera i układ.
- Modify `apps/mobile/test/post_auth_relationship_screen_test.dart` — integracja nazwy podopiecznego.

### Task 1: Persist rest configuration in the API

**Files:**
- Modify: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSet.cs`
- Modify: `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- Modify: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- Modify: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs`
- Modify: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetValidation.cs`
- Modify: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`
- Modify: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetMapping.cs`
- Test: `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`

- [x] **Step 1: Write failing workout-set persistence and validation tests**

Rozszerz test tworzenia/edycji tak, aby wysyłał `RestSeconds = 120`, odczytał tę samą wartość, następnie edytował ją na 75:

```csharp
var createRequest = new
{
    name = "Push A",
    restSeconds = 120,
    rows = ValidRows(),
};

Assert.Equal(120, created.RestSeconds);

var updateRequest = new
{
    name = "Push B",
    restSeconds = 75,
    rows = ExistingRows(created),
};

Assert.Equal(75, updated.RestSeconds);
```

Dodaj teorię dla wartości spoza zakresu:

```csharp
[Theory]
[InlineData(14)]
[InlineData(601)]
public async Task CreateRejectsRestSecondsOutsideAllowedRange(int restSeconds)
{
    var response = await trainerClient.PostAsJsonAsync("/workout-sets", new
    {
        name = "Invalid rest",
        restSeconds,
        rows = ValidRows(),
    });

    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
}
```

Uzupełnij lokalne rekordy testowe `WorkoutSetDetailResponse` i `TraineeAssignedWorkoutSetResponse` o `int RestSeconds`.

- [x] **Step 2: Run workout-set tests and verify RED**

Run:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WorkoutSetEndpointTests" --verbosity minimal
```

Expected: FAIL, ponieważ kontrakty nie przyjmują i nie zwracają `RestSeconds`.

- [x] **Step 3: Add the API fields and validation**

Dodaj do obu encji:

```csharp
public int RestSeconds { get; set; } = 90;
```

Rozszerz żądania:

```csharp
public sealed record CreateWorkoutSetRequest(
    string Name,
    int? RestSeconds,
    IReadOnlyList<WorkoutSetRowRequest> Rows);

public sealed record UpdateWorkoutSetRequest(
    string Name,
    int? RestSeconds,
    IReadOnlyList<WorkoutSetRowRequest> Rows);
```

Dodaj `RestSeconds` po `Name` w odpowiedziach szczegółu i przypisanego zestawu. Podsumowanie listy nie wymaga tej wartości.

Dodaj walidację:

```csharp
public static string? ValidateRestSeconds(int? restSeconds)
{
    return restSeconds.HasValue && (restSeconds is < 15 or > 600)
        ? "Rest seconds must be between 15 and 600."
        : null;
}
```

W `Create` i `Update` sprawdź walidację przed zmianą encji. Brak pola z wcześniejszego klienta oznacza 90 sekund. Następnie ustaw:

```csharp
RestSeconds = request.RestSeconds ?? 90,
```

oraz:

```csharp
workoutSet.RestSeconds = request.RestSeconds ?? 90;
```

Rozszerz `WorkoutSetMapping.ToDetail` i `ToTraineeAssigned` o `workoutSet.RestSeconds`.

W konfiguracji EF dodaj dla obu encji:

```csharp
entity.Property(value => value.RestSeconds)
    .HasDefaultValue(90)
    .IsRequired();
```

oraz ograniczenia:

```csharp
table.HasCheckConstraint(
    "CK_WorkoutSets_RestSeconds",
    "[RestSeconds] BETWEEN 15 AND 600");
```

```csharp
table.HasCheckConstraint(
    "CK_SharedSessions_RestSeconds",
    "[RestSeconds] BETWEEN 15 AND 600");
```

- [x] **Step 4: Run workout-set tests and verify GREEN**

Run:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WorkoutSetEndpointTests" --verbosity minimal
```

Expected: PASS.

- [x] **Step 5: Commit API workout-set configuration**

```powershell
git add apps/api/LiftMate.Api/WorkoutSets apps/api/LiftMate.Api/SharedSessions/SharedSession.cs apps/api/LiftMate.Api/Data/ApplicationDbContext.cs apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs
git commit -m "api: add workout set rest configuration"
```

### Task 2: Snapshot rest configuration into shared sessions

**Files:**
- Modify: `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`
- Modify: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- Modify: `apps/api/LiftMate.Api/SharedSessions/SharedSessionMapping.cs`
- Test: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

- [x] **Step 1: Write a failing session snapshot test**

W teście startu sesji z zestawu utwórz zestaw z `restSeconds = 120`, rozpocznij sesję i sprawdź:

```csharp
Assert.Equal(120, started.RestSeconds);
```

Następnie zaktualizuj zestaw do 60 sekund i ponownie odczytaj rozpoczętą sesję:

```csharp
Assert.Equal(120, reloadedSession.RestSeconds);
```

W teście ręcznie tworzonej sesji sprawdź:

```csharp
Assert.Equal(90, created.RestSeconds);
```

Rozszerz testowy `SharedSessionResponse` o `int RestSeconds`.

- [x] **Step 2: Run shared-session tests and verify RED**

Run:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpointTests" --verbosity minimal
```

Expected: FAIL, ponieważ odpowiedź sesji nie zawiera migawki.

- [x] **Step 3: Copy and expose the snapshot**

Dodaj `int RestSeconds` do `SharedSessionResponse` po `WorkoutSetName`.

Przy ręcznym tworzeniu sesji ustaw:

```csharp
RestSeconds = 90,
```

Przy tworzeniu z zestawu ustaw:

```csharp
RestSeconds = workoutSet.RestSeconds,
```

W `SharedSessionMapping.ToResponse` przekaż `session.RestSeconds`.

- [x] **Step 4: Run shared-session tests and verify GREEN**

Run:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpointTests" --verbosity minimal
```

Expected: PASS.

- [x] **Step 5: Commit session snapshot**

```powershell
git add apps/api/LiftMate.Api/SharedSessions apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs
git commit -m "api: snapshot rest time in shared sessions"
```

### Task 3: Add and verify the database migration

**Files:**
- Create: generated migration `AddWorkoutSetRestSeconds` under `apps/api/LiftMate.Api/Migrations/`
- Modify: `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`

- [x] **Step 1: Generate the EF migration**

Run from `apps/api`:

```powershell
dotnet ef migrations add AddWorkoutSetRestSeconds --project LiftMate.Api/LiftMate.Api.csproj
```

Expected: migration adds non-null `RestSeconds` columns with default `90` to `WorkoutSets` and `SharedSessions`, plus both check constraints.

- [x] **Step 2: Inspect migration content**

Potwierdź, że `Up` zawiera odpowiedniki:

```csharp
migrationBuilder.AddColumn<int>(
    name: "RestSeconds",
    table: "WorkoutSets",
    type: "int",
    nullable: false,
    defaultValue: 90);
```

oraz analogiczną kolumnę dla `SharedSessions`. `Down` musi usunąć constraints przed kolumnami.

- [x] **Step 3: Verify the model builds**

Run:

```powershell
dotnet build LiftMate.slnx --no-restore
```

Expected: build succeeds with zero warnings and errors.

- [x] **Step 4: Commit migration**

```powershell
git add apps/api/LiftMate.Api/Migrations
git commit -m "api: migrate rest time configuration"
```

### Task 4: Carry rest configuration through Flutter workout-set models

**Files:**
- Modify: `apps/mobile/lib/workout_sets/workout_set_models.dart`
- Test: `apps/mobile/test/workout_set_models_test.dart`
- Test: `apps/mobile/test/workout_set_api_client_test.dart`

- [x] **Step 1: Write failing model and payload tests**

Dodaj oczekiwania:

```dart
expect(CreateWorkoutSetRequest(
  name: 'Push A',
  restSeconds: 120,
  rows: rows,
).toJson()['restSeconds'], 120);

expect(WorkoutSetDetail.fromJson({...detailJson, 'restSeconds': 75}).restSeconds, 75);
expect(WorkoutSetDetail.fromJson(detailJson).restSeconds, 90);
expect(TraineeAssignedWorkoutSet.fromJson({
  ...assignedJson,
  'restSeconds': 105,
}).restSeconds, 105);
```

W teście klienta sprawdź `restSeconds` w body `POST` i `PUT`.

- [x] **Step 2: Run focused tests and verify RED**

Run:

```powershell
flutter test --reporter compact test/workout_set_models_test.dart test/workout_set_api_client_test.dart
```

Expected: FAIL z powodu brakującego argumentu i pola.

- [x] **Step 3: Implement mobile workout-set contracts**

Rozszerz żądania:

```dart
const CreateWorkoutSetRequest({
  required this.name,
  required this.rows,
  this.restSeconds = 90,
});

final int restSeconds;
```

Dodaj do JSON:

```dart
'restSeconds': restSeconds,
```

`UpdateWorkoutSetRequest` powinien przekazywać `super.restSeconds = 90`, dzięki czemu istniejące wywołania zachowają zgodność do czasu jawnego podłączenia kontrolki.

Dodaj `restSeconds` do `WorkoutSetDetail` i `TraineeAssignedWorkoutSet`, parsując kompatybilnie:

```dart
final restSeconds = json['restSeconds'] ?? 90;
if (restSeconds is! int) {
  throw const FormatException('Invalid workout set response body.');
}
```

- [x] **Step 4: Run focused tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/workout_set_models_test.dart test/workout_set_api_client_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit Flutter contracts**

```powershell
git add apps/mobile/lib/workout_sets/workout_set_models.dart apps/mobile/test/workout_set_models_test.dart apps/mobile/test/workout_set_api_client_test.dart
git commit -m "mobile: support workout set rest configuration"
```

### Task 5: Add rest controls to the workout-set builder

**Files:**
- Modify: `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`
- Test: `apps/mobile/test/workout_set_trainer_screens_test.dart`

- [x] **Step 1: Write failing builder tests**

W teście tworzenia sprawdź wartość domyślną i zmianę:

```dart
expect(find.text('Czas odpoczynku'), findsOneWidget);
expect(find.text('01:30'), findsOneWidget);

await tester.tap(find.byKey(const ValueKey('builder-rest-increase')));
await tester.pump();
expect(find.text('01:45'), findsOneWidget);
```

Po zapisie sprawdź body z `restSeconds: 105`.

W teście edycji zwróć szczegół z `restSeconds: 120`, sprawdź `02:00`, zmniejsz do `01:45` i potwierdź payload `105`.

- [x] **Step 2: Run builder tests and verify RED**

Run:

```powershell
flutter test --reporter compact test/workout_set_trainer_screens_test.dart
```

Expected: FAIL, ponieważ kontrolka nie istnieje.

- [x] **Step 3: Implement the stepper**

Dodaj stan:

```dart
late int _restSeconds;
```

W `initState`:

```dart
_restSeconds = widget.initialDetail?.restSeconds ?? 90;
```

Pod nazwą zestawu renderuj `_RestSecondsField` z kluczami:

```dart
ValueKey('builder-rest-decrease')
ValueKey('builder-rest-increase')
```

Zmiany ogranicz:

```dart
setState(() {
  _restSeconds = (_restSeconds + delta).clamp(15, 600);
});
```

Formatter:

```dart
String formatRestSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
```

Przekaż `_restSeconds` do obu żądań zapisu.

- [x] **Step 4: Run builder tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/workout_set_trainer_screens_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit builder UI**

```powershell
git add apps/mobile/lib/workout_sets/workout_set_builder_screen.dart apps/mobile/test/workout_set_trainer_screens_test.dart
git commit -m "mobile: configure rest time in workout sets"
```

### Task 6: Parse session rest snapshots and correct the trainer header

**Files:**
- Modify: `apps/mobile/lib/shared_sessions/shared_session_models.dart`
- Modify: `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- Modify: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- Test: `apps/mobile/test/live_session_screen_test.dart`
- Test: `apps/mobile/test/post_auth_relationship_screen_test.dart`

- [x] **Step 1: Write failing model and header tests**

Rozszerz helper sesji o `restSeconds` i sprawdź fallback:

```dart
expect(SharedSession.fromJson({...sessionJson, 'restSeconds': 120}).restSeconds, 120);
expect(SharedSession.fromJson(sessionJson).restSeconds, 90);
```

W teście ekranu przekaż:

```dart
traineeDisplayName: 'Anna Nowak',
```

i sprawdź:

```dart
expect(find.text('Anna'), findsOneWidget);
expect(find.text('trainee@example.test'), findsNothing);
expect(find.text('Zestaw Push A'), findsOneWidget);
expect(find.textContaining('set-1'), findsNothing);
```

W teście powłoki trenera uruchom sesję z wybraną `Anna Nowak` i potwierdź, że ekran pokazuje `Anna`.

- [x] **Step 2: Run focused tests and verify RED**

Run:

```powershell
flutter test --reporter compact test/live_session_screen_test.dart test/post_auth_relationship_screen_test.dart
```

Expected: FAIL dla brakującego pola, argumentu i starego nagłówka.

- [x] **Step 3: Implement the session model and header**

Dodaj do `SharedSession`:

```dart
this.restSeconds = 90,
final int restSeconds;
```

Parsuj:

```dart
final restSeconds = json['restSeconds'] ?? 90;
```

i odrzuć wartość inną niż `int`.

Dodaj do `LiveSessionScreen`:

```dart
final String? traineeDisplayName;
```

Wyznacz tytuł:

```dart
String _traineeFirstName(SharedSession session, String? displayName) {
  final trimmed = displayName?.trim();
  if (trimmed == null || trimmed.isEmpty) return session.traineeEmail;
  return trimmed.split(RegExp(r'\s+')).first;
}
```

Podtytuł:

```dart
String _sessionSubtitle(SharedSession session) {
  final name = session.workoutSetName.trim();
  return name.isEmpty ? 'Trening' : 'Zestaw $name';
}
```

W trenerskiej gałęzi `AuthenticatedRelationshipShell` przekaż:

```dart
traineeDisplayName: selected?.displayName,
```

- [x] **Step 4: Run focused tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/live_session_screen_test.dart test/post_auth_relationship_screen_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit session data and header**

```powershell
git add apps/mobile/lib/shared_sessions/shared_session_models.dart apps/mobile/lib/shared_sessions/live_session_screen.dart apps/mobile/lib/relationships/authenticated_relationship_shell.dart apps/mobile/test/live_session_screen_test.dart apps/mobile/test/post_auth_relationship_screen_test.dart
git commit -m "mobile: show trainee and set names in live session"
```

### Task 7: Pin and automate the rest timer

**Files:**
- Modify: `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- Test: `apps/mobile/test/live_session_screen_test.dart`

- [x] **Step 1: Write failing pinned-layout and auto-start tests**

Dodaj test przy rozmiarze telefonu, który bez scrollowania znajduje:

```dart
expect(find.byKey(const ValueKey('live-rest-footer')), findsOneWidget);
expect(find.text('Zakończ i zapisz trening'), findsOneWidget);
```

Porównaj dolne krawędzie:

```dart
final footerBottom = tester.getBottomLeft(
  find.byKey(const ValueKey('live-rest-footer')),
).dy;
final finishBottom = tester.getBottomLeft(
  find.text('Zakończ i zapisz trening'),
).dy;
expect(footerBottom, lessThan(finishBottom));
```

Dodaj test ukończenia serii z `restSeconds: 120`:

```dart
await tester.tap(find.byTooltip('Oznacz serię').first);
await tester.pumpAndSettle();
expect(find.text('02:00'), findsOneWidget);

await tester.pump(const Duration(seconds: 1));
expect(find.text('01:59'), findsOneWidget);
```

Ukończ następną serię po kilku sekundach i sprawdź ponowne `02:00`. Dodaj osobne testy, że cofnięcie serii oraz wynik błędu API nie zmieniają lub nie uruchamiają timera.

- [x] **Step 2: Run live-session tests and verify RED**

Run:

```powershell
flutter test --reporter expanded test/live_session_screen_test.dart
```

Expected: FAIL, ponieważ timer jest w liście i kliknięcie serii nie steruje odpoczynkiem.

- [x] **Step 3: Replace the scrolling card with a compact footer**

Usuń `_RestTimerCard` z `ListView`. Pod `Expanded`, przed przyciskiem kończącym, dodaj:

```dart
_CompactRestFooter(
  key: const ValueKey('live-rest-footer'),
  remaining: _restRemaining,
  isRunning: _restTimer != null,
  onToggle: _restTimer == null ? _startRest : _pauseRest,
  onAdd: _addRest,
  onReset: _resetRest,
),
```

Footer ma zawierać etykietę, czas, jeden przycisk start/pauza, `+15 s` i reset. Zachowaj istniejącą dolną akcję zakończenia poniżej.

- [x] **Step 4: Make rest state session-specific**

Dodaj:

```dart
String? _restSessionId;
```

Przed renderowaniem aktywnej sesji synchronizuj:

```dart
void _syncRestConfiguration(SharedSession session) {
  if (_restSessionId == session.id) return;
  _restTimer?.cancel();
  _restTimer = null;
  _restSessionId = session.id;
  _restRemaining = session.restSeconds;
}
```

Reset ma używać bieżącej sesji:

```dart
void _resetRestTo(int seconds) {
  _restTimer?.cancel();
  _restTimer = null;
  setState(() => _restRemaining = seconds);
}
```

Automatyczny restart:

```dart
void _restartRest(int seconds) {
  _restTimer?.cancel();
  setState(() => _restRemaining = seconds);
  _startRest();
}
```

- [x] **Step 5: Start only after confirmed completion**

Zmień callback karty na:

```dart
final Future<void> Function(SharedSessionValue value, bool isDone)
    onToggleDone;
```

W stanie ekranu:

```dart
Future<void> _toggleDone(
  SharedSession session,
  SharedSessionValue value,
  bool isDone,
) async {
  final result = await widget.controller.toggleDone(
    user: widget.user,
    value: value,
    isDone: isDone,
  );
  if (!mounted || !result.isSuccess || !isDone) return;
  _restartRest(session.restSeconds);
}
```

Karta wywołuje `onToggleDone(value, !value.isDone)`. Nie uruchamiaj timera przed zakończeniem `await`.

- [x] **Step 6: Run live-session tests and verify GREEN**

Run:

```powershell
flutter test --reporter expanded test/live_session_screen_test.dart
```

Expected: PASS.

- [x] **Step 7: Commit pinned automatic timer**

```powershell
git add apps/mobile/lib/shared_sessions/live_session_screen.dart apps/mobile/test/live_session_screen_test.dart
git commit -m "mobile: pin and automate session rest timer"
```

### Task 8: Full verification

**Files:**
- Verify all files changed in Tasks 1–7.

- [x] **Step 1: Run API gates**

Run:

```powershell
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

Expected: restore succeeds, build has zero warnings/errors, all API tests pass.

- [x] **Step 2: Run Flutter gates**

Run:

```powershell
flutter test --reporter compact
flutter analyze
```

Expected: all Flutter tests pass and analyzer reports no issues.

- [x] **Step 3: Check migration and scope**

Run:

```powershell
dotnet ef migrations list --project LiftMate.Api/LiftMate.Api.csproj
git diff --check
git status --short
```

Expected: `AddWorkoutSetRestSeconds` is the latest migration, no whitespace errors, and unrelated pre-existing user files remain unstaged.

- [x] **Step 4: Commit narrow verification adjustments if required**

Jeżeli pełny przebieg wymaga wyłącznie aktualizacji fixture’ów o nowe pole, ogranicz zmiany do używanych fixture’ów w poniższych plikach:

- `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs`
- `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`
- `apps/mobile/test/workout_set_models_test.dart`
- `apps/mobile/test/workout_set_api_client_test.dart`
- `apps/mobile/test/workout_set_trainer_screens_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

Zapisz wyłącznie faktycznie zmienione pliki:

```powershell
git add apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs apps/mobile/test/workout_set_models_test.dart apps/mobile/test/workout_set_api_client_test.dart apps/mobile/test/workout_set_trainer_screens_test.dart apps/mobile/test/live_session_screen_test.dart apps/mobile/test/post_auth_relationship_screen_test.dart
git commit -m "test: finalize rest timer regressions"
```
