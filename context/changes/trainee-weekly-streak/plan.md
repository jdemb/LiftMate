# Tygodniowa seria regularnosci — Implementation Plan

> **Dla implementacji agentowej:** realizuj fazy osobno, test-first, z oddzielnym commitem dla kazdej fazy. Uzyj `superpowers:test-driven-development` przy zmianach produkcyjnych i `superpowers:verification-before-completion` przed deklaracja ukonczenia. Nie edytuj `context/archive/`.

## Overview

S-11 dodaje tygodniowa serie regularnosci dla podopiecznego. Do serii liczy sie co najmniej jeden zakonczony trening samodzielny albo wspolny w tygodniu od poniedzialku do niedzieli. Aktualna seria rosnie przy kolejnym aktywnym tygodniu, tydzien bez zakonczonego treningu zeruje aktualna serie, a najlepsza seria pozostaje zapisana.

Zakres UI jest szerszy niz samo US-03: podopieczny widzi serie na ekranie "Dzis", a trener widzi ja zgodnie z kontraktem HTML na liscie podopiecznych i na detalu podopiecznego.

## Current State Analysis

- Zakonczone sesje sa trwalym zrodlem historii: `SharedSession.Status == completed` i `ClosedAt != null` (`apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`).
- `POST /shared-sessions/{sessionId}/complete` atomowo ustawia `ClosedAt`, zapisuje progres i uruchamia ewaluator S-10 (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`).
- Historia listuje sesje podopiecznego po `ClosedAt`, z deterministycznym tie-breakerem po `Id` (`apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`).
- Relationship API zwraca liste podopiecznych trenera i podsumowanie relacji podopiecznego, ale nie zawiera jeszcze ostatniego treningu ani serii (`apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`).
- Mobile modele relacji nie maja miejsca na weekly streak (`apps/mobile/lib/relationships/relationship_models.dart`).
- Ekran trenera listuje podopiecznych bez informacji o ostatnim treningu ani plomieniu (`apps/mobile/lib/relationships/trainer_dashboard_screen.dart`).
- Detal podopiecznego ma juz sekcje S-10 i miejsce na dodatkowy kafel statystyk (`apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`).
- Ekran "Dzis" podopiecznego pokazuje trenera i przypisane zestawy, ale nie pokazuje motywacyjnej statystyki (`apps/mobile/lib/relationships/trainee_home_screen.dart`).
- `apps/mobile/design/LiftMate.dc.html` i `apps/mobile/design/LiftMate.html` pokazuja docelowy sygnal `🔥 {{ t.streak }}` pod ostatnim treningiem oraz kafel `🔥6 / seria` na detalu.
- Lekcja projektowa wymaga trzymania mobile UI blisko designu HTML (`context/foundation/lessons.md`).

## Desired End State

- Podopieczny widzi na ekranie "Dzis" aktualna serie, najlepsza serie i neutralna zachete przy `0`.
- Trener widzi na liscie podopiecznych tekst ostatniego zakonczonego treningu oraz pod spodem `🔥 N`, zgodnie z designem.
- Trener widzi na detalu podopiecznego kafel serii zgodny z designem, obok innych informacji relacji.
- API zwraca te same dane serii dla podopiecznego i aktualnego trenera, bez ujawniania danych obcym lub bylym trenerom.
- Istniejace zakonczone sesje zasilaja wynik, wiec uzytkownik z historia nie zaczyna od pustego stanu.
- Aktualna seria jest liczona wzgledem Europe/Warsaw i automatycznie spada do `0`, gdy ostatni aktywny tydzien jest starszy niz poprzedni tydzien.

## Key Decisions

| Area | Decision | Rationale |
|---|---|---|
| Podopieczny UI | Ekran "Dzis" | Seria ma byc motywacyjna i widoczna bez wchodzenia w historie. |
| Trener UI | Lista i detal podopiecznego | Uzytkownik wskazal kontrakt HTML: plomien + liczba pod ostatnim treningiem. |
| Persistence | Snapshot ostatniego aktywnego tygodnia + best | Tani odczyt i stabilny best streak bez stalego przeliczania historii. |
| Current on read | Liczony z snapshotu i obecnego tygodnia | Bez schedulera current moze spasc do `0` po pustym tygodniu. |
| Existing history | Backfill przez rekalkulacje brakujacych snapshotow | Istniejace dane daja sensowny wynik od pierwszego uzycia. |
| Timezone | Europe/Warsaw | Zgodne z beta; brak per-user timezone w obecnym modelu. |
| Zero state | Pokazac `0 tygodni` i neutralna zachete | Jawny stan i czytelna motywacja. |
| Counting | Wiele treningow w tygodniu liczy sie jako jeden aktywny tydzien | Zgodne z PRD. |

## What We're NOT Doing

- Nie dodajemy rankingow, odznak, powiadomien ani rozbudowanej grywalizacji.
- Nie dodajemy per-user timezone ani ustawien profilu.
- Nie liczymy serii per workout set, per cwiczenie ani per trener.
- Nie pozwalamy recznie edytowac serii.
- Nie zmieniamy historii treningow, feedbacku, S-10 guidance ani projekcji progresu.
- Nie edytujemy `context/archive/`.

## Implementation Approach

Implementacja idzie od kontraktu UI do trwalego snapshotu i prezentacji:

1. potwierdzic i ewentualnie doprecyzowac design serii w `LiftMate.dc.html` oraz `LiftMate.html`;
2. dodac model API `TraineeWeeklyStreak`, kalkulator tygodni Europe/Warsaw i migracje;
3. wpiac rekalkulacje po `Complete`, read-through backfill dla brakujacych snapshotow i rozszerzyc relationship responses;
4. dodac modele Flutter i UI na ekranach podopiecznego, listy trenera oraz detalu podopiecznego;
5. zweryfikowac edge cases tygodni, backfill, autoryzacje i brak regresji.

## Critical Implementation Details

### Snapshot zamiast prostego `current`

Nie zapisywac w bazie tylko `CurrentStreak` jako wartosci bezwzglednej. Aktualna seria zalezy od dzisiejszego tygodnia: jesli ostatni aktywny tydzien jest starszy niz poprzedni tydzien, current ma wynosic `0` bez zadnego zdarzenia domenowego.

Snapshot powinien przechowywac co najmniej:

- `TraineeUserId`;
- `LastActiveWeekStart`;
- `CurrentStreakAtLastActiveWeek`;
- `BestStreak`;
- `LastCompletedSessionAt`;
- `CalculatedAt`.

`LastActiveWeekStart` is a nullable local week-start date, not a timestamp:
use `DateOnly?` in the domain/EF model, map it to SQL Server `date`, and serialize
the DTO field `lastActiveWeekStart` as nullable ISO date `yyyy-MM-dd`.

DTO odczytu dopiero mapuje to do:

- `currentStreak`;
- `bestStreak`;
- `lastActiveWeekStart`;
- `lastCompletedWorkoutAt`;
- `isActiveThisWeek`;

gdzie `currentStreak == 0`, jesli `LastActiveWeekStart` jest starszy niz poprzedni tydzien wzgledem Europe/Warsaw.

### Granice tygodnia

Uzywac Europe/Warsaw dla mapowania `ClosedAt` na tydzien poniedzialek-niedziela. `ClosedAt` pozostaje `DateTimeOffset`, ale kalkulator wyznacza lokalna date i poniedzialek tego tygodnia. Testy musza objac niedziele/poniedzialek oraz przejscie przez rok.

### Testowalne zrodlo czasu

Odczyt `currentStreak` zalezy od aktualnego tygodnia, wiec nie opierac mappera response na ukrytym `DateTimeOffset.UtcNow`. Zarejestrowac i wstrzyknac `TimeProvider` w DI; `WeeklyStreakService` albo dedykowany mapper response uzywa `timeProvider.GetUtcNow()` jako jedynego zrodla "teraz". Testy endpointow moga wtedy ustawic kontrolowany czas i potwierdzic, ze pusty tydzien zeruje current.

### Rekalkulacja i backfill

Rekalkulacja dla jednego podopiecznego czyta wszystkie zakonczone sesje tego podopiecznego, bierze unikalne tygodnie z co najmniej jedna sesja i wylicza najdluzszy oraz najnowszy ciag kolejnych tygodni. Wiele sesji w jednym tygodniu nie zwieksza serii.

Po `Complete` serwis rekalkuluje snapshot w tej samej transakcji co zamkniecie sesji, po ustawieniu `ClosedAt`. Dla istniejacych danych brakujacy snapshot moze zostac utworzony przy odczycie relationship summary jako read-through inicjalizacja. Nie przeliczac bez potrzeby kazdego odczytu, jesli snapshot istnieje i jego `LastCompletedSessionAt` odpowiada najnowszej zakonczonej sesji.

### Relationship response jako kontrakt UI

Poniewaz trener potrzebuje serii na liscie podopiecznych, dane powinny wejsc do `GET /trainer/relationship` przy kazdym `TrainerTraineeResponse`. Podopieczny powinien dostac te same dane w `GET /trainee/relationship`, zeby ekran "Dzis" nie wymagal dodatkowego requestu. Zachowac role-based access: obcy trener nie ma sciezki do cudzego snapshotu.

### Ostatni trening dla listy trenera

Design wymaga `ostatnio ...` nad plomieniem. Rozszerzyc response o `lastCompletedWorkoutAt` i formatowac relatywny tekst po stronie Fluttera. Gdy brak treningow, pokazywac neutralne `nie zaczal` oraz `🔥 0`.

---

## Phase 1: Design Contract For Weekly Streak

### Overview

Potwierdzic, ze oba pliki designu zawieraja docelowe miejsca serii i doprecyzowac zero/loading/error state, jesli brakuje ich w HTML.

### Changes Required

#### 1. Reconcile streak design

**Files**:

- `apps/mobile/design/LiftMate.dc.html`
- `apps/mobile/design/LiftMate.html`

**Intent**: Utrzymac design jako kontrakt dla implementacji Flutter.

**Contract**:

- Lista podopiecznych trenera pokazuje pod ostatnim treningiem `🔥 {{ t.streak }}`.
- Detal podopiecznego pokazuje kafel `🔥N` z podpisem `seria`.
- Ekran podopiecznego "Dzis" pokazuje aktualna i najlepsza serie.
- Zakontraktowac stan `0`, brak historii i loading tak, aby tekst nie powodowal overflow.
- Zachowac obecny workflow `.dc.html` jako source-like i `LiftMate.html` jako artefakt docelowy, chyba ze implementer znajdzie jawny skrypt generowania.

### Success Criteria

#### Automated Verification

- `rg -n "🔥|seria|streak|ostatnio|nie zaczął" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html` potwierdza obecny kontrakt.
- `rg -n "Bundled Page|<x-dc|support.js" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html` zostal uzyty do potwierdzenia workflow source/artefakt albo opisany w notatce fazy.

#### Manual Verification

- Plomien i liczba na liscie podopiecznych sa pod informacja o ostatnim treningu.
- Kafel serii na detalu podopiecznego nie wypycha akcji `Historia` i `Zmień zestaw` poza sensowny pierwszy ekran.
- Ekran podopiecznego "Dzis" pokazuje serie bez zaklocania glownego CTA treningu.

---

## Phase 2: API Streak Snapshot And Week Calculator

### Overview

Dodac addytywny model snapshotu, migracje i czysty kalkulator tygodniowej serii.

### Changes Required

#### 1. Add weekly streak entity and EF configuration

**Files**:

- `apps/api/LiftMate.Api/WeeklyStreaks/TraineeWeeklyStreak.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddTraineeWeeklyStreaks.cs`
- `apps/api/LiftMate.Api/Migrations/<timestamp>_AddTraineeWeeklyStreaks.Designer.cs`
- `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`
- `apps/api/LiftMate.Api.Tests/Migrations/MigrationScriptTests.cs`

**Intent**: Przechowywac tani snapshot do relationship summaries bez utraty poprawnego zerowania current.

**Contract**:

- `TraineeUserId` jest PK albo ma unikalny indeks i FK do `AspNetUsers`.
- Encja przechowuje `LastActiveWeekStart`, `CurrentStreakAtLastActiveWeek`, `BestStreak`, `LastCompletedSessionAt`, `CalculatedAt`.
- `LastActiveWeekStart` jest `DateOnly?`, mapowane na SQL Server `date`; nie przechowuje strefy, godziny ani UTC midnight.
- Indeksy wspieraja odczyt po tablicy `TraineeUserId`.
- Migracja jest addytywna i nie modyfikuje `SharedSessions`.
- Constrainty pilnuja nieujemnych wartosci `CurrentStreakAtLastActiveWeek` i `BestStreak`.

#### 2. Add week calculator and projection DTO

**Files**:

- `apps/api/LiftMate.Api/WeeklyStreaks/WeeklyStreakCalculator.cs`
- `apps/api/LiftMate.Api/WeeklyStreaks/WeeklyStreakContracts.cs`
- `apps/api/LiftMate.Api.Tests/WeeklyStreaks/WeeklyStreakCalculatorTests.cs`

**Intent**: Zamknac kalendarzowa logike w jednym miejscu i przetestowac ja bez HTTP.

**Contract**:

- Kalkulator uzywa `TimeZoneInfo` dla Europe/Warsaw.
- Mapper response uzywa wstrzyknietego `TimeProvider`, nie bezposredniego `DateTimeOffset.UtcNow`.
- Tydzien zaczyna sie w poniedzialek lokalnej daty i konczy w niedziele.
- Wiele sesji w tym samym tygodniu daje jeden aktywny tydzien.
- Luki tygodniowe przerywaja aktualny ciag.
- `ToResponse(snapshot, now)` zwraca `currentStreak == 0`, gdy ostatni aktywny tydzien jest starszy niz poprzedni tydzien.
- Brak snapshotu zwraca `currentStreak=0`, `bestStreak=0`, `lastCompletedWorkoutAt=null`.

### Success Criteria

#### Automated Verification

- Kalkulator zwraca `1` dla jednej sesji w aktualnym tygodniu.
- Dwie sesje w tym samym tygodniu nadal daja `1`.
- Kolejne aktywne tygodnie zwiekszaja current i best.
- Pusty tydzien zeruje current przy odczycie, ale best pozostaje.
- Niedziela i poniedzialek Europe/Warsaw trafiaja do wlasciwych tygodni.
- Przejscie grudzien/styczen zachowuje kolejnosc tygodni.
- Idempotentny skrypt migracji SQL Server zawiera addytywna tabele i ograniczenia.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WeeklyStreak"` przechodzi.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"` przechodzi.

#### Manual Verification

- Migracja nie wymaga recznej transformacji istniejacych sesji.
- Semantyka `0`, `current` i `best` jest zrozumiala dla uzytkownika.

---

## Phase 3: API Recalculation And Relationship Contract

### Overview

Wpiac snapshot w lifecycle zakonczenia sesji oraz dodac DTO serii do relationship endpoints.

### Changes Required

#### 1. Add weekly streak service

**Files**:

- `apps/api/LiftMate.Api/WeeklyStreaks/WeeklyStreakService.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api/Program.cs`
- `apps/api/LiftMate.Api.Tests/WeeklyStreaks/WeeklyStreakServiceTests.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Rekalkulowac snapshot po kazdym faktycznym zakonczeniu sesji i unikac duplikowania logiki w endpointach.

**Contract**:

- `RecalculateForTraineeAsync(traineeUserId)` czyta wszystkie zakonczone sesje podopiecznego po `ClosedAt`.
- Serwis upsertuje jeden snapshot dla podopiecznego.
- Serwis albo mapper response otrzymuje `TimeProvider` z DI i uzywa go do wyliczania `currentStreak` na odczycie.
- `Complete` wywoluje serwis po ustawieniu `Completed/ClosedAt`, w tej samej transakcji, przed commitem.
- Ponowne `Complete` juz zakonczonej sesji nie zmienia snapshotu poza bezpieczna idempotencja.
- Sesje `active` i `cancelled` sa ignorowane.
- Trening samodzielny i wspolny licza sie tak samo.

#### 2. Add read-through initialization for existing history

**Files**:

- `apps/api/LiftMate.Api/WeeklyStreaks/WeeklyStreakService.cs`
- `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`

**Intent**: Uzytkownicy z istniejaca historia widza wynik od razu po wdrozeniu.

**Contract**:

- Relationship endpoints pobieraja snapshoty dla targetowanych podopiecznych.
- Jesli snapshotu brakuje, a podopieczny ma zakonczone sesje, endpoint inicjalizuje go przez serwis.
- Jesli snapshot istnieje, ale `LastCompletedSessionAt` jest starszy niz najnowsza zakonczona sesja, endpoint moze jednorazowo zrekalkulowac snapshot.
- Nie przeliczac snapshotu bez potrzeby na kazdym odczycie.
- Odczyt wielu podopiecznych trenera nie moze robic kosztownego N+1 ponad konieczne wykrycie brakujacych snapshotow.

#### 3. Extend relationship contracts

**Files**:

- `apps/api/LiftMate.Api/Auth/AuthContracts.cs`
- `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`
- `apps/api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs`

**Intent**: Dostarczyc dane dokladnie tam, gdzie UI ich potrzebuje.

**Contract**:

- `TrainerTraineeResponse` otrzymuje `weeklyStreak`.
- `TraineeRelationshipSummaryResponse` otrzymuje `weeklyStreak`.
- DTO zawiera `currentStreak`, `bestStreak`, `lastActiveWeekStart`, `lastCompletedWorkoutAt`, `isActiveThisWeek`.
- `lastActiveWeekStart` jest nullable ISO date string `yyyy-MM-dd`, a `lastCompletedWorkoutAt` pozostaje nullable ISO timestamp.
- `GET /trainer/relationship` zwraca serie tylko dla aktualnych podopiecznych danego trenera.
- `GET /trainee/relationship` zwraca serie tylko dla zalogowanego podopiecznego.
- Brak historii zwraca DTO z zerami, nie `null`, zeby mobile mial stabilny kontrakt.

### Success Criteria

#### Automated Verification

- Po zakonczeniu sesji samodzielnej snapshot tworzy sie lub aktualizuje.
- Po zakonczeniu sesji wspolnej snapshot tworzy sie lub aktualizuje.
- Dwie sesje w tym samym tygodniu nie zwiekszaja serii ponad jeden tydzien.
- Tydzien przerwy zeruje current w response, ale nie best.
- Relationship summary trenera zawiera weekly streak dla kazdego aktualnego podopiecznego.
- Relationship summary podopiecznego zawiera weekly streak zalogowanego podopiecznego.
- Obcy trener nie moze dostac cudzej serii przez relationship endpoint.
- Read-through inicjalizacja tworzy sensowny wynik dla istniejacych zakonczonych sesji.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WeeklyStreak"` przechodzi.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PairingEndpoint"` przechodzi.
- `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpoint"` przechodzi.

#### Manual Verification

- Response dla trenera pokazuje `lastCompletedWorkoutAt` i `weeklyStreak` zgodnie z tym samym podopiecznym.
- Read-through backfill nie powoduje widocznego opoznienia na typowej liczbie sesji beta.

---

## Phase 4: Flutter Models And Weekly Streak UI

### Overview

Rozszerzyc mobile relationship models i pokazac serie na ekranach podopiecznego oraz trenera zgodnie z designem.

### Changes Required

#### 1. Extend relationship models and formatting helpers

**Files**:

- `apps/mobile/lib/relationships/relationship_models.dart`
- `apps/mobile/lib/relationships/relationship_api_client.dart`
- `apps/mobile/lib/relationships/relationship_formatters.dart`
- `apps/mobile/test/relationship_api_client_test.dart`
- `apps/mobile/test/relationship_controller_test.dart`
- `apps/mobile/test/relationship_models_test.dart` if present or new

**Intent**: Parsowac stabilny kontrakt API i trzymac copy/formatowanie w jednym miejscu.

**Contract**:

- Dodac model `WeeklyStreakSummary`.
- `TrainerTraineeSummary` i `TraineeRelationshipSummary` zawieraja `weeklyStreak`.
- Parsowanie odrzuca niepoprawne typy i akceptuje `lastCompletedWorkoutAt: null`.
- Helper formatuje:
  - `🔥 0`, `🔥 1`, `🔥 N`;
  - `0 tygodni`, `1 tydzień`, `2 tygodnie`, `5 tygodni`;
  - ostatni trening jako `dzisiaj`, `wczoraj`, `N dni temu`, `nie zaczął`.

#### 2. Add trainee home streak card

**Files**:

- `apps/mobile/lib/relationships/trainee_home_screen.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Pokazac podopiecznemu aktualna i najlepsza serie na ekranie "Dzis".

**Contract**:

- Karta pojawia sie dla podopiecznego z polaczonym trenerem.
- Pokazuje aktualna serie i najlepsza serie.
- Przy `currentStreak == 0` pokazuje neutralna zachete, bez alarmowego tonu.
- Nie blokuje listy przypisanych zestawow ani CTA startu treningu.
- Loading relationship nadal zachowuje obecne zachowanie.

#### 3. Add trainer list flame and last workout copy

**Files**:

- `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Dopasowac liste podopiecznych do HTML: ostatni trening i plomien z liczba.

**Contract**:

- Pod email/subtitle podopiecznego pokazac `ostatnio ...` albo `nie zaczął`.
- Pod tym pokazac `🔥 N`.
- Aktywna sesja badge pozostaje widoczna i nie nachodzi na streak.
- Dlugie imie/email nie powoduje overflow.

#### 4. Add trainer trainee detail streak card

**Files**:

- `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- `apps/mobile/test/trainer_trainee_detail_screen_test.dart`

**Intent**: Pokazac serie na detalu podopiecznego zgodnie z kaflem `🔥N seria` z designu.

**Contract**:

- Kafel serii jest pod naglowkiem osoby i aktywnym CTA, przed lub obok sekcji `Podpowiedzi`, zgodnie z designem.
- Pokazuje aktualna i najlepsza serie albo przynajmniej aktualna serie z podpisem `seria`.
- Nie usuwa ani nie degraduje sekcji S-10.
- Brak danych historii pokazuje `🔥0` i neutralny opis.

### Success Criteria

#### Automated Verification

- Mobile modele parsuja `weeklyStreak` dla trenera i podopiecznego.
- Formatter poprawnie odmienia `tydzień/tygodnie/tygodni`.
- Formatter ostatniego treningu obsluguje null, dzisiaj, wczoraj i kilka dni temu.
- Ekran "Dzis" pokazuje aktualna i najlepsza serie.
- Lista trenera pokazuje `ostatnio ...` i `🔥 N` dla podopiecznego.
- Detal podopiecznego pokazuje kafel serii bez usuwania `Podpowiedzi`.
- `flutter test test/relationship_api_client_test.dart test/relationship_controller_test.dart test/post_auth_relationship_screen_test.dart test/trainer_trainee_detail_screen_test.dart` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- UI pozostaje zgodny z `apps/mobile/design/LiftMate.html`.
- Teksty nie nachodza na siebie na telefonowym viewportcie.
- `🔥 0` wyglada neutralnie i nie sugeruje bledu.

---

## Phase 5: Cross-Feature Verification And Closeout

### Overview

Zweryfikowac caly przeplyw od zakonczenia sesji do UI oraz regresje w historii, S-10 i relacjach.

### Success Criteria

#### Automated Verification

- Pelny zestaw komend API z Phase 5 przechodzi z katalogu `apps/api`:

Run from `apps/api`:

```powershell
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WeeklyStreak"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PairingEndpoint"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpoint"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainingHistory"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~TrainerGuidance"
dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"
dotnet test LiftMate.slnx --no-build --verbosity minimal
```

- Pelny zestaw komend mobile z Phase 5 przechodzi z katalogu `apps/mobile`:

Run from `apps/mobile`:

```powershell
flutter test test/relationship_api_client_test.dart test/relationship_controller_test.dart test/post_auth_relationship_screen_test.dart test/trainer_trainee_detail_screen_test.dart
flutter test
flutter analyze
```

#### Manual Verification

- Podopieczny bez zakonczonych treningow widzi `0` i neutralna zachete.
- Podopieczny po pierwszym zakonczonym treningu w tygodniu widzi aktualna serie `1`.
- Dwa treningi w tym samym tygodniu nie zwiekszaja serii ponad `1`.
- Trening w kolejnym tygodniu zwieksza serie.
- Pusty tydzien zeruje aktualna serie, ale najlepsza zostaje.
- Trener widzi `🔥 N` pod ostatnim treningiem na liscie podopiecznych.
- Trener widzi kafel serii na detalu podopiecznego.
- Sesja zakonczona przez trenera i sesja zakonczona przez podopiecznego licza sie tak samo.
- Obcy albo byly trener nie widzi serii podopiecznego.
- S-10 `Podpowiedzi`, historia treningow i feedback S-09 nadal dzialaja.

## Performance Considerations

- Relationship summary moze pobierac snapshoty dla wielu podopiecznych jednym zapytaniem po `TraineeUserId`.
- Rekalkulacja po `Complete` czyta wszystkie zakonczone sesje jednego podopiecznego; dla skali beta to akceptowalne.
- Jesli liczba sesji wzrosnie, mozna zoptymalizowac rekalkulacje do inkrementalnego dodawania tygodnia, ale MVP powinno zostac proste i deterministyczne.
- Read-through backfill ma dzialac tylko dla brakujacych lub nieaktualnych snapshotow.

## Migration Notes

- Migracja dodaje tabele snapshotow i indeksy.
- Nie backfilluje masowo danych w SQL, zeby uniknac skomplikowanej logiki kalendarzowej w migracji.
- Istniejace sesje pozostaja nienaruszone.
- Rollback usuwa snapshoty serii, ale nie narusza historii treningow.

## References

- Change identity: `context/changes/trainee-weekly-streak/change.md`
- GitHub issue: `https://github.com/jdemb/PrototypApka/issues/31`
- Roadmap S-11: `context/foundation/roadmap.md`
- PRD US-03: `context/foundation/prd-expansion.md`
- Design contract: `apps/mobile/design/LiftMate.dc.html`, `apps/mobile/design/LiftMate.html`
- Session lifecycle: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- Session model: `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- Relationship API: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs`
- Training history reference: `apps/api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs`
- Mobile trainee home: `apps/mobile/lib/relationships/trainee_home_screen.dart`
- Mobile trainer list: `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`
- Mobile trainee detail: `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- Similar materialization pattern: `context/changes/trainer-history-guidance/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Design Contract For Weekly Streak

#### Automated

- [x] 1.1 `rg -n "🔥|seria|streak|ostatnio|nie zaczął" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html` potwierdza obecny kontrakt. — 96090fb
- [x] 1.2 `rg -n "Bundled Page|<x-dc|support.js" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html` zostal uzyty do potwierdzenia workflow source/artefakt albo opisany w notatce fazy. — 96090fb

#### Manual

- [ ] 1.3 Plomien i liczba na liscie podopiecznych sa pod informacja o ostatnim treningu.
- [ ] 1.4 Kafel serii na detalu podopiecznego nie wypycha akcji `Historia` i `Zmień zestaw` poza sensowny pierwszy ekran.
- [ ] 1.5 Ekran podopiecznego "Dzis" pokazuje serie bez zaklocania glownego CTA treningu.

### Phase 2: API Streak Snapshot And Week Calculator

#### Automated

- [x] 2.1 Kalkulator zwraca `1` dla jednej sesji w aktualnym tygodniu. — d032684
- [x] 2.2 Dwie sesje w tym samym tygodniu nadal daja `1`. — d032684
- [x] 2.3 Kolejne aktywne tygodnie zwiekszaja current i best. — d032684
- [x] 2.4 Pusty tydzien zeruje current przy odczycie, ale best pozostaje. — d032684
- [x] 2.5 Niedziela i poniedzialek Europe/Warsaw trafiaja do wlasciwych tygodni. — d032684
- [x] 2.6 Przejscie grudzien/styczen zachowuje kolejnosc tygodni. — d032684
- [x] 2.7 Idempotentny skrypt migracji SQL Server zawiera addytywna tabele i ograniczenia. — d032684
- [x] 2.8 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WeeklyStreak"` przechodzi. — d032684
- [x] 2.9 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~MigrationScript"` przechodzi. — d032684

#### Manual

- [ ] 2.10 Migracja nie wymaga recznej transformacji istniejacych sesji.
- [ ] 2.11 Semantyka `0`, `current` i `best` jest zrozumiala dla uzytkownika.

### Phase 3: API Recalculation And Relationship Contract

#### Automated

- [x] 3.1 Po zakonczeniu sesji samodzielnej snapshot tworzy sie lub aktualizuje. — b27fc21
- [x] 3.2 Po zakonczeniu sesji wspolnej snapshot tworzy sie lub aktualizuje. — b27fc21
- [x] 3.3 Dwie sesje w tym samym tygodniu nie zwiekszaja serii ponad jeden tydzien. — b27fc21
- [x] 3.4 Tydzien przerwy zeruje current w response, ale nie best. — b27fc21
- [x] 3.5 Relationship summary trenera zawiera weekly streak dla kazdego aktualnego podopiecznego. — b27fc21
- [x] 3.6 Relationship summary podopiecznego zawiera weekly streak zalogowanego podopiecznego. — b27fc21
- [x] 3.7 Obcy trener nie moze dostac cudzej serii przez relationship endpoint. — b27fc21
- [x] 3.8 Read-through inicjalizacja tworzy sensowny wynik dla istniejacych zakonczonych sesji. — b27fc21
- [x] 3.9 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~WeeklyStreak"` przechodzi. — b27fc21
- [x] 3.10 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~PairingEndpoint"` przechodzi. — b27fc21
- [x] 3.11 `dotnet test LiftMate.slnx --no-restore --filter "FullyQualifiedName~SharedSessionEndpoint"` przechodzi. — b27fc21

#### Manual

- [ ] 3.12 Response dla trenera pokazuje `lastCompletedWorkoutAt` i `weeklyStreak` zgodnie z tym samym podopiecznym.
- [ ] 3.13 Read-through backfill nie powoduje widocznego opoznienia na typowej liczbie sesji beta.

### Phase 4: Flutter Models And Weekly Streak UI

#### Automated

- [x] 4.1 Mobile modele parsuja `weeklyStreak` dla trenera i podopiecznego. — eefd9e9
- [x] 4.2 Formatter poprawnie odmienia `tydzień/tygodnie/tygodni`. — eefd9e9
- [x] 4.3 Formatter ostatniego treningu obsluguje null, dzisiaj, wczoraj i kilka dni temu. — eefd9e9
- [x] 4.4 Ekran "Dzis" pokazuje aktualna i najlepsza serie. — eefd9e9
- [x] 4.5 Lista trenera pokazuje `ostatnio ...` i `🔥 N` dla podopiecznego. — eefd9e9
- [x] 4.6 Detal podopiecznego pokazuje kafel serii bez usuwania `Podpowiedzi`. — eefd9e9
- [x] 4.7 `flutter test test/relationship_api_client_test.dart test/relationship_controller_test.dart test/post_auth_relationship_screen_test.dart test/trainer_trainee_detail_screen_test.dart` przechodzi. — eefd9e9
- [x] 4.8 `flutter analyze` przechodzi. — eefd9e9

#### Manual

- [ ] 4.9 UI pozostaje zgodny z `apps/mobile/design/LiftMate.html`.
- [ ] 4.10 Teksty nie nachodza na siebie na telefonowym viewportcie.
- [ ] 4.11 `🔥 0` wyglada neutralnie i nie sugeruje bledu.

### Phase 5: Cross-Feature Verification And Closeout

#### Automated

- [x] 5.1 Pelny zestaw komend API z Phase 5 przechodzi z katalogu `apps/api`.
- [x] 5.2 Pelny zestaw komend mobile z Phase 5 przechodzi z katalogu `apps/mobile`.

#### Manual

- [ ] 5.3 Podopieczny bez zakonczonych treningow widzi `0` i neutralna zachete.
- [ ] 5.4 Podopieczny po pierwszym zakonczonym treningu w tygodniu widzi aktualna serie `1`.
- [ ] 5.5 Dwa treningi w tym samym tygodniu nie zwiekszaja serii ponad `1`.
- [ ] 5.6 Trening w kolejnym tygodniu zwieksza serie.
- [ ] 5.7 Pusty tydzien zeruje aktualna serie, ale najlepsza zostaje.
- [ ] 5.8 Trener widzi `🔥 N` pod ostatnim treningiem na liscie podopiecznych.
- [ ] 5.9 Trener widzi kafel serii na detalu podopiecznego.
- [ ] 5.10 Sesja zakonczona przez trenera i sesja zakonczona przez podopiecznego licza sie tak samo.
- [ ] 5.11 Obcy albo byly trener nie widzi serii podopiecznego.
- [ ] 5.12 S-10 `Podpowiedzi`, historia treningow i feedback S-09 nadal dzialaja.
