# Kopiowanie kodu trenera

## Overview

Udostępnić trenerowi działającą akcję kopiowania aktualnego kodu zaproszenia na obu istniejących powierzchniach: ekranie po rejestracji trenera oraz stałym pulpicie trenera. Każda poprawna akcja zapisuje dokładnie wyświetlany kod do systemowego schowka i natychmiast pokazuje nieblokujące potwierdzenie `Kod zaproszenia skopiowany.`.

Zmiana jest wyłącznie mobilna. Istniejące endpointy, format sześciu znaków, generowanie kodu oraz relacja trener-podopieczny pozostają bez zmian.

## Current State Analysis

- Backend już zwraca stabilny kod trenera. `POST /trainer/invite-code` obsługuje ekran porejestracyjny, a `GET /trainer/relationship` zasila pulpit trenera (`apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:20-23`, `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:34-100`).
- Ekran porejestracyjny pokazuje zgodny z designem element `⧉ Kopiuj kod`, ale jest to nieinteraktywny `Container` (`apps/mobile/lib/auth/auth_screen.dart:1336-1387`).
- Pulpit trenera stale pokazuje aktualny kod w `_InviteCodeCard`, lecz nie udostępnia akcji kopiowania (`apps/mobile/lib/relationships/trainer_dashboard_screen.dart:64`, `apps/mobile/lib/relationships/trainer_dashboard_screen.dart:200-253`).
- `AuthenticatedRelationshipShell` jest właścicielem akcji pulpitu i ma już wzorzec potwierdzenia przez `ScaffoldMessenger.showSnackBar` (`apps/mobile/lib/relationships/authenticated_relationship_shell.dart:221`, `apps/mobile/lib/relationships/authenticated_relationship_shell.dart:493-497`).
- Repozytorium nie ma jeszcze integracji z `Clipboard` ani testowego mocka kanału `flutter/platform`.
- Istniejące testy obejmują renderowanie kodu na obu powierzchniach, ale nie sprawdzają działania schowka ani potwierdzenia (`apps/mobile/test/auth_screen_test.dart:210-253`, `apps/mobile/test/post_auth_relationship_screen_test.dart:23-53`).

## Desired End State

- Trener może nacisnąć widoczny przycisk `Kopiuj kod` zarówno bezpośrednio po rejestracji, jak i później na pulpicie.
- Do schowka trafia dokładnie aktualna wartość kodu przekazana przez istniejący kontrakt API.
- Potwierdzenie `Kod zaproszenia skopiowany.` pojawia się przez `SnackBar` bez zauważalnego opóźnienia i bez przechodzenia do innego ekranu.
- Akcja jest nieaktywna podczas ładowania oraz wtedy, gdy nie ma prawidłowej, niepustej wartości kodu; placeholder nigdy nie trafia do schowka.
- Błąd systemowego schowka nie pokazuje fałszywego sukcesu. Użytkownik otrzymuje komunikat `Nie udało się skopiować kodu.` i może spróbować ponownie.

## Decisions

| Area | Decision | Rationale |
| --- | --- | --- |
| Powierzchnie | Ekran porejestracyjny i pulpit trenera | Oba miejsca już pokazują ten sam kod i powinny oferować spójne działanie. |
| Sterowanie na pulpicie | Jawny przycisk `Kopiuj kod` w karcie | Akcja jest łatwa do odkrycia i zgodna z istniejącym ekranem porejestracyjnym. |
| Potwierdzenie | `SnackBar` z tekstem `Kod zaproszenia skopiowany.` | Jest natychmiastowy, polski, nieblokujący i zgodny z istniejącym wzorcem aplikacji. |
| Brak kodu | Widoczna, ale nieaktywna akcja | Układ nie zmienia się podczas ładowania i nie można skopiować placeholdera. |
| Właściciel efektu | Stateful owner każdej powierzchni wykonuje `Clipboard.setData` i pokazuje `SnackBar` | Widżety prezentacyjne pozostają bez zależności od kontekstu aplikacyjnego poza przekazanym callbackiem. |
| Wartość schowka | Kopiowanie bez normalizacji | Spełnia wymaganie skopiowania dokładnie aktualnego kodu otrzymanego z API. |
| Backend | Bez zmian | Kod, autoryzacja i endpointy już istnieją; problem dotyczy wyłącznie brakującej akcji mobilnej. |

