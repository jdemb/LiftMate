# Podpowiedzi trenera z historii — Implementation Plan

> **Dla implementacji agentowej:** realizuj fazy osobno, test-first, z oddzielnym commitem dla każdej fazy. Użyj `superpowers:test-driven-development` przy zmianach produkcyjnych i `superpowers:verification-before-completion` przed deklaracją ukończenia. Docelowym artefaktem kontraktu UI jest `apps/mobile/design/LiftMate.html`, ale obecnym edytowalnym źródłem designu w repo jest `apps/mobile/design/LiftMate.dc.html`; faza 1 musi doprowadzić oba pliki do zgodności.

## Overview

S-10 dodaje neutralne, informacyjne podpowiedzi dla trenera na podstawie historii podopiecznego. System wykrywa dwa sygnały:

- stagnację ciężaru dla tego samego ćwiczenia typu `repsWeight`;
- obniżone samopoczucie na podstawie średniej oceny feedbacku z 3 ostatnich zakończonych sesji z feedbackiem.

Podpowiedzi są materializowane po zakończeniu sesji oraz po zapisie feedbacku, deduplikowane po oknie dowodowym i widoczne dla aktualnego trenera podopiecznego. Trener może oznaczyć podpowiedź jako przeczytaną. Zmiana nie interpretuje komentarzy, nie zmienia automatycznie planów treningowych i nie modyfikuje wartości treningu.

## Current State Analysis

- Zakończone sesje są trwałym źródłem historii i progresu (`apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`).
- Wartości ćwiczeń są zapisane w snapshotach sesji (`apps/api/LiftMate.Api/SharedSessions/SharedSessionValue.cs`).
- Historia filtruje zakończone sesje i używa `ClosedAt` jako osi czasu (`apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`).
- Progres ćwiczenia opiera się na `ExerciseId`, a typ `repsWeight` ma już logikę wyliczania maksymalnego ciężaru w sesji.
- Feedback S-09 jest powiązany 1:1 z sesją przez `PostWorkoutFeedback`, ale S-10 nie może zakładać, że każda zakończona sesja ma feedback.
- Dostęp trenera do historii jest oparty o aktualną relację trener–podopieczny (`TrainingHistoryAccess`), więc S-10 powinno używać tego samego modelu dostępu.
- W mobile trener przechodzi do detalu podopiecznego z dashboardu i tam ma właściwy kontekst do pokazania podpowiedzi.
- Istnieją dwa pliki designu: `apps/mobile/design/LiftMate.html` i `apps/mobile/design/LiftMate.dc.html`. Aktualny stan repo wskazuje, że `.dc.html` jest source-like plikiem edytowalnym, a `LiftMate.html` wygląda jak zbundlowany artefakt docelowy. Feedback S-09 jest obecnie widoczny w `.dc.html`, więc implementacja musi ustalić workflow synchronizacji/generowania i doprowadzić `LiftMate.html` do zgodności.

## Desired End State

- Po zamknięciu sesji API ocenia, czy powstały nowe sygnały stagnacji ciężaru.
- Po zapisie feedbacku API ocenia, czy powstał nowy sygnał obniżonego samopoczucia.
- Dla tego samego sygnału i tego samego okna dowodowego nie powstają duplikaty.
- Odczytana podpowiedź nie wraca dla tego samego fingerprintu.
- Nowe okno dowodowe może utworzyć kolejną podpowiedź.
- Podpowiedzi są globalne dla podopiecznego, nie per trener: jeśli podpowiedź oznaczono jako przeczytaną, nie pojawia się ponownie dla kolejnego trenera przy tym samym fingerprintcie.
- Aktualny trener widzi na detalu podopiecznego maksymalnie 3 aktywne podpowiedzi.
- Karta pokazuje neutralny tekst i konkretne dowody: ćwiczenie oraz 3 ciężary albo średnią ocenę samopoczucia.
- Akcja `Oznacz jako przeczytaną` usuwa kartę z listy po sukcesie.

