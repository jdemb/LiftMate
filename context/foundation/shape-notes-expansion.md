---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego - expansion"
context_type: brownfield
created: 2026-06-23
updated: 2026-06-23
product_type: mobile
target_scale:
  users: medium
  qps: low
  data_volume: small
timeline_budget:
  delivery_weeks: 1
  hard_deadline: 2026-06-28
  after_hours_only: true
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  gray_areas_resolved:
    - topic: "kontekst zmiany"
      decision: "Rozszerzenie istniejącej aplikacji w trybie brownfield."
    - topic: "cel rozszerzenia"
      decision: "Przygotowanie aplikacji do bezpieczniejszej i bardziej dopracowanej bety."
    - topic: "zakres wejściowy"
      decision: "Nowe funkcjonalności i wskazane błędy są wspólnym wejściem do rozszerzenia roadmapy."
    - topic: "persony"
      decision: "Główną personą pozostaje podopieczny, a trener jest personą drugorzędną."
    - topic: "dostęp do rejestracji beta"
      decision: "Każda nowa rejestracja wymaga jednego wspólnego kodu beta bez limitu użyć; kod działa dla obu ról."
    - topic: "istniejące konta i role"
      decision: "Istniejące konta nie wymagają kodu, a obecne logowanie, role i uprawnienia pozostają bez zmian."
    - topic: "kolejność realizacji"
      decision: "Najpierw bezpieczeństwo bety i błędy, następnie feedback po treningu, podpowiedzi dla trenera i system motywacyjny."
    - topic: "termin rozszerzenia"
      decision: "Całe rozszerzenie ma zostać dostarczone do 2026-06-28 w ramach jednego tygodnia pracy po godzinach."
    - topic: "feedback po treningu"
      decision: "Po każdym zakończonym treningu, samodzielnym lub wspólnym, podopieczny może wysłać opcjonalny komentarz i obowiązkową ocenę samopoczucia 1-5; wpis jest nieedytowalny i widoczny trenerowi w historii sesji."
    - topic: "podpowiedzi dla trenera"
      decision: "Jawne reguły tworzą informacyjną podpowiedź po braku wzrostu ciężaru przez 3 kolejne treningi lub średniej ocenie samopoczucia <= 3 z ostatnich 3 treningów; komentarze nie są interpretowane automatycznie, zestaw nie jest zmieniany automatycznie, a trener może oznaczyć podpowiedź jako przeczytaną."
    - topic: "seria regularności"
      decision: "Seria oznacza liczbę kolejnych tygodni od poniedziałku do niedzieli z co najmniej jednym zakończonym treningiem dowolnego typu; podopieczny widzi aktualną i najlepszą serię, a tydzień bez treningu zeruje serię aktualną."
    - topic: "wykrywanie stagnacji ciężaru"
      decision: "Reguła analizuje trzy ostatnie zakończone treningi zawierające to samo ćwiczenie typu powtórzenia + waga, porównuje najwyższy wykonany ciężar w każdej sesji i wykrywa stagnację, gdy trzeci wynik nie jest wyższy od pierwszego; jedna podpowiedź pozostaje aktywna do oznaczenia jako przeczytana."
    - topic: "granice rozszerzenia"
      decision: "Bez weryfikacji e-mail, indywidualnych kodów beta, analizy komentarzy, AI, automatycznych zmian planu, rozbudowanej grywalizacji i zmian obecnego modelu dostępu."
  frs_drafted: 12
  quality_check_status: accepted
---

## Current System

LiftMate jest istniejącą aplikacją mobilną treningową obsługującą relację trener-podopieczny. Podstawowa funkcjonalność określona w dotychczasowej roadmapie została zbudowana.

Z aplikacji korzystają podopieczni oraz trenerzy. Główną personą pozostaje podopieczny, a trener jest personą drugorzędną.

Obecne przepływy, dane oraz reguły relacji trener-podopieczny muszą zostać zachowane bez regresji.

