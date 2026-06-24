---
project: "Aplikacja mobilna treningowa dla trenera i podopiecznego - expansion"
version: 2
status: draft
created: 2026-06-23
updated: 2026-06-24
prd_version: 2
main_goal: speed
top_blocker: time
---

# Roadmap: LiftMate expansion

> Derived from `context/foundation/prd.md` (v2), `context/foundation/prd-expansion.md` (v2), the previous roadmap, and the auto-researched codebase baseline.
> Edit in place; archive when superseded.
> Items are listed in dependency order. The "At a glance" table is the index.

## Vision recap

LiftMate ma wejść w bezpieczniejszą i bardziej dopracowaną betę bez regresji istniejącego przepływu trener-podopieczny. Najpierw zamykamy dostęp i błędy ścieżki rejestracji, a następnie dokładamy feedback po treningu, informacyjne podpowiedzi dla trenera i prostą serię regularności.

## North star

**S-07: Tester może bezpiecznie i poprawnie zarejestrować konto w becie** — to pierwszy wynik, ponieważ usuwa ryzyko publicznej rejestracji i naprawia krytyczną ścieżkę wejścia przed udostępnieniem aplikacji kolejnym testerom.

> North star oznacza tutaj najmniejszy przekrojowy wynik, którego dostarczenie potwierdza, że aplikację można bezpiecznie przekazać użytkownikowi beta.

## At a glance

| ID | Change ID | Outcome (user can ...) | Prerequisites | PRD refs | Status |
|---|---|---|---|---|---|
| F-01 | mobile-api-smoke-path | (foundation) Aplikacja mobilna może potwierdzić dostępność wdrożonego API. | — | `prd.md`: FR-001, US-01 | done |
| F-02 | authenticated-role-boundary | (foundation) Istnieje uwierzytelniona tożsamość i granica ról trenera oraz podopiecznego. | F-01 | `prd.md`: FR-001, FR-002, FR-003, FR-004, FR-005 | done |
| F-03 | shared-session-sync-contract | (foundation) Istnieje kontrakt synchronizacji jednej aktywnej sesji treningowej. | F-01 | `prd.md`: FR-004, FR-012, US-03 | done |
| S-01 | trainer-trainee-pairing | Trener i podopieczny mogą utworzyć konta i nawiązać dozwoloną relację. | F-02 | `prd.md`: FR-001, FR-002, FR-003, FR-004, FR-005 | done |
| S-02 | assign-global-workout-set | Trener może utworzyć zestaw ćwiczeń i przypisać go podopiecznemu. | S-01 | `prd.md`: FR-007, FR-008, FR-010, US-01 | done |
| S-03 | start-shared-workout-session | Trener może rozpocząć aktywną sesję dla podopiecznego i przypisanego zestawu. | S-01, S-02 | `prd.md`: FR-004, FR-010, FR-012, US-03 | done |
| S-04 | live-trainer-led-entry | Trener może wpisywać wartości, a podopieczny widzi tę samą sesję bez ręcznego odświeżania. | F-03, S-03 | `prd.md`: FR-004, FR-011, FR-012, US-03 | done |
| S-05 | save-progress-next-session | Użytkownik może zachować wartości zakończonego treningu jako punkt startowy kolejnej sesji. | S-04 | `prd.md`: FR-011, US-02 | ready |
| S-06 | trainee-self-edit-training-values | Podopieczny może samodzielnie edytować własne wartości podczas wykonywania treningu. | S-02, S-05 | `prd.md`: FR-005, FR-011, US-02 | proposed |
| S-07 | beta-registration-guard | Tester może utworzyć konto trenera albo podopiecznego tylko z poprawnym kodem beta, używając czytelnego i stabilnego formularza. | — | `prd-expansion.md`: US-04, Scope of Change — beta code, Polish validation, password visibility, pasted trainer code | ready |
| S-08 | copy-trainer-invite-code | Trener może skopiować aktualny kod zaproszenia i natychmiast zobaczyć potwierdzenie operacji. | S-01 | `prd-expansion.md`: US-05 | ready |
| S-09 | post-workout-feedback | Podopieczny może wysłać ocenę samopoczucia i opcjonalny komentarz po treningu, a trener widzi nieedytowalny wpis w historii sesji. | S-04 | `prd-expansion.md`: US-01 | done |
| S-10 | trainer-history-guidance | Trener może zobaczyć informacyjne podpowiedzi o stagnacji ciężaru lub obniżonym samopoczuciu i oznaczyć je jako przeczytane. | S-09 | `prd-expansion.md`: US-02 | ready |
| S-11 | trainee-weekly-streak | Podopieczny może zobaczyć aktualną i najlepszą liczbę kolejnych tygodni z zakończonym treningiem. | S-04 | `prd-expansion.md`: US-03 | ready |

