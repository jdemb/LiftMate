# Domknięcie synchronizacji treningu prowadzonego przez trenera — Plan Brief

> Full plan: `context/changes/live-trainer-led-entry/plan.md`

## What & Why

S-04 jest już funkcjonalnie zrealizowane przez S-03, ale ma lukę odporności: automatyczny reconnect SignalR tworzy nowe połączenie, które nie jest ponownie dodawane do grupy aktywnej sesji. Plan domyka tę lukę i dodaje przekrojowy dowód, że wartości trenera aktualizują read-only ekran podopiecznego bez odświeżenia.

## Starting Point

Backend publikuje pełne snapshoty `sessionUpdated`, a oba klienty potrafią dołączyć do jednej sesji. Kontroler odzyskuje sesję po reconnect tylko wtedy, gdy lokalny stan jest pusty; nie wykonuje rejoin, gdy ekran aktywnej sesji pozostaje otwarty.

## Desired End State

Po utracie i odzyskaniu połączenia aktywna sesja pozostaje na ekranie, klient ponownie dołącza do grupy SignalR, a kolejne zmiany trenera docierają do podopiecznego. Starsze eventy nie cofają widocznych wartości. S-04 zostaje zamknięte dopiero po manualnym potwierdzeniu tego zachowania na dwóch klientach.

Event innej aktywnej sesji nie może samodzielnie podmienić aktualnie otwartego treningu. Trener wychodzi z jednej sesji i dołącza do drugiej wyłącznie przez świadomą akcję w UI.

Jeśli rejoin się nie powiedzie, aktywna sesja pozostaje widoczna, a nieblokujący banner informuje o przerwanej synchronizacji. Banner znika automatycznie po udanym ponowieniu.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Reconnect | Rejoin istniejącej sesji | Minimalny ruch sieciowy i bezpośrednie odtworzenie grupy. |
| Rejoin error | Zachować ekran i sesję | Awaria transportu nie powinna przerywać treningu. |
| Realtime error UX | Nieblokujący banner | Informuje o ryzyku nieaktualnych danych bez odbierania dostępu do treningu. |
| Event ordering | Odrzucać niższe wersje | Opóźniony event nie może cofnąć stanu. |
| Session switching | Jawna decyzja użytkownika | Nowa sesja innego podopiecznego nie może przerwać bieżącego treningu. |
| UI proof | Test przez authenticated shell | Pokrywa pełny łańcuch od eventu do read-only UI. |
| Closure | `done` po manualnym QA | Kryterium dotyczy realnego zachowania dwóch klientów. |

## Scope

**In scope:**

- rejoin grupy aktywnej sesji po reconnect;
- ponawialny błąd rejoin bez czyszczenia sesji;
- banner błędu synchronizacji z automatycznym wyczyszczeniem;
- ochrona przed starszymi snapshotami;
- ochrona otwartej sesji przed eventami innych sesji;
- test kontrolera reconnect;
- przekrojowy test read-only UI;
- pełna weryfikacja i późniejsza aktualizacja roadmapy.

**Out of scope:**

- backend, migracje i nowe endpointy;
- polling jako główny transport;
- płatna infrastruktura realtime;
- redesign ekranów;
- zapis progresu na kolejny trening — S-05.

## Architecture / Approach

`SharedSessionController` reaguje na `reconnecting -> connected`. Jeśli ma aktywną sesję, ponownie wywołuje `JoinSession`; jeśli nie ma sesji, zachowuje istniejący fallback `GET /shared-sessions/active`. Snapshoty tej samej sesji są akceptowane tylko przy wersji nie niższej od lokalnej.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Reconnect i wersje | Rejoin, retry i ochrona snapshotów | Podwójny join podczas pierwszego connect |
| 2. Test przekrojowy | Dowód aktualizacji read-only UI | Fake realtime musi odzwierciedlać realny przepływ |
| 3. Weryfikacja | Pełne testy i kontrolowane zamknięcie S-04 | Przedwczesne oznaczenie roadmapy jako done |

**Prerequisites:** ukończone F-03 i S-03.

**Estimated effort:** 2–3 krótkie fazy, bez zmian backendu i schematu danych.

## Open Risks & Assumptions

- Biblioteka SignalR emituje stan `reconnecting`, a następnie `connected` dla automatycznego reconnect.
- Pole `version` pozostaje monotoniczne dla mutacji jednej sesji.
- Manualne QA wymaga dwóch klientów oraz kontrolowanej utraty sieci.

## Success Criteria (Summary)

- Po reconnect kolejne zmiany trenera znów docierają bez odświeżania.
- Starszy event nie cofa wartości widocznych na ekranie.
- Test przekrojowy potwierdza aktualizację read-only UI, a manualne QA pozwala oznaczyć S-04 jako `done`.