## Key Decisions

| Area | Decision | Rationale |
|---|---|---|
| Materializacja | Po zakończeniu sesji i po zapisie feedbacku | Brak skutków ubocznych na zwykłym odczycie i świeże sygnały po zdarzeniach domenowych. |
| Stagnacja a `IsDone` | Liczyć wszystkie zapisane wartości | Spójne z obecną historią/progresem; nie wprowadza drugiej semantyki wartości historycznych. |
| Wellbeing | 3 ostatnie zakończone sesje z feedbackiem | Nie karze braków feedbacku i zachowuje sens progu średniej. |
| Limit UI | Maksymalnie 3 aktywne karty | Chroni detal podopiecznego przed zalaniem podpowiedziami. |
| Read state | Globalny dla podopiecznego/sygnału | Prostszy model produktu; przeczytany sygnał nie wraca przy zmianie trenera. |
| Dowody | Pokazywać konkretne wartości | Trener rozumie, skąd pochodzi podpowiedź. |
| Ton | Neutralny, informacyjny | Zgodne z PRD: podpowiedź nie jest alarmem ani automatyczną rekomendacją zmiany planu. |
| Wiele stagnacji | Osobna podpowiedź per ćwiczenie | Czytelne oznaczanie jako przeczytane i dowody per `ExerciseId`. |
| Tożsamość ćwiczenia | Wyłącznie stabilny, niepusty `ExerciseId` | Nie łączy przypadkowo podobnych nazw ani legacy/ad-hoc ćwiczeń bez ID. |
| Design contract | Edytować source-like `LiftMate.dc.html`, zsynchronizować docelowy `LiftMate.html` | Spełnia wymóg, że finalny kontrakt ma być w `LiftMate.html`, bez ręcznej edycji wygenerowanego artefaktu bez workflow. |

## What We're NOT Doing

- Nie interpretujemy komentarzy feedbacku.
- Nie zmieniamy automatycznie workout setów, ciężarów, powtórzeń ani wartości sesji.
- Nie dodajemy AI, modeli predykcyjnych ani scoringu poza opisanymi regułami.
- Nie pokazujemy podpowiedzi podopiecznemu.
- Nie łączymy ćwiczeń po nazwie, kolejności ani podobieństwie.
- Nie tworzymy osobnego systemu historii; używamy istniejących zakończonych `SharedSession`.
- Nie dodajemy powiadomień push/e-mail.
- Nie edytujemy `context/archive/`.

## Implementation Approach

Implementacja idzie od kontraktu UI do domeny i prezentacji:

1. poprawić design workflow: edytować source-like `LiftMate.dc.html`, zsynchronizować docelowy `LiftMate.html` i sprawdzić brakujące elementy feedbacku z S-09;
2. dodać model danych, migrację i serwis ewaluujący sygnały po zdarzeniach domenowych;
3. dodać endpointy list/read z aktualną kontrolą relacji trener–podopieczny;
4. dodać mobile models/client/controller i sekcję UI na detalu podopiecznego;
5. zweryfikować reguły domenowe, autoryzację, migrację i brak regresji historii/feedbacku.

Każda faza kończy się osobnym commitem. Manualne checkboxy pozostają puste do jawnego potwierdzenia użytkownika.

## Critical Implementation Details

### Fingerprint i deduplikacja

Każda podpowiedź musi mieć stabilny fingerprint okna dowodowego:

- stagnacja: `traineeUserId`, `type=weight_stagnation`, `exerciseId`, trzy `sharedSessionId` użyte do porównania oraz wartości maksymalnego ciężaru;
- wellbeing: `traineeUserId`, `type=low_wellbeing`, trzy `sharedSessionId` z feedbackiem oraz średnia ocena.

Baza powinna wymuszać unikalność fingerprintu. Przy równoległej materializacji należy obsłużyć konflikt unikalności i nie tworzyć duplikatów. Odczytana podpowiedź dla tego samego fingerprintu nie może wrócić po kolejnym uruchomieniu ewaluacji.

