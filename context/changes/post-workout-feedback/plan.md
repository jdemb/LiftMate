# Feedback po zakończonym treningu — Implementation Plan

> **Dla implementacji agentowej:** realizuj fazy osobno, test-first, z oddzielnym commitem dla każdej fazy. Użyj `superpowers:test-driven-development` przy zmianach produkcyjnych i `superpowers:verification-before-completion` przed deklaracją ukończenia.

## Overview

S-09 dodaje jednorazowy, nieedytowalny feedback podopiecznego do zakończonej sesji treningowej. Podopieczny podaje obowiązkową ocenę samopoczucia 1–5 i opcjonalny komentarz po treningu samodzielnym lub wspólnym, a aktualny trener odczytuje wpis w istniejących szczegółach historii.

Zmiana rozszerza istniejący model zakończonej `SharedSession`; nie tworzy drugiego systemu historii i nie zmienia kontraktu kończenia treningu ani projekcji progresu.

## Current State Analysis

- `POST /shared-sessions/{sessionId}/complete` atomowo zamyka sesję i zapisuje progres, ale nie przyjmuje danych feedbacku (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:425`).
- Trening samodzielny i wspólny używają tej samej encji `SharedSession`, więc feedback może być powiązany z jednym stabilnym identyfikatorem sesji (`apps/api/LiftMate.Api/SharedSessions/SharedSession.cs:6`).
- Historia czyta zakończone sesje bezpośrednio z `SharedSessions`; szczegół sesji nie zawiera feedbacku (`apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs:102`, `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryContracts.cs:16`).
- Aktualny model dostępu pozwala podopiecznemu czytać własną historię, a trenerowi historię aktualnie przypisanego podopiecznego (`apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryAccess.cs:15`).
- Po samodzielnym zakończeniu mobile natychmiast czyści sesję i wraca do pulpitu, więc przed `clearSession()` trzeba zachować ID zakończonej sesji (`apps/mobile/lib/relationships/authenticated_relationship_shell.dart:460`).
- W treningu wspólnym podopieczny ma widok read-only i nie wywołuje `complete`; zakończenie dociera przez snapshot realtime (`apps/mobile/lib/shared_sessions/shared_session_controller.dart:435`).
- Istniejący `TrainingHistoryFlow` obsługuje listę, szczegół sesji i progres dla obu ról, dlatego sekcja feedbacku powinna zostać dodana do szczegółu sesji (`apps/mobile/lib/training_history/training_history_flow.dart:333`).
- `apps/mobile/design/LiftMate.dc.html` definiuje zakończenie treningu i historię, ale nie zawiera formularza ani sekcji feedbacku (`apps/mobile/design/LiftMate.dc.html:534`, `apps/mobile/design/LiftMate.dc.html:610`).
- PRD wymaga oceny 1–5, opcjonalnego komentarza, obsługi obu rodzajów treningu, braku edycji i widoczności dla właściwego trenera (`context/foundation/prd-expansion.md:65`).
- Zasada projektu wymaga utrzymywania ekranów możliwie blisko kontraktu Design (`context/foundation/lessons.md:5`).

## Desired End State

- Po zakończeniu treningu podopieczny widzi formularz feedbacku, ale może go świadomie pominąć.
- Pominięty lub niewysłany feedback można później dodać z własnej historii treningu.
- Zakończenie treningu wspólnego przez trenera wywołuje ten sam formularz po terminalnym snapshotcie realtime.
- API zapisuje dokładnie jeden feedback na zakończoną sesję, wyłącznie dla podopiecznego będącego właścicielem sesji.
- Bezpieczne ponowienie identycznego żądania zwraca istniejący wpis jako sukces; próba zmiany zapisanej treści jest odrzucana.
- Aktualny trener widzi read-only feedback w szczegółach właściwej sesji. Były lub obcy trener nadal nie ma dostępu do historii podopiecznego.
- Sesje bez feedbacku pozostają w pełni czytelne i zgodne wstecznie.

## Key Decisions

| Area | Decision | Rationale |
|---|---|---|
| Moment formularza | Natychmiast po zakończeniu, z opcją pominięcia | Maksymalizuje szansę odpowiedzi bez blokowania zakończenia treningu. |
| Późniejsze uzupełnienie | Akcja w historii podopiecznego | Obsługuje pominięcie, offline i zakończenie wspólnej sesji bez aktywnego ekranu. |
| Sesja wspólna | Prompt po przejściu realtime `active → completed` | Zapewnia spójny przepływ dla treningu samodzielnego i prowadzonego. |
| Dostęp trenera | Aktualny trener, zgodnie z obecną historią | Nie wprowadza drugiego modelu autoryzacji. |
| Limit komentarza | 1000 znaków | Pozwala przekazać praktyczny opis przy kontrolowanym rozmiarze danych. |
| Retry | Identyczny replay zwraca zapisany wpis; różna treść zwraca konflikt | Chroni przed utratą odpowiedzi sieciowej bez dopuszczenia edycji. |
| Ocena | Pięć opisanych i dostępnych semantycznie przycisków | Jest szybka na telefonie i jednoznaczna dla użytkownika. |
| Historia bez wpisu | Podopieczny widzi „Dodaj feedback”, trener „Brak feedbacku” | Umożliwia uzupełnienie bez sugerowania trenerowi błędu systemu. |
| Błąd wysyłki | Formularz zachowuje dane i oferuje retry | Komentarz nie ginie po problemie sieciowym. |
| Wyjście | Potwierdzenie „Pominąć feedback?” | Chroni przed przypadkowym zamknięciem, zachowując opcjonalność. |
| Design | Najpierw rozszerzyć `LiftMate.dc.html` | Design pozostaje źródłem prawdy dla UI i copy. |
| Git | Osobne commity dla każdej fazy | Ułatwia review, weryfikację i bezpieczne cofanie. |

## What We're NOT Doing

- Nie zmieniamy kontraktu `complete` ani projekcji progresu.
- Nie wymagamy feedbacku do zakończenia treningu.
- Nie dodajemy edycji, usuwania ani historii zmian feedbacku.
- Nie interpretujemy automatycznie komentarza.
- Nie generujemy podpowiedzi dla trenera; to zakres S-10.
- Nie dodajemy feedbacku do listy historii ani nowych mechanizmów paginacji.
- Nie zmieniamy ról, relacji trener–podopieczny ani zasad dostępu do historii.
- Nie dodajemy powiadomień push, e-mail ani telemetrii aplikacyjnej.
- Nie edytujemy `context/archive/`.

## Implementation Approach

Implementacja przebiega od kontraktu wizualnego do trwałego modelu i UI:

1. zakontraktować formularz, stany i sekcję historii w Design;
2. dodać addytywną encję jeden-do-jednego, endpoint zapisu i projekcję w historii;
3. zbudować typed mobile data flow oraz jednorazowy sygnał zakończonej sesji;
4. wdrożyć formularz i role-aware sekcję historii;
5. zweryfikować przepływ end-to-end, migrację i brak regresji.

Każda faza jest wdrażana test-first i kończy się osobnym commitem. Manualne checkboxy pozostają puste do jawnego potwierdzenia użytkownika.

## Critical Implementation Details

### Retry bez naruszenia nieedytowalności

Unikalność `SharedSessionId` musi być egzekwowana w bazie, nie tylko przez wcześniejszy odczyt. Pierwszy zapis zwraca `201`; identyczny replay zwraca `200` z istniejącym wpisem, natomiast replay z inną oceną lub komentarzem zwraca `409`. Przy wyścigu równoległych żądań endpoint przechwytuje naruszenie unikalności, czyści lokalny EF tracker przez odłączenie `DbUpdateException.Entries` albo `ChangeTracker.Clear()`, ponownie odczytuje istniejący wpis przez `AsNoTracking()` i stosuje tę samą regułę porównania.

### Jednorazowy terminalny sygnał mobile

Formularz nie może zależeć wyłącznie od lokalnego callbacku `complete()`, ponieważ w sesji wspólnej zakończenie wykonuje trener. Warstwa sesji musi wystawić konsumowalny, jednorazowy sygnał z ID przejścia `active → completed`, działający dla odpowiedzi HTTP i snapshotu realtime, bez ponownego otwarcia formularza po rebuildzie, reconnect lub starszym snapshotcie. Dodatkowo kontroler musi odzyskać zakończenie utracone podczas rozłączenia: po reconnect odświeża ostatni znany aktywny `sessionId` ścieżką pozwalającą rozpoznać stan `completed`, emituje pending event tylko jeśli zakończenie nie było wcześniej skonsumowane i nie zastępuje automatycznie już otwartego ekranu live.

### Nawigacja i zachowanie danych formularza

ID zakończonej sesji należy zachować przed wyczyszczeniem bieżącej sesji. Formularz utrzymuje wybraną ocenę i komentarz podczas błędu. Pominięcie z bezpośredniego promptu wraca do pulpitu; anulowanie formularza otwartego z historii wraca do szczegółu tej samej sesji.

---

## Phase 1: Design Contract For Feedback Flow

### Overview

Rozszerzyć autorytatywny design o formularz po treningu, stany walidacji i błędu oraz read-only sekcję feedbacku w historii.

### Changes Required

#### 1. Post-Workout Feedback Screen

**File**: `apps/mobile/design/LiftMate.dc.html`

**Intent**: Zakontraktować wygląd i copy formularza przed implementacją Flutter.

**Contract**:

- Dodać ekran „Jak się czujesz po treningu?” bezpośrednio po stanie końca treningu.
- Pokazać pięć przycisków oceny z opisami: `1 Bardzo źle`, `2 Źle`, `3 W porządku`, `4 Dobrze`, `5 Bardzo dobrze`.
- Dodać pole `Komentarz (opcjonalnie)` z licznikiem `0/1000`.
- Dodać główne CTA `Wyślij feedback` i drugorzędną akcję `Pomiń`.
- Zakontraktować disabled CTA bez oceny, stan wysyłania, błąd z `Spróbuj ponownie` oraz zachowanie wpisanego komentarza.
- Zakontraktować dialog `Pominąć feedback?` z akcjami `Wróć` i `Pomiń`.
- Zakontraktować potwierdzenie `Dzięki! Feedback został zapisany.`.
- Zachować istniejącą typografię, spacing, kolory, zaokrąglenia i układ bez overflow na obsługiwanym telefonie.

#### 2. Feedback In Training History

**File**: `apps/mobile/design/LiftMate.dc.html`

**Intent**: Określić read-only prezentację wpisu oraz różnicę między widokiem podopiecznego i trenera.

**Contract**:

- W szczególe sesji, przed ćwiczeniami, dodać sekcję `Feedback podopiecznego`.
- Zapisany wpis pokazuje `Samopoczucie: N/5`, opis wybranej oceny, komentarz lub `Bez komentarza`.
- Podopieczny bez wpisu widzi CTA `Dodaj feedback`.
- Trener bez wpisu widzi neutralny tekst `Brak feedbacku`.
- Zapisany wpis nie zawiera akcji edycji ani usunięcia.

### Success Criteria

#### Automated Verification

- `rg -n "Jak się czujesz po treningu|Wyślij feedback|Dodaj feedback|Feedback podopiecznego|Pominąć feedback" apps/mobile/design/LiftMate.dc.html` znajduje wszystkie zakontraktowane stany.
- Design zachowuje poprawną składnię i otwiera się bez błędów skryptu w przeglądarce.

#### Manual Verification

- Formularz, dialog pominięcia, błąd i sekcja historii są czytelne na telefonowym viewportcie bez overflow.
- Copy i hierarchia wizualna są spójne z istniejącymi ekranami LiftMate.

**Implementation Note**: Po automatycznej weryfikacji tej fazy zatrzymaj się na ocenę designu. Nie oznaczaj manualnych pozycji jako wykonane bez potwierdzenia użytkownika.

---

## Phase 2: Additive Feedback Persistence And API Contract

### Overview

Dodać trwały, jeden-do-jednego feedback zakończonej sesji, bezpieczny endpoint tworzenia oraz read-only projekcję w szczególe historii.

### Changes Required

#### 1. Feedback Entity And EF Configuration

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/PostWorkoutFeedback.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddPostWorkoutFeedback.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddPostWorkoutFeedback.Designer.cs`
- `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`
- `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`

**Intent**: Przechowywać jeden nieedytowalny wpis na sesję i egzekwować integralność również przy równoległych żądaniach.

**Contract**:

- `PostWorkoutFeedback.SharedSessionId` jest jednocześnie PK i FK do `SharedSessions`.
- Encja zawiera `WellbeingRating`, nullable `Comment` oraz `SubmittedAt`.
- Relacja `SharedSession.Feedback` jest opcjonalna jeden-do-jednego z kaskadowym usunięciem razem z sesją.
- `WellbeingRating` ma constraint `BETWEEN 1 AND 5`.
- `Comment` ma maksymalnie 1000 znaków.
- Migracja jest addytywna; nie zmienia ani nie backfilluje istniejących sesji.
- Test idempotentnego skryptu SQL Server sprawdza tabelę, PK/FK, constraint oceny i limit komentarza.

#### 2. Create-Only Feedback Endpoint

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/PostWorkoutFeedbackContracts.cs`
- `apps/api/LiftMate.Api/SharedSessions/PostWorkoutFeedbackEndpoints.cs`
- `apps/api/LiftMate.Api/Program.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/PostWorkoutFeedbackEndpointTests.cs`

**Intent**: Umożliwić wyłącznie właścicielowi zakończonej sesji jednorazowe przesłanie feedbacku.

**Contract**:

- Dodać `POST /shared-sessions/{sessionId}/feedback` z polityką `TraineeOnly`.
- Request zawiera integer `wellbeingRating` i nullable `comment`.
- Komentarz jest trimowany; pusty po trimie jest zapisywany jako `null`.
- Endpoint wymaga `session.TraineeUserId == NameIdentifier`, `Status == completed` oraz `ClosedAt != null`.
- Trening samodzielny i wspólny są obsługiwane bez warunku na `StartedByRole`.
- Pierwszy zapis zwraca `201` oraz pełny response.
- Identyczny replay zwraca `200` i istniejący response bez zmiany `SubmittedAt`.
- Replay z inną znormalizowaną treścią zwraca `409`.
- Po `DbUpdateException` z naruszenia unikalności endpoint czyści EF tracker, ponownie odczytuje istniejący feedback przez `AsNoTracking()` i dopiero wtedy porównuje replay.
- Ocena poza 1–5 i komentarz ponad 1000 znaków zwracają `400`.
- Sesja aktywna lub anulowana zwraca `409`; brak sesji zwraca `404`; cudza sesja nie ujawnia danych i zwraca `404`.
- Nie dodawać `PUT`, `PATCH` ani `DELETE`.

#### 3. Feedback Projection In Session History

**Files**:

- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryContracts.cs`
- `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`

**Intent**: Pokazać feedback w istniejącym szczególe zakończonej sesji bez rozszerzania listy historii.

**Contract**:

- `TrainingHistorySessionResponse` otrzymuje nullable `Feedback`.
- `Feedback` zawiera `wellbeingRating`, `comment` i `submittedAt`.
- `GetSession` ładuje opcjonalną relację feedbacku i zachowuje dotychczasową autoryzację.
- Sesje bez feedbacku zwracają `feedback: null`.
- Aktualny trener widzi również feedback historycznej sesji sprzed aktualnego przypisania, ponieważ historia nadal opiera dostęp na bieżącej relacji.
- Były i obcy trener nadal otrzymują odmowę całego szczegółu sesji.

### Success Criteria

#### Automated Verification

- Model SQLite tworzy relację jeden-do-jednego i constraint oceny.
- Idempotentny skrypt migracji SQL Server zawiera addytywną tabelę oraz wymagane ograniczenia.
- Podopieczny tworzy feedback dla zakończonej sesji samodzielnej i wspólnej.
- Trener, obcy podopieczny i nieuwierzytelniony użytkownik nie mogą utworzyć feedbacku.
- Aktywna, anulowana i nieistniejąca sesja są odrzucane właściwym statusem.
- Oceny `0` i `6` oraz komentarz ponad 1000 znaków są odrzucane.
- Identyczny replay zwraca istniejący wpis bez zmiany czasu; inna treść zwraca `409`.
- Równoległe żądania nie tworzą dwóch wpisów i nie zmieniają pierwszego.
- Wyścig unikalności po `DbUpdateException` czyści EF tracker i ponownie odczytuje istniejący wpis bez błędu śledzenia.
- Szczegół historii zwraca właściwy feedback lub `null`.
- Aktualny trener ma dostęp, a były i obcy trener nie.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PostWorkoutFeedback"` przechodzi.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"` przechodzi.
- `dotnet build LiftMate.slnx --no-restore` przechodzi.

#### Manual Verification

- Migracja aplikuje się do disposable SQL Server z istniejącymi sesjami bez utraty historii.
- Ręczne żądanie identycznego retry zwraca ten sam wpis, a próba zmiany zapisanej oceny zostaje odrzucona.

---

## Phase 3: Flutter Feedback Data Flow And Completion Signal

### Overview

Dodać modele, klienta API, kontroler formularza, projekcję feedbacku w historii i jednorazowy sygnał zakończonej sesji.

### Changes Required

#### 1. Feedback Models, API Client And Controller

**Files**:

- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_models.dart`
- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_api_client.dart`
- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_controller.dart`
- `apps/mobile/test/post_workout_feedback_models_test.dart`
- `apps/mobile/test/post_workout_feedback_api_client_test.dart`
- `apps/mobile/test/post_workout_feedback_controller_test.dart`

**Intent**: Utrzymać jawne stany formularza i bezpiecznie obsłużyć create, retry oraz konflikt nieedytowalności.

**Contract**:

- Model request wymaga oceny 1–5 i serializuje nullable, trimowany komentarz.
- Model response zawiera ID sesji, ocenę, komentarz i czas wysłania.
- Klient wysyła `POST /shared-sessions/{sessionId}/feedback` z bearer tokenem.
- Statusy rozróżniają sukces utworzenia/replay, walidację, konflikt, brak dostępu, offline i błąd.
- Controller przechowuje `sessionId`, ocenę, komentarz, stan wysyłania, komunikat błędu i zapisany response.
- Błąd nie czyści oceny ani komentarza.
- Podwójne tapnięcie podczas trwającego requestu nie wysyła drugiego żądania.
- Identyczny replay traktowany jest jako sukces.

#### 2. History Feedback Models

**Files**:

- `apps/mobile/lib/training_history/training_history_models.dart`
- `apps/mobile/test/training_history_models_test.dart`

**Intent**: Parsować opcjonalny feedback bez naruszania zgodności sesji historycznych.

**Contract**:

- `TrainingHistorySession` otrzymuje nullable `feedback`.
- Model feedbacku parsuje ocenę, nullable komentarz i `submittedAt`.
- `feedback: null` jest poprawnym stanem.
- Niepoprawna ocena lub typ pola powodują `FormatException`.

#### 3. One-Shot Completed Session Signal

**Files**:

- `apps/mobile/lib/shared_sessions/shared_session_controller.dart`
- `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- `apps/mobile/test/shared_session_controller_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`

**Intent**: Dostarczyć ID zakończonej sesji do shell zarówno po lokalnym `complete`, jak i po terminalnym snapshotcie realtime.

**Contract**:

- Stan kontrolera wystawia konsumowalny event zakończonej sesji z `sessionId`.
- Event powstaje tylko przy przejściu tej samej sesji z `active` do `completed`.
- Lokalna odpowiedź `complete` i odpowiadający jej późniejszy snapshot realtime nie tworzą dwóch eventów.
- Snapshot o starszej wersji i rebuild nie odtwarzają skonsumowanego eventu.
- Kontroler zachowuje identyfikator ostatniej znanej aktywnej sesji do recovery po reconnect.
- Po reconnect kontroler odświeża znany `sessionId` ścieżką dopuszczającą completed snapshot i emituje pending event, jeżeli broadcast zakończenia został utracony i event nie został wcześniej skonsumowany.
- Reconnect bez zmiany statusu oraz już skonsumowane zakończenie nie odtwarzają eventu.
- `cancelled` nie tworzy eventu feedbacku.
- `LiveSessionScreen` nie czyści samodzielnie ID sesji przed obsługą eventu.

#### 4. Dependency Wiring And History Refresh

**Files**:

- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- `apps/mobile/lib/training_history/training_history_controller.dart`
- odpowiednie testy konstruktorów i shell

**Intent**: Wstrzyknąć klienta feedbacku, zarządzać kontrolerem formularza i odświeżać właściwy szczegół historii po zapisie.

**Contract**:

- Produkcyjny klient używa tego samego `API_BASE_URL`.
- `AuthScreen` przyjmuje opcjonalny klient feedbacku z produkcyjnym defaultem zgodnym z istniejącym wzorcem klientów.
- Pełny blast radius konstruktorów obejmuje `main.dart`, `auth_screen.dart`, `authenticated_relationship_shell.dart` oraz testy `auth_screen_test.dart`, `trainee_assigned_workout_sets_screen_test.dart`, `workout_set_trainer_screens_test.dart` i `post_auth_relationship_screen_test.dart`.
- Testy shella wstrzykują klient feedbacku przez ten sam `MockClient`, który obsługuje pozostałe requesty scenariusza.
- Shell konsumuje terminalny event tylko dla roli podopiecznego.
- ID sesji jest zachowane przed `clearSession()`.
- Po sukcesie feedbacku otwartego z historii szczegół sesji zostaje ponownie pobrany.
- Wylogowanie, zmiana użytkownika i dispose czyszczą kontroler oraz pending prompt.

### Success Criteria

#### Automated Verification

- Modele feedbacku poprawnie serializują, parsują i odrzucają niepoprawne dane.
- Klient wysyła prawidłową ścieżkę, token i body oraz mapuje `200`, `201`, `400`, `404`, `409` i offline.
- Controller zachowuje wpisane dane przy błędzie i blokuje równoległe submit.
- Historia parsuje wpis i `null`.
- Lokalny complete emituje jeden event z właściwym ID.
- Realtime `active → completed` emituje jeden event dla sesji wspólnej.
- Duplikat HTTP/realtime i starszy snapshot nie otwierają drugiego promptu.
- Utracony broadcast po reconnect jest odzyskiwany przez odświeżenie znanego `sessionId` i otwiera co najwyżej jeden prompt.
- Cancel nie emituje eventu.
- Po zapisie z historii controller odświeża właściwy detail.
- Targeted Flutter tests dla modeli, klienta, controllera i shared session przechodzą.
- Pełne `flutter test` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- Symulowany błąd sieci zachowuje ocenę i komentarz po ponownym renderze.
- Zakończenie wspólnej sesji przez trenera nie otwiera formularza więcej niż raz u podopiecznego.

---

## Phase 4: Feedback Form And Role-Aware History UI

### Overview

Zaimplementować ekran zgodny z Design, routing po obu typach treningu oraz read-only sekcję w historii.

### Changes Required

#### 1. Post-Workout Feedback Form

**Files**:

- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_screen.dart`
- `apps/mobile/test/post_workout_feedback_screen_test.dart`

**Intent**: Pozwolić szybko ocenić samopoczucie, opcjonalnie dodać komentarz i bezpiecznie ponowić zapis.

**Contract**:

- UI odpowiada ekranowi z `LiftMate.dc.html`.
- Pięć przycisków ma widoczny stan wyboru i etykiety semantyczne z wartością oraz opisem.
- `Wyślij feedback` jest disabled bez oceny i podczas wysyłania.
- Pole komentarza ma limit oraz licznik 1000 znaków.
- Błąd jest czytelny, nie usuwa danych i oferuje `Spróbuj ponownie`.
- Back lub `Pomiń` przed zapisem pokazuje dialog `Pominąć feedback?`.
- Sukces pokazuje `Dzięki! Feedback został zapisany.` i wywołuje właściwy callback nawigacji.
- Formularz nie oferuje edycji istniejącego wpisu.

#### 2. Immediate Prompt Navigation

**Files**:

- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`

**Intent**: Otworzyć formularz po zakończeniu samodzielnej i wspólnej sesji, bez utraty obecnych komunikatów zapisu progresu.

**Contract**:

- Po lokalnym zakończeniu sesji podopieczny trafia do formularza z właściwym `sessionId`.
- Po terminalnym snapshotcie wspólnej sesji podopieczny trafia do tego samego formularza.
- Trener po zakończeniu sesji zachowuje dotychczasowy powrót do dashboardu i nie widzi formularza.
- `Pomiń` po potwierdzeniu wraca do pulpitu podopiecznego.
- Sukces wraca do pulpitu i zachowuje komunikat o zapisaniu wartości na następny trening, jeśli dotyczy.
- Brak sieci nie zamyka formularza; użytkownik może ponowić lub świadomie pominąć.

#### 3. Feedback In Training History Detail

**Files**:

- `apps/mobile/lib/training_history/training_history_flow.dart`
- `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- `apps/mobile/test/training_history_flow_test.dart`

**Intent**: Pokazać zapisany feedback przy właściwej sesji i umożliwić podopiecznemu późniejsze uzupełnienie.

**Contract**:

- Sekcja feedbacku jest renderowana przed listą ćwiczeń.
- `TrainingHistoryFlow` dostaje z shella jawny `viewerRole` oraz capability/callback dodania feedbacku; nie wnioskuje roli z `traineeUserId`, sesji ani obecności danych.
- Zaktualizować oba call sites shella: wejście trenera oraz wejście podopiecznego.
- Zapisany wpis pokazuje ocenę `N/5`, opis oceny, komentarz lub `Bez komentarza`.
- Podopieczny bez wpisu widzi `Dodaj feedback` tylko gdy `viewerRole` to trainee i callback jest dostępny; akcja otwiera formularz dla bieżącego ID sesji.
- Trener bez wpisu widzi `Brak feedbacku` i nie ma akcji zapisu.
- Po sukcesie z historii formularz wraca do szczegółu i pokazuje odświeżony read-only wpis.
- Próba cofnięcia z niezapisanymi danymi wymaga potwierdzenia; po potwierdzeniu wraca do szczegółu historii, nie do pulpitu.

### Success Criteria

#### Automated Verification

- Formularz blokuje submit bez oceny i poprawnie wybiera wartości 1–5.
- Wszystkie opcje oceny mają poprawne etykiety semantyczne.
- Licznik i limit komentarza działają dla 0, 1000 i próby przekroczenia limitu.
- Loading blokuje duplikat, a błąd zachowuje dane i pozwala ponowić.
- Dialog pominięcia działa dla CTA i systemowego back.
- Samodzielne zakończenie otwiera formularz z właściwym ID.
- Zakończenie wspólne przez realtime otwiera formularz raz.
- Trener nie otrzymuje formularza po zakończeniu prowadzonej sesji.
- `TrainingHistoryFlow` używa jawnego `viewerRole` i callbacku; trainer/trainee call sites oraz testy konstruktorów nie inferują roli z danych sesji.
- Historia podopiecznego pokazuje `Dodaj feedback`; historia trenera pokazuje `Brak feedbacku`.
- Zapisany wpis jest read-only i pojawia się tylko przy właściwej sesji.
- Targeted widget tests przechodzą.
- Pełne `flutter test` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- Formularz odpowiada zatwierdzonemu `LiftMate.dc.html` na telefonowym viewportcie.
- Klawiatura, pole komentarza, licznik i przyciski nie powodują overflow.
- Pomiń, retry i sukces prowadzą do właściwych ekranów z czytelnym copy.
- Trener i podopieczny widzą właściwe warianty sekcji historii.

---

## Phase 5: Cross-Stack Verification And Change Closure

### Overview

Zweryfikować migrację, autoryzację, oba rodzaje treningu, retry, nawigację i brak regresji przed zmianą statusu S-09.

### Changes Required

#### 1. Coordinated Regression Coverage

**Files**:

- `apps/api/LiftMate.Api.Tests/SharedSessions/PostWorkoutFeedbackEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- `apps/mobile/test/training_history_flow_test.dart`
- `apps/mobile/test/post_workout_feedback_screen_test.dart`

**Intent**: Udowodnić pełny przepływ `complete → feedback → historia trenera` przez realistyczny zestaw testów backend HTTP, backend SignalR i Flutter fake realtime, zamiast zakładać jeden niedostępny harness cross-stack.

**Contract**:

- Backend HTTP test obejmuje `complete → feedback → historia` dla treningu samodzielnego.
- Backend HTTP test obejmuje zapis feedbacku i projekcję historii dla sesji wspólnej zakończonej przez trenera.
- Backend SignalR test potwierdza completion broadcast dla podopiecznego po zakończeniu sesji przez trenera.
- Flutter test z fake realtime potwierdza `completed snapshot → pojedynczy prompt → feedback API`.
- Test offline/pominięcia potwierdza możliwość późniejszego zapisu z historii.
- Test retry potwierdza brak duplikacji i brak edycji pierwszego wpisu.
- Test autoryzacji potwierdza aktualnego, byłego i obcego trenera.
- Test regresji potwierdza, że `complete`, progres, historia ćwiczeń i realtime nadal działają.

#### 2. Verification And Bookkeeping

**Files**:

- `context/changes/post-workout-feedback/change.md`
- `context/changes/post-workout-feedback/plan.md`
- `context/foundation/roadmap.md`

**Intent**: Zamknąć zmianę dopiero po pełnej automatycznej i jawnie potwierdzonej manualnej weryfikacji.

**Contract**:

- Przed manualnym QA `change.md` pozostaje `implementing`, a roadmap S-09 pozostaje niedone.
- Po jawnej akceptacji manualnej ustawić `change.md` na `implemented`, zaktualizować `updated`, oznaczyć S-09 jako `done` we wszystkich kanonicznych miejscach roadmapy i uzupełnić manualne checkboxy.
- Archiwizacja pozostaje osobną komendą `/10x-archive post-workout-feedback`.

### Success Criteria

#### Automated Verification

- `dotnet restore LiftMate.slnx` przechodzi.
- `dotnet build LiftMate.slnx --no-restore` przechodzi.
- Pełne `dotnet test LiftMate.slnx --no-build --verbosity minimal` przechodzi.
- Pełne `flutter test` przechodzi.
- `flutter analyze` przechodzi.
- Idempotentny skrypt migracji generuje się bez błędu.
- Skoordynowane testy backend HTTP, backend SignalR i Flutter fake realtime pokrywają oba typy treningu, późniejsze uzupełnienie, retry i autoryzację.
- Roadmap S-09 pozostaje niedone przed manualnym potwierdzeniem.

#### Manual Verification

- Podopieczny kończy trening samodzielny, wysyła ocenę i widzi zapis w swojej historii.
- Trener widzi ten sam read-only feedback przy właściwej sesji.
- Trener kończy trening wspólny, a podopieczny otrzymuje formularz dokładnie raz.
- Pominięty lub przerwany feedback można później dodać z historii.
- Błąd sieci zachowuje ocenę i komentarz, a retry zapisuje wpis bez duplikatu.
- Próba ponownej zmiany wysłanego feedbacku nie jest dostępna w UI i jest odrzucana przez API.
- Były i obcy trener nie widzą historii ani feedbacku podopiecznego.
- Istniejące sesje bez feedbacku pozostają czytelne.
- Formularz i sekcja historii odpowiadają zatwierdzonemu Design.
- Po wszystkich kontrolach użytkownik zatwierdza zamknięcie S-09.

---

## Testing Strategy

### API Unit And Integration Tests

- Walidacja oceny, komentarza i normalizacji pustego tekstu.
- Jeden wpis na sesję oraz zachowanie przy równoległych żądaniach.
- Identyczny replay kontra próba zmiany zapisanej treści.
- Status sesji: active, completed, cancelled i missing.
- Właściciel sesji, trener, obcy podopieczny i brak uwierzytelnienia.
- Sesja samodzielna oraz wspólna.
- Projekcja feedbacku w historii i zgodność `null` dla starych sesji.
- Dostęp aktualnego, byłego i obcego trenera.
- Generowanie idempotentnego skryptu migracji SQL Server.

### Flutter Unit, Controller And Widget Tests

- JSON request/response oraz opcjonalny feedback historii.
- Statusy klienta API, timeout, błąd formatu i konflikt.
- Stan formularza, retry, podwójny tap i zachowanie komentarza.
- Jednorazowy event zakończenia z HTTP i realtime.
- Brak eventu dla cancel i starszego snapshotu oraz recovery utraconego completed snapshot po reconnect bez duplikatu promptu.
- Formularz 1–5, semantyka, limit 1000, loading i dialog pominięcia.
- Routing po treningu samodzielnym i wspólnym.
- Role-aware sekcja historii oraz odświeżenie po zapisie.

### Manual Testing Steps

1. Zakończ trening samodzielny jako podopieczny i wyślij ocenę z komentarzem.
2. Otwórz tę sesję w historii podopiecznego i potwierdź read-only wpis.
3. Otwórz tę samą sesję jako aktualny trener.
4. Zakończ trening wspólny jako trener i potwierdź pojedynczy prompt u podopiecznego.
5. Pomiń prompt, przejdź do historii i dodaj feedback później.
6. Przerwij sieć podczas wysyłki, potwierdź zachowanie danych i wykonaj retry.
7. Ponów identyczne żądanie i spróbuj wysłać zmienioną treść.
8. Sprawdź sesję bez feedbacku dla obu ról.
9. Zmień przypisanie trenera i zweryfikuj obecne granice dostępu historii.
10. Sprawdź formularz z otwartą klawiaturą i komentarzem 1000 znaków na telefonowym viewportcie.

## Performance Considerations

- Odczyt szczegółu sesji dołącza co najwyżej jeden rekord feedbacku.
- PK/FK na `SharedSessionId` zapewnia tani lookup i unikalność bez dodatkowego indeksu.
- Lista historii nie jest rozszerzana o feedback, więc paginacja i payload pozostają bez zmian.
- Controller mobile nie wykonuje automatycznych retry w pętli; użytkownik jawnie ponawia zapis.
- Event terminalny jest konsumowany raz i nie powoduje ponownego fetchowania przy rebuildzie.
- S-10 może później odpytywać oceny po czasie zakończenia; jeżeli plan S-10 wykaże potrzebę dodatkowego indeksu sesji, należy go dodać tam na podstawie rzeczywistego zapytania.

## Migration Notes

- Migracja dodaje wyłącznie tabelę feedbacku i relację do istniejących `SharedSessions`.
- Istniejące sesje nie otrzymują sztucznego feedbacku i zwracają `null`.
- Migracja musi działać istniejącą ścieżką EF Core/SQL Server i być sprawdzona idempotentnym skryptem.
- Testy endpointów na SQLite `EnsureCreated()` nie zastępują smoke testu migracji SQL Server.
- `Down` usuwa tabelę feedbacku; rollback po produkcyjnym zapisie traci nowe dane feedbacku, ale nie narusza sesji ani historii treningowej.

## References

- Change identity: `context/changes/post-workout-feedback/change.md`
- GitHub issue: `https://github.com/jdemb/PrototypApka/issues/27`
- Roadmap S-09: `context/foundation/roadmap.md`
- PRD US-01: `context/foundation/prd-expansion.md`
- Design contract: `apps/mobile/design/LiftMate.dc.html`
- Design lesson: `context/foundation/lessons.md`
- Session lifecycle: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- Session model: `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- History API: `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- History authorization: `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryAccess.cs`
- Mobile session controller: `apps/mobile/lib/shared_sessions/shared_session_controller.dart`
- Mobile shell: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`
- Mobile history flow: `apps/mobile/lib/training_history/training_history_flow.dart`
- Similar completed-session plan: `context/changes/save-progress-next-session/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Design Contract For Feedback Flow

#### Automated

- [x] 1.1 `rg -n "Jak się czujesz po treningu|Wyślij feedback|Dodaj feedback|Feedback podopiecznego|Pominąć feedback" apps/mobile/design/LiftMate.dc.html` znajduje wszystkie zakontraktowane stany. — 225fcf8
- [x] 1.2 Design zachowuje poprawną składnię i otwiera się bez błędów skryptu w przeglądarce. — 225fcf8

#### Manual

- [ ] 1.3 Formularz, dialog pominięcia, błąd i sekcja historii są czytelne na telefonowym viewportcie bez overflow.
- [ ] 1.4 Copy i hierarchia wizualna są spójne z istniejącymi ekranami LiftMate.

### Phase 2: Additive Feedback Persistence And API Contract

#### Automated

- [x] 2.1 Model SQLite tworzy relację jeden-do-jednego i constraint oceny. — eef79c4
- [x] 2.2 Idempotentny skrypt migracji SQL Server zawiera addytywną tabelę oraz wymagane ograniczenia. — eef79c4
- [x] 2.3 Podopieczny tworzy feedback dla zakończonej sesji samodzielnej i wspólnej. — eef79c4
- [x] 2.4 Trener, obcy podopieczny i nieuwierzytelniony użytkownik nie mogą utworzyć feedbacku. — eef79c4
- [x] 2.5 Aktywna, anulowana i nieistniejąca sesja są odrzucane właściwym statusem. — eef79c4
- [x] 2.6 Oceny `0` i `6` oraz komentarz ponad 1000 znaków są odrzucane. — eef79c4
- [x] 2.7 Identyczny replay zwraca istniejący wpis bez zmiany czasu; inna treść zwraca `409`. — eef79c4
- [x] 2.8 Równoległe żądania nie tworzą dwóch wpisów i nie zmieniają pierwszego. — eef79c4
- [x] 2.9 Wyścig unikalności po `DbUpdateException` czyści EF tracker i ponownie odczytuje istniejący wpis bez błędu śledzenia. — eef79c4
- [x] 2.10 Szczegół historii zwraca właściwy feedback lub `null`. — eef79c4
- [x] 2.11 Aktualny trener ma dostęp, a były i obcy trener nie. — eef79c4
- [x] 2.12 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PostWorkoutFeedback"` przechodzi. — eef79c4
- [x] 2.13 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"` przechodzi. — eef79c4
- [x] 2.14 `dotnet build LiftMate.slnx --no-restore` przechodzi. — eef79c4

#### Manual

- [ ] 2.15 Migracja aplikuje się do disposable SQL Server z istniejącymi sesjami bez utraty historii.
- [ ] 2.16 Ręczne żądanie identycznego retry zwraca ten sam wpis, a próba zmiany zapisanej oceny zostaje odrzucona.

### Phase 3: Flutter Feedback Data Flow And Completion Signal

#### Automated

- [x] 3.1 Modele feedbacku poprawnie serializują, parsują i odrzucają niepoprawne dane. — 8493625
- [x] 3.2 Klient wysyła prawidłową ścieżkę, token i body oraz mapuje `200`, `201`, `400`, `404`, `409` i offline. — 8493625
- [x] 3.3 Controller zachowuje wpisane dane przy błędzie i blokuje równoległe submit. — 8493625
- [x] 3.4 Historia parsuje wpis i `null`. — 8493625
- [x] 3.5 Lokalny complete emituje jeden event z właściwym ID. — 8493625
- [x] 3.6 Realtime `active → completed` emituje jeden event dla sesji wspólnej. — 8493625
- [x] 3.7 Duplikat HTTP/realtime i starszy snapshot nie otwierają drugiego promptu. — 8493625
- [x] 3.8 Utracony broadcast po reconnect jest odzyskiwany przez odświeżenie znanego `sessionId` i otwiera co najwyżej jeden prompt. — 8493625
- [x] 3.9 Cancel nie emituje eventu. — 8493625
- [x] 3.10 Po zapisie z historii controller odświeża właściwy detail. — 8493625
- [x] 3.11 Targeted Flutter tests dla modeli, klienta, controllera i shared session przechodzą. — 8493625
- [x] 3.12 Pełne `flutter test` przechodzi. — 8493625
- [x] 3.13 `flutter analyze` przechodzi. — 8493625

#### Manual

- [ ] 3.14 Symulowany błąd sieci zachowuje ocenę i komentarz po ponownym renderze.
- [ ] 3.15 Zakończenie wspólnej sesji przez trenera nie otwiera formularza więcej niż raz u podopiecznego.

### Phase 4: Feedback Form And Role-Aware History UI

#### Automated

- [x] 4.1 Formularz blokuje submit bez oceny i poprawnie wybiera wartości 1–5.
- [x] 4.2 Wszystkie opcje oceny mają poprawne etykiety semantyczne.
- [x] 4.3 Licznik i limit komentarza działają dla 0, 1000 i próby przekroczenia limitu.
- [x] 4.4 Loading blokuje duplikat, a błąd zachowuje dane i pozwala ponowić.
- [x] 4.5 Dialog pominięcia działa dla CTA i systemowego back.
- [x] 4.6 Samodzielne zakończenie otwiera formularz z właściwym ID.
- [x] 4.7 Zakończenie wspólne przez realtime otwiera formularz raz.
- [x] 4.8 Trener nie otrzymuje formularza po zakończeniu prowadzonej sesji.
- [x] 4.9 `TrainingHistoryFlow` używa jawnego `viewerRole` i callbacku; trainer/trainee call sites oraz testy konstruktorów nie inferują roli z danych sesji.
- [x] 4.10 Historia podopiecznego pokazuje `Dodaj feedback`; historia trenera pokazuje `Brak feedbacku`.
- [x] 4.11 Zapisany wpis jest read-only i pojawia się tylko przy właściwej sesji.
- [x] 4.12 Targeted widget tests przechodzą.
- [x] 4.13 Pełne `flutter test` przechodzi.
- [x] 4.14 `flutter analyze` przechodzi.

#### Manual

- [ ] 4.15 Formularz odpowiada zatwierdzonemu `LiftMate.dc.html` na telefonowym viewportcie.
- [ ] 4.16 Klawiatura, pole komentarza, licznik i przyciski nie powodują overflow.
- [ ] 4.17 Pomiń, retry i sukces prowadzą do właściwych ekranów z czytelnym copy.
- [ ] 4.18 Trener i podopieczny widzą właściwe warianty sekcji historii.

### Phase 5: Cross-Stack Verification And Change Closure

#### Automated

- [ ] 5.1 `dotnet restore LiftMate.slnx` przechodzi.
- [ ] 5.2 `dotnet build LiftMate.slnx --no-restore` przechodzi.
- [ ] 5.3 Pełne `dotnet test LiftMate.slnx --no-build --verbosity minimal` przechodzi.
- [ ] 5.4 Pełne `flutter test` przechodzi.
- [ ] 5.5 `flutter analyze` przechodzi.
- [ ] 5.6 Idempotentny skrypt migracji generuje się bez błędu.
- [ ] 5.7 Skoordynowane testy backend HTTP, backend SignalR i Flutter fake realtime pokrywają oba typy treningu, późniejsze uzupełnienie, retry i autoryzację.
- [ ] 5.8 Roadmap S-09 pozostaje niedone przed manualnym potwierdzeniem.

#### Manual

- [ ] 5.9 Podopieczny kończy trening samodzielny, wysyła ocenę i widzi zapis w swojej historii.
- [ ] 5.10 Trener widzi ten sam read-only feedback przy właściwej sesji.
- [ ] 5.11 Trener kończy trening wspólny, a podopieczny otrzymuje formularz dokładnie raz.
- [ ] 5.12 Pominięty lub przerwany feedback można później dodać z historii.
- [ ] 5.13 Błąd sieci zachowuje ocenę i komentarz, a retry zapisuje wpis bez duplikatu.
- [ ] 5.14 Próba ponownej zmiany wysłanego feedbacku nie jest dostępna w UI i jest odrzucana przez API.
- [ ] 5.15 Były i obcy trener nie widzą historii ani feedbacku podopiecznego.
- [ ] 5.16 Istniejące sesje bez feedbacku pozostają czytelne.
- [ ] 5.17 Formularz i sekcja historii odpowiadają zatwierdzonemu Design.
- [ ] 5.18 Po wszystkich kontrolach użytkownik zatwierdza zamknięcie S-09.
