# Test Plan

> Phased test rollout for this project. Strategy is frozen at the top
> (§1–§5); cookbook patterns at the bottom (§6) fill in as phases ship.
> Read before writing any new test.
>
> Refresh: re-run `/10x-test-plan --refresh` when stale (see §8).
>
> Last updated: 2026-06-30

## 1. Strategy

Tests follow three non-negotiable principles for this project:

1. **Cost × signal.** The cheapest test that gives a real signal for the
   risk wins. Do not promote to e2e because e2e "feels safer." Do not put a
   vision model on top of a deterministic visual diff that already catches
   the regression.
2. **User concerns are first-class evidence.** Risks anchored in "the team
   is worried about X, and the failure would surface somewhere in an area"
   carry the same weight as PRD lines or hot-spot data.
3. **Risks are scenarios, not code locations.** This plan documents *what
   could fail* and *why we believe it's likely* — drawn from documents,
   interview, and codebase *signal* (churn, structure, test base). It does
   NOT claim to know which line owns the failure. That knowledge is produced
   by `/10x-research` during each rollout phase. If the plan and research
   disagree about where the failure lives, research is the ground truth.

Hot-spot scope used for likelihood weighting: `apps/mobile/lib`,
`apps/api/LiftMate.Api`, `docs`, `documents`, `context/foundation` (excluding
`context/foundation/archive`, generated output, migrations, lockfiles, and
snapshots). The scoped history contained 126 commits in the last 30 days.

## 2. Risk Map

The top failure scenarios are ordered by impact × likelihood. Sources record
evidence that raised the risk, never a presumed code anchor.

| # | Risk (failure scenario) | Impact | Likelihood | Source (evidence — not anchor) |
|---|---|---|---|---|
| 1 | Po reconnect trener i podopieczny widzą różne sesje lub wartości bez widocznego ostrzeżenia. | High | High | interview Q1, Q4; PRD US-03 i NFR realtime; hot-spot dirs `apps/mobile/lib/shared_sessions` (33) i `apps/api/LiftMate.Api/SharedSessions` (44) |
| 2 | Współbieżny zapis aktywnej sesji kończy się `500`, utratą wartości albo nieokreślonym wynikiem. | High | High | interview Q1, Q2; roadmap S-05; hot-spot dir `apps/api/LiftMate.Api/SharedSessions` (44) |
| 3 | Migracja działa lokalnie, ale podczas wdrożenia blokuje API albo uszkadza istniejące dane. | High | High | interview Q2; roadmap Baseline; deployment constraint: migrations execute during deploy |
| 4 | Wygaśnięcie tokenu podczas zapisu lub reconnect powoduje utratę, duplikację operacji albo trwałe wylogowanie. | High | High | interview Q3; hot-spot dirs `apps/mobile/lib/auth` (40) i `apps/api/LiftMate.Api/Auth` (38) |
| 5 | Zalogowany użytkownik odczytuje lub modyfikuje sesję albo dane obcej relacji trener–podopieczny. | High | Medium | PRD Access Control; roadmap F-02 i S-01; abuse/security lens |
| 6 | Opóźniony event nadpisuje nowszy snapshot albo przełącza użytkownika na inną sesję. | High | Medium | archived F-03 i S-04 plans; shared-session hot-spot directories |
| 7 | Niepoprawny kod beta umożliwia rejestrację albo poprawny kod blokuje testera. | High | Medium | roadmap S-07; auth hot-spot directories |

### Risk Response Guidance