## Scope

### In scope

- Działający przycisk kopiowania na ekranie porejestracyjnym trenera.
- Działający przycisk kopiowania w stałej karcie kodu na pulpicie trenera.
- Systemowy schowek Fluttera przez `Clipboard.setData`.
- Polski `SnackBar` sukcesu i błędu.
- Nieaktywna akcja dla stanu ładowania, braku kodu i pustego kodu.
- Dostępna etykieta/tooltip umożliwiająca jednoznaczne znalezienie akcji w testach i przez technologie asystujące.
- Testy widgetowe weryfikujące dokładną wartość schowka, potwierdzenie oraz stan nieaktywny.
- Pełne bramki `flutter test` i `flutter analyze`.

### Out of scope

- Zmiany API, bazy danych, migracji lub formatu kodu.
- Regeneracja, rotacja, wygaszanie albo unieważnianie kodu.
- Systemowy arkusz udostępniania, SMS, e-mail, QR lub deep link.
- Zmiany kodu beta i przepływu rejestracji podopiecznego.
- Przebudowa karty kodu lub pulpitu wykraczająca poza dodanie akcji.
- Implementowanie oddzielnej abstrakcji schowka lub nowego pakietu zewnętrznego.
- Nadawanie działania pustemu CTA `Zaproś podopiecznego`; S-08 dotyczy bezpośrednio kopiowania kodu.

## Architecture / Approach

Obie powierzchnie użyją systemowego `Clipboard` z `package:flutter/services.dart`, lecz zachowają obecne granice komponentów. `_AuthScreenState` obsłuży kopiowanie na ekranie porejestracyjnym i przekaże callback przez `_PairingPanel` do `_InviteCodeCard`. `_AuthenticatedRelationshipShellState` obsłuży tę samą operację dla pulpitu i przekaże callback do `TrainerDashboardScreen`, a następnie do jego `_InviteCodeCard`.

Widżety kart odpowiadają wyłącznie za prezentację i dostępność przycisku. Callback jest `null`, gdy kod jest niedostępny, pusty albo dopiero ładowany. Sukces jest sygnalizowany dopiero po zakończeniu `Clipboard.setData`; wyjątek daje polski komunikat błędu zamiast fałszywego potwierdzenia.

## Phase 1: Kopiowanie na ekranie porejestracyjnym

### Goal

Zamienić istniejący dekoracyjny element `⧉ Kopiuj kod` w działającą, dostępną akcję bez zmiany układu ekranu z designu.

### Changes Required

#### `apps/mobile/lib/auth/auth_screen.dart`

**Intent:** Umożliwić trenerowi skopiowanie wygenerowanego kodu przed przejściem do pulpitu, zachowując wygląd ekranu `pair` z designu.

**Contract:**

- `_AuthScreenState` udostępnia asynchroniczną akcję kopiującą bieżący `_trainerInviteCode` przez `Clipboard.setData(ClipboardData(text: code))`.
- Akcja kończy się `SnackBar` z tekstem `Kod zaproszenia skopiowany.` wyłącznie po poprawnym zapisie do schowka.
- Wyjątek schowka daje `SnackBar` `Nie udało się skopiować kodu.`.
- `_PairingPanel` przekazuje opcjonalny callback do `_InviteCodeCard`.
- `_InviteCodeCard` renderuje przycisk `Kopiuj kod` zgodny wizualnie z istniejącą kapsułką designu.
- Przycisk jest nieaktywny, jeśli `isLoading == true`, kod jest `null` albo `code.trim().isEmpty`.
- Kod przekazany do schowka nie jest przycinany ani zmieniany.
- Przycisk ma stabilny `ValueKey` i dostępny tooltip/semantics `Kopiuj kod zaproszenia`.
- Po zakończeniu asynchronicznej operacji kod sprawdza `mounted` przed użyciem `ScaffoldMessenger`.