### Źródło danych dla ewaluatora

Nie używać `WorkoutProgress` ani `WorkoutProgressProjector` jako źródła S-10. Ewaluator czyta zakończone `SharedSession` i `SharedSessionValue` tak jak endpoint historii/progresu ćwiczenia: po `Status == completed`, `ClosedAt != null`, stabilnym `ExerciseId` i wartościach snapshotu sesji. `WorkoutProgressProjector` działa per workout set i ma inną semantykę niż analiza historii jednego ćwiczenia po `ExerciseId`.

### Transakcje i replay materializacji

Ewaluacja stagnacji działa w transakcji `Complete` po ustawieniu `Status = completed` i `ClosedAt`, po projekcji progresu, ale przed commitem transakcji. Ponowne zakończenie już zakończonej sesji nie może tworzyć nowych podpowiedzi dla tego samego fingerprintu.

Ewaluacja wellbeing działa tylko po faktycznym utworzeniu nowego `PostWorkoutFeedback`. Idempotentny replay istniejącego feedbacku oraz ścieżka konfliktu równoległego zapisu nie powinny ponownie uruchamiać materializacji poza bezpieczną idempotencją fingerprintu.

Evaluator powinien być zarejestrowany w DI jawnie, analogicznie do istniejących usług domenowych, i wpięty w endpointy po stronie API bez ukrytych skutków ubocznych na `GET`.

### Reguła stagnacji

Stagnacja jest liczona dla każdego stabilnego, niepustego `ExerciseId`, tylko dla ćwiczeń typu `repsWeight`. Algorytm:

1. wybierz zakończone sesje podopiecznego zawierające dane ćwiczenie;
2. sortuj malejąco po `ClosedAt`, z deterministycznym tie-breakerem po `SharedSession.Id`;
3. weź 3 najnowsze sesje zawierające to ćwiczenie;
4. dla każdej sesji policz najwyższy zapisany ciężar;
5. utwórz sygnał, gdy najnowszy wynik nie jest wyższy niż najstarszy z trzech.

Przykłady:

- `[40, 45, 40]` tworzy podpowiedź;
- `[40, 35, 40]` tworzy podpowiedź;
- `[40, 35, 42.5]` nie tworzy podpowiedzi.

Sesje aktywne/anulowane są ignorowane. Ćwiczenia bez `ExerciseId` są ignorowane. Zmiana nazwy lub kolejności nie przerywa serii, jeśli `ExerciseId` pozostaje ten sam; zmiana typu ćwiczenia zaczyna nową serię.

### Reguła wellbeing

Wellbeing używa 3 ostatnich zakończonych sesji podopiecznego, które mają zapisany feedback. Sesje bez feedbacku są pomijane. Sygnał powstaje przy średniej `<= 3.0`, włącznie z dokładnym `3.0`. Komentarze tekstowe są ignorowane.

### Globalny read state

Podpowiedź jest globalna dla podopiecznego i fingerprintu. Endpoint `read` oznacza konkretną podpowiedź jako przeczytaną niezależnie od trenera, ale dostęp do tej operacji ma tylko aktualny trener podopiecznego. Były trener traci dostęp przez standardową kontrolę relacji.

### UI copy

Copy ma być neutralne:

- `Podpowiedzi`
- `Na podstawie 3 ostatnich treningów.`
- `Warto sprawdzić ciężar w ćwiczeniu ...`
- `Średnia ocena samopoczucia z ostatnich treningów wynosi ...`
- `Oznacz jako przeczytaną`

Nie używać tonu alarmowego ani sformułowań sugerujących automatyczną zmianę planu.

---

## Phase 1: Design Contract and S-09 Design Reconciliation

### Overview

