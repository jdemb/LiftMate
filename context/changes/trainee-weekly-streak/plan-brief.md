# Tygodniowa seria regularnosci — Plan Brief

> Full plan: `context/changes/trainee-weekly-streak/plan.md`

## What & Why

S-11 dodaje podopiecznemu i trenerowi widoczna tygodniowa serie regularnosci. Seria rosnie, gdy podopieczny ma co najmniej jeden zakonczony trening w kolejnym tygodniu od poniedzialku do niedzieli, a tydzien bez treningu zeruje aktualna serie bez kasowania najlepszego wyniku.

## Starting Point

Zakonczone treningi sa juz zapisywane jako `SharedSession` z `Status == completed` i `ClosedAt`. Historia oraz S-10 korzystaja z tego samego zrodla, a design HTML pokazuje docelowe miejsca serii: ikona plomienia z liczba na liscie podopiecznych oraz kafel `🔥6 seria` na detalu podopiecznego.

## Desired End State

Podopieczny widzi na ekranie "Dzis" aktualna i najlepsza serie. Trener widzi skrot `🔥 N` pod informacja o ostatnim treningu na liscie podopiecznych oraz pelniejszy kafel na detalu podopiecznego. Wynik uwzglednia istniejaca historie, treningi samodzielne i wspolne, oraz granice tygodnia Europe/Warsaw.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Primary UI | Ekran "Dzis" podopiecznego | Seria ma dzialac motywacyjnie bez wchodzenia w historie. |
| Trainer UI | Lista i detal podopiecznego | Uzytkownik wskazal kontrakt HTML: plomien + liczba pod ostatnim treningiem i kafel na detalu. |
| Persistence | Snapshot + read-time current | Tani odczyt, zachowany best streak i poprawne zerowanie po pustym tygodniu. |
| Week contract | `DateOnly`/SQL `date` + ISO date in JSON | Tydzien jest lokalna data poniedzialku, nie timestampem. |
| Existing history | Backfill/read-through rekalkulacja | Uzytkownicy z historia dostaja sensowny wynik od razu. |
| Timezone | Europe/Warsaw | Zgodne z beta i prostsze niz brakujace per-user timezone. |
| Zero state | Pokazac `0 tygodni` z neutralna zacheta | Jawny stan bez ukrywania mechanizmu. |
| Weekly counting | Jeden lub wiecej treningow = jeden tydzien | Zgodne z PRD: co najmniej jeden zakonczony trening w tygodniu. |

## Scope

**In scope:**

- kontrakt designu dla serii w `LiftMate.dc.html` i `LiftMate.html`;
- nowy snapshot tygodniowej serii w API;
- rekalkulacja po zakonczeniu sesji i bezpieczne zasilenie istniejacej historii;
- rozszerzenie `GET /trainee/relationship` i `GET /trainer/relationship`;
- modele i UI Flutter dla podopiecznego, listy trenera i detalu podopiecznego;
- testy granic tygodnia, backfillu, relacji trener-podopieczny i UI.

**Out of scope:**

- rankingi, odznaki, powiadomienia i rozbudowana grywalizacja;
- edycja reczna serii;
- per-user timezone;
- seria per zestaw lub per cwiczenie;
- zmiana zasad historii, feedbacku, guidance albo progresu.

## Architecture / Approach

API przechowuje `TraineeWeeklyStreak` jako snapshot ostatniego aktywnego tygodnia, serii na ten tydzien i najlepszego wyniku. `LastActiveWeekStart` jest lokalna data poniedzialku (`DateOnly`/SQL `date`, JSON `yyyy-MM-dd`), a odczyt uzywa wstrzyknietego `TimeProvider` do wyliczenia `currentStreak` wzgledem obecnego tygodnia Europe/Warsaw. Relationship endpoints dolaczaja gotowy DTO do podopiecznego i trenera.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Design contract | Seria w HTML dla podopiecznego i trenera | Rozjazd Fluttera z projektem |
| 2. API snapshot | Encja, migracja, kalkulator tygodni | Bledne granice tygodnia |
| 3. API integration | Rekalkulacja po complete i relationship DTO | N+1 albo brak backfillu |
| 4. Mobile models/UI | Plomien na liscie, kafle na detail/home | Overflow i konflikt z istniejacymi akcjami |
| 5. Verification | Regresje i edge cases | Rzadkie daty przy granicy tygodnia |

**Prerequisites:** S-04 zakonczone; aktualny kod S-09/S-10 pozostaje nietkniety poza wspolnym odczytem historii.
**Estimated effort:** 4-6 skoncentrowanych sesji, najlepiej w 5 osobnych commitach.

## Open Risks & Assumptions

- Europe/Warsaw jest swiadomym uproszczeniem bety; zmiana na per-user timezone wymagalaby profilu/preferencji.
- Read-through rekalkulacja dla brakujacego snapshotu jest dopuszczona tylko jako inicjalizacja/backfill, nie jako stale liczenie kazdego odczytu.
- Aktualna seria moze byc `0`, nawet gdy `bestStreak` jest wiekszy, jesli ostatni aktywny tydzien jest starszy niz poprzedni tydzien.

## Success Criteria Summary

- Podopieczny widzi aktualna i najlepsza tygodniowa serie.
- Trener widzi `🔥 N` na liscie i szczegoly serii na detalu podopiecznego.
- Sesje samodzielne i wspolne licza sie tak samo, a pusty tydzien zeruje tylko aktualna serie.
