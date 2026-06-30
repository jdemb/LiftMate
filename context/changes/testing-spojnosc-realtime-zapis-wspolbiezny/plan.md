# Spójność Realtime i Współbieżny Zapis Sesji — Implementation Plan

## Overview

Rollout Phase 1 ustanawia jednoznaczny kontrakt współbieżności aktywnej sesji. Dwa równoległe zapisy zachowują atomowy last-write-wins z unikalnymi, monotonicznymi wersjami, a zapis ścigający się z `complete` lub `cancel` jest liniowo uporządkowany względem terminalnej mutacji. API odpowiada i publikuje przez SignalR wyłącznie kanoniczny snapshot odczytany po commicie.

Plan zaczyna od regresji integracyjnych API, następnie wprowadza minimalną zmianę produkcyjną bez migracji i bez zmiany wire contract, a kończy pełną weryfikacją istniejących zabezpieczeń mobile oraz uzupełnieniem cookbook w `context/foundation/test-plan.md`.

## Current State Analysis

- Mobile ma już automatic reconnect, rejoin grupy, REST reconciliation po ID, nieblokujący banner, guard niższej wersji oraz ochronę przed eventem obcej sesji (`apps/mobile/lib/shared_sessions/shared_session_controller.dart:426-529`, `apps/mobile/lib/shared_sessions/live_session_screen.dart:125-141`).
- Istniejące testy mobile pokrywają reconnect, retry, banner, stale snapshot i cross-session replacement (`apps/mobile/test/shared_session_controller_test.dart:267-435`, `apps/mobile/test/live_session_screen_test.dart:404-455`, `apps/mobile/test/post_auth_relationship_screen_test.dart:900-965`).
- `UpdateValue` wykonuje read/check/mutate/`Version += 1`/save/broadcast bez transakcji serializującej (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:399-459`).
- `Cancel` ma analogicznie słabszą granicę niż `Complete`; `Complete` korzysta już z execution strategy i `Serializable` (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:462-588`).
- Request aktualizacji nie zawiera `expectedVersion`, a `SharedSession.Version` nie jest concurrency tokenem (`apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs:19-23`, `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:118-200`).
- Produkcyjny Azure SQL `500` z zastępowania projekcji progresu został już naprawiony i ma regresje; nie jest ponownie implementowany (`apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs:21-73`, `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs:693-820`).
- Test host używa SQLite in-memory z `EnsureCreated`; SQL Server smoke i migracje należą do rollout Phase 3 (`apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs:15-62`).

## Desired End State

- Każda zaakceptowana mutacja tej samej sesji ma odrębną, rosnącą wartość `Version`.
- Dwa równoległe `PATCH` mogą oba zakończyć się `200`; późniejszy commit jest kanoniczny, a odpowiedzi nie mają tej samej wersji.
- `PATCH` zatwierdzony przed `complete` lub `cancel` staje się częścią stanu terminalnego. `PATCH` uporządkowany po terminalnym commicie zwraca `409` i nie modyfikuje sesji ani progresu.
- Response i `sessionUpdated` powstają z kanonicznego snapshotu odczytanego po commicie; broadcast nigdy nie dzieje się wewnątrz retryable execution-strategy callback.
- Nie zmieniają się route’y, JSON request/response, schema bazy, UI ani zachowanie auth.
- Istniejące zabezpieczenia reconnect i ordering mobile nadal przechodzą bez nowych mobile-only guardów.
- §6 test planu wskazuje kanoniczne wzorce dla testów reconnect i współbieżnego zapisu sesji.

### Key Discoveries

- W repo istnieje zaakceptowany wzorzec `CreateExecutionStrategy()` + `BeginTransactionAsync(IsolationLevel.Serializable)` + ponowny odczyt wewnątrz transakcji: start sesji, `Complete` i archiwizacja zestawu.
- Istniejący concurrency test uruchamia dwa publiczne requesty przez osobne klienty i używa `Task.WhenAll`, a wynik ocenia przez invarianty niezależne od zwycięzcy (`SharedSessionEndpointTests.cs:301-343`).
- Hub tests używają `TaskCompletionSource` i `WaitAsync`, więc broadcast można testować bez `Task.Delay` (`SharedSessionHubTests.cs:71-136`).
- Client guard odrzuca tylko wersje niższe. Jego poprawność zależy od serwerowej gwarancji, że różne zaakceptowane mutacje nie dostaną tej samej wersji.

