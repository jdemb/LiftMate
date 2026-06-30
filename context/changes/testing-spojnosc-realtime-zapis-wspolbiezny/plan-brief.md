# Spójność Realtime i Współbieżny Zapis Sesji — Plan Brief

> Full plan: `context/changes/testing-spojnosc-realtime-zapis-wspolbiezny/plan.md`
> Research: `context/changes/testing-spojnosc-realtime-zapis-wspolbiezny/research.md`

## What & Why

Rollout Phase 1 zamyka lukę między mobile stale-version guard a serwerowym zapisem sesji. Równoległe mutacje mają być liniowo uporządkowane, otrzymywać unikalne wersje i publikować wyłącznie kanoniczny snapshot po commicie, bez `500`, silent overwrite terminalnego treningu lub rozbieżnego SignalR eventu.

## Starting Point

Reconnect, banner, niższe wersje i obce sesje są już chronione oraz przetestowane po S-04. Brakujący kontrakt leży w API: `PATCH` i `cancel` nie używają tej samej granicy `Serializable` co `complete`, a zwykłe `Version += 1` może przy konkurencji wyprodukować dwa różne snapshoty z tym samym numerem.

Historyczny Azure SQL `500` w projekcji progresu został naprawiony i nie jest ponownie implementowany.

## Desired End State

Dwa równoległe `PATCH` mogą oba zakończyć się sukcesem w modelu atomowego last-write-wins, ale każdy ma inną rosnącą wersję. `PATCH` przed terminalnym commitem trafia do stanu końcowego; `PATCH` po `complete` lub `cancel` dostaje `409`. HTTP i SignalR zawsze zwracają snapshot odczytany po commicie.

Wire contract, schema bazy, auth i UI pozostają bez zmian.

## Key Decisions Made

| Decision | Choice | Why | Source |
|---|---|---|---|
| Conflict policy | Atomowy last-write-wins | Zachowuje obecny UX bez konflikt modal i zapobiega duplicate versions. | Plan interview |
| Lifecycle race | Liniowa kolejność commitów | Update przed terminalem wchodzi do snapshotu; po terminalu jest `409`. | Plan interview |
| Broadcast | Kanoniczny reload po commicie | Event musi odpowiadać bazie, nie tracked state requestu. | Research + Plan interview |
| Concurrency primitive | Istniejące `Version` + database transaction | Bez migracji, wire changes i process-local locks. | Research + Plan interview |
| Mobile scope | API-first, istniejące testy jako regression floor | Najtańsza warstwa zamyka źródło błędu. | Test plan + Plan interview |
| Rollout shape | Test-first + minimal server fix + cookbook | Zielona suite i trwały wzorzec dla kolejnych testów. | Test plan + Plan interview |

## Scope

**In scope:**

- równoległe `PATCH` tej samej wartości;
- `PATCH` kontra `complete` i `cancel`;
- execution strategy + `Serializable` dla objętych mutacji;
- kanoniczny response i SignalR broadcast po commicie;
- API endpoint i hub regressions bez `Task.Delay`;
- ponowne uruchomienie istniejących testów reconnect/widget;
- aktualizacja §6.1, §6.2 i §6.6 `test-plan.md`.

**Out of scope:**

- `expectedVersion`, ETag i UI konfliktów;
- `rowversion`, migracje i zmiany JSON;
- nowe mobile guardy lub UI;
- SQL Server smoke, device e2e, golden snapshots i CI YAML;
- duplikowanie naprawionego `WorkoutProgressProjector` regression.

## Architecture / Approach

`UpdateValue` i `Cancel/Close` przejmują istniejący wzorzec `CreateExecutionStrategy()` + krótka transakcja `Serializable` + ponowny odczyt stanu. `Complete` zachowuje obecną transakcję i projekcję. Po commicie każda mutacja ładuje pełną kanoniczną sesję, a dopiero potem buduje response i wysyła `sessionUpdated`. SignalR pozostaje poza retryable callbackiem.

Testy uruchamiają publiczne requesty równolegle i akceptują oba poprawne porządki liniowe. Oracle stanowią statusy, monotoniczne wersje, końcowy GET, terminalność i progres — nie kolejność schedulera.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Atomowy kontrakt mutacji | API regressions, serializowane mutacje i kanoniczny broadcast | Flaky concurrency test lub side effect wewnątrz retry |
| 2. Cross-layer verification i cookbook | Pełny quality floor oraz trwałe §6 patterns | Redundant mobile tests lub przypadkowy scope creep |

**Prerequisites:** `research.md`, istniejące S-04 reconnect coverage, działający API integration test host.

**Estimated effort:** 2 krótkie fazy; jedna implementacyjna i jedna weryfikacyjno-dokumentacyjna.

## Open Risks & Assumptions

- SQLite dowodzi kontraktu aplikacyjnego, ale nie semantyki Azure SQL; provider smoke pozostaje w rollout Phase 3.
- `Serializable` może podnieść latency tylko przy konkurencji tej samej sesji; transakcja musi pozostać krótka i bez SignalR send.
- Testy concurrency muszą oceniać invarianty niezależne od zwycięzcy i nie mogą polegać na `Task.Delay`.

## Success Criteria (Summary)

- Równoległe mutacje nie zwracają `500`, nie duplikują zaakceptowanych wersji i nie zmieniają terminalnej sesji po commicie.
- Najwyższa wersja SignalR odpowiada kanonicznemu GET, a istniejące reconnect/banner/ordering tests pozostają zielone.
- §6 zawiera gotowe lokalizacje, reference tests i komendy dla reconnect oraz concurrent session writes.
