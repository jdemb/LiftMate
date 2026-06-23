---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego - expansion"
version: 2
status: draft
created: 2026-06-23
context_type: brownfield
product_type: mobile
target_scale:
  users: medium
  qps: low
  data_volume: small
timeline_budget:
  delivery_weeks: 1
  hard_deadline: 2026-06-28
  after_hours_only: true
---

## Current System Overview

LiftMate jest istniejącą aplikacją mobilną treningową obsługującą relację trener-podopieczny. Podstawowa funkcjonalność określona w dotychczasowej roadmapie została zbudowana.

Z aplikacji korzystają podopieczni oraz trenerzy. Główną personą pozostaje podopieczny, a trener jest personą drugorzędną. Obecne przepływy, dane oraz reguły relacji trener-podopieczny muszą zostać zachowane bez regresji.

System jest monorepo z aplikacją mobilną Flutter oraz serwerowym API ASP.NET Core. API używa relacyjnej bazy danych, migracji, uwierzytelniania tokenowego, autoryzacji ról i relacji trener-podopieczny oraz synchronizacji aktywnej sesji. Automatyczne wdrożenie API i migracji jest dostępne; wydawanie aplikacji mobilnej pozostaje ręczne. Dedykowana telemetria aplikacyjna nie jest obecnie skonfigurowana.

## Problem Statement & Motivation

Kolejny etap rozwoju ma przygotować aplikację do bezpieczniejszej i bardziej dopracowanej bety. Zakres obejmuje nowe funkcjonalności oraz usunięcie błędów opisanych w `documents/idea-expansion-notes.md`.

Obecne luki obejmują publiczną dostępność rejestracji, mało przyjazne komunikaty walidacyjne, brak feedbacku po treningu, brak podpowiedzi dla trenera, niedziałające lub brakujące akcje w interfejsie oraz brak mechanizmu motywacyjnego dla podopiecznego.

Pierwsza kolejność realizacji obejmuje ograniczenie rejestracji kodem beta, przyjazne komunikaty walidacyjne, naprawę funkcji „pokaż hasło”, naprawę błędu po wklejeniu kodu trenerskiego oraz kopiowanie kodu trenera. Druga kolejność obejmuje feedback i ocenę po treningu, podpowiedzi dla trenera oraz system motywacyjny dla podopiecznego.

## User & Persona

Primary persona: podopieczny korzystający z aplikacji podczas samodzielnego treningu lub treningu prowadzonego przez trenera. Rozszerzenie ma poprawić zrozumiałość aplikacji, możliwość przekazania informacji po treningu i motywację do regularnego wykonywania treningów.

### Secondary persona

Trener prowadzący podopiecznych, odbierający ich feedback i potrzebujący użytecznych sygnałów wynikających z historii treningowej.

## Success Criteria

### Primary

- Do 2026-06-28 rejestracja nowych kont jest ograniczona wspólnym kodem beta, a wskazane błędy rejestracji, hasła, komunikatów i kopiowania kodu trenera są usunięte.
- Podopieczny może przekazać trenerowi feedback po zakończonym treningu, a trener otrzymuje użyteczne podpowiedzi wynikające z historii treningowej i feedbacku.

### Secondary

- Podopieczny otrzymuje informację motywującą do regularnego wykonywania treningów.
- Komunikaty walidacyjne są zrozumiałe dla polskiego użytkownika.

### Guardrails

- Obecne logowanie, role i uprawnienia pozostają bez zmian.
- Istniejące konta nie wymagają kodu beta.
- Obecne przepływy treningowe, zapisane dane i relacja trener-podopieczny nie ulegają regresji.
- Akcje wykonywane podczas rejestracji nie powodują uszkodzenia, przepełnienia ani nieczytelności widoku na obsługiwanych telefonach.
- Skopiowanie kodu trenera daje użytkownikowi widoczne potwierdzenie w czasie krótszym niż 1 sekunda.
- Dodanie rozszerzenia nie pogarsza aktualizacji wspólnej sesji treningowej bez ręcznego odświeżania.

