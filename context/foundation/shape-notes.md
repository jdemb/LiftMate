---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego"
context_type: greenfield
product_type: mobile
target_scale:
  users: medium
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 2
  hard_deadline: 2026-06-21
  after_hours_only: true
created: 2026-05-23
updated: 2026-05-23
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  gray_areas_resolved:
    - topic: "context type"
      decision: "greenfield; repo is fresh and prepared for a new build"
    - topic: "product insight"
      decision: "the app combines guided training flow, continuity of progression, and trainer-client control; these are equal and non-conflicting"
    - topic: "access model"
      decision: "login accounts with two roles: trainer and trainee; one trainer can have many trainees, one trainee has exactly one trainer"
    - topic: "mvp timeline"
      decision: "target 2 weeks of after-hours work; buffer up to 3 weeks accepted"
    - topic: "template scope"
      decision: "global templates are must-have; individual templates are nice-to-have"
    - topic: "exercise library scope"
      decision: "separate trainer exercise library is nice-to-have; MVP defines exercise name and type inside the set"
    - topic: "business logic"
      decision: "the app lets the trainer prepare a trainee's workout set ahead of time and track progress through values saved across training sessions"
    - topic: "product type"
      decision: "mobile app"
    - topic: "target scale"
      decision: "dozens to about 100 users at launch; mapped to medium user scale, low qps, small data volume"
    - topic: "scale stress"
      decision: "business rule does not change at 100x scale"
    - topic: "deadline"
      decision: "hard deadline: 2026-06-21"
    - topic: "work mode"
      decision: "after-hours work"
    - topic: "non-goals"
      decision: "mobile only; no automatic exercise recommendation; no data export; no trainee-trainee or trainer-trainer interactions; no individual templates in MVP; no separate trainer exercise library in MVP; trainer edits training data only"
  frs_drafted: 11
  quality_check_status: accepted
---

# Shape Notes

Seed source: `documents/idea-notes.md`

## Vision & Problem Statement

Podopieczny trenera personalnego nie chce podczas treningu na siłowni śledzić progresu ciężarów/liczby powtórzeń ani zastanawiać się nad kolejnym ćwiczeniem. Koszt dzisiaj: podopieczny musi sam pamiętać plan, ciężary, powtórzenia i progres albo polegać ręcznie na trenerze.

Insight: aplikacja ma jednocześnie prowadzić podopiecznego przez gotowy plan i aktualne wartości, zachowywać ciągłość progresu między treningami oraz wspierać relację trener-podopieczny, w której trener kontroluje plan i dane, a podopieczny wykonuje trening.

Vision note: aplikacja ma w jak największym stopniu ułatwić podopiecznemu wejście w świat siłowni pod okiem trenera.

Scale note: reguła produktu nie zmienia się przy 100x skali.

## User & Persona

Primary persona: podopieczny trenera personalnego, który w trakcie treningu na siłowni potrzebuje jasnej informacji, jakie ćwiczenie, serie, powtórzenia i ciężary ma wykonać bez samodzielnego planowania.

Secondary persona: trener personalny, który przygotowuje ćwiczenia, zestawy i wartości treningowe dla wielu podopiecznych.

## Access Control

Użytkownik zakłada konto z jedną z dwóch ról: trener albo podopieczny.

Role i dostęp:
- Trener może mieć wielu podopiecznych.
- Podopieczny może być podpięty do dokładnie jednego trenera.
- Trener widzi i edytuje dane treningowe swoich podopiecznych.
- Podopieczny widzi i edytuje swoje własne dane.
- Trenerzy nie widzą danych innych trenerów.
- Podopieczni nie widzą danych innych podopiecznych.

## Success Criteria

### Primary

- Podopieczni i trenerzy mogą zakładać konta i łączyć się w pary w modelu: jeden trener do wielu podopiecznych, jeden podopieczny do jednego trenera.
- Trener może przeprowadzić pełny przepływ: tworzy listę ćwiczeń, buduje zestaw, przypisuje go podopiecznemu, edytuje dane w trakcie treningu, a zapisane wartości są dostępne do wykonania na kolejnym treningu.