## Streams

Ta sekcja grupuje elementy współdzielące łańcuch zależności. Kanoniczna kolejność pozostaje zapisana w polach `Prerequisites`.

| Stream | Theme | Chain | Note |
|---|---|---|---|
| A | Podstawowy przepływ treningowy | `F-01` → (`F-02` → `S-01` → `S-02` → `S-03` / `F-03`) → `S-04` → `S-05` → `S-06` | Zachowuje historię podstawowego produktu i otwarte domknięcie progresu. |
| B | Gotowość bety | `S-07` / `S-08` | Niezależne poprawki dostępu i obsługi kodów; zabezpieczenie rejestracji prowadzi sekwencję ze względu na cel `speed`. |
| C | Feedback i zaangażowanie | `S-09` → `S-10`; `S-11` równolegle | Feedback odblokowuje podpowiedzi o samopoczuciu, a seria korzysta z istniejących zakończonych sesji. |

## Baseline

Stan kodu na 2026-06-23, potwierdzony przez użytkownika:

- **Frontend:** present — Flutter zawiera gotowe przepływy uwierzytelniania, relacji, aktywnej sesji i historii treningów.
- **Backend / API:** present — ASP.NET Core udostępnia endpointy auth, parowania, zestawów, sesji, historii i synchronizacji.
- **Data:** present — relacyjna baza danych, migracje oraz projekcje progresu i historii są używane produkcyjnie.
- **Auth:** present — tożsamość, tokeny, role i autoryzacja relacji są aktywne.
- **Deploy / infra:** partial — API i migracje są wdrażane automatycznie; wydawanie aplikacji mobilnej pozostaje ręczne.
- **Observability:** absent — brak dedykowanej telemetrii, metryk i śledzenia błędów poza standardowymi logami.

## Foundations

Nie są potrzebne nowe foundation slices. Wszystkie warstwy wymagane przez expansion istnieją, a addytywne zmiany danych i kontraktów powinny być wprowadzane w pierwszym konsumującym je slice.

### F-01: Mobile-to-API smoke path

- **Outcome:** (foundation) Aplikacja mobilna może potwierdzić dostępność wdrożonego API.
- **Change ID:** `mobile-api-smoke-path`
- **PRD refs:** `prd.md`: FR-001, US-01
- **Unlocks:** F-02, F-03 i wszystkie przekrojowe przepływy mobile/API.
- **Prerequisites:** —
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Bez sprawdzonego połączenia mobile/API błędy środowiska byłyby mylone z błędami produktu.
- **Status:** done

### F-02: Authenticated role boundary

- **Outcome:** (foundation) Istnieje uwierzytelniona tożsamość i granica ról trenera oraz podopiecznego.
- **Change ID:** `authenticated-role-boundary`
- **PRD refs:** `prd.md`: FR-001, FR-002, FR-003, FR-004, FR-005
- **Unlocks:** S-01, S-03, S-04, S-06 i S-07.
- **Prerequisites:** F-01
- **Parallel with:** F-03
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Błędy granic ról mogłyby ujawnić lub pomieszać dane treningowe użytkowników.
- **Status:** done

### F-03: Shared-session sync contract

- **Outcome:** (foundation) Istnieje kontrakt synchronizacji jednej aktywnej sesji treningowej.
- **Change ID:** `shared-session-sync-contract`
- **PRD refs:** `prd.md`: FR-004, FR-012, US-03
- **Unlocks:** S-04 oraz zachowanie aktualizacji sesji wymagane przez expansion.
- **Prerequisites:** F-01
- **Parallel with:** F-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Oddzielne kopie sesji po stronie trenera i podopiecznego złamałyby podstawową obietnicę produktu.
- **Status:** done

## Slices

### S-01: Trainer-trainee pairing

- **Outcome:** Trener i podopieczny mogą utworzyć konta i nawiązać dozwoloną relację.
- **Change ID:** `trainer-trainee-pairing`
- **PRD refs:** `prd.md`: FR-001, FR-002, FR-003, FR-004, FR-005
- **Prerequisites:** F-02
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Relacja jest granicą dostępu do wszystkich danych treningowych.
- **Status:** done

### S-02: Assign global workout set

- **Outcome:** Trener może utworzyć zestaw ćwiczeń i przypisać go podopiecznemu.
- **Change ID:** `assign-global-workout-set`
- **PRD refs:** `prd.md`: FR-007, FR-008, FR-010, US-01
- **Prerequisites:** S-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Niestabilna tożsamość ćwiczeń utrudniłaby progres i analizę historii.
- **Status:** done

### S-03: Start shared workout session

