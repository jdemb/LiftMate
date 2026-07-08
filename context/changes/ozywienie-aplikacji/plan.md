# Ożywienie aplikacji — plan implementacji

## Overview

Wprowadzamy spójny system animacji i mikrointerakcji do aplikacji Flutter zgodnie z prototypem `apps/mobile/design/LiftMate.dc.html` oraz handoffem `HANDOFF-animacje.md`. Zakres obejmuje priorytety 0–2: wspólne tokeny ruchu, reduced motion, reakcję na dotyk i haptykę, przejścia ekranów, stagger list, animacje liczb i stanów treningu oraz oszczędne dekoracje.

## Current State Analysis

Aplikacja ma działające ekrany i logikę domenową, ale nie ma wspólnej warstwy motion. Onboarding i widoki po zalogowaniu są przełączane przez stan widgetów, a nie przez stos tras; kontrolki są budowane lokalnie z `FilledButton`, `IconButton`, `TextButton`, `InkWell` i podobnych widgetów. Timer odpoczynku aktualizuje wartość raz na sekundę, a pasek widoku tylko do odczytu używa stałego mianownika 90 sekund.

## Desired End State

Wejścia ekranów, listy, liczby, kontrolki i stany treningu reagują spójnie z prototypem, bez zmiany obecnych przepływów biznesowych. Odpoczynek ma jeden autorytatywny stan serwerowy, więc trener i podopieczny widzą ten sam płynny countdown również w trybie read-only i po reconnect. Ustawienie systemowe reduced motion usuwa przesunięcia, skalowanie i pętle, zachowując zmiany stanu oraz wybraną pełną haptykę. Animacje są deterministyczne w testach i nie blokują `pumpAndSettle()`.

### Key Discoveries:

- Tokeny i keyframes prototypu są zdefiniowane w `apps/mobile/design/LiftMate.dc.html:33-88`.
- `MaterialApp` nie konfiguruje motion ani globalnej polityki animacji (`apps/mobile/lib/main.dart:107`).
- `AuthenticatedRelationshipShell` zwraca różne ekrany bez warstwy przejść (`apps/mobile/lib/relationships/authenticated_relationship_shell.dart:145-319`).
- Timer odpoczynku jest oparty na `Timer.periodic`, a `+15 s` zmienia tylko wartość pozostałą (`apps/mobile/lib/shared_sessions/live_session_screen.dart:248-291`).
- Wykres progresu jest własnym widgetem, więc nie wymaga `fl_chart` (`apps/mobile/lib/training_history/training_history_flow.dart:711-780`).
- Testy ekranowe szeroko używają `pumpAndSettle()`, dlatego pętle orb/sheen muszą mieć jawnie sterowany cykl życia.

## What We're NOT Doing

- Nie wdrażamy responsywności i gestów z priorytetów 3–4 handoffu.
- Nie migrujemy obecnego shella do pełnego routingu `Navigator`.
- Nie dodajemy swipe-back, swipe-to-action ani nowych zachowań pull-to-refresh.
- Nie zmieniamy logiki zestawów, progresu, feedbacku ani istniejących reguł dostępu do sesji poza dodaniem autorytatywnego sterowania odpoczynkiem dla użytkownika uprawnionego do edycji sesji.
- Nie dodajemy liczenia wartości od zera; kluczowe liczby używają wyłącznie efektu pop.
- Nie edytujemy `LiftMate.dc.html`, `LiftMate.html` ani innych plików prototypu.
- Nie dodajemy `flutter_slidable` ani `fl_chart`.

## Implementation Approach

Warstwa motion będzie złożona z tokenów, kontekstowej polityki dostępności oraz małych reużywalnych widgetów. Istniejąca nawigacja stanowa pozostaje bez zmian; onboarding, shell i poziomy historii dostają stabilne klucze oraz kontrolowane przejścia. `flutter_staggered_animations` obsługuje sekwencyjne listy, a pozostałe efekty korzystają z wbudowanych mechanizmów Fluttera. Stan odpoczynku jest utrwalany w `SharedSession`, aktualizowany atomowo przez API i rozsyłany istniejącym zdarzeniem `sessionUpdated`; klient interpoluje lokalnie względem deadline'u i czasu serwera, bez broadcastu co sekundę.

## Critical Implementation Details

### Timing & lifecycle

Animacje zapętlone działają tylko przy aktywnym `TickerMode`, wyłączonym reduced motion i jawnej zgodzie produkcyjnego `MotionScope`. Brak scope'a oznacza brak pętli, dzięki czemu bezpośrednie testy ekranów pozostają deterministyczne. Kontrolery muszą być zatrzymywane i zwalniane przy zmianie widoku oraz `dispose`.