### Secondary

- Użytkownicy mają wgląd w swoje dane zgodnie z rolą i przypisaniem trener-podopieczny.

### Guardrails

- MVP ma pozostać wersją mobilną, bez aplikacji webowej lub desktopowej.
- MVP nie dobiera automatycznie ćwiczeń pod potrzeby podopiecznego.
- MVP nie obejmuje eksportu danych.
- MVP nie obejmuje interakcji między podopiecznymi ani między trenerami.

## MVP Flow

1. Trener zakłada konto.
2. Podopieczny zakłada konto.
3. Trener i podopieczny łączą się w parę.
4. Trener definiuje ćwiczenia w zestawie.
5. Trener buduje zestaw ćwiczeń.
6. Trener przypisuje zestaw podopiecznemu.
7. W trakcie treningu dane są edytowane.
8. Zapisane wartości są używane jako wartości na kolejny trening.

## Timeline

Target: 2 tygodnie pracy po godzinach. Akceptowany bufor: do 3 tygodni pracy po godzinach.

Hard deadline: 2026-06-21.

## Functional Requirements

### Accounts & Relationships

- FR-001: Użytkownik może założyć konto z rolą trener albo podopieczny. Priority: must-have
  > Socrates: Counter-argument considered: "Brak kontrargumentu; zostaje jak jest." Resolution: kept.
- FR-002: Trener może połączyć się z wieloma podopiecznymi. Priority: must-have
  > Socrates: Counter-argument considered: "To jest sedno aplikacji dla trenera, bez tego produkt traci sens." Resolution: kept as must-have.
- FR-003: Podopieczny może być połączony z dokładnie jednym trenerem. Priority: must-have
  > Socrates: Counter-argument considered: "Jest właściwe dla MVP, bo upraszcza własność danych." Resolution: kept as must-have.
- FR-004: Trener może widzieć i edytować dane treningowe swoich podopiecznych. Priority: must-have
  > Socrates: Counter-arguments considered: "Zbyt szerokie dane mogą naruszyć granice prywatności" and "edycja w trakcie treningu może kolidować z edycją podopiecznego." Resolution: kept, but narrowed to training data only; personal/account data is out of scope for trainer edits, and interaction conflicts must be handled.
- FR-005: Podopieczny może widzieć i edytować swoje własne dane. Priority: must-have
  > Socrates: Counter-argument considered: "Edycja jest potrzebna, jeśli podopieczny wykonuje trening sam." Resolution: kept as must-have.

### Exercises & Templates

- FR-006: Trener może tworzyć własną bibliotekę ćwiczeń widoczną tylko dla niego. Priority: nice-to-have
  > Socrates: Counter-argument considered: "Biblioteka ćwiczeń opóźnia MVP; wystarczyłaby ręczna nazwa w zestawie." Resolution: moved to nice-to-have; MVP defines exercises inline inside a set.
- FR-007: Trener może zdefiniować ćwiczenie w zestawie przez nazwę i typ: powtórzenia+waga, same powtórzenia albo czas. Priority: must-have
  > Socrates: Counter-argument considered: "Typy są konieczne, bo inne ćwiczenia mają inne parametry progresu." Resolution: kept as must-have.
- FR-008: Trener może budować globalny szablon zestawu ćwiczeń do przypisania wielu podopiecznym. Priority: must-have
  > Socrates: Counter-argument considered: "Brak kontrargumentu; zostaje jak jest." Resolution: kept.
- FR-009: Trener może budować indywidualny szablon zestawu ćwiczeń dla konkretnego podopiecznego. Priority: nice-to-have
  > Socrates: Counter-argument considered: "Przesunięcie poza MVP ma sens, bo globalny szablon może być punktem startu." Resolution: kept as nice-to-have.