## What We're NOT Doing

- Bez `expectedVersion`, `ETag`, `If-Match` i UI rozwiązywania konfliktów.
- Bez nowej kolumny `rowversion`, migracji lub zmian model snapshotu.
- Bez blokad procesu API, które nie działają między instancjami.
- Bez nowych testów mobile kopiujących istniejące reconnect/banner/stale-event coverage.
- Bez powtarzania naprawionego regresu Azure SQL dla `WorkoutProgressProjector`.
- Bez SQL Server container/smoke; provider-realistic verification należy do rollout Phase 3.
- Bez device e2e i testów na dwóch klientach; ten poziom należy do rollout Phase 4.
- Bez snapshot tests UI, zmian designu i GitHub Actions YAML.

## Implementation Approach

Rozszerzyć istniejący wzorzec mutacji serializowanych na `UpdateValue` oraz `Cancel/Close`. Każda mutacja działa przez execution strategy, otwiera krótką transakcję `Serializable`, czyści tracker i ponownie odczytuje sesję wraz z wartościami przed walidacją i zapisem. Dzięki temu konkurujące mutacje tej samej sesji są liniowo uporządkowane przez bazę, a każdy commit inkrementuje wersję od aktualnego stanu.

Po commicie endpoint czyści tracker i ponownie odczytuje sesję, aby response i broadcast korzystały z kanonicznego snapshotu. `Complete` zachowuje obecną transakcję, projekcję progresu, streak i guidance, ale również odpowiada i publikuje dopiero po kanonicznym reloadzie. Żadne wysłanie SignalR nie znajduje się wewnątrz callbacku, który execution strategy może powtórzyć.

Testy najpierw definiują invarianty przez publiczne HTTP i SignalR. Nie zakładają, który request wygra, nie używają `Task.Delay` i nie kopiują obliczeń z produkcyjnej implementacji. Asercje opierają się na kontrakcie: dozwolone statusy, unikalne wersje, terminalność, zgodność progresu i zgodność najwyższej wersji z kanonicznym GET.

## Critical Implementation Details

### Retry and side-effect boundary

Execution strategy może powtórzyć cały callback po błędzie przejściowym. Transaction commit jest granicą persistence; response construction i SignalR broadcast muszą pozostać po callbacku, aby retry nie publikował niezatwierdzonych lub podwójnych eventów.

### Lifecycle ordering

Walidacja `Status == active`, odczyt wartości, inkrementacja wersji i zapis muszą należeć do tej samej transakcji. Ponowny odczyt przed każdą próbą decyduje, czy `PATCH` jest wcześniejszy od terminalnej mutacji, czy powinien zwrócić `409`.

### Canonical response

Tracked entity użyte do zapisu nie jest automatycznie dowodem finalnego stanu po konkurencji. Po commicie endpoint ponownie odczytuje pełną sesję wraz z uporządkowanymi wartościami i dopiero ten snapshot mapuje do HTTP oraz SignalR.

## Phase 1: Atomowy Kontrakt Mutacji Sesji

### Overview

Najpierw dodać regresje publicznego kontraktu, następnie rozszerzyć istniejący wzorzec transakcyjny na wszystkie mutacje wartości i lifecycle objęte ryzykiem. Faza kończy się pełną zieloną suite API.

### Changes Required

#### 1. Endpoint concurrency regressions