Ustalić właściwy workflow kontraktu UI: edytować source-like `LiftMate.dc.html`, zsynchronizować docelowy `LiftMate.html`, najpierw przenieść lub uzupełnić brakujące elementy feedbacku z S-09 w artefakcie docelowym, potem dopisać sekcję podpowiedzi S-10 na detalu podopiecznego.

### Changes Required

#### 1. Reconcile feedback design from S-09

**Files**:

- `apps/mobile/design/LiftMate.dc.html`
- `apps/mobile/design/LiftMate.html`

**Intent**: Upewnić się, że source-like plik i docelowy artefakt zawierają ostatnie zmiany dotyczące feedbacku po treningu.

**Contract**:

- Porównać `LiftMate.html` z `LiftMate.dc.html` w obszarach feedbacku S-09.
- Traktować `LiftMate.dc.html` jako aktualny source-like plik edytowalny, chyba że implementer znajdzie w repo jawny skrypt/workflow wskazujący inaczej.
- Jeśli w `LiftMate.html` brakuje formularza feedbacku, sekcji historii albo copy z S-09, zsynchronizować go z `.dc.html`.
- Nie zostawić sytuacji, w której feedback S-09 albo podpowiedzi S-10 istnieją tylko w jednym z dwóch plików.

#### 2. Add trainer guidance cards to trainee detail

**Files**:

- `apps/mobile/design/LiftMate.dc.html`
- `apps/mobile/design/LiftMate.html`

**Intent**: Zakontraktować miejsce, copy i stany sekcji `Podpowiedzi`.

**Contract**:

- Na detalu podopiecznego dodać sekcję `Podpowiedzi` pod nagłówkiem osoby i aktywnym CTA sesji, przed przyciskami `Historia` / `Zmień zestaw`.
- Pokazać maksymalnie 3 karty.
- Karta stagnacji zawiera ćwiczenie, trzy wartości ciężaru i tekst `Na podstawie 3 ostatnich treningów`.
- Karta wellbeing zawiera średnią ocenę oraz trzy oceny źródłowe.
- Każda karta ma akcję `Oznacz jako przeczytaną`.
- Zakontraktować loading, empty i error state.
- Empty state ma być dyskretny albo niewidoczny, żeby nie zwiększać szumu na detalu.

### Success Criteria

#### Automated Verification

- `rg -n "Feedback podopiecznego|Jak się czujesz po treningu|Podpowiedzi|Oznacz jako przeczytaną|Na podstawie 3 ostatnich treningów" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html`
- `rg -n "Bundled Page|<x-dc|support.js" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html` został użyty do potwierdzenia workflow źródło/artefakt albo jego ręcznego opisania w notatce fazy.

#### Manual Verification

- Detal podopiecznego zachowuje czytelną hierarchię na telefonowym viewportcie.
- Karty podpowiedzi nie wypychają kluczowych akcji poza sensowny pierwszy ekran przy 1–3 kartach.
- Feedback S-09 jest obecny w `LiftMate.html` i `LiftMate.dc.html`.

---

## Phase 2: API Data Model and Guidance Evaluation

### Overview

Dodać trwałą encję podpowiedzi, migrację i serwis materializacji wywoływany po zakończeniu sesji oraz po zapisie feedbacku.

### Changes Required

#### 1. Add TrainerGuidance entity and EF configuration

**Files**:

- `apps/api/LiftMate.Api/TrainerGuidance/TrainerGuidance.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- EF migration and model snapshot

**Contract**:

- Encja przechowuje:
  - `Id`
  - `TraineeUserId`
  - `Type`
  - nullable `ExerciseId`
  - `Fingerprint`
  - dowody jako JSON/string value object lub jawne kolumny wspierające DTO
  - `CreatedAt`
  - nullable `ReadAt`
- Unikalny indeks na `TraineeUserId + Type + ExerciseId + Fingerprint`.
- Indeksy pod listowanie aktywnych podpowiedzi dla podopiecznego.

#### 2. Implement evaluator

**Files**:

- `apps/api/LiftMate.Api/TrainerGuidance/TrainerGuidanceEvaluator.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api/SharedSessions/PostWorkoutFeedbackEndpoints.cs`
- `apps/api/LiftMate.Api/Program.cs`

**Contract**:

- Po zakończeniu sesji wywołać ewaluację stagnacji dla podopiecznego.
- Po zapisie feedbacku wywołać ewaluację wellbeing dla podopiecznego.
- Ewaluacja stagnacji działa w transakcji `Complete`, po ustawieniu `Completed/ClosedAt`, przed commitem.
- Ewaluacja wellbeing działa tylko po faktycznym utworzeniu nowego feedbacku, nie przy replayu istniejącego wpisu.
- `Program.cs` rejestruje evaluator w DI i mapuje późniejsze endpointy guidance.
- Ewaluator jest idempotentny i bezpieczny przy retry/równoległości.
- Nie tworzy podpowiedzi, jeśli istnieje rekord dla tego samego fingerprintu, także przeczytany.
- Nie tworzy więcej niż jednej aktywnej podpowiedzi dla tego samego sygnału/fingerprintu.

#### 3. Add API tests for evaluator

**Files**:

- `apps/api/LiftMate.Api.Tests/TrainerGuidance/TrainerGuidanceEvaluatorTests.cs`
- or existing endpoint test project structure if naming differs

**Coverage**:

- mniej niż 3 sesje nie tworzą stagnacji;
- tylko `repsWeight` jest analizowane;
- `ExerciseId == null` jest ignorowane;
- rename/reorder przy tym samym `ExerciseId` zachowuje serię;
- te same nazwy z różnym `ExerciseId` nie są łączone;
- `[40,45,40]` i `[40,35,40]` tworzą podpowiedź;
- `[40,35,42.5]` nie tworzy podpowiedzi;
- sesje bez feedbacku są pomijane w wellbeing;
- średnia `3.0` tworzy podpowiedź;
- komentarz feedbacku nie wpływa na wynik;
- ponowna ewaluacja tego samego okna nie tworzy duplikatu.
- ponowny `complete` zakończonej sesji nie tworzy nowej podpowiedzi;
- idempotentny replay feedbacku nie tworzy nowej podpowiedzi wellbeing.

### Success Criteria

#### Automated Verification

Run from `apps/api`:

```powershell
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"
```

#### Manual Verification

- Migracja jest addytywna i nie dotyka istniejących tabel historii poza relacjami/indeksami wymaganymi do odczytu.
- Ewaluator nie wymaga ręcznego backfillu starych danych w MVP.

---

## Phase 3: API Endpoints and Access Control

### Overview

Dodać endpoint listowania aktywnych podpowiedzi i endpoint oznaczania jako przeczytane.

### Changes Required

#### 1. Add contracts and endpoints

**Files**:

- `apps/api/LiftMate.Api/TrainerGuidance/TrainerGuidanceContracts.cs`
- `apps/api/LiftMate.Api/TrainerGuidance/TrainerGuidanceEndpoints.cs`
- `apps/api/LiftMate.Api/Program.cs`

**Contract**:

- `GET /trainer-guidance?traineeUserId=...`
  - tylko trainer;
  - wymaga aktualnej relacji z podopiecznym;
  - zwraca aktywne nieprzeczytane podpowiedzi, posortowane najnowsze najpierw;
  - limit wyników może być większy niż UI, ale mobile pokazuje maksymalnie 3.
- `POST /trainer-guidance/{id}/read`
  - tylko trainer;
  - wymaga aktualnej relacji z podopiecznym powiązanym z podpowiedzią;
  - idempotentne: ponowne oznaczenie zwraca sukces;
  - ustawia `ReadAt`.

#### 2. DTO evidence shape

**Response fields**:

- `id`
- `type`
- `traineeUserId`
- `exerciseId`
- `exerciseName`
- `message`
- `evidence`
  - stagnation: 3 session values with `sessionId`, `closedAt`, `maxWeight`
  - wellbeing: 3 feedback values with `sessionId`, `closedAt`, `rating`
  - average rating for wellbeing
- `createdAt`

#### 3. Endpoint tests

**Coverage**:

- aktualny trener może listować i oznaczać jako przeczytane;
- obcy trener nie ma dostępu;
- były trener traci dostęp;
- podopieczny nie może listować trenerskich podpowiedzi;
- read jest idempotentny;
- przeczytana podpowiedź znika z listy;
- nowy fingerprint może utworzyć nową podpowiedź po przeczytaniu starego.

### Success Criteria

#### Automated Verification

Run from `apps/api`:

```powershell
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PostWorkoutFeedback"
```

#### Manual Verification

- Endpointy nie materializują nowych podpowiedzi przy samym `GET`.
- Autoryzacja używa aktualnej relacji, nie historycznego trenera z momentu utworzenia sesji.

---

## Phase 4: Mobile Data Flow and Trainee Detail UI

### Overview

Dodać typed klienta, controller i sekcję `Podpowiedzi` w detalu podopiecznego trenera.

### Changes Required

#### 1. Add models and API client

**Files**:

- `apps/mobile/lib/trainer_guidance/trainer_guidance_models.dart`
- `apps/mobile/lib/trainer_guidance/trainer_guidance_api_client.dart`
- tests under `apps/mobile/test/`

**Contract**:

- Modele parsują oba typy podpowiedzi i dowody.
- Klient obsługuje listowanie po `traineeUserId`.
- Klient obsługuje `markAsRead(id)`.
- Błędy API mapują się na czytelny stan controller/UI.

#### 2. Add controller/state

**Files**:

- `apps/mobile/lib/trainer_guidance/trainer_guidance_controller.dart`
- integration point in `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/auth/auth_screen.dart`
- relevant widget test factories, especially `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Contract**:

- Ładuje podpowiedzi po wejściu na detal podopiecznego.
- Ma stany `initial/loading/loaded/error`.
- Po `markAsRead` usuwa kartę lokalnie albo odświeża listę.
- Nie blokuje całego detalu podopiecznego, jeśli endpoint podpowiedzi zwróci błąd.
- `TrainerGuidanceApiClient` jest wstrzyknięty tym samym wzorcem co istniejące klienty API: `main.dart` → `AuthScreen` → `AuthenticatedRelationshipShell`.
- Testy mają fake/stub klienta guidance bez wykonywania realnych żądań HTTP.

#### 3. Add trainee detail section

**File**: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`

**Contract**:

- Sekcja znajduje się zgodnie z `LiftMate.html`.
- Pokazuje maksymalnie 3 aktywne karty.
- Empty state jest dyskretny albo niewidoczny.
- Error state pozwala ponowić tylko ładowanie podpowiedzi.
- Loading state nie powoduje layout shift blokującego główne akcje.
- Karta ma neutralny ton i pokazuje dowody.

### Success Criteria

#### Automated Verification

Run from `apps/mobile`:

```powershell
flutter test test/trainer_guidance_models_test.dart test/trainer_guidance_api_client_test.dart test/trainer_guidance_controller_test.dart
flutter test test/trainer_trainee_detail_screen_test.dart test/post_auth_relationship_screen_test.dart test/training_history_flow_test.dart
flutter analyze
```

#### Manual Verification

- Trener widzi maksymalnie 3 podpowiedzi na detalu podopiecznego.
- Oznaczenie jako przeczytane usuwa kartę bez opuszczania ekranu.
- Błąd podpowiedzi nie psuje akcji `Historia` i `Zmień zestaw`.

---

## Phase 5: Cross-Feature Verification and Closeout

### Overview

Zweryfikować pełny przepływ S-10 oraz regresje w historii, feedbacku i workout setach.

### Verification Commands

Run from `apps/api`:

```powershell
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PostWorkoutFeedback"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WorkoutSet"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

