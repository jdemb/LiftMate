# Bezpieczna i poprawna rejestracja beta — Plan Brief

> Full plan: `context/changes/beta-registration-guard/plan.md`
> Research: `context/changes/beta-registration-guard/research.md`

## What & Why

Nowe konta trenera i podopiecznego będą tworzone tylko z poprawnym wspólnym kodem beta, podczas gdy istniejące konta zachowają obecne logowanie. Ten sam slice naprawia krytyczne błędy formularza: niedziałające pokazywanie hasła, techniczne komunikaty oraz niestabilne wklejanie kodu trenera.

## Starting Point

Publiczny `POST /auth/register` nie ma obecnie bramki dostępu. Mobilny signup nie wysyła kodu beta, `Pokaż` jest statycznym tekstem, a sześciopolowy kod trenera może wysłać więcej znaków niż pokazuje UI.

## Desired End State

API wymusza dokładnie zgodny kod beta przechowywany wyłącznie w konfiguracji App Service. Formularz pozostaje zgodny z istniejącym onboardingiem, pokazuje spokojne polskie błędy, poprawnie przełącza hasło i nie pozwala nowemu podopiecznemu zakończyć bieżącego onboardingu bez poprawnego kodu trenera.

## Key Decisions Made

| Decision | Choice | Why | Source |
|---|---|---|---|
| UI kodu beta | Pole w signup | Nie dodaje osobnego kroku sprzecznego z designem. | Plan |
| Porównanie kodu | Exact, case-sensitive | Zachowuje jednoznaczny kontrakt sekretu. | Plan |
| Brak settingu | `503` tylko dla rejestracji | Fail-closed bez blokowania istniejących kont. | Plan |
| Komunikaty | Polski tekst bez kodów i szczegółów | Użytkownik dostaje instrukcję zamiast błędu technicznego. | Plan |
| Kod trenera | Obowiązkowy w bieżącym onboardingu podopiecznego, także po restarcie | Lokalny znacznik dla nowego podopiecznego usuwa obejście wsteczem, restartem i ponownym logowaniem. | Plan review F1 |
| Paste kodu trenera | 6 znaków, trim + uppercase | Widok i request reprezentują tę samą wartość. | Plan |
| Błędy kodu trenera | Lokalne mapowanie w onboardingowym ekranie | Daje spokojny polski komunikat bez zmiany wspólnego klienta i post-auth relationship flow. | Plan review F3 |
| Granica bezpieczeństwa | API, nie Flutter | Publiczny endpoint można wywołać poza aplikacją. | Research |
| Sekret | `Auth__RegistrationInviteCode` w App Service | Nie trafia do repozytorium ani binarki. | Research |
| Test fixtures | Centralna fabryka i helper `Register` | Chroni ponad sto istniejących testowych wywołań. | Research |
| Wdrożenie | Backend przed mobilką | Zapewnia kompatybilność kontraktu i aktywną bramkę. | Research |

## Scope

**In scope:**

- server-side registration gate dla obu ról;
- polski kontrakt wszystkich błędów rejestracji;
- pole `Kod beta` w istniejącym signup;
- działające `Pokaż` / `Ukryj` w loginie i signup;
- stabilne sześci znakowe wklejanie kodu trenera;
- obowiązkowe poprawne parowanie w bieżącym onboardingu podopiecznego;
- API, Flutter, testy, konfiguracja App Service i smoke verification.

**Out of scope:**

- indywidualne i wygasające kody beta;
- e-mail verification, CAPTCHA i rate limiting;
- przechowywanie kodu beta w bazie lub aplikacji;
- kopiowanie kodu trenera — S-08;
- zmiana logowania, tokenów, ról lub modelu relacji;
- tłumaczenie błędów niezwiązanych z tym przepływem.

## Architecture / Approach

Flutter zbiera kod beta i przesyła go w `POST /auth/register`. API odczytuje oczekiwany sekret z konfiguracji, fail-closed sprawdza go przed zapytaniem o e-mail i zwraca jeden bezpieczny polski `error`. Po rejestracji kod trenera pozostaje oddzielnym wywołaniem `/trainee/trainer-link`. Dla nowego podopiecznego aplikacja zapisuje lokalny znacznik niedokończonego onboardingu, odtwarza parowanie po restarcie lub ponownym logowaniu i usuwa znacznik dopiero po sukcesie API.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. API gate | Kontrakt kodu beta, polskie błędy, fixtures i pełna regresja API | Brak settingu nie może zatrzymać loginu |
| 2. Mobile forms | Pole beta, toggle hasła, błędy i stabilne parowanie | Dwa kody nie mogą zostać pomylone |
| 3. Deployment | Sekret App Service, backend-first rollout i E2E | Sekret nie może trafić do repo/logów |

**Prerequisites:** Dostęp do konfiguracji Azure App Service i możliwość wdrożenia API przed mobilką.
**Estimated effort:** trzy osobne commity/fazy, około 3–5 skupionych sesji.

## Open Risks & Assumptions

- Wspólny kod beta jest lekką kontrolą prywatnej bety, nie pełną ochroną przed nadużyciami.
- Stare buildy mobilne utracą możliwość rejestracji po wdrożeniu gate, ale zachowają logowanie.
- Obowiązkowość kodu trenera dotyczy bieżącego onboardingu nowego podopiecznego; plan nie migruje ani nie blokuje istniejących kont bez relacji.
- Lokalny znacznik blokuje obejście w oficjalnej aplikacji po restarcie i ponownym logowaniu, ale nie stanowi serwerowej blokady po reinstalacji ani przy bezpośrednim użyciu API.
- Rollback backendu otworzy rejestrację, dlatego musi być decyzją świadomą.

## Success Criteria (Summary)

- Bez poprawnego kodu beta żadne nowe konto nie powstaje; istniejące konta nadal się logują.
- Użytkownik widzi wyłącznie spokojne polskie komunikaty, w tym lokalnie mapowane błędy kodu trenera w onboardingu, a hasło i oba kody nie wyciekają.
- Formularz działa bez overflow, toggle hasła działa, submit jest single-flight, a podopieczny kończy onboarding dopiero po poprawnym kodzie trenera również po restarcie lub ponownym logowaniu.
