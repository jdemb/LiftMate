---
date: 2026-06-30T10:58:58.1384201+02:00
researcher: Codex
git_commit: c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab
branch: deploy-2026-05-26
repository: jdemb/PrototypApka
topic: "Spójność realtime i współbieżny zapis aktywnej sesji"
tags: [research, shared-sessions, signalr, concurrency, flutter, aspnet-core]
status: complete
last_updated: 2026-06-30
last_updated_by: Codex
---

# Research: Spójność realtime i współbieżny zapis aktywnej sesji

**Date**: 2026-06-30T10:58:58.1384201+02:00
**Researcher**: Codex
**Git Commit**: c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab
**Branch**: deploy-2026-05-26
**Repository**: jdemb/PrototypApka

## Research Question

Ugruntować rollout Phase 1 z `context/foundation/test-plan.md` dla ryzyk #1, #2 i #6: odzyskanie tej samej kanonicznej sesji po reconnect z widoczną degradacją, zdefiniowany wynik równoległych zapisów bez HTTP 500 oraz odporność na starsze i obce eventy. Zweryfikować istniejące testy, realne ścieżki awarii i najtańszą warstwę dającą użyteczny sygnał.

## Summary

Ryzyka #1 i #6 mają już znaczącą ochronę po S-04. Mobile wykrywa `reconnecting -> connected`, ponownie dołącza do grupy, pobiera kanoniczny snapshot ostatniej sesji przez REST, zachowuje ekran przy błędzie rejoin, pokazuje banner, odrzuca niższą wersję i ignoruje event innej sesji. Istniejące testy kontrolera i widgetu pokrywają te zachowania; uruchomiony zestaw 29 testów przeszedł.

Główna aktualna luka leży po stronie API. `PATCH` wartości nie przyjmuje oczekiwanej wersji, `SharedSession.Version` nie jest tokenem współbieżności, a inkrementacja jest wykonywana w pamięci przed zwykłym `SaveChangesAsync`. Dwa równoległe żądania mogą więc odczytać tę samą wersję, oba zwrócić kolejną identyczną wersję i rozgłosić różne pełne snapshoty. Mobile odrzuca tylko wersje niższe, więc nie potrafi rozstrzygnąć dwóch rozbieżnych snapshotów z tym samym numerem.

Dokładny produkcyjny HTTP 500 przy finalizacji późniejszej sesji nie jest już otwartą luką: incydent z Azure SQL został naprawiony 2026-06-29 przez set-based replacement projekcji progresu i ma regresje strategii persistence oraz endpointu. Rollout nie powinien duplikować tych testów. Ryzyko #2 należy doprecyzować do równoległych `PATCH` oraz wyścigu `PATCH` z `complete`/`cancel`.

Najtańszy wartościowy następny krok to deterministyczny kontrakt integracyjny API: każda zaakceptowana mutacja ma otrzymać jednoznacznie rosnącą wersję albo jawny konflikt, a terminalna sesja nie może zostać zmieniona przez żądanie, które wcześniej odczytało stan `active`. Kolejne testy mobile mają sens dopiero po ustaleniu tego kontraktu; obecne testy reconnect i bannera nie wymagają powielania.

## Detailed Findings

### 1. Reconnect odzyskuje grupę i kanoniczny stan