| Risk | What would prove protection | Must challenge | Context `/10x-research` must ground | Likely cheapest layer | Anti-pattern to avoid |
|---|---|---|---|---|---|
| #1 | Po utracie sieci wraca ta sama kanoniczna sesja, a przerwa synchronizacji jest widoczna. | `connected` oznacza pełne odtworzenie subskrypcji. | Lifecycle transportu, członkostwo grupy, fallback i tożsamość sesji. | controller/widget + integration | Happy-path-only reconnect. |
| #2 | Równoległe zapisy mają zdefiniowany wynik, bez `500` i niespójnego stanu. | Końcowe `200` dowodzi braku utraconego zapisu. | Granica transakcji, reguła współbieżności, idempotency i provider bazy. | API integration | Sekwencyjny test lub oracle skopiowany z implementacji. |
| #3 | Upgrade istniejącej bazy przechodzi bez utraty danych i zachowuje kompatybilność API. | Migracja pustej bazy reprezentuje produkcję. | Łańcuch migracji, produkcyjny provider, kolejność deploy i punkt odzyskania. | migration integration + pre-prod smoke | Testowanie wygenerowanych linii migracji. |
| #4 | Refresh podczas zapisu ponawia operację najwyżej raz i zachowuje właściwą rolę oraz sesję. | Test loginu pokrywa runtime refresh. | Replay HTTP, przechowywanie tokenów, równoległe żądania i kontrakt błędu. | mobile unit/controller + API integration | Nadmierne mockowanie wnętrza klienta. |
| #5 | Obcy trener lub podopieczny zawsze otrzymuje odmowę odczytu i mutacji. | Poprawna rola wystarcza bez ownership. | Granica zasobu, uczestnicy sesji, relacja i źródło tożsamości. | API integration | Test samej polityki bez zasobu. |
| #6 | Starsze i obce eventy nie cofają ani nie przełączają bieżącej sesji. | Kolejność dostarczenia odpowiada wersji stanu. | Wersjonowanie, typy eventów, reducer klienta i reguła przełączania. | controller/widget integration | Test zależny od idealnej kolejności eventów. |
| #7 | Serwer odrzuca zły kod, przyjmuje poprawny i nie ujawnia sekretu. | Walidacja UI stanowi zabezpieczenie. | Granica rejestracji, konfiguracja kodu, walidacja serwera i abuse controls. | API integration + widget | Wyłącznie test formularza. |

## 3. Phased Rollout

Each row opens a discrete change folder. Status values and column order are
parser contracts for `/10x-test-plan`.

| # | Phase name | Goal (one line) | Risks covered | Test types | Status | Change folder |
|---|---|---|---|---|---|---|
| 1 | Spójność realtime i zapis współbieżny | Udowodnić reconnect, ordering oraz bezpieczny zapis aktywnej sesji. | #1, #2, #6 | API integration, controller, widget | change opened | `testing-spojnosc-realtime-zapis-wspolbiezny` |
| 2 | Odporność auth i granice własności | Chronić zapis podczas refresh oraz izolację danych i rejestracji. | #4, #5, #7 | API integration, unit, widget | not started | — |
| 3 | Realistyczne migracje i smoke wdrożeniowy | Zweryfikować upgrade istniejącej bazy i zapis po migracji. | #2, #3 | migration integration, pre-prod smoke | not started | — |
| 4 | Selektywna kontrola krytycznego przepływu | Sprawdzić granicę urządzenie–API i widoczność awarii bez dublowania tańszych testów. | #1, #2, cross-cutting | minimal device integration, selective multimodal review, gates | not started | — |

## 4. Stack

Test base profile: **meaningful** — 41 Flutter test files and 16 API test
files distributed across both application layers.

| Layer | Tool | Version | Notes |
|---|---|---|---|
| Flutter unit + widget | `flutter_test` | Flutter 3.44.0 / Dart 3.12.0 | Existing primary mobile layer; keep most behavior here. |
| API unit + integration | xUnit + `Microsoft.AspNetCore.Mvc.Testing` | xUnit 2.9.3 / ASP.NET Core 10.0 | Existing `WebApplicationFactory` HTTP pipeline. |
| Test persistence | EF Core SQLite | 10.0.8 | Useful for most integration tests; research must verify where SQL Server semantics are required. |
| Mobile integration | Flutter `integration_test` | none yet — see Phase 4 | Only for the critical device–API boundary not covered more cheaply. |
| AI-native visual review | current-session multimodal inspection; checked: 2026-06-30 | n/a | Use only on 1–2 active-session warning states; not when widget assertions or deterministic diffs suffice. |

