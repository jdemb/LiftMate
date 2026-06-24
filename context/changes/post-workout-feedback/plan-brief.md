# Feedback po zakończonym treningu — Plan Brief

> Full plan: `context/changes/post-workout-feedback/plan.md`

## What & Why

Podopieczny będzie mógł po zakończeniu treningu samodzielnego lub wspólnego wysłać obowiązkową ocenę samopoczucia 1–5 i opcjonalny komentarz. Feedback zostanie trwale przypisany do właściwej sesji i pokazany aktualnemu trenerowi w istniejącej historii.

## Starting Point

Zakończone `SharedSession` są już niezmiennym źródłem historii i progresu, ale nie zawierają feedbacku. Mobile natychmiast czyści lokalną sesję po zakończeniu, a przy treningu wspólnym podopieczny otrzymuje zakończenie wyłącznie przez realtime.

## Desired End State

Po treningu podopieczny widzi nieblokujący formularz, może go pominąć lub uzupełnić później z historii. Zapis jest jednorazowy i odporny na retry, a aktualny trener widzi read-only ocenę i komentarz przy właściwej sesji.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Prompt | Natychmiast po zakończeniu, z opcją pominięcia | Naturalny moment bez blokowania treningu. |
| Późniejszy zapis | Z historii podopiecznego | Obsługuje pominięcie, offline i brak aktywnego ekranu. |
| Sesja wspólna | Prompt po `active → completed` realtime | Zapewnia ten sam efekt po zakończeniu przez trenera. |
| Dostęp | Aktualny trener zgodnie z historią | Zachowuje istniejący model autoryzacji. |
| Dane | Ocena 1–5, komentarz do 1000 znaków | Spełnia PRD i kontroluje rozmiar wpisu. |
| Nieedytowalność | Jeden wpis na sesję | Feedback pozostaje historycznym snapshotem. |
| Retry | Identyczny replay = sukces, inna treść = konflikt | Pozwala bezpiecznie ponowić utraconą odpowiedź. |
| Brak wpisu | CTA dla podopiecznego, neutralny tekst dla trenera | Wspiera późniejsze uzupełnienie bez mylącego błędu. |
| Design | Najpierw `LiftMate.dc.html` | UI i copy mają pozostać zgodne z kontraktem projektu. |
| Commits | Jeden commit na fazę | Ułatwia review i rollback. |

## Scope

**In scope:**

- rozszerzenie Design o formularz i sekcję historii;
- addytywna tabela feedbacku jeden-do-jednego z sesją;
- create-only endpoint z autoryzacją i bezpiecznym retry;
- nullable feedback w szczególe historii;
- Flutter models/client/controller;
- jednorazowy sygnał zakończenia lokalnego i realtime;
- formularz, pominięcie, retry i późniejsze uzupełnienie;
- role-aware read-only historia;
- migracja i pełna weryfikacja.

**Out of scope:**

- edycja lub usuwanie feedbacku;
- automatyczna analiza komentarzy;
- podpowiedzi trenera z S-10;
- zmiana procesu kończenia sesji lub progresu;
- powiadomienia i telemetria.

## Architecture / Approach

Nowa encja `PostWorkoutFeedback` użyje `SharedSessionId` jako PK/FK, co wymusi jeden wpis na sesję. Oddzielny endpoint zapisze feedback wyłącznie dla właściciela zakończonej sesji, a istniejący endpoint szczegółu historii zwróci nullable projekcję. Mobile skonsumuje jednorazowy event `active → completed`, odzyska utracone zakończenie po reconnect przez odświeżenie znanego `sessionId`, otworzy formularz i pozwoli wrócić do niego z historii.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Design contract | Formularz, copy, stany i historia | Brak wcześniejszego kontraktu UI |
| 2. API/data | Migracja, create-only endpoint i historia | Wyścigi retry i granice dostępu |
| 3. Mobile data flow | Klient, controller i terminalny event z reconnect recovery | Podwójny prompt HTTP/realtime lub utracony broadcast |
| 4. Mobile UI | Formularz i jawnie role-aware historia | Nawigacja, klawiatura i zachowanie danych |
| 5. Verification | Skoordynowane testy backend HTTP, backend SignalR i Flutter fake realtime oraz kontrolowany closeout | Regresja sesji live lub historii |

**Prerequisites:** S-04 ukończone; istniejąca historia S-05; aktualny `LiftMate.dc.html`.

**Estimated effort:** pięć osobnych commitów, około 5–8 skoncentrowanych sesji implementacyjnych.

## Open Risks & Assumptions

- Aktualny trener nadal widzi całą dostępną historię podopiecznego, także wpisy z wcześniejszych sesji.
- Podopieczny offline w chwili zakończenia odzyskuje możliwość zapisu przez historię, bez lokalnej kolejki offline.
- Krótkie rozłączenie podczas zakończenia sesji wspólnej jest odzyskiwane przez reconnect recovery znanego `sessionId`; dłuższy brak aplikacji nadal ma fallback przez historię.
- Identyczny replay porównuje znormalizowany komentarz; inna treść pozostaje niedozwoloną edycją.
- Testy SQLite nie wystarczą do potwierdzenia migracji SQL Server.
- Jeden automatyczny test przez prawdziwy backend SignalR i Flutter nie jest dostępny; wymagany jest zestaw pokrywających się testów backend HTTP, backend SignalR i Flutter fake realtime.

## Success Criteria (Summary)

- Podopieczny może wysłać lub później uzupełnić feedback po obu typach treningu.
- Dokładnie jeden, nieedytowalny wpis trafia do właściwej sesji i jest odporny na retry.
- Aktualny trener widzi wpis read-only, a nieuprawnieni użytkownicy nie uzyskują dostępu.
- Istniejące kończenie sesji, realtime, progres i historia nie mają regresji.