**File**: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`

**Intent**: Udowodnić zachowanie użytkowe równoległych zapisów i terminalnych wyścigów przez rzeczywisty pipeline HTTP oraz persistence.

**Contract**:

- Dwa osobne klienty wykonują równoległe `PATCH` tej samej wartości przez `Task.WhenAll`. Oba sukcesy mają różne kolejne wersje; najwyższa wersja i payload odpowiadają późniejszemu kanonicznemu GET. Żadna odpowiedź nie jest `500`.
- `PATCH` oraz `complete` startują równolegle. Dozwolone są wyłącznie dwa liniowe wyniki: `PATCH 200` przed `complete 200`, z wartością obecną w sesji terminalnej i progresie, albo `complete 200` przed `PATCH 409`, bez późniejszej mutacji. Sesja kończy jako `completed` dokładnie raz.
- `PATCH` oraz `cancel` startują równolegle. Dozwolone są analogiczne wyniki: update przed anulowaniem albo `409` po anulowaniu. Sesja kończy jako `cancelled` i po końcowym GET nie zmienia wartości.
- Asercje sprawdzają invarianty, nie konkretnego zwycięzcę schedulera. Nie używają `Task.Delay`, pętli probabilistycznych ani oczekiwań skopiowanych z bieżącej kolejności implementacji.

**Risk coverage and anti-patterns**:

| Risk | Behavior asserted | Regression caught | Research source | Boundary case | Anti-pattern avoided |
|---|---|---|---|---|---|
| #2 | Każdy zaakceptowany zapis ma unikalną wersję i kanoniczny wynik. | Dwa sukcesy z tą samą wersją, lost update, `500`. | `research.md` §3 | Dwa `PATCH` tej samej wartości. | Sekwencyjny happy path i oracle z implementacji. |
| #2 | Terminalny commit zamyka dalsze mutacje. | Update po complete/cancel i rozjazd progresu. | `research.md` §4 | `PATCH` kontra complete/cancel. | Test zależny od konkretnego zwycięzcy. |

#### 2. Canonical SignalR broadcast regression

**File**: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs`

**Intent**: Udowodnić, że konkurujące mutacje publikują pełne, kanoniczne snapshoty z rozróżnialnymi wersjami, które klient może bezpiecznie uporządkować.

**Contract**: Dołączyć uczestnika do grupy, zebrać eventy `sessionUpdated` przez istniejący wzorzec `TaskCompletionSource`/`WaitAsync`, uruchomić dwa równoległe `PATCH`, a następnie porównać najwyższą odebraną wersję i wartości z kanonicznym GET. Nie zakładać kolejności dostarczenia eventów; sortować lub indeksować je po `Version`. Timeout służy wyłącznie ograniczeniu oczekiwania na eventy, nie koordynacji wyścigu.

**Risk coverage and anti-patterns**:

| Risk | Behavior asserted | Regression caught | Research source | Boundary case | Anti-pattern avoided |
|---|---|---|---|---|---|
| #6 | Różne mutacje mają różne wersje, a najwyższa wersja odpowiada bazie. | Rozbieżne equal-version snapshoty i broadcast niekanonicznego tracked state. | `research.md` §2-3 | Odwrócona kolejność dostarczenia. | Mobile-only guard i `Task.Delay`. |

#### 3. Serialized update and terminal mutations

**File**: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`

**Intent**: Uporządkować wszystkie mutacje tej samej sesji przez istniejącą, wieloinstancyjną granicę bazy zamiast przez blokady procesu.

**Contract**:

- `UpdateValue` oraz `Cancel/Close` używają execution strategy i krótkiej transakcji `Serializable` zgodnej ze wzorcem `StartFromWorkoutSet`, `Complete` i workout-set delete.
- Każda próba czyści tracker i ponownie odczytuje sesję przed access check, terminal-state check, walidacją payloadu i inkrementacją `Version`.
- `UpdateValue` zachowuje aktualne role: trener może edytować dozwoloną sesję, a podopieczny wyłącznie własną self-start session. Wszystkie dotychczasowe `400`, `401`, `403`, `404` i `409` pozostają kompatybilne.
- `Complete` zachowuje obecną serializable transaction, idempotency, progress projection, weekly streak i guidance evaluation. Fix `WorkoutProgressProjector` pozostaje nietknięty.
- Po commicie każda mutacja ponownie ładuje pełną sesję; response i `BroadcastUpdatedAsync` korzystają wyłącznie z tego snapshotu.
- Broadcast nie jest wykonywany wewnątrz retryable callbacku. Brak nowych route’ów, request fields, response fields i zmian schematu.

### Success Criteria

#### Automated Verification

- Focused concurrent endpoint regressions pass without `500`, duplicate accepted versions, or terminal-state mutation.
- Canonical SignalR broadcast regression passes and highest broadcast version matches canonical GET.
- Existing shared-session lifecycle, authorization, progress replacement and hub tests remain green.
- `dotnet build LiftMate.slnx --no-restore` passes from `apps/api` with zero errors.
- `dotnet test LiftMate.slnx --no-build --verbosity minimal` passes from `apps/api`.

**Implementation Note**: Faza nie wymaga manualnego device QA. Zachowanie dwóch realnych klientów i provider-realistic SQL Server są świadomie odłożone do rollout Phase 4 i Phase 3.

---

## Phase 2: Cross-Layer Verification i Cookbook

### Overview

Potwierdzić, że serwerowy kontrakt nie naruszył istniejącego reconnect/UI, uruchomić pełny lokalny quality floor i zamienić placeholdery §6 w trwałe instrukcje dodawania kolejnych testów.

### Changes Required

#### 1. Existing mobile regression floor

**Files**:

- `apps/mobile/test/shared_session_controller_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Zweryfikować istniejące zabezpieczenia ryzyk #1 i #6 bez dodawania redundantnego mobile behavior lub device e2e.

