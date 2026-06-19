# Live Trainer-Led Entry Implementation Plan

## Overview

Domknąć roadmapowe S-04 bez ponownej implementacji przepływu z S-03. Istniejący backend, SignalR, ekran edytowalny trenera i ekran read-only podopiecznego już realizują podstawowy scenariusz. Pozostała praca dotyczy odporności po reconnect, odrzucania starszych snapshotów, przekrojowego dowodu aktualizacji UI oraz formalnego zamknięcia slice'a po manualnym QA.

## Current State Analysis

- SignalR używa automatycznego reconnect w `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart:180`.
- Klient dołącza do grupy sesji przez `joinSession` w `apps/mobile/lib/shared_sessions/shared_session_controller.dart:337`.
- Obsługa ponownego stanu `connected` pobiera aktywną sesję tylko wtedy, gdy lokalna sesja jest pusta (`apps/mobile/lib/shared_sessions/shared_session_controller.dart:354`).
- Po reconnect z zachowaną lokalną sesją nowy connection ID nie jest ponownie dodawany do grupy SignalR, więc kolejne `sessionUpdated` mogą nie dotrzeć.
- `_handleRealtimeSession` bezwarunkowo zastępuje lokalny snapshot (`apps/mobile/lib/shared_sessions/shared_session_controller.dart:364`), również gdy opóźniony event ma niższą wersję.
- Test kontrolera pokrywa odzyskanie sesji przy pustym stanie, ale nie rejoin przy już załadowanej sesji (`apps/mobile/test/shared_session_controller_test.dart:164`).
- Test read-only flow potwierdza statyczny widok podopiecznego, ale nie aktualizację wartości po zdarzeniu realtime (`apps/mobile/test/post_auth_relationship_screen_test.dart:505`).
- API i hub już publikują pełny snapshot `sessionUpdated`; zmiany backendu nie są potrzebne.

## Desired End State

- Po każdym przejściu `reconnecting -> connected` klient z aktywną lokalną sesją ponownie wywołuje `JoinSession`.
- Rejoin nie pobiera sesji ponownie, jeśli aktywny snapshot jest już lokalnie dostępny.
- Nieudany rejoin zachowuje aktualną sesję i ekran, zgłasza istniejącym kanałem błąd realtime oraz pozwala kolejnemu reconnectowi spróbować ponownie.
- Przy zachowanej sesji błąd realtime jest widoczny jako nieblokujący banner nad ekranem treningu i znika po udanym rejoin.
- Snapshot realtime zastępuje lokalny stan tylko wtedy, gdy dotyczy aktualnie otwartej sesji i jego `version` nie jest niższa od lokalnej.
- Event dotyczący innej sesji nigdy nie podmienia otwartego treningu. Może odświeżyć listę aktywnych sesji, ale przełączenie wymaga świadomego wyjścia użytkownika i dołączenia z UI.
- Test przekrojowy pokazuje, że read-only widok podopiecznego zmienia wartości po emisji `sessionUpdated`, bez ręcznego odświeżenia.
- S-04 jest oznaczone jako zakończone dopiero po pełnej weryfikacji automatycznej i potwierdzonym manualnym QA na dwóch klientach.

## Decisions

| Area | Decision | Rationale |
|---|---|---|
| Reconnect recovery | Rejoin istniejącej sesji po każdym reconnect | Przywraca utraconą przynależność connection ID do grupy bez zbędnego żądania REST. |
| Rejoin failure | Zachować sesję i pokazać błąd realtime | Krótkotrwały problem transportu nie powinien wyrzucać użytkownika z aktywnego treningu. |
| Realtime error UX | Nieblokujący banner | Użytkownik widzi, że synchronizacja jest przerwana, ale może nadal odczytać aktywny trening. |
| Snapshot ordering | Odrzucać snapshoty z niższą wersją | Opóźniony event nie może cofnąć widocznych wartości treningu. |
| Session switching | Tylko po decyzji użytkownika w UI | Event innego podopiecznego nie może przerwać aktualnie prowadzonego treningu. |
| UI verification | Test przez authenticated shell i fake realtime | Dowodzi całego łańcucha event -> controller -> read-only UI. |
| Roadmap closure | `done` dopiero po manualnym QA | S-04 jest obietnicą zachowania na dwóch realnych klientach, nie tylko zestawem testów jednostkowych. |

## What We're NOT Doing

