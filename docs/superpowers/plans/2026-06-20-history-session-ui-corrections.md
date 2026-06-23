# History Session UI Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skorygować prezentację czasu aktywnej sesji, polską odmianę ukończonych serii, copy historii oraz powrót trenera ze strony historii podopiecznego.

**Architecture:** API historii pozostaje bez zmian, ponieważ czas jest już wyliczany z `ClosedAt - CreatedAt`. Flutter dostanie mały współdzielony formatter czasu i odmiany, stanowy timer oparty o serwerowe `SharedSession.createdAt` oraz opcjonalny nagłówek poziomu 1 historii, używany tylko dla wejścia trenera.

**Tech Stack:** Flutter/Dart, `flutter_test`, ASP.NET Core/.NET 10, xUnit.

---

## File map

- Modify `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs` — utrwalić kontrakt czasu `ClosedAt - CreatedAt`, również dla sesji krótszej niż minuta.
- Modify `apps/mobile/lib/shared_sessions/live_session_screen.dart` — timer wieku sesji i poprawna odmiana ukończonych serii.
- Modify `apps/mobile/test/live_session_screen_test.dart` — test timera i odmiany.
- Modify `apps/mobile/lib/training_history/training_history_flow.dart` — copy `postęp` i opcjonalny przycisk powrotu poziomu 1.
- Modify `apps/mobile/test/training_history_flow_test.dart` — test copy i zachowania przycisku powrotu.
- Modify `apps/mobile/lib/relationships/authenticated_relationship_shell.dart` — zachować wybranego podopiecznego przy otwieraniu i zamykaniu historii trenera.
- Modify `apps/mobile/test/post_auth_relationship_screen_test.dart` — test powrotu do szczegółów tego samego podopiecznego.

### Task 1: Lock the history duration contract

**Files:**
- Modify: `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

- [x] **Step 1: Add a sub-minute completed session assertion**

W istniejącym teście listy historii utwórz dodatkową ukończoną sesję:

```csharp
var shortSession = await SeedSession(
    dbContext,
    trainer.User.Id,
    trainee.User.Id,
    workoutSetId,
    exerciseId,
    completedAt: DateTimeOffset.UtcNow,
    duration: TimeSpan.FromSeconds(42));
```

Po pobraniu szczegółów potwierdź:

```csharp
Assert.Equal(42, shortDetail.DurationSeconds);
Assert.Equal(shortDetail.CompletedAt - shortDetail.StartedAt, TimeSpan.FromSeconds(42));
```

Jeżeli helper `SeedSession` przyjmuje obecnie wyłącznie stałe dziesięć minut, dodaj parametr `TimeSpan? duration = null` i ustaw:

```csharp
var createdAt = completedAt.HasValue
    ? completedAt.Value - (duration ?? TimeSpan.FromMinutes(10))
    : DateTimeOffset.UtcNow;
```

- [x] **Step 2: Run the targeted API history test**

Run:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory" --verbosity minimal
```

Expected: PASS. Ten test dokumentuje istniejące, poprawne zachowanie; nie wymaga zmiany kodu produkcyjnego.

- [x] **Step 3: Commit the contract test**

```powershell
git add apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs
git commit -m "test(history): lock session duration calculation"
```

### Task 2: Replace the trainer live badge with elapsed session time

**Files:**
- Modify: `apps/mobile/test/live_session_screen_test.dart`
- Modify: `apps/mobile/lib/shared_sessions/live_session_screen.dart`

- [x] **Step 1: Write failing timer and Polish series-label tests**

Dodaj test widgetowy z sesją rozpoczętą 65 sekund przed kontrolowanym `now`:

```dart
testWidgets('trainer header shows elapsed time from server session start', (
  tester,
) async {
  final now = DateTime.utc(2026, 6, 20, 12);
  final controller = _controllerWithSession(
    _session(createdAt: now.subtract(const Duration(seconds: 65))),
  );

  await tester.pumpWidget(
    _app(
      LiveSessionScreen(
        user: _trainer,
        controller: controller,
        editable: true,
        onBack: () {},
        now: () => now,
      ),
    ),
  );

  expect(find.text('01:05'), findsOneWidget);
  expect(find.text('żywo'), findsNothing);
});
```