## User Stories

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

- Reguła stagnacji analizuje trzy ostatnie zakończone treningi zawierające to samo ćwiczenie typu „powtórzenia + waga”.
- Reguła stagnacji porównuje najwyższy wykonany ciężar w każdej sesji i uruchamia się, gdy trzeci wynik nie jest wyższy od pierwszego.
- Reguła samopoczucia analizuje średnią ocenę z ostatnich trzech zakończonych treningów i uruchamia się dla wyniku nie większego niż 3.
- Komentarze tekstowe nie są automatycznie interpretowane.
- Podpowiedź nie zmienia automatycznie zestawu ani wartości treningowych.
- Dla danego sygnału jedna podpowiedź pozostaje aktywna do oznaczenia jej jako przeczytanej.
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

### US-04: Tester bezpiecznie rejestruje konto w becie

- **Given** tester posiada wspólny kod beta i wybiera rolę trenera albo podopiecznego
- **When** wypełnia formularz rejestracji, opcjonalnie wkleja kod trenera i wysyła dane
- **Then** konto powstaje tylko dla poprawnego kodu beta, a formularz pozostaje czytelny i pokazuje zrozumiały polski rezultat

#### Acceptance Criteria

- Niepoprawny lub brakujący kod beta blokuje utworzenie nowego konta.
- Poprawny wspólny kod beta działa dla konta trenera i podopiecznego bez limitu użyć.
- Istniejące konta nadal logują się bez kodu beta.
- Przycisk „pokaż hasło” poprawnie przełącza widoczność hasła.
- Wklejenie kodu trenera nie uszkadza ani nie zniekształca widoku.
- Błędy formularza i rejestracji są przedstawiane zrozumiałym komunikatem po polsku.

### US-05: Trener kopiuje kod zaproszenia

- **Given** trener ma wygenerowany kod trenerski
- **When** wybiera akcję kopiowania kodu
- **Then** kod zostaje skopiowany, a trener otrzymuje widoczne potwierdzenie operacji

#### Acceptance Criteria

- Akcja kopiuje dokładnie aktualny kod trenera.
- Potwierdzenie skopiowania jest widoczne w czasie krótszym niż 1 sekunda.

## Scope of Change

- [new] Podopieczny może przekazać ocenę samopoczucia i opcjonalny komentarz po zakończeniu treningu samodzielnego lub wspólnego.
- [new] Trener widzi feedback podopiecznego w historii właściwej sesji treningowej.
- [new] Trener otrzymuje informacyjną podpowiedź po wykryciu stagnacji ciężaru lub obniżonej średniej oceny samopoczucia.
- [new] Trener może oznaczyć podpowiedź jako przeczytaną.
- [new] Podopieczny widzi aktualną i najlepszą tygodniową serię regularności.
- [modified] Rejestracja nowego konta trenera albo podopiecznego wymaga poprawnego wspólnego kodu beta.
- [modified] Komunikaty walidacyjne są zrozumiałe dla polskiego użytkownika zamiast prezentowania niezrozumiałych komunikatów technicznych.
- [modified] Przycisk pokazywania hasła poprawnie przełącza widoczność wartości.
- [modified] Wklejenie kodu trenera podczas rejestracji nie uszkadza widoku i pokazuje zrozumiały rezultat.
- [modified] Kod trenera można skopiować przyciskiem, a użytkownik otrzymuje potwierdzenie operacji.
- [preserved] Istniejący użytkownik nadal loguje się bez podawania kodu beta.
- [preserved] Aplikacja nie interpretuje automatycznie komentarzy i nie zmienia automatycznie zestawów ani wartości treningowych.
- [preserved] Feedback nie zmienia wartości wykonania ani pozostałych danych zakończonego treningu.

## Constraints & Compatibility