- Bez zmian API, bazy danych, migracji i kontraktów SignalR.
- Bez pollingu jako podstawowego mechanizmu synchronizacji.
- Bez Azure SignalR Service lub płatnej infrastruktury realtime.
- Bez przebudowy ekranów live albo zmian designu.
- Bez zapisu wartości jako punktu startowego kolejnego treningu; to pozostaje S-05.
- Bez dopuszczenia edycji przez podopiecznego w sesji prowadzonej przez trenera.
- Bez edycji `context/archive/`; dokumentacja S-03 pozostaje niezmienna.

## Implementation Approach

Zmiana pozostaje po stronie Fluttera. Kontroler rozróżni pierwsze połączenie od powrotu po stanie `reconnecting`. Przy ponownym `connected` wybierze jedną z dwóch ścieżek: istniejąca aktywna sesja zostanie ponownie dołączona do grupy, a pusty stan zachowa obecny fallback `GET /shared-sessions/active`. Odbiór eventów dostanie prostą ochronę wersji. Następnie test kontrolera i test przekrojowy shell/UI udowodnią oba wymagania.

## Phase 1: Reconnect Rejoin And Snapshot Ordering

### Overview

Najpierw zablokować regresje testami kontrolera, następnie wprowadzić minimalną zmianę w orkiestracji realtime.

### Changes Required

#### Controller Regression Tests

**File**: `apps/mobile/test/shared_session_controller_test.dart`

**Intent**: Udowodnić zachowanie kontrolera po utracie i odzyskaniu połączenia oraz przy opóźnionych eventach.

**Contract**:

- Załaduj aktywną sesję i potwierdź pierwszy `JoinSession`.
- Wyemituj `reconnecting`, następnie `connected`; oczekuj drugiego `JoinSession` dla tego samego ID bez dodatkowego `getActive`.
- Zasymuluj błąd drugiego `joinSession`; lokalna sesja i jej wartości pozostają dostępne, a kontroler przechodzi do czytelnego stanu błędu realtime.
- Po kolejnym cyklu reconnect kontroler ponawia próbę rejoin, a udana próba czyści wcześniejszy komunikat błędu.
- Wyemituj snapshot tej samej sesji z wyższą wersją, a następnie z niższą; stan pozostaje na najwyższej zaakceptowanej wersji.
- Jako trener z otwartą sesją A wyemituj `sessionStarted` dla sesji B innego podopiecznego; sesja A pozostaje w kontrolerze, a relationship data zostaje unieważnione, aby UI pokazało dostępność sesji B.
- Zachowaj obecny test pustego stanu: `connected` bez sesji nadal wywołuje `getActive` i dołącza odnalezioną sesję.

Fake realtime client powinien umożliwiać sterowanie błędem `joinSession`, liczyć wywołania i emitować stany połączenia oraz snapshoty.

#### Reconnect State Tracking

**File**: `apps/mobile/lib/shared_sessions/shared_session_controller.dart`

**Intent**: Przywrócić grupową subskrypcję po automatycznym reconnect bez zbędnego pobierania aktywnej sesji.

**Contract**:

- Kontroler zapamiętuje, czy bieżące `connected` nastąpiło po stanie `reconnecting`.
- Przy `connected` po reconnect:
  - jeżeli lokalna sesja jest aktywna, wywołuje `joinSession(session.id)`;
  - jeżeli sesji nie ma, wykonuje istniejące `loadActive(user)`;
  - jeżeli lokalna sesja jest zamknięta, nie dołącza jej ponownie.
- Zwykłe zdarzenia `connected` podczas pierwszego `connect()` nie mogą powodować podwójnego join.
- Błąd rejoin nie czyści sesji. Powinien zostać przedstawiony przez istniejący stan/message kontrolera i nie blokować późniejszej próby.
- Udany rejoin ustawia stan z powrotem na `loaded` i czyści wcześniejszy message, bez ponownego pobierania sesji.
- Operacje asynchroniczne pochodzące ze streamu nie mogą powodować nieobsłużonych wyjątków.

#### Active-Session Realtime Error Banner

**File**: `apps/mobile/lib/shared_sessions/live_session_screen.dart`

**Intent**: Pokazać utratę synchronizacji bez zasłaniania lub zamykania aktywnego treningu.

**Contract**:

- Gdy sesja pozostaje załadowana, a `SharedSessionControllerState.message` zawiera błąd realtime, ekran pokazuje kompaktowy nieblokujący banner nad zawartością live.
- Banner jasno komunikuje problem z synchronizacją i to, że klient spróbuje ponownie po odzyskaniu połączenia.
- Banner nie zmienia `editable`, nie usuwa wartości i nie blokuje przycisku powrotu.
- Po udanym rejoin kontroler czyści message, a banner znika bez ręcznej akcji użytkownika.
- Brak message nie zmienia obecnego układu ekranu poza minimalnym warunkowym miejscem bannera.

