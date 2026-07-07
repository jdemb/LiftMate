<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Ożywienie aplikacji

- **Plan**: `context/changes/ozywienie-aplikacji/plan.md`
- **Mode**: Deep
- **Date**: 2026-07-07
- **Verdict**: SOUND
- **Findings**: 1 critical, 3 warnings, 0 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | PASS |
| Plan Completeness | PASS |

## Grounding

Grounding: 10/10 existing paths ✓, 5/5 symbols ✓, brief↔plan ✓, Progress↔phases and criteria ✓. New motion files and the EF migration are intentional additions.

## Findings

### F1 — Niewykonalna manualna bramka fazy 1

- **Severity**: ❌ CRITICAL
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1 — Fundament motion
- **Detail**: Faza nie integrowała prymitywów z widocznym ekranem, ale wymagała manualnej oceny ich demonstracyjnego użycia.
- **Fix**: Usunąć manualny punkt fazy 1 i pozostawić automatyczne testy oraz końcową manualną kontrolę reduced motion w fazie 5.
- **Decision**: FIXED — rekomendowany fix

### F2 — Read-only timer nie ma źródła zsynchronizowanego czasu

- **Severity**: ⚠️ WARNING
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: End-State Alignment
- **Location**: Phase 4 — Animacje stanu treningu i progresu
- **Detail**: Istniejący model przesyła tylko skonfigurowane `restSeconds`; lokalny timer edytora nie może zasilić read-only ani odtworzyć countdownu po reconnect.
- **Fix A ⭐ Recommended**: Ograniczyć płynne odliczanie do sesji edytowalnych i pozostawić read-only statyczny.
  - Strength: Zachowuje frontend-only scope.
  - Tradeoff: Trainer-led read-only nie dostaje countdownu.
  - Confidence: HIGH — obecny kontrakt nie przenosi stanu timera.
  - Blind spot: Nie spełnia pełnego zachowania prototypu dla obu ról.
- **Fix B**: Rozszerzyć encję, API i realtime o autorytatywny deadline, remaining/total i czas serwera.
  - Strength: Oba klienty oraz reconnect odtwarzają ten sam timer bez broadcastu co sekundę.
  - Tradeoff: Dodaje migrację oraz cross-stackową fazę implementacji i testów.
  - Confidence: HIGH — istniejący `sessionUpdated`, `Version` i serializowane transakcje są właściwymi punktami integracji.
  - Blind spot: Jakość synchronizacji wymaga manualnego testu dwóch klientów.
- **Decision**: FIXED — Fix B wybrany przez użytkownika

### F3 — Brakuje testów bezpośrednio dotykanych ekranów

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 2 — Dotyk i haptyka
- **Detail**: Pierwotna komenda pomijała testy szczegółu podopiecznego, przypisanych zestawów i tygodniowej serii mimo zmian w tych widgetach.
- **Fix**: Dodać `trainer_trainee_detail_screen_test.dart`, `trainee_assigned_workout_sets_screen_test.dart` i `weekly_streak_screen_test.dart` do bramki fazy 2.
- **Decision**: FIXED — rekomendowany fix

### F4 — Sprzeczna semantyka anulowanego dotyku

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Critical Implementation Details / Phase 2
- **Detail**: Handoff emituje `selectionClick()` na pointer-down, ale pierwotne kryterium zabraniało haptyki po anulowanym geście.
- **Fix**: Pozwolić zachować `selectionClick()` z pointer-down, jednocześnie blokując callback i feedback semantyczny po anulowaniu.
- **Decision**: FIXED — rekomendowany fix