## Vision & Problem Statement

Kolejny etap rozwoju ma przygotować aplikację do bezpieczniejszej i bardziej dopracowanej bety. Zakres obejmuje nowe funkcjonalności oraz usunięcie błędów opisanych w `documents/idea-expansion-notes.md`.

Obecne luki obejmują publiczną dostępność rejestracji przez API, mało przyjazne komunikaty walidacyjne, brak feedbacku po samodzielnym treningu, brak podpowiedzi dla trenera, niedziałające lub brakujące akcje w interfejsie oraz brak mechanizmu motywacyjnego dla podopiecznego.

## User & Persona

Primary persona: podopieczny korzystający z aplikacji podczas samodzielnego treningu lub treningu prowadzonego przez trenera. Rozszerzenie ma poprawić zrozumiałość aplikacji, możliwość przekazania informacji po treningu i motywację do regularnego wykonywania treningów.

### Secondary persona

Trener prowadzący podopiecznych, odbierający ich feedback i potrzebujący użytecznych sygnałów wynikających z historii treningowej.

## Access Control

Obecny model logowania, role trenera i podopiecznego oraz ich uprawnienia pozostają bez zmian.

Każda nowa rejestracja wymaga podania jednego wspólnego kodu dostępu do bety. Kod jest wspólny dla testerów, nie ma limitu użyć i pozwala tworzyć konta obu ról. Istniejące konta nadal logują się bez podawania kodu.

## Success Criteria

### Primary

- Do 2026-06-28 rejestracja nowych kont jest ograniczona wspólnym kodem beta, a wskazane błędy rejestracji, hasła, komunikatów i kopiowania kodu trenera są usunięte.
- Podopieczny może przekazać trenerowi feedback po samodzielnie wykonanym treningu, a trener otrzymuje użyteczne podpowiedzi wynikające z historii treningowej i feedbacku.

### Secondary

- Podopieczny otrzymuje informację motywującą do regularnego wykonywania treningów.
- Komunikaty walidacyjne są zrozumiałe dla polskiego użytkownika.

### Guardrails

- Obecne logowanie, role i uprawnienia pozostają bez zmian.
- Istniejące konta nie wymagają kodu beta.
- Obecne przepływy treningowe, zapisane dane i relacja trener-podopieczny nie ulegają regresji.

## Delivery Scope

Pierwsza kolejność realizacji obejmuje ograniczenie rejestracji kodem beta, przyjazne komunikaty walidacyjne, naprawę funkcji „pokaż hasło”, naprawę błędu po wklejeniu kodu trenerskiego oraz kopiowanie kodu trenera.

Druga kolejność obejmuje feedback i ocenę po treningu, podpowiedzi dla trenera oraz system motywacyjny dla podopiecznego.

## Draft User Stories

### US-01: Podopieczny przekazuje feedback po treningu

- **Given** podopieczny zakończył trening samodzielny albo wspólny
- **When** podaje ocenę samopoczucia w skali 1–5 i opcjonalny komentarz
- **Then** feedback zostaje zapisany przy zakończonej sesji i jest dostępny trenerowi w jej historii

#### Acceptance Criteria

- Ocena samopoczucia 1–5 jest wymagana do wysłania feedbacku.
- Komentarz tekstowy jest opcjonalny.
- Feedback można zostawić po treningu samodzielnym i wspólnym.
- Wysłanego feedbacku podopieczny nie może edytować.
- Trener widzi feedback przy właściwej zakończonej sesji treningowej.

### US-02: Trener otrzymuje podpowiedź na podstawie historii

- **Given** podopieczny ma co najmniej trzy zakończone treningi zawierające wymagane dane
- **When** ciężar danego ćwiczenia nie wzrósł przez trzy kolejne treningi albo średnia ocena samopoczucia z ostatnich trzech treningów wynosi 3 lub mniej
- **Then** trener widzi informacyjną podpowiedź dotyczącą podopiecznego