Dodaj test jednostkowy lub widgetowy dla:

```dart
expect(completedSeriesLabel(1), '1 ukończona seria');
expect(completedSeriesLabel(2), '2 ukończone serie');
expect(completedSeriesLabel(5), '5 ukończonych serii');
expect(completedSeriesLabel(12), '12 ukończonych serii');
expect(completedSeriesLabel(22), '22 ukończone serie');
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test --reporter compact test/live_session_screen_test.dart
```

Expected: FAIL, ponieważ `LiveSessionScreen` nie przyjmuje `now`, a nagłówek nadal renderuje `żywo`.

- [x] **Step 3: Implement the elapsed timer**

Dodaj do `LiveSessionScreen` opcjonalny zegar:

```dart
final DateTime Function() now;

const LiveSessionScreen({
  // existing arguments
  DateTime Function()? now,
}) : now = now ?? DateTime.now;
```

W stanie dodaj:

```dart
Timer? _sessionTimer;
DateTime? _sessionStartedAt;
int _elapsedSeconds = 0;
```

Synchronizuj timer po otrzymaniu sesji:

```dart
void _syncSessionTimer(SharedSession session) {
  if (_sessionStartedAt == session.createdAt && _sessionTimer != null) return;
  _sessionTimer?.cancel();
  _sessionStartedAt = session.createdAt;
  _updateElapsed(session.createdAt);
  _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() => _updateElapsed(session.createdAt));
  });
}

void _updateElapsed(DateTime startedAt) {
  _elapsedSeconds = math.max(
    0,
    widget.now().toUtc().difference(startedAt.toUtc()).inSeconds,
  );
}
```

Wywołaj `_syncSessionTimer(session)` bezpiecznie po zbudowaniu stanu sesji, anuluj `_sessionTimer` w `dispose`, a `_LiveTopBar` przekaż:

```dart
trailing: Text(formatElapsedSessionTime(_elapsedSeconds))
```

Formatter:

```dart
String formatElapsedSessionTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
```

- [x] **Step 4: Implement Polish completed-series copy**

Dodaj:

```dart
String completedSeriesLabel(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  if (count == 1) return '1 ukończona seria';
  if (lastTwo < 12 || lastTwo > 14) {
    if (last >= 2 && last <= 4) return '$count ukończone serie';
  }
  return '$count ukończonych serii';
}
```

Zastąp:

```dart
'Ukończone serie: $completed'
```

przez:

```dart
completedSeriesLabel(completed)
```