### User experience spec

Zmiana danych w istniejącym ekranie nie może ponownie uruchamiać wejścia ani staggeru; animacja startuje wyłącznie po zmianie stabilnego klucza ekranu lub poziomu. Haptyka domyślna to `selectionClick()` emitowany na pointer-down dla każdej aktywnej powierzchni akcji, więc może wystąpić również po późniejszym anulowaniu gestu. Anulowanie blokuje callback i feedback semantyczny; akcje semantyczne zastępują domyślny sygnał pojedynczym `mediumImpact()` przy ukończeniu serii i `heavyImpact()` po zakończeniu odpoczynku — bez podwójnego feedbacku.

### State sequencing

Serwer przechowuje czas pozostały w pauzie, dynamiczny czas całkowity i deadline aktywnego odliczania. `+15 s` zwiększa czas całkowity oraz pozostały/deadline, pauza materializuje pozostały czas, reset przywraca wartość z sesji, a udane odhaczenie serii atomowo zaczyna nowy pełny interwał. Odpowiedź zawiera także czas serwera, aby oba klienty liczyły countdown bez zależności od zgodności zegarów urządzeń.

## Phase 1: Fundament motion

### Overview

Dodanie jednej polityki ruchu, tokenów i testowalnych prymitywów, na których opierają się następne fazy.

### Changes Required:

#### 1. Zależność stagger

**File**: `apps/mobile/pubspec.yaml`

**Intent**: Dodać wyłącznie `flutter_staggered_animations` do obsługi list i sekcji.

**Contract**: Zależności produkcyjne nie obejmują `flutter_slidable` ani `fl_chart`.

#### 2. Tokeny i polityka ruchu

**File**: `apps/mobile/lib/theme/motion.dart`

**Intent**: Zdefiniować czasy 180/300/500/550 ms, krzywe standard/spring, krok stagger 60 ms oraz kontekstową obsługę reduced motion i animacji ciągłych.

**Contract**: Jeden publiczny kontrakt zwraca efektywne czasy i informację, czy przesunięcie, skala oraz pętle są dozwolone; reduced motion sprowadza czas do zera i wyłącza transformacje oraz pętle, ale nie haptykę.

#### 3. Prymitywy jednorazowych animacji

**Files**:

- `apps/mobile/lib/widgets/motion/motion_reveals.dart`
- `apps/mobile/lib/widgets/motion/pressable_scale.dart`

**Intent**: Udostępnić wejście fade/slide/scale, stagger, pop oraz nieprzechwytujący semantyki wrapper nacisku.

**Contract**: `PressableScale` respektuje `enabled`, skaluje 1→0.94→1 i pozwala wybrać haptykę albo ją wyłączyć dla zdarzenia z własnym feedbackiem.

#### 4. Scope aplikacji

**File**: `apps/mobile/lib/main.dart`

**Intent**: Włączyć produkcyjną politykę animacji ciągłych wewnątrz `MaterialApp.builder` bez zmiany konfiguracji usług i ekranu startowego.

**Contract**: Bezpośrednio montowane widgety testowe nie uruchamiają pętli, dopóki test jawnie nie dostarczy scope'a.

#### 5. Testy fundamentu

**Files**:

- `apps/mobile/test/motion_test.dart`
- `apps/mobile/test/pressable_scale_test.dart`

**Intent**: Zabezpieczyć tokeny, reduced motion, aktywację/wyłączenie pętli, skalowanie, anulowanie pointera, stan disabled i brak przejęcia callbacku dziecka.

**Contract**: Testy sprawdzają zachowanie w czasie przez kontrolowane `pump`, bez snapshotów pojedynczych klatek.

### Success Criteria:

#### Automated Verification:

- Zależności rozwiązują się poprawnie: `flutter pub get`
- Testy fundamentu przechodzą: `flutter test test/motion_test.dart test/pressable_scale_test.dart --reporter compact`
- Analiza statyczna przechodzi: `flutter analyze`

**Implementation Note**: Po przejściu automatycznej weryfikacji można przejść do fazy 2; manualna kontrola reduced motion odbywa się po integracji prymitywów w fazie 5.

---

## Phase 2: Dotyk i haptyka

### Overview

Wdrożenie sprężystej reakcji i haptyki na wszystkich aktywnych powierzchniach akcji bez zmiany ich semantyki, callbacków i stanów disabled.

### Changes Required:

#### 1. Onboarding i komponenty wspólne

**Files**:

- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/relationships/relationship_screen_styles.dart`

**Intent**: Objąć wspólne przyciski auth, role cards, przyciski wstecz, dolną nawigację i współdzielone kafle reakcją press oraz `selectionClick()`.

**Contract**: Pola tekstowe, scroll i kontrolki disabled nie skalują się i nie generują haptyki.

#### 2. Ekrany relacji i zestawów

**Files**:

- `apps/mobile/lib/relationships/trainee_home_screen.dart`
- `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`
- `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart`
- `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`
- `apps/mobile/lib/workout_sets/add_workout_set_exercise_screen.dart`
- `apps/mobile/lib/workout_sets/assign_workout_set_screen.dart`
- `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart`

**Intent**: Zastosować wspólną reakcję do CTA, ikon, stepperów, kart podopiecznych, kart ćwiczeń i wyborów.

**Contract**: Istniejące klucze, tooltipy, ripple, fokus, obsługa klawiatury i callbacki pozostają zachowane.

#### 3. Sesja, historia i feedback

**Files**:

- `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- `apps/mobile/lib/training_history/training_history_flow.dart`
- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_screen.dart`

**Intent**: Ujednolicić reakcję przycisków sesji, ocen, historii, wykresu, paginacji i akcji odpoczynku.

**Contract**: Odhaczenie serii rezerwuje własne `mediumImpact()` w fazie 4; wrapper nie może emitować dodatkowego `selectionClick()` dla tej akcji.

#### 4. Regresje interakcji

**Files**:

- `apps/mobile/test/auth_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- `apps/mobile/test/workout_set_trainer_screens_test.dart`
- `apps/mobile/test/trainer_trainee_detail_screen_test.dart`
- `apps/mobile/test/trainee_assigned_workout_sets_screen_test.dart`
- `apps/mobile/test/weekly_streak_screen_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`
- `apps/mobile/test/training_history_flow_test.dart`
- `apps/mobile/test/post_workout_feedback_screen_test.dart`

**Intent**: Potwierdzić, że wrappery nie zmieniają dostępności, stanów disabled ani pojedynczego wykonania callbacków.

**Contract**: Testy używają istniejących kluczy i finderów; nie uzależniają się od prywatnej struktury animacji.

### Success Criteria:

#### Automated Verification:

- Testy ekranów interaktywnych przechodzą: `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart test/workout_set_trainer_screens_test.dart test/trainer_trainee_detail_screen_test.dart test/trainee_assigned_workout_sets_screen_test.dart test/weekly_streak_screen_test.dart test/live_session_screen_test.dart test/training_history_flow_test.dart test/post_workout_feedback_screen_test.dart --reporter compact`
- Testy `PressableScale` potwierdzają dokładnie jeden callback i jeden feedback dla aktywacji
- Analiza statyczna przechodzi: `flutter analyze`

#### Manual Verification:

- Wszystkie aktywne przyciski, kafelki, elementy nawigacji i steppery na Androidzie kurczą się do około 0.94 i generują pojedynczą haptykę
- Kontrolki disabled nie generują haptyki; anulowany gest może zachować `selectionClick()` z pointer-down, ale nie uruchamia akcji ani feedbacku semantycznego

**Implementation Note**: Po przejściu automatycznej weryfikacji zatrzymaj się na potwierdzenie manualne przed fazą 3.

---

## Phase 3: Kinowe wejścia i sekwencyjne odsłanianie

### Overview

Dodanie przejść ekranowych oraz staggeru list bez zmiany obecnego modelu stanu i bez ponownego animowania odświeżeń danych.

### Changes Required:

#### 1. Onboarding

**File**: `apps/mobile/lib/auth/auth_screen.dart`

**Intent**: Animować zmianę kroków welcome/role/login/signup/pair przez fade, slide-up i skalę zgodną z prototypem.

**Contract**: Stabilny klucz wynika wyłącznie z aktywnego kroku; walidacja formularza, focus i kontrolery pól nie są resetowane przez animację.

#### 2. Shell po zalogowaniu