- **Outcome:** Trener może rozpocząć aktywną sesję dla podopiecznego i przypisanego zestawu.
- **Change ID:** `start-shared-workout-session`
- **PRD refs:** `prd.md`: FR-004, FR-010, FR-012, US-03
- **Prerequisites:** S-01, S-02
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Aktywna sesja musi pozostać jednym współdzielonym obiektem.
- **Status:** done

### S-04: Live trainer-led entry

- **Outcome:** Trener może wpisywać wartości, a podopieczny widzi tę samą sesję bez ręcznego odświeżania.
- **Change ID:** `live-trainer-led-entry`
- **PRD refs:** `prd.md`: FR-004, FR-011, FR-012, US-03
- **Prerequisites:** F-03, S-03
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Utrata synchronizacji podczas treningu podważa główną wartość prowadzonej sesji.
- **Status:** done

### S-05: Save progress for the next session

- **Outcome:** Użytkownik może zachować wartości zakończonego treningu jako punkt startowy kolejnej sesji.
- **Change ID:** `save-progress-next-session`
- **PRD refs:** `prd.md`: FR-011, US-02
- **Prerequisites:** S-04
- **Parallel with:** S-07, S-08, S-09, S-11
- **Blockers:** —
- **Unknowns:**
  - Ręczna weryfikacja i formalne domknięcie istniejącej implementacji pozostają do potwierdzenia. — Owner: user. Block: no.
- **Risk:** Niepoprawne reguły nadpisywania mogą utracić progres lub pokazać stare wartości.
- **Status:** ready

### S-06: Trainee self-edit training values

- **Outcome:** Podopieczny może samodzielnie edytować własne wartości podczas wykonywania treningu.
- **Change ID:** `trainee-self-edit-training-values`
- **PRD refs:** `prd.md`: FR-005, FR-011, US-02
- **Prerequisites:** S-02, S-05
- **Parallel with:** S-07, S-08, S-09, S-11
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Samodzielna edycja musi stosować te same reguły własności i progresu co sesja prowadzona.
- **Status:** proposed

### S-07: Bezpieczna i poprawna rejestracja beta

- **Outcome:** Tester może utworzyć konto trenera albo podopiecznego tylko z poprawnym kodem beta, używając czytelnego i stabilnego formularza.
- **Change ID:** `beta-registration-guard`
- **PRD refs:** `prd-expansion.md`: US-04, Scope of Change — beta code, Polish validation, password visibility, pasted trainer code
- **Prerequisites:** —
- **Parallel with:** S-05, S-08, S-09, S-11
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Nieszczelna lub uszkodzona rejestracja uniemożliwia bezpieczne przekazanie bety testerom.
- **Status:** ready

### S-08: Kopiowanie kodu trenera

- **Outcome:** Trener może skopiować aktualny kod zaproszenia i natychmiast zobaczyć potwierdzenie operacji.
- **Change ID:** `copy-trainer-invite-code`
- **PRD refs:** `prd-expansion.md`: US-05
- **Prerequisites:** S-01
- **Parallel with:** S-05, S-07, S-09, S-11
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Błędnie skopiowany kod blokuje parowanie mimo poprawnie działającego backendu.
- **Status:** ready

### S-09: Feedback po zakończonym treningu

- **Outcome:** Podopieczny może wysłać ocenę samopoczucia i opcjonalny komentarz po treningu, a trener widzi nieedytowalny wpis w historii sesji.
- **Change ID:** `post-workout-feedback`
- **PRD refs:** `prd-expansion.md`: US-01
- **Prerequisites:** S-04
- **Parallel with:** S-05, S-07, S-08, S-11
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Feedback przypisany do niewłaściwej sesji zniekształci historię i późniejsze podpowiedzi.
- **Status:** done

### S-10: Podpowiedzi trenera z historii

- **Outcome:** Trener może zobaczyć informacyjne podpowiedzi o stagnacji ciężaru lub obniżonym samopoczuciu i oznaczyć je jako przeczytane.
- **Change ID:** `trainer-history-guidance`
- **PRD refs:** `prd-expansion.md`: US-02
- **Prerequisites:** S-09
- **Parallel with:** S-06, S-11
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Niejednoznaczne porównanie ćwiczeń lub duplikowanie sygnałów obniży zaufanie trenera.
- **Status:** ready

### S-11: Tygodniowa seria regularności

- **Outcome:** Podopieczny może zobaczyć aktualną i najlepszą liczbę kolejnych tygodni z zakończonym treningiem.
- **Change ID:** `trainee-weekly-streak`
- **PRD refs:** `prd-expansion.md`: US-03
- **Prerequisites:** S-04
- **Parallel with:** S-05, S-07, S-08, S-09
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Niewłaściwa granica tygodnia lub czasu może niesprawiedliwie wyzerować serię.
- **Status:** ready

## Backlog Handoff

