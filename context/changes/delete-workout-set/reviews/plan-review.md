<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Usuwanie zestawu z ekranu Moje zestawy

- **Plan**: `context/changes/delete-workout-set/plan.md`
- **Mode**: Deep
- **Date**: 2026-06-29
- **Verdict**: SOUND (after fixes; initial verdict REVISE)
- **Findings**: 1 critical, 2 warnings, all fixed

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | PASS |
| Plan Completeness | PASS |

## Grounding

Grounding: 9/9 existing paths ✓, 5/5 symbols ✓, brief↔plan ✓, Progress contract ✓. The migration path is intentionally generated during implementation.

## Findings

### F1 — Wyścig między rozpoczęciem sesji a usunięciem

- **Severity**: ❌ CRITICAL
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Blind Spots
- **Location**: Critical Implementation Details; Phase 1
- **Detail**: Transakcja obejmująca wyłącznie DELETE nie zapobiega odczytaniu aktywnego zestawu przez `StartFromWorkoutSet` przed zatwierdzeniem usunięcia i późniejszemu zapisowi sesji.
- **Fix ⭐ Recommended**: Objąć DELETE oraz `StartFromWorkoutSet` istniejącym wzorcem execution strategy i transakcji `Serializable`, z ponownym odczytem stanu wewnątrz transakcji.
  - Strength: Wymusza invariant przy użyciu istniejącego wzorca repozytorium.
  - Tradeoff: Rozszerza transakcję startu i może powodować retry przy konkurencji.
  - Confidence: HIGH — `Complete` już używa tego wzorca.
  - Blind spot: Testy SQLite nie odwzorowują dokładnie blokad SQL Server.
- **Decision**: FIXED — zastosowano rekomendowane rozwiązanie

### F2 — Pominięto aktywne podsumowanie relacji

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architectural Fitness
- **Location**: Phase 1
- **Detail**: `PairingEndpoints` buduje `AssignedWorkoutSets` osobnym aktywnym zapytaniem, którego plan nie uwzględniał.
- **Fix**: Dodać `PairingEndpoints.cs`, warunek `DeletedAt == null` oraz test endpointu relacji.
- **Decision**: FIXED — zastosowano rekomendowane rozwiązanie

### F3 — Brak weryfikacji migracji SQL Server

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1 tests
- **Detail**: Testy endpointów używają SQLite `EnsureCreated` i nie weryfikują wygenerowanej migracji SQL Server.
- **Fix**: Rozszerzyć `MigrationScriptTests.cs` o nullable `datetimeoffset` `DeletedAt` oraz indeks aktywnych zestawów.
- **Decision**: FIXED — zastosowano rekomendowane rozwiązanie
