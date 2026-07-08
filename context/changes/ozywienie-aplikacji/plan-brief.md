# Ożywienie aplikacji — Plan Brief

> Full plan: `context/changes/ozywienie-aplikacji/plan.md`

## What & Why

LiftMate otrzyma spójny system animacji i mikrointerakcji zgodny z prototypem. Ruch ma poprawić orientację, responsywność dotyku i satysfakcję z treningu, bez zmiany istniejącej logiki aplikacji.

## Starting Point

Flutter UI ma lokalne widgety `AnimatedBuilder`, ale nie ma wspólnych tokenów ani polityki motion. Ekrany są przełączane stanem w onboardingu i `AuthenticatedRelationshipShell`, a timer odpoczynku jest lokalny dla edytora — tryb read-only nie otrzymuje zsynchronizowanego countdownu.

## Desired End State

Ekrany wchodzą kinowo, listy odsłaniają się sekwencyjnie, a wszystkie aktywne przyciski i kafelki reagują skalą oraz haptyką. Serie, liczby i wykres mają animacje powiązane ze stanem, a odpoczynek jest utrwalany na serwerze i płynnie synchronizowany między trenerem a podopiecznym. Orb i sheen występują tylko w miejscach wskazanych przez prototyp; reduced motion usuwa transformacje i pętle.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Zakres | Priorytety 0–2 | Dostarcza pełne ożywienie bez dokładania gestów i responsywnego refaktoru |
| Nawigacja | Hybrydowy `AnimatedSwitcher` | Zachowuje działający shell i obecne callbacki back |
| Restart animacji | Tylko po zmianie widoku/poziomu | Reload danych nie może powodować migotania |
| Haptyka | Wszystkie aktywne akcje | Użytkownik wybrał pełny, wyraźny feedback dotyku |
| Stagger | `flutter_staggered_animations` | Jedyna nowa zależność upraszcza listy i sekcje |
| Reduced motion | Bez ruchu, z haptyką | Respektuje dostępność i zachowuje informację dotykową |
| Dekoracje | Dokładnie według prototypu | Orb i sheen pozostają oszczędne |
| Liczby | Pop bez liczenia od zera | Wartość jest czytelna natychmiast |
| Odpoczynek `+15 s` | Zwiększa pozostały i całkowity czas | Pasek zawsze reprezentuje sensowny procent |
| Synchronizacja odpoczynku | Backend + istniejące `sessionUpdated` | Read-only i reconnect muszą odtworzyć ten sam deadline bez broadcastu co sekundę |
| Platforma manualna | Android | iOS pozostaje pod analizą/testami wspólnymi, web dodatkowo przechodzi build |

## Scope

**In scope:**

- Tokeny motion, reduced motion i sterowanie pętlami.
- `PressableScale` oraz haptyka wszystkich aktywnych akcji.
- Wejścia onboarding/shell/historia i stagger głównych list.
- Pop liczb, check serii, słupki progresu i płynny odpoczynek.
- Migracja, API i realtime dla autorytatywnego timera sesji.
- Orb na karcie „Dziś” oraz sheen na dwóch głównych CTA.
- Testy komponentów, ekranów, pełna regresja i build Android/web.

**Out of scope:**

- Responsywność P3, gesty P4, swipe-back i swipe-to-action.
- Refaktor do pełnego routingu Navigator.
- Zmiany API niezwiązane z timerem odpoczynku oraz zmiany reguł dostępu do pozostałych operacji sesji.
- Edycja plików prototypu oraz nowe biblioteki wykresów.

## Architecture / Approach

Nowy moduł motion udostępni tokeny, kontekstową politykę dostępności i małe widgety: press, reveal, stagger, pop oraz efekty ciągłe. Stabilne klucze widoków kontrolują przejścia w istniejącej architekturze stanowej. Serwer utrwala stan odpoczynku i rozsyła snapshot przez istniejące `sessionUpdated`; oba klienty interpolują lokalnie względem deadline'u i `serverNow`. Produkcyjny `MotionScope` uruchamia pętle, a brak scope'a w testach pozostawia je wyłączone.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Fundament motion | Tokeny, polityka, prymitywy i zależność stagger | Deterministyczne zachowanie testów |
| 2. Dotyk i haptyka | Press i feedback na wszystkich aktywnych akcjach | Zachowanie semantyki i brak podwójnej haptyki |
| 3. Wejścia i stagger | Przejścia ekranów oraz odsłanianie treści | Brak restartu po reloadzie |
| 4. Animacje stanu | Liczby, serie, wykres oraz serwerowo synchronizowany odpoczynek | Migracja, konkurencja komend i korekta zegarów klientów |
| 5. Dekoracje i regresja | Orb, sheen i pełna weryfikacja | Pętle nie mogą blokować `pumpAndSettle()` |

**Prerequisites:** Dostępne Flutter SDK i .NET SDK oraz bieżące pliki prototypu jako read-only reference.
**Estimated effort:** Około 5 faz implementacyjnych; każda faza ma osobną weryfikację automatyczną i manualną.

## Open Risks & Assumptions

- Pętle muszą być uruchamiane wyłącznie przez produkcyjny scope i aktywny `TickerMode`.
- API timera musi atomowo aktualizować `Version` i deadline; klienci muszą odrzucać starsze snapshoty realtime.
- Pełna haptyka wymaga sprawdzenia na fizycznym urządzeniu Android; emulator nie potwierdzi jakości feedbacku.
- iOS nie może zostać lokalnie zbudowany na środowisku Windows, więc jego pokrycie ogranicza się do wspólnego kodu Flutter, analizy i testów.

## Success Criteria (Summary)

- Wszystkie zatwierdzone ekrany i stany odpowiadają timingowi oraz charakterowi ruchu z prototypu.
- Reduced motion wyłącza transformacje i pętle, a testy pozostają deterministyczne.
- Pełne `dotnet test`, `flutter test`, `flutter analyze`, Android debug build i web build przechodzą.
