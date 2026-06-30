# Usuwanie zestawu z ekranu Moje zestawy — Plan Brief

> Full plan: `context/changes/delete-workout-set/plan.md`

## What & Why

Trener otrzyma możliwość usunięcia zestawu bezpośrednio z ekranu „Moje zestawy” przez menu trzech kropek zgodne z plikami designu. Operacja będzie bezpieczna dla historii treningów: zamiast fizycznego kasowania zestaw zostanie zarchiwizowany i wycofany z bieżącego użycia.

## Starting Point

Ekran ma dziś akcje „Edytuj” i „Przypisz”, a API nie udostępnia usuwania całego zestawu. Zestawy są powiązane z przypisaniami, sesjami i progresem; sesje oraz progres mają restrykcyjne klucze obce, więc twarde kasowanie naruszałoby istniejący model historii.

## Desired End State

Trener otwiera zakotwiczone menu przy konkretnej karcie, wybiera „Usuń zestaw”, potwierdza i po sukcesie widzi zniknięcie karty. Przypisania są usuwane, nowe użycie zestawu jest niemożliwe, historia pozostaje dostępna, a aktywna sesja blokuje operację czytelnym komunikatem.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Semantyka usuwania | Archiwizacja wszystkich zestawów | Jedna przewidywalna reguła chroni historię i relacje FK. |
| Aktywna sesja | Blokada `409 Conflict` | Trening nie może zostać przerwany przez akcję administracyjną. |
| Przypisania | Usunięcie przy archiwizacji | Zestaw musi zniknąć również z aktywnych widoków podopiecznych. |
| Potwierdzenie | Dialog z nazwą zestawu | Chroni przed przypadkowym kliknięciem destrukcyjnej akcji. |
| Aktualizacja UI | Dopiero po `204` | Lista zawsze odzwierciedla potwierdzony stan serwera. |
| Błąd | Zachowanie karty i komunikat | Użytkownik nie traci kontekstu i może ponowić operację. |
| Przywracanie | Poza zakresem | MVP dostarcza usunięcie bez nowego modułu zarządzania archiwum. |
| Współbieżność | `Serializable` dla startu i DELETE | Obie operacje muszą atomowo rozstrzygać stan zestawu i aktywnej sesji. |

## Scope

**In scope:**

- nullable `DeletedAt`, migracja i indeks,
- `DELETE /workout-sets/{id}` z autoryzacją i idempotencją,
- blokada aktywnej sesji oraz filtrowanie archiwalnych zestawów,
- usunięcie aktywnych przypisań przy zachowaniu historii i wierszy,
- klient i kontroler Fluttera,
- menu, dialog, komunikaty oraz testy API/mobile.

**Out of scope:**

- twarde kasowanie historii lub progresu,
- anulowanie aktywnej sesji,
- ekran archiwum, restore i undo,
- zmiany w kreatorze, przypisywaniu i istniejącej nawigacji,
- edycja plików designu.

## Architecture / Approach

Backend zachowuje rekord zestawu i oznacza go `DeletedAt`, usuwa przypisania oraz filtruje go ze wszystkich aktywnych zapytań, w tym podsumowań relacji. Start sesji i DELETE używają execution strategy oraz transakcji `Serializable`, aby wykluczyć wyścig między utworzeniem sesji a archiwizacją. Klient aktualizuje lokalną listę wyłącznie po sukcesie, a ekran prezentuje menu i dialog zgodne z `LiftMate.dc.html`. Dane historyczne nadal opierają się na istniejących sesjach, snapshotach wartości i progresie.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Archiwizacja i kontrakt API | Migracja, endpoint, filtrowanie i ochrona sesji | Niejawne użycie archiwalnego ID lub częściowa mutacja przy konflikcie. |
| 2. Klient mobilny | Żądanie DELETE i spójne przejścia stanu | Przedwczesne usunięcie karty lub utrata listy przy błędzie. |
| 3. UI zgodne z designem | Menu, dialog, komunikaty i testy widgetowe | Drift wizualny albo podwójne wywołanie akcji. |

**Prerequisites:** Branch `codex/delete-workout-set`, działające projekty API i Flutter oraz aktualna baza zgodna z migracjami repozytorium.

**Estimated effort:** Średni zakres, trzy kolejno weryfikowane fazy obejmujące backend i mobile.

## Open Risks & Assumptions

- Zakończona historia korzysta z istniejących snapshotów sesji i nie wymaga ponownego aktywowania zestawu.
- Transakcje `Serializable` mogą być ponawiane przez execution strategy; implementacja nie może emitować komunikatów ani eventów przed zatwierdzeniem transakcji.
- Testy funkcjonalne używają SQLite, dlatego test skryptu migracji osobno weryfikuje kontrakt SQL Server; dokładne zachowanie blokad dostawcy pozostaje elementem weryfikacji wdrożeniowej.
- Manualna zgodność wizualna wymaga uruchomienia aplikacji na docelowym ekranie Androida.

## Success Criteria (Summary)

- Trener usuwa zestaw przez „3 kropki → Usuń zestaw → potwierdzenie”, a karta znika dopiero po sukcesie.
- Zestaw znika ze wszystkich aktywnych widoków i nie może rozpocząć nowej sesji, ale historia oraz progres pozostają dostępne.
- Aktywna sesja i błędy sieci nie zmieniają danych ani listy; użytkownik otrzymuje jasny komunikat i może ponowić operację.