#### `apps/mobile/test/auth_screen_test.dart`

**Intent:** Chronić działanie istniejącego przycisku porejestracyjnego, a nie tylko jego wygląd.

**Contract:**

- Test instaluje tymczasowy handler kanału `flutter/platform` i przechwytuje `Clipboard.setData`.
- Po rejestracji trenera naciśnięcie akcji przekazuje dokładnie `7F2K9D`.
- W tej samej interakcji pojawia się `Kod zaproszenia skopiowany.`.
- Test stanu ładowania lub braku kodu potwierdza, że akcja jest nieaktywna i nie wywołuje kanału schowka.
- Handler platformowy jest zawsze usuwany w `tearDown`, aby nie wpływać na pozostałe testy.
- Test błędu kanału potwierdza komunikat `Nie udało się skopiować kodu.` i brak komunikatu sukcesu.

### Success Criteria

#### Automated Verification

- `flutter test test/auth_screen_test.dart` przechodzi z `apps/mobile`.
- Test potwierdza dokładny argument `Clipboard.setData` i polski komunikat sukcesu.
- Test potwierdza brak wywołania schowka bez dostępnego kodu.
- Test potwierdza polski komunikat błędu bez fałszywego sukcesu.

#### Manual Verification

- Po rejestracji trenera przycisk zachowuje wygląd kapsułki z designu i reaguje na dotyk.
- Skopiowany kod można wkleić poza aplikacją bez dodatkowych znaków.
- Potwierdzenie pojawia się natychmiast i nie zasłania przycisku `Przejdź do pulpitu`.
- Stan ładowania nie pozwala skopiować `...` ani `------`.

**Implementation Note:** Po przejściu automatycznej weryfikacji pozostawić pozycje manualne do potwierdzenia przez użytkownika przy QA/PR; nie oznaczać ich automatycznie.

---

## Phase 2: Kopiowanie na pulpicie i regresja całości

### Goal

Udostępnić tę samą akcję dla aktualnego kodu zwracanego przez `GET /trainer/relationship`, zachowując obecne stany ładowania, odświeżania i błędu pulpitu.

### Changes Required

#### `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent:** Umieścić efekt systemowego schowka i potwierdzenie w istniejącym właścicielu akcji pulpitu.

**Contract:**

- `_AuthenticatedRelationshipShellState` dodaje asynchroniczną akcję kopiowania przyjmującą kod widoczny na pulpicie.
- Akcja używa `Clipboard.setData` i tych samych komunikatów sukcesu/błędu co ekran porejestracyjny.
- Callback jest przekazywany do `TrainerDashboardScreen`.
- Istniejące potwierdzenie zapisu progresu pozostaje bez zmian; nowe komunikaty nie współdzielą stanu ze wspólną sesją.
- Po operacji asynchronicznej obowiązuje kontrola `mounted`.

#### `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`

**Intent:** Dodać jednoznaczną akcję `Kopiuj kod` do stałej karty bez zmiany źródła danych ani pozostałych elementów pulpitu.

**Contract:**