- FR-010: Trener może przypisać zestaw ćwiczeń podopiecznemu. Priority: must-have
  > Socrates: Counter-argument considered: "Bez przypisania nie ma przepływu trener -> podopieczny." Resolution: kept as must-have.

### Training Progress

- FR-011: Użytkownik może zapisać wartości przy ćwiczeniu, np. liczbę powtórzeń albo wagę, tak żeby były wartościami do wykonania na kolejnym treningu. Priority: must-have
  > Socrates: Counter-argument considered: "Trzeba określić, które wartości i kiedy nadpisują poprzednie." Resolution: kept, clarified as editing exercise values such as repetitions or weight.

## User Stories

### US-01: Trener przygotowuje i przypisuje trening podopiecznemu

- **Given** trener ma konto i połączonego podopiecznego
- **When** trener definiuje ćwiczenia w zestawie, buduje globalny zestaw i przypisuje go podopiecznemu
- **Then** podopieczny ma dostęp do zestawu ćwiczeń do wykonania podczas treningu

#### Acceptance Criteria

- Trener może zdefiniować ćwiczenie w zestawie przez nazwę i typ.
- Ćwiczenie ma nazwę i jeden z typów: powtórzenia+waga, same powtórzenia albo czas.
- Zestaw ćwiczeń przechowuje parametry wykonania, np. liczbę setów, powtórzeń na set i wagę.
- Zestaw globalny może zostać przypisany podopiecznemu.

### US-02: Trening zapisuje wartości na kolejną sesję

- **Given** podopieczny ma przypisany zestaw ćwiczeń
- **When** wartości treningowe zostaną edytowane w trakcie treningu
- **Then** zapisane wartości są dostępne jako wartości do wykonania na kolejnym treningu

#### Acceptance Criteria

- Zapisane wartości obejmują parametry zależne od typu ćwiczenia.
- Kolejny trening pokazuje ostatnio zapisane wartości dla przypisanego zestawu.

## Business Logic

Aplikacja pozwala trenerowi przygotować z wyprzedzeniem zestaw ćwiczeń dla podopiecznego oraz śledzić jego progres przez wartości zapisywane przy kolejnych treningach.

Reguła konsumuje przypisany zestaw ćwiczeń, typy ćwiczeń oraz wartości wykonania zapisane przy treningu, takie jak liczba powtórzeń albo waga. Jej wynikiem jest aktualny punkt progresu podopiecznego dostępny dla kolejnej sesji treningowej.

Podopieczny spotyka tę regułę podczas wykonywania przypisanego zestawu, a trener podczas przygotowania zestawu i późniejszego wglądu w progres.

## Non-Functional Requirements

- Dane treningowe są widoczne tylko dla właściwego trenera i właściwego podopiecznego zgodnie z relacją trener-podopieczny.
- Podczas treningu użytkownik widzi potwierdzenie zapisu lub zmiany wartości w czasie krótszym niż 1 sekunda w typowych warunkach działania aplikacji.
- Ekrany używane podczas treningu pozostają czytelne na telefonie i pozwalają odczytać ćwiczenie, serię oraz wartości wykonania bez przechodzenia przez dodatkowe wyjaśnienia.

## Non-Goals

- Brak aplikacji webowej i desktopowej; MVP jest wyłącznie aplikacją mobilną.
- Brak automatycznego algorytmu dobierania ćwiczeń pod potrzeby podopiecznego.
- Brak eksportu danych.
- Brak interakcji podopieczny-podopieczny i trener-trener.
- Brak indywidualnych szablonów w MVP; są oznaczone jako nice-to-have.
- Brak osobnej biblioteki ćwiczeń trenera w MVP; ćwiczenia są definiowane w zestawie.
- Brak edycji danych konta lub danych personalnych podopiecznego przez trenera; trener edytuje tylko dane treningowe.

## Quality cross-check

- Access Control: present.
- Business Logic: present.
- Project artifacts: present.
- Timeline-cost ack: present.
- Non-Goals: present.
- Preserved behavior: n/a (greenfield).