| Roadmap ID | Change ID | Suggested issue title | Ready for `/10x-plan` | Notes |
|---|---|---|---|---|
| F-01 | `mobile-api-smoke-path` | Mobile-to-API smoke path | no | done |
| F-02 | `authenticated-role-boundary` | Authenticated role boundary | no | done |
| F-03 | `shared-session-sync-contract` | Shared-session sync contract | no | done |
| S-01 | `trainer-trainee-pairing` | Trainer-trainee pairing | no | done |
| S-02 | `assign-global-workout-set` | Assign global workout set | no | done |
| S-03 | `start-shared-workout-session` | Start shared workout session | no | done |
| S-04 | `live-trainer-led-entry` | Live trainer-led entry | no | done |
| S-05 | `save-progress-next-session` | Domknij zapis progresu na kolejną sesję | no | Istniejąca implementacja wymaga ręcznej weryfikacji i closeoutu. |
| S-06 | `trainee-self-edit-training-values` | Podopieczny edytuje własne wartości treningowe | no | Czeka na domknięcie S-05. |
| S-07 | `beta-registration-guard` | Zabezpiecz i napraw rejestrację beta | yes | Run `/10x-plan beta-registration-guard`. |
| S-08 | `copy-trainer-invite-code` | Dodaj kopiowanie kodu trenera | yes | Run `/10x-plan copy-trainer-invite-code`. |
| S-09 | `post-workout-feedback` | Dodaj feedback po treningu | no | done |
| S-10 | `trainer-history-guidance` | Dodaj podpowiedzi trenera z historii | yes | Run `/10x-plan trainer-history-guidance`. |
| S-11 | `trainee-weekly-streak` | Dodaj tygodniową serię regularności | yes | Run `/10x-plan trainee-weekly-streak`. |

## Open Roadmap Questions

Brak otwartych pytań blokujących planowanie nowych slice’ów. Szczegóły addytywnych migracji i nowych kontraktów są rozstrzygane w `/10x-plan` pierwszego slice’a, który ich potrzebuje.

## Parked

- **Weryfikacja adresu e-mail** — poza zakresem expansion; dostęp do bety kontroluje wspólny kod.
- **Indywidualne kody beta i limity użyć** — wspólny kod jest świadomym uproszczeniem bety.
- **Automatyczna analiza komentarzy** — komentarze pozostają informacją dla trenera.
- **AI i automatyczne zmiany planu** — podpowiedzi są jawne, informacyjne i nie modyfikują treningu.
- **Rozbudowana grywalizacja** — zakres ogranicza się do aktualnej i najlepszej serii.
- **Zmiany ról, logowania i relacji trener-podopieczny** — obecny model pozostaje bez zmian.
- **Biblioteka ćwiczeń trenera** — pozostaje poza podstawowym przepływem.
- **Indywidualne szablony zestawów** — pozostają poza podstawowym przepływem.
- **Płatna infrastruktura realtime** — wróci do oceny dopiero po przekroczeniu ograniczeń obecnego środowiska.

## Done

- **S-09: Podopieczny może wysłać ocenę samopoczucia i opcjonalny komentarz po treningu, a trener widzi nieedytowalny wpis w historii sesji.** — Completed 2026-06-24. Change: `context/changes/post-workout-feedback/`.
- **F-01: Aplikacja mobilna może potwierdzić dostępność wdrożonego API.** — Archived 2026-06-18 → `context/archive/2026-06-01-mobile-api-smoke-path/`. Lesson: —.
- **F-02: Istnieje uwierzytelniona tożsamość i granica ról trenera oraz podopiecznego.** — Archived 2026-06-18 → `context/archive/2026-06-02-authenticated-role-boundary/`. Lesson: —.
- **F-03: Istnieje kontrakt synchronizacji jednej aktywnej sesji treningowej.** — Archived 2026-06-18 → `context/archive/2026-06-03-shared-session-sync-contract/`. Lesson: —.
- **S-01: Trener i podopieczny mogą utworzyć konta i nawiązać dozwoloną relację.** — Archived 2026-06-18 → `context/archive/2026-06-15-trainer-trainee-pairing/`. Lesson: —.
- **S-02: Trener może utworzyć zestaw ćwiczeń i przypisać go podopiecznemu.** — Archived 2026-06-18 → `context/archive/2026-06-16-assign-global-workout-set/`. Lesson: —.
- **S-03: Trener może rozpocząć aktywną sesję dla podopiecznego i przypisanego zestawu.** — Archived 2026-06-18 → `context/archive/2026-06-17-start-shared-workout-session/`. Lesson: —.
- **S-04: Trener może wpisywać wartości, a podopieczny widzi tę samą sesję bez ręcznego odświeżania.** — Archived 2026-06-19 → `context/archive/2026-06-19-live-trainer-led-entry/`. Lesson: —.