- Obecne konta, role, relacje trener-podopieczny i uprawnienia pozostają zgodne z dotychczasowym zachowaniem.
- Kod beta ogranicza wyłącznie tworzenie nowych kont i nie zmienia logowania istniejących użytkowników.
- Nowy feedback i podpowiedzi nie zmieniają historycznych wartości wykonania ani planów treningowych.
- Treningi samodzielne i wspólne pozostają zgodne z obecnym przepływem rozpoczynania, synchronizacji i kończenia sesji.
- Istniejące dane muszą pozostać dostępne po wprowadzeniu rozszerzenia.
- Użytkownik otrzymuje zrozumiały polski rezultat walidacji lub operacji zamiast komunikatu technicznego.
- Zapisany feedback, historia treningów oraz podpowiedzi są widoczne wyłącznie dla właściwego podopiecznego i jego trenera.
- Rozszerzenie zachowuje istniejące kontrakty logowania, rejestracji, parowania, aktywnej sesji, historii treningów i progresu.
- Nowe dane są dodawane bez usuwania lub reinterpretacji istniejących kont, sesji, historii i wartości treningowych.
- Zmiany danych wymagane przez feedback, podpowiedzi i serię regularności mają być addytywne i wdrażalne istniejącą ścieżką migracji.

## Business Logic Changes

Podpowiedź dla trenera powstaje, gdy historia trzech ostatnich zakończonych treningów spełnia jawną regułę stagnacji ciężaru albo obniżonego samopoczucia, bez automatycznej zmiany planu treningowego.

Reguła stagnacji dotyczy wyłącznie ćwiczeń typu „powtórzenia + waga”. Analizuje trzy ostatnie zakończone treningi zawierające to samo ćwiczenie i porównuje najwyższy wykonany ciężar w każdej sesji. Stagnacja występuje, gdy wynik trzeciego treningu nie jest wyższy od wyniku pierwszego. Dla danego sygnału utrzymywana jest jedna aktywna podpowiedź do czasu oznaczenia jej przez trenera jako przeczytanej.

Reguła samopoczucia analizuje obowiązkowe oceny z trzech ostatnich zakończonych treningów. Podpowiedź powstaje, gdy średnia ocena wynosi 3 lub mniej. Komentarze tekstowe pozostają dostępne trenerowi, ale nie są automatycznie interpretowane.

Seria regularności jest liczbą kolejnych tygodni od poniedziałku do niedzieli, w których podopieczny zakończył co najmniej jeden trening samodzielny albo wspólny. Tydzień bez zakończonego treningu zeruje aktualną serię, ale nie usuwa najlepszej osiągniętej serii.

## Access Control Changes

Obecny model logowania, role trenera i podopiecznego oraz ich uprawnienia pozostają bez zmian.

Każda nowa rejestracja wymaga podania jednego wspólnego kodu dostępu do bety. Kod jest wspólny dla testerów, nie ma limitu użyć i pozwala tworzyć konta obu ról. Istniejące konta nadal logują się bez podawania kodu.

Feedback, historia treningów i podpowiedzi pozostają widoczne wyłącznie dla właściwego podopiecznego i jego trenera.

## Non-Goals

- Brak weryfikacji adresu e-mail w tej wersji — dostęp do bety kontroluje wspólny kod.
- Brak indywidualnych kodów beta oraz limitów ich użycia.
- Brak automatycznej analizy treści komentarzy podopiecznego.
- Brak AI i automatycznych zmian zestawu lub wartości treningowych.
- Brak rozbudowanej grywalizacji poza aktualną i najlepszą tygodniową serią regularności.
- Brak zmian obecnych ról, logowania, uprawnień i reguł relacji trener-podopieczny.

## Open Questions

Brak otwartych pytań blokujących roadmapę. Szczegółowe kształty addytywnych migracji i kontraktów nowych endpointów należą do planowania odpowiednich zmian.