- Klient SignalR ma automatyczny reconnect i mapuje stany biblioteki na domenowe `reconnecting` oraz `connected` ([shared_session_realtime_client.dart:179-259](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart#L179)).
- Kontroler pamięta przejście przez reconnect. Po powrocie ponawia `JoinSession`, a następnie pobiera ostatnią znaną sesję po ID, co odzyskuje także przegapiony terminalny snapshot ([shared_session_controller.dart:426-485](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/mobile/lib/shared_sessions/shared_session_controller.dart#L426)).
- Błąd rejoin nie usuwa załadowanej sesji. Kontroler zachowuje snapshot i ustawia komunikat błędu ([shared_session_controller.dart:522-542](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/mobile/lib/shared_sessions/shared_session_controller.dart#L522)); ekran pokazuje go jako nieblokujący banner nad aktywnym treningiem ([live_session_screen.dart:125-141](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/mobile/lib/shared_sessions/live_session_screen.dart#L125)).
- Testy potwierdzają rejoin, retry po błędzie, zachowanie sesji, usunięcie bannera po sukcesie oraz odzyskanie przegapionego zakończenia (`apps/mobile/test/shared_session_controller_test.dart:267-386`, `apps/mobile/test/live_session_screen_test.dart:404-455`).
- Korekta historyczna: brief S-04 mówił o rejoin bez dodatkowego odczytu. Bieżący kod celowo wykonuje GET po ID, aby odzyskać terminalny stan. Plan Phase 1 musi opierać się na aktualnym zachowaniu, nie na starym założeniu „bez reloadu”.

### 2. Ochrona ordering działa tylko przy unikalnej wersji serwera

- Kontroler ignoruje event innej sesji i niższą wersję bieżącej sesji ([shared_session_controller.dart:488-520](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/mobile/lib/shared_sessions/shared_session_controller.dart#L488)).
- Testy pokrywają oba przypadki (`apps/mobile/test/shared_session_controller_test.dart:388-435`), a test przekrojowy dowodzi aktualizacji read-only UI bez dodatkowego REST (`apps/mobile/test/post_auth_relationship_screen_test.dart:900-965`).
- Guard ma postać `incoming.version < current.version`; równa wersja zostaje zaakceptowana. Jest to poprawne dla zduplikowanego identycznego pełnego snapshotu, ale nie chroni przed dwoma różnymi snapshotami o tej samej wersji.
- API nie gwarantuje obecnie unikalnej wersji na zaakceptowaną mutację. `Version` jest zwykłą właściwością `long` (`apps/api/LiftMate.Api/SharedSessions/SharedSession.cs:32-40`), a konfiguracja EF nie oznacza jej jako concurrency token (`apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:118-200`). Snapshot modelu również mapuje ją wyłącznie jako `bigint` (`apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs:248-253`).
- Wniosek: dodatkowy mobile-only test stale-event nie zamknie ryzyka #6. Najpierw trzeba ustanowić serwerową semantykę wersji przy współbieżnych zapisach.

### 3. Równoległy `PATCH` nie ma jawnego kontraktu

- Request aktualizacji zawiera tylko nowe wartości i `isDone`; nie niesie `expectedVersion` ani innego warunku precondition ([SharedSessionContracts.cs:19-23](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs#L19)). Mobile wysyła ten sam kształt (`apps/mobile/lib/shared_sessions/shared_session_models.dart:299-319`).
- Endpoint najpierw odczytuje całą sesję, sprawdza `active`, zmienia wartość, wykonuje `session.Version += 1`, zapisuje i dopiero potem broadcastuje swój śledzony snapshot ([SharedSessionEndpoints.cs:399-459](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs#L399)).
- Bez tokenu współbieżności dwa requesty mogą bazować na tej samej wersji. Możliwy wynik to last-write-wins w bazie, dwa sukcesy z tym samym numerem wersji oraz broadcast snapshotu, który nie odpowiada już finalnemu rekordowi. To dokładnie łączy ryzyko #2 z #6.
- Istniejące endpoint tests są sekwencyjne: sprawdzają pojedynczy update, walidację, persistence `IsDone` i terminalność (`apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs:125-181`, `:421-456`, `:504-560`). Jedyny test z `Task.WhenAll` dotyczy startu sesji i archiwizacji zestawu, nie aktualizacji sesji (`:302-342`).
- Do zaplanowania są co najmniej dwa scenariusze: dwa równoległe `PATCH` tej samej wartości oraz `PATCH` ścigający się z `complete` (opcjonalnie także `cancel`). Oczekiwany wynik musi zostać ustalony przed napisaniem asercji: atomowy last-write-wins z unikalną wersją albo optimistic conflict.

### 4. Finalizacja sesji ma silniejszą granicę, ale wyścig z update pozostaje nieudowodniony

- `Complete` używa execution strategy, transakcji `Serializable`, ponownego odczytu wewnątrz transakcji, projekcji progresu i broadcastu dopiero po commit ([SharedSessionEndpoints.cs:462-536](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs#L462)).
- `Cancel` oraz `UpdateValue` nie używają analogicznej granicy (`apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:539-588`). Request może odczytać `active` przed równoległym zamknięciem i próbować zapisać po zmianie lifecycle. Rzeczywisty wynik zależy od locków providera i wymaga deterministycznego testu; obecna suite go nie dowodzi.
- Produkcyjny 500 opisany w `docs/superpowers/specs/2026-06-29-workout-progress-concurrency-fix-design.md` dotyczył drugiego `SaveChangesAsync` podczas zastępowania istniejącej projekcji, nie równoległych `PATCH`.
- Fix czyta istniejącą projekcję bez trackingu, wykonuje set-based update/delete i sprawdza liczbę zmienionych rekordów ([WorkoutProgressProjector.cs:21-73](https://github.com/jdemb/PrototypApka/blob/c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab/apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs#L21)). Dwa testy chronią strategię EF i pełny scenariusz późniejszej sesji (`SharedSessionEndpointTests.cs:693-820`).
- Pięć uruchomionych testów API obejmujących fix, lifecycle i pojedynczy update przeszło. Nie ma podstaw do ponownego planowania tego samego naprawionego przypadku w Phase 1.

### 5. SQLite daje tani sygnał, ale nie dowodzi Azure SQL

- `TestApplicationFactory` używa współdzielonej bazy SQLite in-memory i `EnsureCreated`, nie migracji ani SQL Server (`apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs:15-62`). Produkcja używa SQL Server z retry (`apps/api/LiftMate.Api/Program.cs:24-27`).
- SQLite wystarcza do kontraktu HTTP, autoryzacji, terminalności i większości persistence. Nie odtworzył wcześniejszego provider-specific `DbUpdateConcurrencyException`; dlatego dodano deterministyczny test strategii trackingu obok scenariusza endpointowego.
- Phase 1 powinna nadal preferować API integration, ale test współbieżności musi być deterministyczny i nie może polegać na przypadkowym schedulerze SQLite. Provider-realistic smoke należy do Phase 3 test planu, nie powinien blokować tańszego kontraktu Phase 1.

## Code References

- `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart:179-259` — automatic reconnect i mapowanie stanów.
- `apps/mobile/lib/shared_sessions/shared_session_controller.dart:426-520` — rejoin, REST reconciliation, version/session guards.
- `apps/mobile/lib/shared_sessions/live_session_screen.dart:125-141` — banner przy zachowanej aktywnej sesji.
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs:19-23` — update bez expected version.
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:399-459` — nieatomowy read/mutate/increment/save/broadcast.
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs:462-588` — serializable complete kontra zwykłe cancel/update.
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs:118-200` — brak concurrency token dla sesji.
- `apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs:15-62` — SQLite in-memory i `EnsureCreated`.
- `apps/api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs:21-73` — istniejący fix produkcyjnego 500.

## Architecture Insights

- `SharedSession` jest kanonicznym pełnym snapshotem, a SignalR dystrybuuje pełne odpowiedzi zamiast delta-events. To upraszcza klienta, ale wymaga ścisłej, monotonicznej wersji po stronie serwera.
- REST i SignalR celowo się uzupełniają: SignalR daje niską latencję, REST po ID uzgadnia stan po przerwie transportu. Reconnect nie powinien polegać wyłącznie na eventach.
- Widoczny banner jest właściwą degradacją: zachowuje możliwość odczytu treningu, ale nie udaje aktualności danych.
- Wersja jest obecnie numerem aplikacyjnym, nie mechanizmem kontroli współbieżności. Client guard nie może naprawić serwerowych duplikatów numeru.
- Broadcast po zapisie jest bezpieczny tylko wtedy, gdy snapshot reprezentuje faktycznie zatwierdzony kanoniczny stan. Przy konkurencyjnych zapisach obecny tracked response nie daje tej gwarancji.

## Historical Context (from prior changes)

- `context/archive/2026-06-19-live-trainer-led-entry/plan-brief.md` — S-04 wprowadziło rejoin, banner, stale-version guard i jawne przełączanie sesji.
- `context/archive/2026-06-19-live-trainer-led-entry/reviews/plan-review.md` — review wykryło cross-session replacement oraz niewidoczny rejoin failure; oba zostały naprawione.
- `context/changes/save-progress-next-session/plan.md` — ustanowił serializable completion i projekcję progresu.
- `docs/superpowers/specs/2026-06-29-workout-progress-concurrency-fix-design.md` — dokumentuje rzeczywisty Azure SQL 500 i granicę fixu.
- Commit `e382e5f` dodał reconnect rejoin i snapshot ordering; commit `52b0496` naprawił zastępowanie projekcji progresu.

## Related Research

Brak osobnego wcześniejszego `research.md` dla tej kombinacji ryzyk. Najbliższe źródła to plan/review S-04 oraz design produkcyjnego concurrency fixu wymienione wyżej.

## Open Questions

1. Jaki kontrakt ma obowiązywać dla równoległych mutacji: jawny optimistic conflict oparty na `expectedVersion`, czy atomowy server-side last-write-wins z unikalnym numerem dla każdej zaakceptowanej mutacji?
2. Czy Phase 1 obejmuje również wyścig `PATCH` kontra `complete` i `cancel`? Rekomendacja: co najmniej `PATCH` kontra `complete`, ponieważ chroni niezmienność zakończonego treningu i projekcji progresu.
3. Jak wprowadzić deterministyczny punkt synchronizacji testu bez test-only warunków w produkcyjnym endpointcie? Plan powinien preferować publiczny kontrakt lub warstwę persistence, nie timing oparty na `Task.Delay`.
4. Provider-realistic SQL Server verification pozostawić w Phase 3; Phase 1 powinna ustanowić szybki kontrakt API działający w zwykłej suite.

## Verification Performed

- `flutter test --reporter compact test/shared_session_controller_test.dart test/live_session_screen_test.dart` — PASS, 29 tests.
- Targeted API suite for progress replacement, lifecycle and single update — PASS, 5 tests.
- HEAD `c2fafb8ac6709d1ee2b306c3cae26877bd1b28ab` equals upstream `origin/deploy-2026-05-26`; source permalinks target this commit.
- GitHub CLI metadata lookup returned HTTP 401; repository identity was derived from configured `origin` (`https://github.com/jdemb/PrototypApka.git`).

## Test-plan Correction

Risk #2 should be reframed from the already-fixed generic production `500` to: **“Równoległy zapis wartości albo zapis ścigający się z zakończeniem sesji zwraca nieokreślony wynik, duplikuje wersję, modyfikuje terminalny trening lub kończy się `500`.”** The response guidance should require a defined concurrency policy and distinct monotonic versions or an explicit conflict. The historical progress-projection `500` remains evidence, not the primary untested failure path.
