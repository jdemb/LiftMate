# Usuwanie zestawu z ekranu Moje zestawy — Implementation Plan

## Overview

Implementujemy bezpieczne usuwanie zestawów przez trenera z ekranu „Moje zestawy”. Interakcja ma odwzorować kontrakt z `apps/mobile/design/LiftMate.dc.html`: przycisk trzech kropek otwiera menu z czerwoną akcją „Usuń zestaw”; przed wykonaniem operacji aplikacja pokaże potwierdzenie, a backend zachowa historię przez archiwizację rekordu.

## Current State Analysis

- Ekran trenera listuje zestawy i obsługuje tylko „Edytuj” oraz „Przypisz”; karta nie ma menu ani akcji usuwania (`apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart:8`, `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart:111`).
- API udostępnia listowanie, tworzenie, odczyt, aktualizację, przypisywanie i odpinanie, ale nie ma `DELETE /workout-sets/{setId}` (`apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs:12`).
- Wiersze i przypisania są zależnościami kaskadowymi, ale sesje współdzielone oraz zapisany progres mają relacje `Restrict` do zestawu (`apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:169`, `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:327`, `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:403`). Fizyczne kasowanie naruszałoby historię.
- Rozpoczęcie sesji pobiera zestaw bez warunku archiwizacji, więc ten punkt wejścia musi jawnie odrzucać wycofane zestawy (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:167`).
- Klient i kontroler mobilny mają wzorzec operacji `DELETE` dla odpinania przypisania, który można rozszerzyć o usuwanie całego zestawu (`apps/mobile/lib/workout_sets/workout_set_api_client.dart:125`, `apps/mobile/lib/workout_sets/workout_set_controller.dart:289`).
- Design definiuje pozycję trzech kropek, zakotwiczone menu, czerwony tekst i ikonę kosza (`apps/mobile/design/LiftMate.dc.html:310`).

## Desired End State

Trener może otworzyć menu konkretnej karty, wybrać „Usuń zestaw”, potwierdzić operację i zobaczyć usunięcie karty dopiero po sukcesie API. Usunięcie oznacza archiwizację zestawu, usunięcie jego aktywnych przypisań i wykluczenie go ze wszystkich bieżących operacji, przy zachowaniu zakończonych sesji i progresu. Próba usunięcia zestawu używanego w aktywnej sesji kończy się kontrolowanym konfliktem bez zmiany danych.

### Key Discoveries:

- `WorkoutSet` potrzebuje nullable `DeletedAt`; wszystkie istniejące rekordy pozostają aktywne po migracji.
- Nie stosujemy bezwarunkowego globalnego query filter, ponieważ historyczne relacje nadal muszą móc odwoływać się do zarchiwizowanego rekordu. Aktywne endpointy filtrują `DeletedAt == null` jawnie.
- Archiwizacja i usunięcie przypisań muszą być jedną operacją zapisu; kontrola aktywnej sesji musi nastąpić przed zmianą stanu.
- UI nie usuwa karty optymistycznie: lokalna lista zmienia się dopiero po `204 No Content`.

## What We're NOT Doing

- Nie dodajemy ekranu archiwum, przywracania zestawu ani endpointu restore.
- Nie usuwamy fizycznie zestawów, wierszy, zakończonych sesji, feedbacku ani progresu.
- Nie anulujemy aktywnej sesji w ramach usuwania zestawu.
- Nie zmieniamy kreatora, przypisywania, zapisywania zestawów ani nawigacji po tych operacjach.
- Nie edytujemy plików designu ani `context/archive/`.
- Nie dodajemy optymistycznego usuwania ani funkcji „Cofnij”.

## Implementation Approach

Najpierw rozszerzamy model o znacznik archiwizacji i definiujemy atomowy kontrakt API. Następnie dodajemy obsługę żądania oraz deterministyczną aktualizację stanu w aplikacji mobilnej. Na końcu odwzorowujemy menu z designu, dokładamy dialog bezpieczeństwa i pokrywamy pełny przepływ testami widgetowymi. Aktywne zapytania i rozpoczęcie sesji jawnie odrzucają zarchiwizowane zestawy, natomiast dane historyczne pozostają bez zmian.

## Critical Implementation Details

Usuwanie oraz `StartFromWorkoutSet` muszą korzystać z `Database.CreateExecutionStrategy()` i transakcji `IsolationLevel.Serializable`, zgodnie z istniejącym wzorcem zamykania sesji. Obie operacje ponownie odczytują zestaw i stan aktywnej sesji wewnątrz transakcji przed zapisem, dzięki czemu równoległy start i DELETE nie mogą zakończyć się aktywną sesją wskazującą zarchiwizowany zestaw. Powtórne usunięcie własnego, już zarchiwizowanego zestawu jest idempotentne i zwraca `204`; obcy trener nadal otrzymuje `404`.

## Phase 1: Archiwizacja i kontrakt API

### Overview

Ta faza wprowadza trwałą semantykę usuwania, chroni historię oraz zamyka wszystkie serwerowe punkty wejścia, które mogłyby nadal używać zarchiwizowanego zestawu.

### Changes Required:

#### 1. Model archiwizacji i migracja

**Files**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSet.cs`, `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`, `apps/api/LiftMate.Api/Migrations/<timestamp>_AddWorkoutSetDeletedAt.cs`, odpowiadający plik designer i `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`

**Intent**: Dodać nullable znacznik czasu archiwizacji bez zmiany stanu istniejących rekordów i bez osłabienia relacji zachowujących historię.

**Contract**: `WorkoutSet.DeletedAt` ma typ `DateTimeOffset?`; `null` oznacza zestaw aktywny. Migracja dodaje nullable kolumnę i indeks wspierający listowanie aktywnych zestawów trenera. Relacje sesji i progresu pozostają `Restrict`, a wiersze nie są kasowane przy archiwizacji.

#### 2. Endpoint usuwania i filtrowanie aktywnych zestawów

**File**: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs`

**Intent**: Udostępnić właścicielowi bezpieczną, idempotentną operację usunięcia oraz wykluczyć zarchiwizowane rekordy z list, szczegółów, aktualizacji, przypisywania i widoków podopiecznego.

**Contract**: `DELETE /workout-sets/{setId:guid}` wymaga `TrainerOnly`. Zwraca `204` po archiwizacji lub przy ponowieniu dla własnego zarchiwizowanego zestawu, `404` dla nieistniejącego lub cudzego ID oraz `409` z komunikatem błędu, gdy istnieje aktywna sesja wskazująca zestaw. Operacja działa przez execution strategy i transakcję `Serializable`; wewnątrz niej ponownie pobiera należący do trenera zestaw, sprawdza aktywną sesję, ustawia `DeletedAt` i usuwa wszystkie `WorkoutSetAssignments` jednym zapisem. Zachowuje `WorkoutSetRows`, historię i progres. Aktywne query helpers stosują `DeletedAt == null`; lookup usuwania może jawnie uwzględnić archiwalne rekordy tylko dla kontroli właściciela i idempotencji.

#### 3. Ochrona rozpoczęcia sesji

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`

**Intent**: Uniemożliwić rozpoczęcie nowej sesji dla zarchiwizowanego zestawu nawet przy bezpośrednim użyciu znanego ID.

**Contract**: Cały `StartFromWorkoutSet` działa przez execution strategy i transakcję `Serializable`. Zestaw, przypisania, progres oraz brak aktywnej sesji są odczytywane i ponownie weryfikowane wewnątrz transakcji; lookup wymaga `DeletedAt == null`. Zarchiwizowane ID zachowuje istniejącą semantykę niedostępnego zestawu i nie tworzy sesji ani wartości. Rozwiązanie ma użyć istniejącego wzorca z `Complete`, zamiast wprowadzać lokalne blokady działające tylko w jednej instancji API.

#### 4. Aktywne podsumowania relacji

**File**: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`

**Intent**: Zapewnić, że podsumowania `AssignedWorkoutSets` nigdy nie eksponują zarchiwizowanego zestawu, niezależnie od stanu lub pochodzenia relacji przypisania.

**Contract**: Zapytanie budujące przypisane zestawy trenera wymaga `assignment.WorkoutSet.DeletedAt == null`. Usunięcie przypisań pozostaje podstawowym efektem DELETE, a filtr jest defensywną granicą wszystkich aktywnych odczytów.

#### 5. Testy API, migracji i trwałości

**Files**: `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs`, `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetPersistenceTests.cs`, `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`, `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`, `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`

**Intent**: Udowodnić semantykę archiwizacji, autoryzację, blokadę aktywnej sesji i zachowanie historii.

**Contract**: Testy obejmują usunięcie własnego zestawu, ponowienie, obcego trenera i rolę podopiecznego; usunięcie przypisań; brak zestawu w aktywnych listach, szczegółach i `AssignedWorkoutSets`; konflikt aktywnej sesji bez częściowej mutacji; sukces przy zakończonej sesji/progresie; odrzucenie startu zarchiwizowanego zestawu oraz zachowanie historycznych rekordów i wierszy. Test skryptu migracji SQL Server potwierdza nullable `datetimeoffset` `DeletedAt` oraz indeks. Test współbieżności uruchamia skoordynowany start i usunięcie i potwierdza invariant: po zakończeniu operacji zestaw jest aktywny z aktywną sesją albo zarchiwizowany bez aktywnej sesji — nigdy oba stany jednocześnie.

### Success Criteria:

#### Automated Verification:

- Migracja i model zapisują nullable `DeletedAt`, a istniejące zestawy pozostają aktywne.
- Testy endpointów potwierdzają archiwizację, idempotencję, autoryzację i usunięcie przypisań.
- Testy sesji potwierdzają konflikt dla aktywnej sesji, zachowanie historii oraz zakaz rozpoczęcia nowej sesji z archiwalnego zestawu.
- `dotnet restore LiftMate.slnx`, `dotnet build LiftMate.slnx --no-restore` i `dotnet test LiftMate.slnx --no-build --verbosity minimal` kończą się sukcesem z `apps/api`.
- Test współbieżności potwierdza, że start i usunięcie nie mogą pozostawić aktywnej sesji dla zarchiwizowanego zestawu.
- Test relacji potwierdza brak zarchiwizowanego zestawu w `AssignedWorkoutSets`.
- Test skryptu migracji SQL Server potwierdza nullable `DeletedAt` i indeks aktywnych zestawów.

---

## Phase 2: Obsługa usuwania w kliencie mobilnym

### Overview

Ta faza dodaje żądanie `DELETE`, stan operacji i bezpieczne usunięcie elementu z lokalnej listy dopiero po potwierdzeniu serwera.

### Changes Required:

#### 1. Klient API zestawów

**File**: `apps/mobile/lib/workout_sets/workout_set_api_client.dart`

**Intent**: Dodać typowaną operację archiwizacji zestawu zgodną z obecnym wspólnym mechanizmem `_send` i mapowaniem błędów.

**Contract**: Nowa metoda przyjmuje token i `workoutSetId`, wysyła `DELETE /workout-sets/{id}`, akceptuje `204`, nie oczekuje body i zwraca `WorkoutSetApiResult<void>`. `409` pozostaje mapowany na `WorkoutSetApiStatus.conflict`.

#### 2. Stan i kontroler

**File**: `apps/mobile/lib/workout_sets/workout_set_controller.dart`

**Intent**: Koordynować pojedynczą operację usuwania, zablokować duplikaty i zachować listę przy błędzie.

**Contract**: Stan identyfikuje aktualnie usuwany zestaw. `deleteSet(id)` wymaga tokenu, uruchamia klienta, a po sukcesie usuwa tylko odpowiadający element z `trainerSets`, czyści pasujący `selectedSet` i wraca do stanu loaded. Brak tokenu, `409`, offline i pozostałe błędy zachowują kartę oraz zwracają wynik do warstwy UI; identyfikator operacji jest czyszczony po zakończeniu.

#### 3. Testy klienta i kontrolera

**Files**: `apps/mobile/test/workout_set_api_client_test.dart`, `apps/mobile/test/workout_set_controller_test.dart`

**Intent**: Zabezpieczyć ścieżkę HTTP i kolejność zmian stanu bez zależności od widgetów.

**Contract**: Testy sprawdzają metodę/path/status `204`, mapowanie `409`, usunięcie jednego elementu po sukcesie, zachowanie listy przy konflikcie/offline/braku tokenu, czyszczenie stanu operacji i brak podwójnego żądania dla tego samego zestawu.

### Success Criteria:

#### Automated Verification:

- Test klienta potwierdza `DELETE /workout-sets/{id}`, brak body oraz obsługę `204` i `409`.
- Test kontrolera potwierdza usunięcie właściwej karty dopiero po sukcesie.
- Testy kontrolera potwierdzają zachowanie listy i możliwość ponowienia po konflikcie, błędzie sieci lub braku tokenu.
- `flutter test test/workout_set_api_client_test.dart test/workout_set_controller_test.dart` kończy się sukcesem z `apps/mobile`.

---

## Phase 3: Menu i potwierdzenie zgodne z designem

### Overview

Ta faza dostarcza widoczną funkcję trenera: trzy kropki na karcie, zakotwiczone menu, bezpieczny dialog i komunikaty wyniku.

### Changes Required:

#### 1. Karta i menu „Usuń zestaw”

**File**: `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart`

**Intent**: Odwzorować układ i stylistykę z kontraktu designu bez zmiany istniejących akcji „Edytuj” i „Przypisz”.

**Contract**: Obok etykiety „globalny” pojawia się przycisk `more_vert` z etykietą dostępności „Więcej”. Kliknięcie otwiera jedno zakotwiczone menu o ciemnym tle; dotknięcie poza nim je zamyka. Menu zawiera czerwoną ikonę kosza i tekst „Usuń zestaw”, zgodnie z `apps/mobile/design/LiftMate.dc.html:320-337`. Operacja dla usuwanego zestawu nie może zostać wywołana drugi raz.

#### 2. Potwierdzenie, wynik i błędy

**File**: `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart`

**Intent**: Chronić przed przypadkowym usunięciem i jasno zakomunikować wynik bez opuszczania ekranu.

**Contract**: Akcja menu otwiera dialog zawierający nazwę zestawu, „Anuluj” i destrukcyjne „Usuń”. Anulowanie nie wywołuje API. Po potwierdzeniu UI czeka na wynik kontrolera; po `204` karta znika i pojawia się krótki polski komunikat sukcesu. Przy `409` karta zostaje i użytkownik widzi komunikat o aktywnej sesji; przy pozostałych błędach widzi ogólny komunikat z możliwością ponowienia. Po usunięciu ostatniego zestawu przycisk „Nowy zestaw” pozostaje dostępny.

#### 3. Testy widgetowe pełnego przepływu

**File**: `apps/mobile/test/workout_set_trainer_screens_test.dart`

**Intent**: Zweryfikować interakcję od trzech kropek do aktualizacji listy oraz brak regresji istniejących funkcji.

**Contract**: Testy otwierają menu właściwej karty, sprawdzają tekst i destrukcyjny wygląd semantyczny, anulują dialog bez requestu, potwierdzają dokładnie jeden request, sprawdzają usunięcie właściwej karty po sukcesie, zachowanie przy `409`/offline oraz dalszą dostępność „Edytuj”, „Przypisz” i „Nowy zestaw”.

### Success Criteria:

#### Automated Verification:

- Test widgetowy potwierdza menu trzech kropek i akcję „Usuń zestaw” zgodną z kontraktem designu.
- Test widgetowy potwierdza, że „Anuluj” zamyka dialog bez żądania HTTP.
- Test widgetowy potwierdza pojedyncze usunięcie karty po sukcesie i pozostawienie przycisku „Nowy zestaw”.
- Test widgetowy potwierdza zachowanie karty oraz właściwy komunikat przy aktywnej sesji i błędzie sieci.
- `flutter test --reporter compact` i `flutter analyze` kończą się sukcesem z `apps/mobile`.

#### Manual Verification:

- Menu trzech kropek, pozycja, ciemne tło, czerwony tekst i ikona odpowiadają `LiftMate.dc.html` na docelowym ekranie Androida.
- Dialog pokazuje właściwą nazwę zestawu, a anulowanie nie zmienia listy.
- Po potwierdzeniu nieprzypisany lub historyczny zestaw znika z „Moje zestawy” i ekranów podopiecznych, a historia treningów pozostaje czytelna.
- Zestaw używany w aktywnej sesji pozostaje widoczny i wyświetla zrozumiały komunikat bez przerwania treningu.

**Implementation Note**: Po zakończeniu fazy i przejściu wszystkich testów automatycznych zatrzymaj się przed oznaczeniem punktów manualnych jako wykonane. Wymagają potwierdzenia użytkownika po testach aplikacji.

## Testing Strategy

### Unit Tests:

- Model i kontroler: znaczenie `DeletedAt`, przejścia stanu usuwania, zachowanie listy i obsługa braku tokenu/błędów.
- Klient mobilny: metoda, ścieżka, statusy `204`/`409` i brak parsowania body.

### Integration Tests:

- API: właściciel, obcy trener, podopieczny, przypisania, aktywna i zakończona sesja, progres oraz powtórzone usunięcie.
- Flutter widget: menu, dialog, anulowanie, sukces, konflikt, offline i brak regresji istniejących akcji.

### Manual Testing Steps:

1. Otwórz „Zestawy” jako trener i porównaj kartę oraz menu z `LiftMate.dc.html`.
2. Otwórz menu, wybierz „Usuń zestaw”, anuluj i potwierdź brak zmiany.
3. Usuń nieużywany zestaw i sprawdź komunikat, zniknięcie karty oraz działanie „Nowy zestaw”.
4. Usuń zestaw przypisany bez aktywnej sesji i sprawdź, że podopieczny przestaje go widzieć.
5. Usuń zestaw mający wyłącznie zakończoną historię i sprawdź zachowanie wpisów historii/progresu.
6. Spróbuj usunąć zestaw podczas aktywnej sesji i sprawdź konflikt bez przerwania treningu.
7. Powtórz operację bez sieci i sprawdź zachowanie karty oraz możliwość ponowienia.

## Performance Considerations

- Lista trenera oraz lookup usuwania powinny korzystać z indeksu obejmującego właściciela i stan archiwizacji.
- Usunięcie przypisań oraz zapis `DeletedAt` wykonują się w jednym zapisie/transakcji; nie pobieramy ponownie całej listy po sukcesie.
- Nie dodajemy globalnego filtra, który mógłby niejawnie zmieniać historyczne zapytania.

## Migration Notes

- Migracja jest wstecznie kompatybilna: nullable `DeletedAt` pozostawia wszystkie istniejące zestawy aktywne.
- Nie ma backfillu ani fizycznego kasowania danych.
- Rollback usuwa wyłącznie kolumnę i indeks; wcześniej zarchiwizowane rekordy po rollbacku znów byłyby aktywne, więc rollback produkcyjny wymaga świadomej decyzji operacyjnej.

## References

- Change identity: `context/changes/delete-workout-set/change.md`
- Design contract: `apps/mobile/design/LiftMate.dc.html:310-342`
- Current mobile list: `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart:8-190`
- Current API routes: `apps/api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs:12-24`
- Historical FK constraints: `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:169-172`, `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:403-406`
- Existing mobile delete pattern: `apps/mobile/lib/workout_sets/workout_set_api_client.dart:125-139`
- Existing endpoint coverage: `apps/api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs:200-320`
- Existing serializable transaction pattern: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:439-445`
- Active relationship set summary: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:94-119`
- SQL Server migration verification: `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Archiwizacja i kontrakt API

#### Automated

- [x] 1.1 Migracja i model zapisują nullable `DeletedAt`, a istniejące zestawy pozostają aktywne. — d8b0c68
- [x] 1.2 Testy endpointów potwierdzają archiwizację, idempotencję, autoryzację i usunięcie przypisań. — d8b0c68
- [x] 1.3 Testy sesji potwierdzają konflikt dla aktywnej sesji, zachowanie historii oraz zakaz rozpoczęcia nowej sesji z archiwalnego zestawu. — d8b0c68
- [x] 1.4 `dotnet restore LiftMate.slnx`, `dotnet build LiftMate.slnx --no-restore` i `dotnet test LiftMate.slnx --no-build --verbosity minimal` kończą się sukcesem z `apps/api`. — d8b0c68
- [x] 1.5 Test współbieżności potwierdza, że start i usunięcie nie mogą pozostawić aktywnej sesji dla zarchiwizowanego zestawu. — d8b0c68
- [x] 1.6 Test relacji potwierdza brak zarchiwizowanego zestawu w `AssignedWorkoutSets`. — d8b0c68
- [x] 1.7 Test skryptu migracji SQL Server potwierdza nullable `DeletedAt` i indeks aktywnych zestawów. — d8b0c68

### Phase 2: Obsługa usuwania w kliencie mobilnym

#### Automated

- [x] 2.1 Test klienta potwierdza `DELETE /workout-sets/{id}`, brak body oraz obsługę `204` i `409`. — f64981b
- [x] 2.2 Test kontrolera potwierdza usunięcie właściwej karty dopiero po sukcesie. — f64981b
- [x] 2.3 Testy kontrolera potwierdzają zachowanie listy i możliwość ponowienia po konflikcie, błędzie sieci lub braku tokenu. — f64981b
- [x] 2.4 `flutter test test/workout_set_api_client_test.dart test/workout_set_controller_test.dart` kończy się sukcesem z `apps/mobile`. — f64981b

### Phase 3: Menu i potwierdzenie zgodne z designem

#### Automated

- [x] 3.1 Test widgetowy potwierdza menu trzech kropek i akcję „Usuń zestaw” zgodną z kontraktem designu. — 2ae47e9
- [x] 3.2 Test widgetowy potwierdza, że „Anuluj” zamyka dialog bez żądania HTTP. — 2ae47e9
- [x] 3.3 Test widgetowy potwierdza pojedyncze usunięcie karty po sukcesie i pozostawienie przycisku „Nowy zestaw”. — 2ae47e9
- [x] 3.4 Test widgetowy potwierdza zachowanie karty oraz właściwy komunikat przy aktywnej sesji i błędzie sieci. — 2ae47e9
- [x] 3.5 `flutter test --reporter compact` i `flutter analyze` kończą się sukcesem z `apps/mobile`. — 2ae47e9

#### Manual

- [ ] 3.6 Menu trzech kropek, pozycja, ciemne tło, czerwony tekst i ikona odpowiadają `LiftMate.dc.html` na docelowym ekranie Androida.
- [ ] 3.7 Dialog pokazuje właściwą nazwę zestawu, a anulowanie nie zmienia listy.
- [ ] 3.8 Po potwierdzeniu nieprzypisany lub historyczny zestaw znika z „Moje zestawy” i ekranów podopiecznych, a historia treningów pozostaje czytelna.
- [ ] 3.9 Zestaw używany w aktywnej sesji pozostaje widoczny i wyświetla zrozumiały komunikat bez przerwania treningu.