- [x] **Step 5: Run focused tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/live_session_screen_test.dart
```

Expected: PASS.

- [x] **Step 6: Commit timer and grammar**

```powershell
git add apps/mobile/lib/shared_sessions/live_session_screen.dart apps/mobile/test/live_session_screen_test.dart
git commit -m "fix(live-session): show elapsed time and Polish series copy"
```

### Task 3: Change history copy and add an optional Level 1 back action

**Files:**
- Modify: `apps/mobile/test/training_history_flow_test.dart`
- Modify: `apps/mobile/lib/training_history/training_history_flow.dart`

- [x] **Step 1: Write failing copy and back-button tests**

W istniejącym teście przejścia przez historię zmień oczekiwanie:

```dart
expect(find.text('postęp ›'), findsOneWidget);
expect(find.text('progres ›'), findsNothing);
```

Po otwarciu poziomu 3:

```dart
expect(find.text('Postęp ćwiczenia'), findsOneWidget);
expect(find.textContaining('Progres'), findsNothing);
```

Dodaj test pierwszego poziomu z opcjonalnym powrotem:

```dart
testWidgets('trainer history level one exposes close action', (tester) async {
  var closed = false;
  await tester.pumpWidget(
    _app(
      controller,
      showLevelOneBack: true,
      onClose: () => closed = true,
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byTooltip('Wróć'), findsOneWidget);
  await tester.tap(find.byTooltip('Wróć'));
  expect(closed, isTrue);
});
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test --reporter compact test/training_history_flow_test.dart
```

Expected: FAIL dla starego copy i braku przycisku poziomu 1.

- [x] **Step 3: Implement copy and optional Level 1 header**

Rozszerz `TrainingHistoryFlow`:

```dart
const TrainingHistoryFlow({
  required this.controller,
  required this.onClose,
  this.showLevelOneBack = false,
  super.key,
});

final bool showLevelOneBack;
```

Przekaż flagę do `_ListLevel`. Nad listą, tylko gdy flaga jest ustawiona, renderuj:

```dart
_HistoryHeader(
  title: 'Historia treningów',
  onBack: onClose,
)
```

W wariancie bez przycisku zachowaj obecny tytuł wewnątrz listy, aby ekran podopiecznego się nie zmienił.

Zastąp teksty:

```dart
'progres ›' -> 'postęp ›'
'Progres ćwiczenia' -> 'Postęp ćwiczenia'
```

- [x] **Step 4: Run focused tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/training_history_flow_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit history UI corrections**

```powershell
git add apps/mobile/lib/training_history/training_history_flow.dart apps/mobile/test/training_history_flow_test.dart
git commit -m "fix(history): use Polish progress copy and level-one back"
```

### Task 4: Return trainer history to the selected trainee detail

**Files:**
- Modify: `apps/mobile/test/post_auth_relationship_screen_test.dart`
- Modify: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

- [x] **Step 1: Extend the trainer navigation test**

Po otwarciu historii:

```dart
expect(find.byTooltip('Wróć'), findsOneWidget);
await tester.tap(find.byTooltip('Wróć'));
await tester.pumpAndSettle();

expect(find.text('Podopieczny'), findsOneWidget);
expect(find.text('Anna Nowak'), findsWidgets);
expect(find.text('Aktywna relacja'), findsOneWidget);
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test --reporter compact test/post_auth_relationship_screen_test.dart \
  --plain-name "Post-auth relationship screens trainer history targets the selected linked trainee"
```

Expected: FAIL, ponieważ obecne zamknięcie historii czyści kontekst i prowadzi do pulpitu.

- [x] **Step 3: Preserve the selected trainee while history is open**

W `AuthenticatedRelationshipShell` przekaż:

```dart
showLevelOneBack: true,
```

Zmodyfikuj `onClose`, aby:

```dart
onClose: () {
  _trainerHistoryController?.dispose();
  _trainerHistoryController = null;
  setState(() => _trainerView = _TrainerView.dashboard);
},
```

nie czyścił `_selectedTrainee`. Warunek `selected != null` ponownie wyrenderuje `TrainerTraineeDetailScreen` dla tego samego podopiecznego.

- [x] **Step 4: Run focused tests and verify GREEN**

Run:

```powershell
flutter test --reporter compact test/post_auth_relationship_screen_test.dart \
  --plain-name "Post-auth relationship screens trainer history targets the selected linked trainee"
```

Expected: PASS.

- [x] **Step 5: Commit trainer return navigation**

```powershell
git add apps/mobile/lib/relationships/authenticated_relationship_shell.dart apps/mobile/test/post_auth_relationship_screen_test.dart
git commit -m "fix(history): return trainer to trainee detail"
```

### Task 5: Full verification

**Files:**
- Verify all files modified in Tasks 1–4.

- [x] **Step 1: Run API verification**

```powershell
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

Expected: build succeeds with zero warnings and all API tests pass.

- [x] **Step 2: Run Flutter verification**

```powershell
flutter test --reporter compact
flutter analyze
```

Expected: all Flutter tests pass and analyzer reports no issues.

- [x] **Step 3: Check repository scope**

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; unrelated existing changes remain unstaged and untouched.

- [x] **Step 4: Commit any verification-only test adjustments**

Only if a test required a narrow assertion adjustment:

```powershell
git add <exact test files>
git commit -m "test(history): finalize session UI regressions"
```