**File**: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart`

**Intent**: Wprowadzić centralną identyfikację widoku i `AnimatedSwitcher` dla dashboardu, szczegółów, zestawów, buildera, przypisania, live, historii i feedbacku.

**Contract**: Powiadomienia kontrolerów i przeładowania danych zachowują ten sam klucz i nie uruchamiają ponownie wejścia; istniejące callbacki back pozostają źródłem nawigacji.

#### 3. Listy i sekcje

**Files**:

- `apps/mobile/lib/relationships/trainee_home_screen.dart`
- `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`
- `apps/mobile/lib/relationships/trainer_trainee_detail_screen.dart`
- `apps/mobile/lib/workout_sets/trainer_workout_sets_screen.dart`
- `apps/mobile/lib/workout_sets/workout_set_builder_screen.dart`
- `apps/mobile/lib/workout_sets/assign_workout_set_screen.dart`
- `apps/mobile/lib/shared_sessions/live_session_screen.dart`
- `apps/mobile/lib/training_history/training_history_flow.dart`
- `apps/mobile/lib/post_workout_feedback/post_workout_feedback_screen.dart`

**Intent**: Odsłaniać główne karty, listy podopiecznych, serie, historię, feedback i sekcje ekranów w odstępach 60 ms.

**Contract**: Pozycja stagger jest ograniczona do 10; elementy doładowane lub odświeżone nie powodują ponownej animacji całej listy; reduced motion renderuje finalny układ natychmiast.

#### 4. Testy przejść

**Files**:

- `apps/mobile/test/auth_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`
- `apps/mobile/test/training_history_flow_test.dart`

**Intent**: Sprawdzić stabilne klucze, brak ponownego wejścia po notify/reload i natychmiastowy stan końcowy przy reduced motion.

**Contract**: Testy przejść używają jawnych kroków czasu; istniejące testy biznesowe nadal mogą używać `pumpAndSettle()`.

### Success Criteria:

#### Automated Verification:

- Testy przejść i ekranów przechodzą: `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart test/training_history_flow_test.dart --reporter compact`
- Test potwierdza limit staggeru po dziesiątym elemencie
- Test potwierdza brak restartu animacji po odświeżeniu danych w tym samym widoku
- Analiza statyczna przechodzi: `flutter analyze`

#### Manual Verification:

- Wejścia ekranów na Androidzie odpowiadają prototypowi: około 500 ms, fade, około 18 px slide-up i skala 0.985→1
- Powrót, zmiana zakładki i przejścia poziomów historii są czytelne, a odświeżenie listy nie powoduje migotania

**Implementation Note**: Po przejściu automatycznej weryfikacji zatrzymaj się na potwierdzenie manualne przed fazą 4.

---

## Phase 4: Animacje stanu treningu i progresu

### Overview

Dodanie efektów powiązanych z konkretnymi zmianami danych oraz jednego serwerowego źródła prawdy dla odpoczynku: pop liczb, odhaczenie serii, rosnący wykres i zsynchronizowany płynny countdown.

### Changes Required:

#### 1. Utrwalony stan odpoczynku

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/SharedSession.cs`
- `apps/api/LiftMate.Api/Data/ApplicationDbContext.cs`
- `apps/api/LiftMate.Api/Migrations/`
- `apps/api/LiftMate.Api/Migrations/ApplicationDbContextModelSnapshot.cs`

**Intent**: Rozszerzyć sesję o autorytatywny stan timera, który przeżywa reconnect i może być odtworzony identycznie przez trenera oraz podopiecznego.

**Contract**: `SharedSession` przechowuje `RestTimerTotalSeconds`, `RestTimerRemainingSeconds` i opcjonalny `RestTimerEndsAt`. Migracja `AddSharedSessionRestTimer` backfilluje oba pola sekund z istniejącego `RestSeconds`; wartości pozostają nieujemne i są ograniczone do 3600 sekund.

#### 2. API i broadcast timera

**Files**:

- `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionMapping.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`
- `apps/api/LiftMate.Api/SharedSessions/SharedSessionBroadcaster.cs`

**Intent**: Udostępnić sterowanie start/pauza/+15/reset i dostarczać kanoniczny timer w każdej odpowiedzi oraz aktualizacji realtime.

**Contract**: `PATCH /shared-sessions/{sessionId}/rest` przyjmuje akcję `start`, `pause`, `add` albo `reset`; `add` przyjmuje wyłącznie `deltaSeconds: 15`. Uprawnienia są identyczne jak dla edycji wartości sesji: trener uczestniczący w sesji albo podopieczny w sesji uruchomionej samodzielnie. Operacja działa w transakcji, zwiększa `Version`, zapisuje `UpdatedAt`, zwraca pełny `SharedSessionResponse` i emituje istniejące `sessionUpdated`. Odpowiedź zawiera `restTimer.totalSeconds`, wyliczone `restTimer.remainingSeconds`, nullable `restTimer.endsAt` oraz `restTimer.serverNow`, aby klienci korygowali różnice zegarów. Przejście serii `isDone: false→true` uruchamia nowy pełny timer w tej samej transakcji co zapis serii; cofnięcie serii nie restartuje timera.

#### 3. Mobilny kontrakt synchronizacji

**Files**:

- `apps/mobile/lib/shared_sessions/shared_session_models.dart`
- `apps/mobile/lib/shared_sessions/shared_session_api_client.dart`
- `apps/mobile/lib/shared_sessions/shared_session_controller.dart`
- `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart`

**Intent**: Parsować stan timera, wysyłać komendy sterujące i aktualizować oba widoki z odpowiedzi HTTP oraz `sessionUpdated`.

**Contract**: Model klienta przechowuje snapshot timera i offset `serverNow`; kontroler wystawia jedną metodę aktualizacji odpoczynku oraz zachowuje istniejącą ochronę wersji przed stale snapshot. Reconnect/GET odbudowuje pozostały czas z serwerowego deadline'u bez lokalnego resetu.

#### 4. Kluczowe liczby

**Files**:

- `apps/mobile/lib/relationships/trainer_dashboard_screen.dart`
- `apps/mobile/lib/training_history/training_history_flow.dart`

**Intent**: Dodać jednorazowy spring pop do liczników dashboardu i aktualnej wartości progresu bez animowania wartości od zera.

**Contract**: Czytnik ekranu od początku otrzymuje wartość docelową; aktualizacja danych w tym samym ekranie nie resetuje wejścia.

#### 5. Odhaczanie serii

**File**: `apps/mobile/lib/shared_sessions/live_session_screen.dart`

**Intent**: Animować tło, obramowanie i ikonę ukończenia oraz emitować pojedyncze `mediumImpact()` dopiero po udanym zapisie stanu done; serwerowy zapis uruchamia równocześnie timer widoczny dla obu uczestników.

**Contract**: Cofnięcie serii zachowuje wizualną zmianę stanu, ale nie używa feedbacku sukcesu; błąd API nie uruchamia animacji sukcesu.

#### 6. Wykres progresu

**File**: `apps/mobile/lib/training_history/training_history_flow.dart`

**Intent**: Animować istniejące słupki od dołu z odstępem około 70 ms, bez dodawania biblioteki wykresów.

**Contract**: Wysokości docelowe i etykiety pozostają zgodne z obecną logiką; reduced motion renderuje pełne słupki od razu.

#### 7. Zsynchronizowany płynny odpoczynek

**File**: `apps/mobile/lib/shared_sessions/live_session_screen.dart`

**Intent**: Zastąpić lokalny autorytatywny timer płynną projekcją serwerowego snapshotu, zachowując sekundową etykietę, pauzę, reset, `+15 s` i automatyczny start po serii na obu klientach.

**Contract**: `LiveSessionScreen` wylicza bieżący postęp z `endsAt` skorygowanego o `serverNow`; gdy timer jest w pauzie, używa kanonicznego `remainingSeconds`. Akcje edytora wywołują API zamiast mutować lokalne źródło prawdy. Pasek jest ograniczony do 0–1, widok read-only animuje ten sam deadline, a każdy klient emituje jeden `heavyImpact()` po lokalnym przejściu danego interwału do zera. Nowy snapshot, pauza, reset i `+15 s` bezpiecznie zastępują bieżącą projekcję bez podwójnego sygnału końca.

#### 8. Testy backendu i mobile

**Files**:

- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs`
- `apps/api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs`
- `apps/mobile/test/shared_session_models_test.dart`
- `apps/mobile/test/shared_session_api_client_test.dart`
- `apps/mobile/test/shared_session_controller_test.dart`
- `apps/mobile/test/shared_session_realtime_client_test.dart`
- `apps/mobile/test/live_session_screen_test.dart`
- `apps/mobile/test/training_history_flow_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Zabezpieczyć migrację/backfill, uprawnienia, transakcje, broadcast, reconnect, sukces/błąd odhaczenia, brak podwójnej haptyki, płynny postęp, dynamiczne `+15 s`, pauzę, reset, koniec timera, pop i wykres przy reduced motion.

**Contract**: Testy API używają kontrolowanego czasu lub tolerancji wyłącznie na granicy mapowania; testy Flutter sterują czasem przez `tester.pump` i jawne snapshoty `serverNow`/`endsAt`. Równoległe komendy nie gubią wersji ani dodanych sekund, użytkownik read-only otrzymuje broadcast, ale nie może sterować timerem.

### Success Criteria:

#### Automated Verification:

- Migracja i backend budują się poprawnie: `dotnet build LiftMate.slnx --no-restore`
- Testy API i realtime przechodzą: `dotnet test LiftMate.slnx --no-build --filter "FullyQualifiedName~SharedSession"`
- Testy sesji i progresu przechodzą: `flutter test test/shared_session_models_test.dart test/shared_session_api_client_test.dart test/shared_session_controller_test.dart test/shared_session_realtime_client_test.dart test/live_session_screen_test.dart test/training_history_flow_test.dart test/post_auth_relationship_screen_test.dart --reporter compact`
- Test timera potwierdza dynamiczny mianownik, start/pauzę/reset/`+15 s`, reconnect, uprawnienia, broadcast do read-only oraz dokładnie jeden sygnał końca
- Test reduced motion potwierdza natychmiastowe checkboxy, liczby i słupki
- Analiza statyczna przechodzi: `flutter analyze`

#### Manual Verification:

- Odhaczenie serii na Androidzie daje pojedynczy wyraźny feedback i sprężysty check bez opóźnienia zapisu UI
- Na dwóch klientach Android pasek odpoczynku trenera i podopiecznego pozostaje zsynchronizowany podczas startu, pauzy, resetu, `+15 s`, reconnectu i automatycznego startu po serii
- Pasek odpoczynku porusza się płynnie, a oba klienty emitują pojedynczą ciężką haptykę po zakończeniu tego samego interwału
- Liczby i wykres progresu pojawiają się raz na wejście i nie restartują przy zwykłym rebuildzie

**Implementation Note**: Po przejściu automatycznej weryfikacji zatrzymaj się na potwierdzenie manualne przed fazą 5.

---

## Phase 5: Dekoracje i pełna regresja

### Overview

Dodanie dwóch oszczędnych efektów ciągłych z prototypu oraz końcowa weryfikacja stabilności, dostępności i platformy referencyjnej.

### Changes Required:

#### 1. Widgety dekoracyjne

**File**: `apps/mobile/lib/widgets/motion/continuous_motion.dart`

**Intent**: Udostępnić dryfującą poświatę 8 s i sheen 3.6 s z kontrolowanym cyklem życia.

**Contract**: Pętle działają tylko przy aktywnym `TickerMode`, zgodzie `MotionScope` i wyłączonym reduced motion; nie przechwytują hit-testów ani semantyki.

#### 2. Welcome i trening na dziś

**Files**:

- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/relationships/trainee_home_screen.dart`
- `apps/mobile/lib/workout_sets/trainee_assigned_workout_set_view.dart`

**Intent**: Dodać sheen wyłącznie do „Załóż konto” i „Rozpocznij trening” oraz orb wyłącznie do karty dzisiejszego treningu.

**Contract**: Na ekranie działa maksymalnie jeden sheen; dekoracje są przycięte do kształtu CTA/karty i nie zmieniają layoutu.

#### 3. Testy ciągłych efektów

**Files**:

- `apps/mobile/test/motion_test.dart`
- `apps/mobile/test/auth_screen_test.dart`
- `apps/mobile/test/post_auth_relationship_screen_test.dart`

**Intent**: Potwierdzić zakres dekoracji, zatrzymanie przez reduced motion/TickerMode oraz brak wiszącego `pumpAndSettle()` w istniejących testach.

**Contract**: Testy pętli włączają je jawnie przez testowy scope i używają ograniczonego `pump`.

#### 4. Końcowa weryfikacja

**Files**: `apps/mobile/lib/**`, `apps/mobile/test/**`

**Intent**: Uruchomić pełną regresję i upewnić się, że zmiana nie narusza przepływów auth, relacji, zestawów, live, historii ani feedbacku.

**Contract**: Android jest platformą manualną; web przechodzi build, a iOS pozostaje pokryty analizą i wspólnymi testami Flutter z uwagi na środowisko Windows.

### Success Criteria:

#### Automated Verification:

- Pełny zestaw testów API przechodzi: `dotnet test LiftMate.slnx --no-restore`
- Pełny zestaw testów przechodzi: `flutter test --reporter compact`
- Analiza statyczna przechodzi: `flutter analyze`
- Android debug buduje się poprawnie: `flutter build apk --debug`
- Web buduje się poprawnie: `flutter build web`
- Istniejące testy z `pumpAndSettle()` kończą się mimo obecności orb i sheen

#### Manual Verification:

- Na Androidzie orb i sheen odpowiadają prototypowi, pozostają subtelne i występują tylko w zatwierdzonych miejscach
- Pełny przebieg trener oraz podopieczny zachowuje poprawne interakcje, czytelność i płynność bez zauważalnych przycięć
- Systemowe reduced motion wyłącza wszystkie przesunięcia, skale i pętle, zachowując kolory stanu i pełną haptykę

**Implementation Note**: Po przejściu automatycznej weryfikacji zatrzymaj się na końcowe potwierdzenie manualne przed oznaczeniem zmiany jako zaimplementowanej.

---

## Testing Strategy

### Unit Tests:

- Tokeny i polityka motion, w tym reduced motion i scope animacji ciągłych.
- `PressableScale`: down/up/cancel, disabled, callback i wybór haptyki.
- Serwerowy i mobilny model czasu odpoczynku: mapowanie `serverNow`/`endsAt`, start, pauza, reset, `+15 s`, reconnect i zero.

### Integration Tests:

- Stabilne przejścia onboardingu, shella i poziomów historii.
- Brak restartu reveal po odświeżeniu kontrolera.
- Integracja press/haptyki z istniejącymi akcjami i kluczami testowymi.
- Animacje serii, wykresu i dekoracji z reduced motion.
- Transakcyjne API timera, autoryzacja edytora, stale-version guarding oraz `sessionUpdated` odbierane przez klienta read-only.

### Manual Testing Steps:

1. Na Androidzie przejść onboarding, konto trenera i konto podopiecznego, kontrolując press oraz haptykę każdej aktywnej akcji.
2. Przejść dashboard, podopiecznego, zestawy, builder, przypisanie, live, feedback i historię; sprawdzić wejścia oraz stagger bez restartów po reloadzie.
3. Na dwóch klientach wejść do tej samej sesji trainer-led, odhaczyć i cofnąć serię, sterować odpoczynkiem, użyć `+15 s`, pauzy i resetu, wykonać reconnect oraz poczekać do końca.
4. Otworzyć progres ćwiczenia i sprawdzić pop wartości oraz wzrost słupków.
5. Włączyć systemowe reduced motion i powtórzyć kluczowe ekrany, potwierdzając brak transformacji oraz pętli.

## Performance Considerations

- Stagger jest ograniczony do dziesięciu pozycji, aby opóźnienie nie rosło dla długich list.
- Pętle działają tylko na aktywnym ekranie i zatrzymują się przez `TickerMode`.
- Dekoracje animują transformację/gradient bez zmiany layoutu; nie mogą powodować rebuildów całych ekranów.
- Przejścia są kluczowane identyfikatorem widoku, a nie stanem kontrolera, aby reload danych nie resetował animacji.
- Countdown jest interpolowany lokalnie z serwerowego deadline'u; backend nadaje snapshot wyłącznie przy zmianie stanu, a nie co sekundę.

## Migration Notes

Zmiana wymaga migracji `AddSharedSessionRestTimer`, która dodaje pola timera i backfilluje je z `RestSeconds`. Migracja jest kompatybilna wstecznie na poziomie odczytu: stare klienty ignorują nowe pola odpowiedzi, ale po wdrożeniu endpointu tylko serwer jest źródłem zmian timera. Rollback kodu wymaga wcześniejszego zatrzymania nowych klientów; migrację można cofnąć przez usunięcie pól timera bez utraty danych treningowych. Nowa zależność Flutter wymaga `flutter pub get`.

## References

- Handoff: `C:/Users/jedrz/Downloads/HANDOFF-animacje.md`
- Kontrakt wizualny: `apps/mobile/design/LiftMate.dc.html:33-88`
- Mapa ekranów: `apps/mobile/design/mapa-implementacji.md`
- Shell widoków: `apps/mobile/lib/relationships/authenticated_relationship_shell.dart:145-319`
- Timer odpoczynku: `apps/mobile/lib/shared_sessions/live_session_screen.dart:248-291`
- Kontrakt sesji API: `apps/api/LiftMate.Api/SharedSessions/SharedSessionContracts.cs`
- Endpointy i broadcast: `apps/api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs`, `apps/api/LiftMate.Api/SharedSessions/SharedSessionBroadcaster.cs`
- Wykres progresu: `apps/mobile/lib/training_history/training_history_flow.dart:711-780`
- Reguła projektowa: `context/foundation/lessons.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Fundament motion

#### Automated

- [x] 1.1 Zależności rozwiązują się poprawnie: `flutter pub get` — 725bb5d
- [x] 1.2 Testy fundamentu przechodzą: `flutter test test/motion_test.dart test/pressable_scale_test.dart --reporter compact` — 725bb5d
- [x] 1.3 Analiza statyczna przechodzi: `flutter analyze` — 725bb5d

### Phase 2: Dotyk i haptyka

#### Automated

- [x] 2.1 Testy ekranów interaktywnych przechodzą: `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart test/workout_set_trainer_screens_test.dart test/trainer_trainee_detail_screen_test.dart test/trainee_assigned_workout_sets_screen_test.dart test/weekly_streak_screen_test.dart test/live_session_screen_test.dart test/training_history_flow_test.dart test/post_workout_feedback_screen_test.dart --reporter compact` — 23bb2c8
- [x] 2.2 Testy `PressableScale` potwierdzają dokładnie jeden callback i jeden feedback dla aktywacji — 23bb2c8
- [x] 2.3 Analiza statyczna przechodzi: `flutter analyze` — 23bb2c8

#### Manual

- [ ] 2.4 Wszystkie aktywne przyciski, kafelki, elementy nawigacji i steppery na Androidzie kurczą się do około 0.94 i generują pojedynczą haptykę
- [ ] 2.5 Kontrolki disabled nie generują haptyki; anulowany gest może zachować `selectionClick()` z pointer-down, ale nie uruchamia akcji ani feedbacku semantycznego

### Phase 3: Kinowe wejścia i sekwencyjne odsłanianie

#### Automated

- [x] 3.1 Testy przejść i ekranów przechodzą: `flutter test test/auth_screen_test.dart test/post_auth_relationship_screen_test.dart test/training_history_flow_test.dart --reporter compact` — fd190bf
- [x] 3.2 Test potwierdza limit staggeru po dziesiątym elemencie — fd190bf
- [x] 3.3 Test potwierdza brak restartu animacji po odświeżeniu danych w tym samym widoku — fd190bf
- [x] 3.4 Analiza statyczna przechodzi: `flutter analyze` — fd190bf

#### Manual

- [ ] 3.5 Wejścia ekranów na Androidzie odpowiadają prototypowi: około 500 ms, fade, około 18 px slide-up i skala 0.985→1
- [ ] 3.6 Powrót, zmiana zakładki i przejścia poziomów historii są czytelne, a odświeżenie listy nie powoduje migotania

### Phase 4: Animacje stanu treningu i progresu

#### Automated

- [x] 4.1 Migracja i backend budują się poprawnie: `dotnet build LiftMate.slnx --no-restore` — 650530c
- [x] 4.2 Testy API i realtime przechodzą: `dotnet test LiftMate.slnx --no-build --filter "FullyQualifiedName~SharedSession"` — 650530c
- [x] 4.3 Testy sesji i progresu przechodzą: `flutter test test/shared_session_models_test.dart test/shared_session_api_client_test.dart test/shared_session_controller_test.dart test/shared_session_realtime_client_test.dart test/live_session_screen_test.dart test/training_history_flow_test.dart test/post_auth_relationship_screen_test.dart --reporter compact` — 650530c
- [x] 4.4 Test timera potwierdza dynamiczny mianownik, start/pauzę/reset/`+15 s`, reconnect, uprawnienia, broadcast do read-only oraz dokładnie jeden sygnał końca — 650530c
- [x] 4.5 Test reduced motion potwierdza natychmiastowe checkboxy, liczby i słupki — 650530c
- [x] 4.6 Analiza statyczna przechodzi: `flutter analyze` — 650530c

#### Manual

- [ ] 4.7 Odhaczenie serii na Androidzie daje pojedynczy wyraźny feedback i sprężysty check bez opóźnienia zapisu UI
- [ ] 4.8 Na dwóch klientach Android pasek odpoczynku trenera i podopiecznego pozostaje zsynchronizowany podczas startu, pauzy, resetu, `+15 s`, reconnectu i automatycznego startu po serii
- [ ] 4.9 Pasek odpoczynku porusza się płynnie, a oba klienty emitują pojedynczą ciężką haptykę po zakończeniu tego samego interwału
- [ ] 4.10 Liczby i wykres progresu pojawiają się raz na wejście i nie restartują przy zwykłym rebuildzie

### Phase 5: Dekoracje i pełna regresja

#### Automated

- [x] 5.1 Pełny zestaw testów API przechodzi: `dotnet test LiftMate.slnx --no-restore`
- [x] 5.2 Pełny zestaw testów przechodzi: `flutter test --reporter compact`
- [x] 5.3 Analiza statyczna przechodzi: `flutter analyze`
- [x] 5.4 Android debug buduje się poprawnie: `flutter build apk --debug`
- [x] 5.5 Web buduje się poprawnie: `flutter build web`
- [x] 5.6 Istniejące testy z `pumpAndSettle()` kończą się mimo obecności orb i sheen

#### Manual

- [ ] 5.7 Na Androidzie orb i sheen odpowiadają prototypowi, pozostają subtelne i występują tylko w zatwierdzonych miejscach
- [ ] 5.8 Pełny przebieg trener oraz podopieczny zachowuje poprawne interakcje, czytelność i płynność bez zauważalnych przycięć
- [ ] 5.9 Systemowe reduced motion wyłącza wszystkie przesunięcia, skale i pętle, zachowując kolory stanu i pełną haptykę