#### Active-Session Error Banner Tests

**File**: `apps/mobile/test/live_session_screen_test.dart`

**Intent**: Zablokować regresję, w której błąd realtime jest zapisany w stanie, ale niewidoczny przy zachowanej sesji.

**Contract**:

- Przy załadowanej sesji i błędzie rejoin ekran nadal pokazuje ćwiczenie i wartości oraz renderuje banner.
- Po emisji udanego reconnect/rejoin banner znika, a sesja pozostaje widoczna.
- Test obejmuje co najmniej read-only widok podopiecznego; zachowanie komponentu bannera jest wspólne dla obu trybów.

#### Realtime Snapshot Guard

**File**: `apps/mobile/lib/shared_sessions/shared_session_controller.dart`

**Intent**: Nie dopuścić, aby opóźniony event cofnął widoczne wartości.

**Contract**:

- Gdy event dotyczy tej samej sesji co lokalny snapshot, zaakceptuj go tylko przy `incoming.version >= current.version`.
- Gdy lokalna sesja jest pusta, `sessionStarted` może zostać zaakceptowane jako odkryta aktywna sesja bez ręcznego odświeżenia.
- Gdy lokalna sesja jest już otwarta, event z innym `session.id` nie zastępuje jej niezależnie od wersji. Dla trenera wywołuje jedynie `onTrainerSessionInvalidated`, aby dashboard/detail po świadomym wyjściu pokazał nową aktywną sesję.
- Zmiana z sesji A na B następuje wyłącznie przez istniejący flow wyjścia z live view i jawne `loadById`/dołączenie wybrane w UI.
- Odrzucony starszy event nie zmienia statusu, message ani nie wywołuje invalidacji danych trenera.
- Zaakceptowany event bieżącej sesji zachowuje obecne zachowanie `onTrainerSessionInvalidated`.

### Success Criteria

#### Automated Verification

- Test kontrolera dowodzi rejoin aktywnej sesji po `reconnecting -> connected`.
- Rejoin nie wykonuje dodatkowego `GET /shared-sessions/active`, gdy sesja jest lokalnie dostępna.
- Nieudany rejoin zachowuje aktywny snapshot i pozwala na następną próbę.
- Nieudany rejoin pokazuje nieblokujący banner, a udany retry automatycznie go usuwa.
- Starszy snapshot realtime nie zastępuje nowszej wersji lokalnej.
- Event innej sesji nie zastępuje aktualnie otwartego treningu i odświeża dostępność sesji dla trenera.
- Obecny fallback pustego stanu nadal działa.
- `flutter test test/shared_session_controller_test.dart` przechodzi.
- `flutter test test/live_session_screen_test.dart` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- Przy krótkiej utracie sieci ekran aktywnego treningu pozostaje otwarty.
- Przy błędzie synchronizacji banner jest widoczny, ale trening nadal można odczytać i opuścić.
- Po odzyskaniu sieci kolejne zmiany drugiego uczestnika znów pojawiają się bez ręcznego odświeżenia.

---

## Phase 2: Trainee Read-Only Realtime Integration Coverage

### Overview

Dodać test przekrojowy rzeczywistego product flow, zamiast ograniczać dowód do osobnych testów transportu, kontrolera i statycznego widgetu.

### Changes Required

#### Controllable Realtime Test Double

**File**: `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Umożliwić testowi shell/UI emisję stanu połączenia i pełnych snapshotów sesji.

**Contract**:

- Zastąpić lub rozszerzyć lokalny `_FakeRealtimeClient`, zachowując kompatybilność z istniejącymi testami.
- Fake przechowuje przekazane ID sesji, udostępnia kontrolowane streamy i metodę emisji `SharedSession`.
- Test zamyka kontrolery streamów po zakończeniu, aby nie pozostawiać zasobów.

#### Read-Only Live Update Test

**File**: `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Udowodnić kryterium S-04 na poziomie widocznego ekranu podopiecznego.

**Contract**:

- Uruchom authenticated shell jako podopieczny powiązany z trenerem.
- Załaduj trainer-led active session i wejdź do read-only live view.
- Potwierdź wartość początkową.
- Wyemituj `sessionUpdated` tej samej sesji z wyższą wersją, zmienioną wagą/powtórzeniami i stanem ukończenia.
- Bez wywoływania REST, retry ani akcji refresh potwierdź nowe wartości i licznik ukończonych serii.
- Potwierdź, że kontrolki edycji nadal są nieobecne.