**Contract**: Nie zmieniać testów tylko po to, aby wygenerować diff. Uruchomić kanoniczne testy rejoin, REST reconciliation, bannera, stale-version guard, cross-session guard i read-only realtime update. Jeżeli serwerowa zmiana wymusi modyfikację mobile, traktować to jako drift kontraktu i wrócić do planu zamiast maskować test.

**Risk coverage and anti-patterns**:

| Risk | Behavior asserted | Regression caught | Research source | Boundary case | Anti-pattern avoided |
|---|---|---|---|---|---|
| #1 | Reconnect zachowuje sesję, uzgadnia stan i pokazuje degradację. | Cicha utrata grupy lub bannera. | `research.md` §1 | Failed rejoin i missed completion. | Duplikowanie istniejących testów. |
| #6 | Niższa wersja i obca sesja nie zastępują ekranu. | Cofnięcie lub wymuszone przełączenie sesji. | `research.md` §2 | Out-of-order i cross-session event. | Nowy equal-version guard maskujący serwer. |

#### 2. Test-plan cookbook update

**File**: `context/foundation/test-plan.md`

**Intent**: Wypełnić po wysłaniu rollout Phase 1 kanoniczne wzorce, aby następne testy korzystały z najtańszej warstwy i poprawnych oracle.

**Contract**:

- §6.1 opisuje lokalizację, naming, reference tests i komendy dla reconnect/realtime-ordering: controller/widget testy z fake realtime, bez device e2e i bez snapshotów UI.
- §6.2 opisuje lokalizację, naming, reference tests i komendy dla concurrent session-write API tests: publiczne HTTP, osobne klienty, `Task.WhenAll`, outcome-independent invariants, brak `Task.Delay` i brak zależności od SQL Server w tej fazie.
- §6.6 dodaje krótką notę z odkryciem, że mobile stale-version guard wymaga unikalnej wersji serwera, a provider-specific smoke pozostaje w Phase 3.
- Nie zmieniać §1-§5 poza statusem obsługiwanym przez `/10x-test-plan`; nie dodawać file anchors do Risk Map.

### Success Criteria

#### Automated Verification

- Focused mobile realtime/controller/widget tests pass with no source changes required.
- Full `flutter test --reporter compact` passes from `apps/mobile`.
- `flutter analyze` passes from `apps/mobile`.
- Full API build and test suite remain green after the cookbook update.
- `context/foundation/test-plan.md` §6.1, §6.2 and §6.6 contain shipped locations, reference tests and exact run commands instead of Phase 1 placeholders.

**Implementation Note**: Po przejściu automatycznej weryfikacji ta faza kończy rollout. Manualne testy urządzenie–API pozostają jawnie w późniejszej Phase 4, więc nie blokują ukończenia tej zmiany.

## Testing Strategy

### API Integration Tests