- `TrainerDashboardScreen` przyjmuje callback kopiowania aktualnego kodu.
- `_InviteCodeCard` renderuje jawny przycisk `Kopiuj kod`, pozostawiając widoczny kod oraz obecne etykiety stanu.
- Przycisk jest nieaktywny podczas początkowego ładowania bez kodu, po błędzie bez zachowanego kodu oraz dla pustej wartości.
- Podczas odświeżania z zachowanym poprzednim kodem akcja pozostaje dostępna i kopiuje kod faktycznie widoczny w karcie.
- Układ mieści kod i przycisk na szerokości telefonu 412 px bez overflow; w razie potrzeby karta może przejść z jednego `Row` na responsywny układ wewnętrzny, bez redesignu reszty pulpitu.
- Przycisk ma stabilny `ValueKey` i dostępny tooltip/semantics `Kopiuj kod zaproszenia`.

#### `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent:** Zweryfikować kopiowanie aktualnego kodu z pełnego zalogowanego przepływu trenera.

**Contract:**

- Istniejący fixture trenera z kodem `7F2K9D` jest rozszerzony o mock kanału schowka.
- Naciśnięcie akcji na pulpicie wywołuje `Clipboard.setData` dokładnie z `7F2K9D`.
- Test potwierdza `SnackBar` `Kod zaproszenia skopiowany.`.
- Test stanu początkowego ładowania lub błędu bez danych potwierdza nieaktywną akcję.
- Test odświeżania z zachowanym podsumowaniem potwierdza, że przycisk nadal kopiuje widoczny kod.
- Test przy szerokości 412 px potwierdza brak wyjątku overflow.
- Handler platformowy jest usuwany po każdym teście.

### Success Criteria

#### Automated Verification

- `flutter test test/post_auth_relationship_screen_test.dart` przechodzi z `apps/mobile`.
- `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart` przechodzi z `apps/mobile`.
- `flutter test` przechodzi z `apps/mobile`.
- `flutter analyze` przechodzi z `apps/mobile`.
- Test pulpitu potwierdza dokładny kod, `SnackBar`, nieaktywny stan i brak overflow na 412 px.

#### Manual Verification

- Zalogowany trener może skopiować kod niezależnie od liczby podopiecznych.
- Po odświeżeniu pulpitu akcja kopiuje kod aktualnie widoczny w karcie.
- Kod wklejony poza aplikacją jest identyczny z kodem wyświetlonym.
- Przycisk i karta pozostają czytelne na obsługiwanym telefonie i nie zmieniają istniejącej nawigacji.
- Powtórne szybkie naciśnięcie nie powoduje nawigacji, regeneracji kodu ani błędu ekranu.

**Implementation Note:** Po przejściu automatycznej weryfikacji pozostawić pozycje manualne do potwierdzenia przez użytkownika przy QA/PR; nie oznaczać ich automatycznie.

---

## Testing Strategy

### Widget Tests

- Przechwycenie metody `Clipboard.setData` na kanale `flutter/platform`.
- Dokładna wartość schowka dla kodu `7F2K9D`.
- Sukces i awaria operacji systemowego schowka.
- Nieaktywna akcja bez kodu i podczas początkowego ładowania.
- Zachowanie dostępnej akcji podczas odświeżania z zachowanym kodem.
- Widoczny polski `SnackBar`.
- Brak overflow przy szerokości 412 px.

### Regression Tests

- Istniejący ekran porejestracyjny nadal przechodzi do pulpitu.
- Pulpit nadal pokazuje kod, listę/empty state i obsługuje odświeżenie.
- Pełny zestaw testów Fluttera i analiza statyczna pozostają zielone.

### Manual Testing Steps

1. Zarejestrować konto trenera i nacisnąć `Kopiuj kod`.
2. Wkleić kod w zewnętrznym polu tekstowym i porównać go znak po znaku z ekranem.
3. Przejść do pulpitu, ponownie skopiować kod i sprawdzić to samo.
4. Odświeżyć pulpit gestem pull-to-refresh i skopiować kod podczas/po odświeżeniu.
5. Sprawdzić oba ekrany na urządzeniu o szerokości odpowiadającej projektowi 412 px.
6. Potwierdzić, że komunikat pojawia się w czasie krótszym niż 1 sekunda.