**Stack grounding tools (current session):**
- Docs: no docs MCP — official Flutter and Microsoft documentation checked via web; checked: 2026-06-30.
- Search: web search available — used only to locate current primary sources; checked: 2026-06-30.
- Runtime/browser: in-app browser available but not used; LiftMate's critical target is native Flutter; checked: 2026-06-30.
- Provider/platform: GitHub CLI and local workflow inspection available; deploy workflow builds, migrates, and deploys but has no test step; checked: 2026-06-30.

## 5. Quality Gates

The current deploy workflow provides API restore/build but no PR test gate.
This lesson defines the required floor; Phase 4 prepares the runnable gate
contract. GitHub Actions YAML remains owned by the later CI lesson.

| Gate | Where | Required? | Catches |
|---|---|---|---|
| Flutter analyze | local; CI not wired | required now locally; CI required after Phase 4 | Dart lint and type drift |
| API restore + build | local + existing deploy workflow | required | compile and package drift |
| Flutter unit + widget | local; CI not wired | required; CI required after Phase 4 | mobile state and UI regressions |
| API unit + integration | local; CI not wired | required; CI required after Phase 1 | HTTP, persistence, auth and permission regressions |
| Critical device–API flow | pre-prod/device; CI not wired | required after Phase 4 | reconnect/save failures crossing process boundaries |
| Migration upgrade verification | local/ephemeral realistic database | required after Phase 3 | provider-specific upgrade and data-preservation failures |
| Selective multimodal review | local agent review | recommended after Phase 4 | warning visibility issues missed by behavioral assertions |

## 6. Cookbook Patterns

How to add new tests in this project. Each entry is filled when its rollout
phase ships.

### 6.1 Reconnect and realtime-ordering test

TBD — see §3 Phase 1 for canonical-session recovery, warning visibility, and
stale-event rejection patterns.

### 6.2 Concurrent session-write API test

TBD — see §3 Phase 1 for concurrent writes, defined conflict outcomes, and
no-`500` persistence patterns.

### 6.3 Auth refresh and ownership test

TBD — see §3 Phase 2 for request replay, role, resource ownership, and beta
registration patterns.

### 6.4 Migration upgrade test

TBD — see §3 Phase 3 for upgrading non-empty data with production-relevant
provider semantics.

### 6.5 Critical device–API smoke and visual review

TBD — see §3 Phase 4 for the minimal reconnect/save flow and selective review
of active-session warning states.

### 6.6 Per-rollout-phase notes

TBD — each completed rollout phase appends its durable testing lesson here.

## 7. What We Deliberately Don't Test

- **Snapshoty każdego ekranu Fluttera** — wysoki koszt utrzymania, niski sygnał. Re-evaluate only if a stable deterministic visual contract is introduced. (Source: Phase 2 interview Q5.)
- **Wygenerowany kod i migracje linia po linii** — testujemy rezultat upgrade i zachowanie danych, nie generator. Re-evaluate if custom generation logic appears. (Source: Phase 2 interview Q5.)
- **Pełne e2e dla zachowań pokrywalnych taniej** — prefer API integration, controller, and widget tests. Re-evaluate only when the failure crosses a boundary unavailable to cheaper layers. (Source: Phase 2 interview Q5.)
- **AI-native review całej aplikacji** — ograniczony do 1–2 krytycznych ekranów; nie zastępuje deterministycznych asercji. Re-evaluate if visual risk becomes a top-three product risk. (Source: cost × signal principle.)

## 8. Freshness Ledger

- Strategy (§1–§5) last reviewed: 2026-06-30
- Stack versions last verified: 2026-06-30
- AI-native tool references last verified: 2026-06-30

Refresh (`/10x-test-plan --refresh`) when:

- a new top-3 risk surfaces from the roadmap or archive,
- a recommended tool's `checked:` date is older than three months,
- the project's tech stack changes (new framework or test runner),
- §7 negative-space no longer matches what the team believes.