- Testować publiczne endpointy przez `WebApplicationFactory`, osobne `HttpClient` i rzeczywiste SQLite persistence.
- Dla konkurencji uruchamiać operacje razem i asercjami opisywać dopuszczalne liniowe wyniki, nie wymuszać jednego zwycięzcy.
- Sprawdzać status HTTP, wersje odpowiedzi, końcowy GET, terminalność oraz progres; sam `200` nie jest oracle.
- SignalR testować przez realne połączenie test-server i `TaskCompletionSource`/`WaitAsync`; nie używać `Task.Delay` do ustalania kolejności.
- Zachować istniejące regresje naprawionego `WorkoutProgressProjector` bez ich kopiowania.

### Mobile Controller and Widget Tests

- Użyć istniejących testów jako regresyjnego floor dla reconnect, bannera i ordering.
- Nie dodawać equal-version guard po stronie mobile; unikalność wersji jest kontraktem serwera.
- Nie dodawać device e2e, golden snapshots ani pełnego app flow w tej fazie.

### Manual Testing

- Brak obowiązkowego manualnego QA w tym rollout. Dwa urządzenia, utrata sieci i środowisko wdrożeniowe są zakresem późniejszych Phase 3/4 w `test-plan.md`.

## Performance Considerations

- Transakcja obejmuje wyłącznie jedną sesję i jej wartości; nie może obejmować SignalR send ani innych zewnętrznych efektów.
- `Serializable` celowo serializuje konkurencję tej samej sesji. Różne sesje pozostają niezależne przy obecnych indeksach po `Id`.
- Kanoniczny reload dodaje jeden odczyt po mutacji. Jest zaakceptowanym kosztem za pewność, że response i broadcast odpowiadają zatwierdzonemu stanowi.
- Nie dodawać pętli retry na poziomie aplikacji bez ograniczenia. Korzystać z istniejącej execution strategy providera.

## Migration Notes

- Brak zmian schematu i migracji EF Core.
- Brak zmian JSON; obecne aplikacje mobilne pozostają kompatybilne.
- Rollback polega na odwróceniu zmian endpointu i nowych testów; nie wymaga operacji na danych.
- SQL Server migration/provider smoke pozostaje w rollout Phase 3 zgodnie z `context/foundation/test-plan.md`.

## References

- Test strategy: `context/foundation/test-plan.md`
- Related research: `context/changes/testing-spojnosc-realtime-zapis-wspolbiezny/research.md`
- Existing transaction pattern: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:146-348`, `:462-536`
- Existing concurrency test pattern: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs:301-343`
- Existing SignalR test pattern: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs:71-136`
- Existing mobile proof: `apps/mobile/test/shared_session_controller_test.dart:267-435`, `apps/mobile/test/live_session_screen_test.dart:404-455`
- Historical reconnect decisions: `context/archive/2026-06-19-live-trainer-led-entry/plan-brief.md`
- Historical production concurrency fix: `docs/superpowers/specs/2026-06-29-workout-progress-concurrency-fix-design.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Atomowy Kontrakt Mutacji Sesji

#### Automated

- [x] 1.1 Focused concurrent endpoint regressions pass without `500`, duplicate accepted versions, or terminal-state mutation — 7aeb244
- [x] 1.2 Canonical SignalR broadcast regression passes and highest broadcast version matches canonical GET — 7aeb244
- [x] 1.3 Existing shared-session lifecycle, authorization, progress replacement and hub tests remain green — 7aeb244
- [x] 1.4 `dotnet build LiftMate.slnx --no-restore` passes from `apps/api` with zero errors — 7aeb244
- [x] 1.5 `dotnet test LiftMate.slnx --no-build --verbosity minimal` passes from `apps/api` — 7aeb244

### Phase 2: Cross-Layer Verification i Cookbook

#### Automated

- [x] 2.1 Focused mobile realtime/controller/widget tests pass with no source changes required
- [x] 2.2 Full `flutter test --reporter compact` passes from `apps/mobile`
- [x] 2.3 `flutter analyze` passes from `apps/mobile`
- [x] 2.4 Full API build and test suite remain green after the cookbook update
- [x] 2.5 `context/foundation/test-plan.md` §6.1, §6.2 and §6.6 contain shipped locations, reference tests and exact run commands instead of Phase 1 placeholders