## Performance Considerations

Operacja zapisuje sześć znaków do lokalnego schowka i nie wykonuje żadnego żądania sieciowego. Nie wymaga cache, debouncingu ani dodatkowego stanu kontrolera. Potwierdzenie powinno pojawić się bez oczekiwania na odświeżenie relacji.

## Migration Notes

Brak migracji danych, zmian kontraktu API i nowych zależności. `Clipboard` oraz `ClipboardData` pochodzą z Flutter SDK.

## Rollback Notes

Zmianę można wycofać przez usunięcie callbacków, przycisków i testów schowka. Wycofanie nie wpływa na istniejące kody, konta ani relacje.

## References

- GitHub issue: `#25` — Dodaj kopiowanie kodu trenera
- Roadmap: `context/foundation/roadmap.md:198-208`
- PRD: `context/foundation/prd-expansion.md:123-132`
- Design: `apps/mobile/design/LiftMate.dc.html:169-177`
- Design lesson: `context/foundation/lessons.md:5-8`
- Onboarding invite UI: `apps/mobile/lib/auth/auth_screen.dart:838-935`, `apps/mobile/lib/auth/auth_screen.dart:1336-1387`
- Trainer dashboard invite UI: `apps/mobile/lib/relationships/trainer_dashboard_screen.dart:64`, `apps/mobile/lib/relationships/trainer_dashboard_screen.dart:200-253`
- Dashboard action owner: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart:221`, `apps/mobile/lib/relationships/authenticated_relationship_shell.dart:493-497`
- Onboarding tests: `apps/mobile/test/auth_screen_test.dart:210-253`
- Post-auth tests: `apps/mobile/test/post_auth_relationship_screen_test.dart:23-53`
- Backend code contract: `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:12-14`, `apps/api/LiftMate.Api/Auth/PairingEndpoints.cs:34-100`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Kopiowanie na ekranie porejestracyjnym

#### Automated

- [x] 1.1 `flutter test test/auth_screen_test.dart` przechodzi z `apps/mobile`
- [x] 1.2 Test potwierdza dokładny argument `Clipboard.setData` i polski komunikat sukcesu
- [x] 1.3 Test potwierdza brak wywołania schowka bez dostępnego kodu
- [x] 1.4 Test potwierdza polski komunikat błędu bez fałszywego sukcesu

#### Manual

- [x] 1.5 Przycisk porejestracyjny zachowuje wygląd designu i reaguje na dotyk
- [x] 1.6 Skopiowany kod można wkleić poza aplikacją bez dodatkowych znaków
- [x] 1.7 Potwierdzenie pojawia się natychmiast i nie zasłania głównego CTA
- [x] 1.8 Stan ładowania nie pozwala skopiować placeholdera

### Phase 2: Kopiowanie na pulpicie i regresja całości

#### Automated

- [ ] 2.1 `flutter test test/post_auth_relationship_screen_test.dart` przechodzi z `apps/mobile`
- [ ] 2.2 `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart` przechodzi z `apps/mobile`
- [ ] 2.3 `flutter test` przechodzi z `apps/mobile`
- [ ] 2.4 `flutter analyze` przechodzi z `apps/mobile`
- [ ] 2.5 Test pulpitu potwierdza dokładny kod, `SnackBar`, nieaktywny stan i brak overflow na 412 px

#### Manual

- [ ] 2.6 Zalogowany trener może skopiować kod niezależnie od liczby podopiecznych
- [ ] 2.7 Po odświeżeniu pulpitu akcja kopiuje kod aktualnie widoczny w karcie
- [ ] 2.8 Kod wklejony poza aplikacją jest identyczny z kodem wyświetlonym
- [ ] 2.9 Przycisk i karta pozostają czytelne na obsługiwanym telefonie
- [ ] 2.10 Powtórne szybkie naciśnięcie nie zmienia kodu ani nawigacji