#### Acceptance Criteria

- Reguła stagnacji analizuje brak wzrostu ciężaru przez trzy kolejne zakończone treningi.
- Reguła samopoczucia analizuje średnią ocenę z ostatnich trzech zakończonych treningów i uruchamia się dla wyniku nie większego niż 3.
- Komentarze tekstowe nie są automatycznie interpretowane.
- Podpowiedź nie zmienia automatycznie zestawu ani wartości treningowych.
- Trener może oznaczyć podpowiedź jako przeczytaną.

### US-03: Podopieczny śledzi serię regularności

- **Given** podopieczny kończy treningi samodzielne lub wspólne
- **When** zakończy co najmniej jeden trening w kolejnym tygodniu
- **Then** jego aktualna seria regularności zwiększa się, a najlepsza seria pozostaje zapisana

#### Acceptance Criteria

- Tydzień trwa od poniedziałku do niedzieli.
- Do serii liczy się co najmniej jeden zakończony trening samodzielny albo wspólny w tygodniu.
- Podopieczny widzi aktualną i najlepszą serię.
- Tydzień bez zakończonego treningu zeruje aktualną serię.

## Draft Functional Requirements

- FR-001: Nowy użytkownik może utworzyć konto trenera albo podopiecznego wyłącznie po podaniu poprawnego wspólnego kodu beta. Priority: must-have
- FR-002: Istniejący użytkownik może nadal logować się bez podawania kodu beta. Priority: must-have
- FR-003: Polski użytkownik otrzymuje zrozumiałe komunikaty walidacyjne zamiast niezrozumiałych komunikatów technicznych. Priority: must-have
- FR-004: Użytkownik może pokazać i ponownie ukryć hasło w polu hasła. Priority: must-have
- FR-005: Podopieczny może wkleić kod trenera podczas rejestracji bez uszkodzenia widoku i otrzymuje zrozumiały komunikat o wyniku operacji. Priority: must-have
- FR-006: Trener może skopiować swój kod trenerski przyciskiem w aplikacji. Priority: must-have
- FR-007: Podopieczny może po zakończeniu treningu samodzielnego lub wspólnego wysłać ocenę samopoczucia 1–5 i opcjonalny komentarz. Priority: must-have
- FR-008: Trener może zobaczyć nieedytowalny feedback podopiecznego przy właściwej zakończonej sesji. Priority: must-have
- FR-009: Trener może otrzymać informacyjną podpowiedź na podstawie stagnacji ciężaru albo średniej oceny samopoczucia z ostatnich trzech treningów. Priority: must-have
- FR-010: Trener może oznaczyć podpowiedź jako przeczytaną. Priority: must-have
- FR-011: Podopieczny może zobaczyć aktualną i najlepszą tygodniową serię regularności. Priority: must-have
- FR-012: Aplikacja może zerować aktualną serię po tygodniu bez zakończonego treningu, zachowując najlepszą serię. Priority: must-have

## Business Logic Changes

Podpowiedź dla trenera powstaje, gdy historia trzech ostatnich zakończonych treningów spełnia jawną regułę stagnacji ciężaru albo obniżonego samopoczucia, bez automatycznej zmiany planu treningowego.

Reguła stagnacji dotyczy wyłącznie ćwiczeń typu „powtórzenia + waga”. Analizuje trzy ostatnie zakończone treningi zawierające to samo ćwiczenie i porównuje najwyższy wykonany ciężar w każdej sesji. Stagnacja występuje, gdy wynik trzeciego treningu nie jest wyższy od wyniku pierwszego. Dla danego sygnału utrzymywana jest jedna aktywna podpowiedź do czasu oznaczenia jej przez trenera jako przeczytanej.

Reguła samopoczucia analizuje obowiązkowe oceny z trzech ostatnich zakończonych treningów. Podpowiedź powstaje, gdy średnia ocena wynosi 3 lub mniej. Komentarze tekstowe pozostają dostępne trenerowi, ale nie są automatycznie interpretowane.