Run from `apps/mobile`:

```powershell
flutter test test/trainer_guidance_models_test.dart test/trainer_guidance_api_client_test.dart test/trainer_guidance_controller_test.dart
flutter test test/trainer_trainee_detail_screen_test.dart test/training_history_flow_test.dart test/post_auth_relationship_screen_test.dart
flutter test
flutter analyze
```

### Manual Verification Checklist

- Trener widzi podpowiedź stagnacji po 3 zakończonych sesjach z tym samym `ExerciseId`, gdy trzeci maksymalny ciężar nie jest wyższy od pierwszego.
- Trener nie widzi podpowiedzi stagnacji dla ćwiczeń bez `ExerciseId`, typów innych niż `repsWeight`, ani dla mniej niż 3 sesji.
- Trener widzi podpowiedź wellbeing przy średniej feedbacku `<= 3.0` z 3 ostatnich zakończonych sesji z feedbackiem.
- Sesje bez feedbacku są pomijane w wellbeing.
- `Oznacz jako przeczytaną` usuwa kartę i nie odtwarza jej dla tego samego fingerprintu.
- Nowe okno 3 sesji może utworzyć nową podpowiedź.
- Obcy lub były trener nie ma dostępu do podpowiedzi.
- UI pozostaje zgodny z `apps/mobile/design/LiftMate.html`.
- Feedback S-09 jest poprawnie obecny w `LiftMate.html` i `LiftMate.dc.html`.

## Open Risks and Assumptions

- Globalny read state oznacza, że nowy trener nie zobaczy przeczytanego wcześniej sygnału dla tego samego fingerprintu. To zaakceptowana decyzja produktowa dla prostszego modelu.
- Brak backfillu oznacza, że stare dane mogą nie wygenerować podpowiedzi do czasu kolejnego zakończenia sesji lub zapisu feedbacku.
- Aktualny stan repo wskazuje, że `LiftMate.dc.html` jest source-like, a `LiftMate.html` zbundlowanym artefaktem; faza 1 musi potwierdzić lub skorygować ten workflow przed zmianami designu.
- Liczenie wszystkich zapisanych wartości, niezależnie od `IsDone`, jest świadomie zgodne z obecną historią/progresem, ale może obejmować wartości niedokończonych serii.
- Testy SQLite mogą nie złapać wszystkich różnic SQL Server; migracja musi być sprawdzona przez istniejący `MigrationScript` flow.

## Success Criteria Summary

- Podpowiedzi są materializowane po zakończeniu sesji i zapisie feedbacku, bez skutków ubocznych na `GET`.
- Stagnacja i wellbeing spełniają reguły PRD oraz uzgodnione decyzje planistyczne.
- Deduplication/read lifecycle nie tworzy spamu.
- Aktualny trener widzi maksymalnie 3 neutralne karty z dowodami i może je oznaczyć jako przeczytane.
- Nie ma regresji historii treningów, feedbacku S-09, workout setów ani dostępu trener–podopieczny.

## Progress

### Phase 1: Design Contract and S-09 Design Reconciliation

- [x] 1.1 Automated: `rg` potwierdza obecność copy feedbacku S-09 i podpowiedzi S-10 w `LiftMate.dc.html` oraz `LiftMate.html`. — 24c1ceb
- [x] 1.2 Automated: workflow source/artefakt designu został potwierdzony przez znaczniki bundlera albo opisany w notatce fazy. — 24c1ceb
- [ ] 1.3 Manual: Detal podopiecznego zachowuje czytelną hierarchię na telefonowym viewportcie.
- [ ] 1.4 Manual: Karty podpowiedzi nie wypychają kluczowych akcji poza sensowny pierwszy ekran przy 1-3 kartach.
- [ ] 1.5 Manual: Feedback S-09 jest obecny w `LiftMate.html` i `LiftMate.dc.html`.

### Phase 2: API Data Model and Guidance Evaluation