### Success Criteria

#### Automated Verification

- Test przekrojowy potwierdza aktualizację read-only UI po `sessionUpdated`.
- Test potwierdza brak ręcznego odświeżenia i brak dodatkowego żądania sesji po samym evencie.
- Test potwierdza zachowanie granicy read-only.
- Istniejące testy wejścia, powrotu i fallbacku nazwy trenera nadal przechodzą.
- `flutter test test/post_auth_relationship_screen_test.dart` przechodzi.
- Pełne `flutter test` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- Na dwóch klientach trener zmienia wagę, powtórzenia i done-state, a podopieczny widzi każdą zmianę w tej samej aktywnej sesji bez odświeżania.

---

## Phase 3: Full Verification And Roadmap Closure

### Overview

Zweryfikować cały kontrakt S-04, a po potwierdzeniu manualnym zsynchronizować roadmapę i change record.

### Changes Required

#### Full Automated Verification

**Files**:

- `apps/mobile`
- `apps/api`

**Intent**: Potwierdzić brak regresji w startowaniu, autoryzacji, aktualizowaniu i synchronizacji sesji.

**Contract**: Uruchomić pełne testy mobilne, analizator oraz testy API. Backend nie powinien wymagać zmian, ale jego test SignalR pozostaje dowodem publikowania aktualizacji do grupy.

#### Roadmap Bookkeeping

**Files**:

- `context/foundation/roadmap.md`
- `context/changes/live-trainer-led-entry/change.md`
- `context/changes/live-trainer-led-entry/plan.md`

**Intent**: Oznaczyć north-star slice jako zakończony dopiero po potwierdzonym zachowaniu na dwóch klientach.

**Contract**:

- Przed manualnym QA pozostawić S-04 jako `proposed` i `change.md` jako `preparing`/`implementing` zgodnie z etapem.
- Po automatycznej weryfikacji i wyraźnym potwierdzeniu manualnego QA:
  - zmienić status S-04 w tabeli i sekcji slice na `done`;
  - zaktualizować datę roadmapy;
  - dodać wpis S-04 do `## Done` wskazujący change record; ścieżkę archiwum dodać dopiero podczas osobnego `/10x-archive`;
  - ustawić `change.md` na `implemented`;
  - zaznaczyć manualne pozycje Progress.
- Nie edytować istniejących plików w `context/archive/`.

### Success Criteria

#### Automated Verification

- `dotnet test LiftMate.slnx --no-restore` przechodzi.
- Pełne `flutter test` przechodzi.
- `flutter analyze` przechodzi.
- Roadmapa nie jest oznaczona jako `done` przed manualnym potwierdzeniem.

#### Manual Verification

- Dwa zalogowane urządzenia lub klienci są w tej samej trainer-led session.
- Zmiany wartości i done-state trenera pojawiają się u podopiecznego bez odświeżenia.
- Po chwilowej utracie i odzyskaniu sieci podopieczny nadal otrzymuje kolejne zmiany.
- Po potwierdzeniu powyższego S-04 może zostać oznaczone jako `done`.

---

## Testing Strategy

### Unit And Controller Tests

- Pierwsze połączenie wykonuje jeden join.
- Reconnect aktywnej sesji wykonuje dokładnie jeden dodatkowy join.
- Reconnect bez sesji zachowuje fallback `getActive`.
- Reconnect zamkniętej sesji nie wykonuje join.
- Błąd rejoin zachowuje sesję i może zostać naprawiony kolejnym reconnectem.
- Błąd rejoin jest widoczny w nieblokującym bannerze, który znika po udanej kolejnej próbie.
- Snapshoty wersji `N+1`, `N` i `N-1` nie cofają stanu poniżej najwyższej zaakceptowanej wersji.
- `sessionStarted` dla innego podopiecznego nie podmienia otwartej sesji trenera; po świadomym wyjściu UI pozwala dołączyć do nowej sesji.

### Integration And Widget Tests

- API/hub test nadal dowodzi, że uczestnik grupy otrzymuje `sessionUpdated`.
- Shell test dowodzi, że event przechodzi przez realtime client i controller do read-only UI.
- Read-only test potwierdza brak przycisków edycji po aktualizacji.

### Manual Testing Steps

1. Zaloguj trenera i podopiecznego na dwóch klientach.
2. Trener uruchamia sesję z przypisanego zestawu.
3. Podopieczny dołącza do read-only live view.
4. Trener zmienia wagę, powtórzenia i oznacza serię jako wykonaną.
5. Potwierdź aktualizacje u podopiecznego bez odświeżania.
6. Odłącz sieć podopiecznego na czas wejścia SignalR w reconnect.
7. Przywróć sieć bez opuszczania ekranu.
8. Trener wykonuje kolejną zmianę.
9. Potwierdź, że podopieczny otrzymuje zmianę po rejoin.

