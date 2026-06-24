# Podpowiedzi trenera z historii — Plan Brief

> Full plan: `context/changes/trainer-history-guidance/plan.md`

## What & Why

S-10 dodaje neutralne podpowiedzi dla trenera na podstawie historii podopiecznego: stagnację ciężaru dla tego samego ćwiczenia `repsWeight` oraz obniżone samopoczucie ze średniej feedbacku. Celem jest dać trenerowi informację kontekstową bez automatycznej zmiany planu lub wartości treningu.

## Starting Point

Historia i progres bazują na zakończonych `SharedSession`, a feedback S-09 jest przypisany do sesji. Brakuje trwałego modelu podpowiedzi, ewaluatora reguł, endpointów list/read oraz sekcji UI na detalu podopiecznego.

Ważna korekta designu: docelowym artefaktem kontraktu ma być `apps/mobile/design/LiftMate.html`, ale obecnym source-like plikiem w repo jest `apps/mobile/design/LiftMate.dc.html`. Plan wymaga sprawdzenia workflow synchronizacji/generowania oraz doprowadzenia obu plików do zgodności, bo zmiany feedbacku z S-09 są obecnie widoczne w `.dc.html`.

## Desired End State

Po zakończeniu sesji i po zapisie feedbacku API materializuje nowe sygnały, deduplikuje je po fingerprintcie okna dowodowego i nie odtwarza przeczytanych podpowiedzi dla tego samego fingerprintu. Aktualny trener widzi na detalu podopiecznego maksymalnie 3 aktywne karty z dowodami i może oznaczyć je jako przeczytane.

## Key Decisions Made

| Decision | Choice | Why |
|---|---|---|
| Materializacja | Po zakończeniu sesji i zapisie feedbacku | Brak skutków ubocznych na zwykłym odczycie. |
| Stagnacja | Wszystkie zapisane wartości | Spójne z obecną historią/progresem. |
| Wellbeing | 3 ostatnie zakończone sesje z feedbackiem | Sesje bez feedbacku są pomijane. |
| UI limit | Maks. 3 aktywne karty | Chroni detal podopiecznego przed szumem. |
| Read state | Globalny dla podopiecznego/sygnału | Prostszy model; przeczytany fingerprint nie wraca po zmianie trenera. |
| Dowody | Konkretne wartości w API/UI | Trener widzi, skąd pochodzi podpowiedź. |
| Ton | Neutralny informacyjny | Nie sugeruje automatycznej zmiany planu. |
| Wiele stagnacji | Osobna karta per ćwiczenie | Czytelne dowody i read state per `ExerciseId`. |
| Design | Source-like `.dc.html` + docelowy `LiftMate.html` | Finalny kontrakt ma być w `LiftMate.html`, ale nie wolno zgubić workflow źródło/artefakt. |

## Scope

**In scope:**

- uzupełnienie `LiftMate.html` o brakujące elementy feedbacku S-09 oraz zsynchronizowanie go z source-like `.dc.html`;
- sekcja `Podpowiedzi` w designie detalu podopiecznego;
- encja `TrainerGuidance`, migracja i unikalny fingerprint;
- ewaluator stagnacji i wellbeing;
- materializacja po zakończeniu sesji i zapisie feedbacku;
- endpointy `GET /trainer-guidance?traineeUserId=...` i `POST /trainer-guidance/{id}/read`;
- Flutter models/client/controller;
- sekcja kart na detalu podopiecznego;
- testy domenowe, endpointowe i mobile.

**Out of scope:**

- AI lub interpretacja komentarzy;
- automatyczne zmiany planu treningowego;
- podpowiedzi dla podopiecznego;
- łączenie ćwiczeń po nazwie;
- backfill starych danych;
- powiadomienia push/e-mail.

## Architecture / Approach

Podpowiedzi będą trwałymi rekordami deduplikowanymi po fingerprintcie trzech sesji. Ewaluator uruchamia się po zdarzeniach domenowych, a `GET` tylko odczytuje aktywne rekordy. Stagnacja działa w transakcji `Complete`, a wellbeing tylko po faktycznym utworzeniu feedbacku, nie po replayu. Dostęp opiera się na aktualnej relacji trener–podopieczny. Mobile ładuje podpowiedzi przy wejściu na detal podopiecznego i lokalnie odświeża listę po oznaczeniu jako przeczytane.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Design contract | `.dc.html` + `LiftMate.html`, korekta S-09 feedbacku i sekcja S-10 | Rozjazd między źródłem i artefaktem |
| 2. API model/evaluator | Encja, migracja, fingerprint, reguły | Duplikaty i błędne okno 3 sesji |
| 3. API endpoints/access | List/read i autoryzacja aktualnego trenera | Były/obcy trener nie może dostać dostępu |
| 4. Mobile UI/data | Klient, controller, karty na detalu | Błąd podpowiedzi nie może blokować detalu |
| 5. Verification | Regresje historii, feedbacku i workout setów | Rozjazd semantyki z istniejącym progresem |

**Prerequisites:** S-09 feedback ukończony; istniejąca historia treningów; aktualne pliki `LiftMate.dc.html` i `LiftMate.html`.

**Estimated effort:** pięć osobnych commitów, około 5–8 skoncentrowanych sesji implementacyjnych.

## Success Criteria Summary

- API tworzy podpowiedzi po zakończeniu sesji i zapisie feedbacku, nie na samym `GET`.
- Stagnacja analizuje 3 najnowsze zakończone sesje zawierające to samo `ExerciseId` typu `repsWeight`.
- Wellbeing analizuje 3 najnowsze zakończone sesje z feedbackiem i średnią `<= 3.0`.
- Przeczytany fingerprint nie wraca; nowe okno może utworzyć nową podpowiedź.
- Trener widzi maksymalnie 3 neutralne karty z dowodami i może je oznaczyć jako przeczytane.
- `LiftMate.dc.html` i `LiftMate.html` zawierają właściwy kontrakt feedbacku S-09 i podpowiedzi S-10.