- [x] 2.1 Automated: `dotnet restore LiftMate.slnx` przechodzi z katalogu `apps/api`. — 99747b6
- [x] 2.2 Automated: `dotnet build LiftMate.slnx --no-restore` przechodzi z katalogu `apps/api`. — 99747b6
- [x] 2.3 Automated: `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"` przechodzi. — 99747b6
- [x] 2.4 Automated: `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"` przechodzi. — 99747b6
- [ ] 2.5 Manual: Migracja jest addytywna i nie dotyka istniejących tabel historii poza relacjami/indeksami wymaganymi do odczytu.
- [ ] 2.6 Manual: Ewaluator nie wymaga ręcznego backfillu starych danych w MVP.

### Phase 3: API Endpoints and Access Control

- [x] 3.1 Automated: `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"` przechodzi. — bd10090
- [x] 3.2 Automated: `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"` przechodzi. — bd10090
- [x] 3.3 Automated: `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PostWorkoutFeedback"` przechodzi. — bd10090
- [ ] 3.4 Manual: Endpointy nie materializują nowych podpowiedzi przy samym `GET`.
- [ ] 3.5 Manual: Autoryzacja używa aktualnej relacji, nie historycznego trenera z momentu utworzenia sesji.

### Phase 4: Mobile Data Flow and Trainee Detail UI

- [x] 4.1 Automated: `flutter test test/trainer_guidance_models_test.dart test/trainer_guidance_api_client_test.dart test/trainer_guidance_controller_test.dart` przechodzi. — 23c8c20
- [x] 4.2 Automated: `flutter test test/trainer_trainee_detail_screen_test.dart test/post_auth_relationship_screen_test.dart test/training_history_flow_test.dart` przechodzi. — 23c8c20
- [x] 4.3 Automated: `flutter analyze` przechodzi. — 23c8c20
- [ ] 4.4 Manual: Trener widzi maksymalnie 3 podpowiedzi na detalu podopiecznego.
- [ ] 4.5 Manual: Oznaczenie jako przeczytane usuwa kartę bez opuszczania ekranu.
- [ ] 4.6 Manual: Błąd podpowiedzi nie psuje akcji `Historia` i `Zmień zestaw`.

### Phase 5: Cross-Feature Verification and Closeout

- [x] 5.1 Automated: Pełny zestaw komend API z Phase 5 przechodzi z katalogu `apps/api`. — 6d7d25f
- [x] 5.2 Automated: Pełny zestaw komend mobile z Phase 5 przechodzi z katalogu `apps/mobile`. — 6d7d25f
- [ ] 5.3 Manual: Trener widzi podpowiedź stagnacji po 3 zakończonych sesjach z tym samym `ExerciseId`, gdy trzeci maksymalny ciężar nie jest wyższy od pierwszego.
- [ ] 5.4 Manual: Trener nie widzi podpowiedzi stagnacji dla ćwiczeń bez `ExerciseId`, typów innych niż `repsWeight`, ani dla mniej niż 3 sesji.
- [ ] 5.5 Manual: Trener widzi podpowiedź wellbeing przy średniej feedbacku `<= 3.0` z 3 ostatnich zakończonych sesji z feedbackiem.
- [ ] 5.6 Manual: Sesje bez feedbacku są pomijane w wellbeing.
- [ ] 5.7 Manual: `Oznacz jako przeczytaną` usuwa kartę i nie odtwarza jej dla tego samego fingerprintu.
- [ ] 5.8 Manual: Nowe okno 3 sesji może utworzyć nową podpowiedź.
- [ ] 5.9 Manual: Obcy lub były trener nie ma dostępu do podpowiedzi.
- [ ] 5.10 Manual: UI pozostaje zgodny z `apps/mobile/design/LiftMate.html`.
- [ ] 5.11 Manual: Feedback S-09 jest poprawnie obecny w `LiftMate.html` i `LiftMate.dc.html`.