Seria regularności jest liczbą kolejnych tygodni od poniedziałku do niedzieli, w których podopieczny zakończył co najmniej jeden trening samodzielny albo wspólny. Tydzień bez zakończonego treningu zeruje aktualną serię, ale nie usuwa najlepszej osiągniętej serii.

## Constraints & Preserved Behavior

- Obecne konta, role, relacje trener-podopieczny i uprawnienia pozostają zgodne z dotychczasowym zachowaniem.
- Kod beta ogranicza wyłącznie tworzenie nowych kont i nie zmienia logowania istniejących użytkowników.
- Nowy feedback i podpowiedzi nie zmieniają historycznych wartości wykonania ani planów treningowych.
- Treningi samodzielne i wspólne pozostają zgodne z obecnym przepływem rozpoczynania, synchronizacji i kończenia sesji.
- Istniejące dane muszą pozostać dostępne po wprowadzeniu rozszerzenia.

## Non-Functional Requirements

- Użytkownik otrzymuje zrozumiały polski rezultat walidacji lub operacji zamiast komunikatu technicznego.
- Akcje wykonywane podczas rejestracji nie powodują uszkodzenia, przepełnienia ani nieczytelności widoku na obsługiwanych telefonach.
- Skopiowanie kodu trenera daje użytkownikowi widoczne potwierdzenie w czasie krótszym niż 1 sekunda.
- Zapisany feedback, historia treningów oraz podpowiedzi są widoczne wyłącznie dla właściwego podopiecznego i jego trenera.
- Dodanie rozszerzenia nie pogarsza aktualizacji wspólnej sesji treningowej bez ręcznego odświeżania.

## Non-Goals

- Brak weryfikacji adresu e-mail w tej wersji — dostęp do bety kontroluje wspólny kod.
- Brak indywidualnych kodów beta oraz limitów ich użycia.
- Brak automatycznej analizy treści komentarzy podopiecznego.
- Brak AI i automatycznych zmian zestawu lub wartości treningowych.
- Brak rozbudowanej grywalizacji poza aktualną i najlepszą tygodniową serią regularności.
- Brak zmian obecnych ról, logowania, uprawnień i reguł relacji trener-podopieczny.

## Quality cross-check

- Access Control: present.
- Business Logic Changes: present.
- Project artifact and checkpoint: present.
- Timeline-cost acknowledgment: present — one week of after-hours work, deadline 2026-06-28.
- Non-Goals: present.
- Constraints & Preserved Behavior: present.
- Result: accepted with no blocking gaps.

## Draft Scope of Change

- [new] Podopieczny może przekazać ocenę samopoczucia i opcjonalny komentarz po zakończeniu treningu samodzielnego lub wspólnego.
- [new] Trener widzi feedback podopiecznego w historii właściwej sesji treningowej.
- [new] Trener otrzymuje informacyjną podpowiedź po wykryciu stagnacji ciężaru lub obniżonej średniej oceny samopoczucia.
- [new] Trener może oznaczyć podpowiedź jako przeczytaną.
- [new] Podopieczny widzi aktualną i najlepszą tygodniową serię regularności.
- [modified] Rejestracja nowego konta wymaga poprawnego wspólnego kodu beta.
- [modified] Komunikaty walidacyjne są zrozumiałe dla polskiego użytkownika.
- [modified] Przycisk pokazywania hasła poprawnie przełącza widoczność wartości.
- [modified] Wklejenie kodu trenera nie uszkadza widoku i pokazuje zrozumiały rezultat.
- [modified] Kod trenera można skopiować przyciskiem.
- [preserved] Aplikacja nie interpretuje automatycznie komentarzy i nie zmienia automatycznie zestawów ani wartości treningowych.
- [preserved] Feedback nie zmienia wartości wykonania ani pozostałych danych zakończonego treningu.