## Performance Considerations

- Reconnect z istniejącą sesją wykonuje jedno wywołanie hub `JoinSession`, bez dodatkowego REST.
- Fallback REST pozostaje tylko dla pustego lokalnego stanu.
- Guard wersji jest stałokosztowym porównaniem i nie zmienia rozmiaru payloadu.

## Migration Notes

Brak migracji danych i zmian kontraktów. Zmiana jest kompatybilna z istniejącymi sesjami posiadającymi monotoniczne pole `version`.

## References

- Roadmap S-04: `context/foundation/roadmap.md:123`
- PRD US-03 i FR-012: `context/foundation/prd.md`
- Reconnect transport: `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart:180`
- Controller recovery: `apps/mobile/lib/shared_sessions/shared_session_controller.dart:354`
- Existing controller tests: `apps/mobile/test/shared_session_controller_test.dart:164`
- Existing read-only shell test: `apps/mobile/test/post_auth_relationship_screen_test.dart:505`
- SignalR group broadcast: `apps/api/LiftMate.Api/SharedSessions/SharedSessionBroadcaster.cs`
- SignalR integration proof: `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Reconnect Rejoin And Snapshot Ordering

#### Automated

- [x] 1.1 Test kontrolera dowodzi rejoin aktywnej sesji po `reconnecting -> connected`
- [x] 1.2 Rejoin nie wykonuje dodatkowego `GET /shared-sessions/active`, gdy sesja jest lokalnie dostępna
- [x] 1.3 Nieudany rejoin zachowuje aktywny snapshot i pozwala na następną próbę
- [x] 1.4 Nieudany rejoin pokazuje nieblokujący banner, a udany retry automatycznie go usuwa
- [x] 1.5 Starszy snapshot realtime nie zastępuje nowszej wersji lokalnej
- [x] 1.6 Event innej sesji nie zastępuje otwartego treningu i odświeża dostępność sesji dla trenera
- [x] 1.7 Obecny fallback pustego stanu nadal działa
- [x] 1.8 `flutter test test/shared_session_controller_test.dart` przechodzi
- [x] 1.9 `flutter test test/live_session_screen_test.dart` przechodzi
- [x] 1.10 `flutter analyze` przechodzi

#### Manual

- [ ] 1.11 Przy krótkiej utracie sieci ekran aktywnego treningu pozostaje otwarty
- [ ] 1.12 Banner błędu synchronizacji nie blokuje odczytu ani wyjścia z treningu
- [ ] 1.13 Po odzyskaniu sieci banner znika i kolejne zmiany pojawiają się bez ręcznego odświeżenia
- [ ] 1.14 Trener świadomie wychodzi z sesji A i dopiero z UI dołącza do dostępnej sesji B

### Phase 2: Trainee Read-Only Realtime Integration Coverage

#### Automated

- [ ] 2.1 Test przekrojowy potwierdza aktualizację read-only UI po `sessionUpdated`
- [ ] 2.2 Test potwierdza brak ręcznego odświeżenia i dodatkowego żądania sesji
- [ ] 2.3 Test potwierdza zachowanie granicy read-only
- [ ] 2.4 Istniejące testy read-only nadal przechodzą
- [ ] 2.5 `flutter test test/post_auth_relationship_screen_test.dart` przechodzi
- [ ] 2.6 Pełne `flutter test` przechodzi
- [ ] 2.7 `flutter analyze` przechodzi

#### Manual

- [ ] 2.8 Na dwóch klientach zmiany trenera aktualizują ekran podopiecznego bez odświeżenia

### Phase 3: Full Verification And Roadmap Closure

#### Automated

- [ ] 3.1 `dotnet test LiftMate.slnx --no-restore` przechodzi
- [ ] 3.2 Pełne `flutter test` przechodzi
- [ ] 3.3 `flutter analyze` przechodzi
- [ ] 3.4 Roadmapa pozostaje `proposed` przed manualnym potwierdzeniem

#### Manual

- [ ] 3.5 Dwa klienty widzą tę samą trainer-led session
- [ ] 3.6 Wartości i done-state aktualizują się bez odświeżenia
- [ ] 3.7 Synchronizacja działa po utracie i odzyskaniu sieci
- [ ] 3.8 Po potwierdzeniu QA S-04 zostaje oznaczone jako `done`
