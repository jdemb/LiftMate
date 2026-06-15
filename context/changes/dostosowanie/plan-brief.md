# Dostosowanie onboardingu auth do projektu Design - Plan Brief

> Full plan: `context/changes/dostosowanie/plan.md`

## What & Why

Dostosowujemy mobilne logowanie i tworzenie konta do projektu z `apps/mobile/design/LiftMate.dc.html`. Obecny ekran auth jest techniczny i jednowarstwowy, a design zakłada produktowy onboarding z powitaniem, wyborem roli, rejestracją, logowaniem i parowaniem kodem trenera.

## Starting Point

Flutter ma dziś jeden `AuthScreen`, który przełącza `Sign in` / `Create account` i pokazuje diagnostykę API oraz panele probe/shared-session. Backend auth nie przechowuje imienia i nazwiska, mimo że projekt signup pokazuje takie pole.

## Desired End State

Użytkownik widzi ciemny onboarding LiftMate: `Załóż konto`, `Mam już konto`, wybór roli, osobny login, signup z imieniem i nazwiskiem oraz ekran parowania. Trener może wygenerować 6-znakowy kod do przekazania poza aplikacją, a podopieczny może wpisać ten kod i zostać przypisany do trenera. Po sukcesie nadal trafia do tymczasowego zalogowanego panelu, bo dashboardy z designu są poza tym zakresem. Backend zapisuje i zwraca `displayName`.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Auth scope | Full onboarding | Design rozbija auth na kilka ekranów, więc nie ograniczamy się do jednego formularza. |
| UI language | Mixed | Teksty produktowe są po polsku, a techniczne komunikaty API mogą zostać po angielsku. |
| Name field | Backend extension | Pole z designu ma realnie zapisywać dane, nie być atrapą. |
| Registration gate | Keep in registration | Zachowuje obecny kontrakt i globalną bramkę rejestracji. |
| Pairing | Add trainer-code endpoints | Ekrany parowania z designu będą funkcjonalne bez budowania przyszłego okna ustawień trenera. |
| Code format | 6 uppercase unambiguous chars | Jeden kontrakt dla backendu, mobile i testów zapobiega driftowi walidacji. |
| Shared-session access | Enforce pairing | Trwała relacja trener-podopieczny musi ograniczać tworzenie sesji treningowych. |
| Login | Separate screen | Utrzymuje działający login i pasuje do wieloetapowego onboardingu. |
| Diagnostics | Remove from auth UI | Auth ma być produktem, nie ekranem smoke-testowym. |
| Post-auth | Temporary authenticated panel | Nie rozszerzamy tej zmiany o dashboardy trenera i podopiecznego. |

## Scope

**In scope:**

- Backend `displayName` w `ApplicationUser`, DTO, token/me responses, migracji i testach.
- Backend kodów zaproszeń trenera, przypisania podopiecznego do trenera i egzekwowania tej relacji przy tworzeniu shared sessions.
- Mobile `displayName` w modelach, kliencie API, kontrolerze i testach.
- Mobile API calls dla wygenerowania kodu trenera i wprowadzenia kodu przez podopiecznego.
- Nowy onboarding auth: welcome, role, login, signup, pair.
- Usunięcie diagnostyki API, paneli technicznych i martwych zależności konstrukcyjnych z `AuthScreen`.
- Aktualizacja testów Flutter i API.

**Out of scope:**

- Dashboardy trenera i podopiecznego.
- Przyszłe okno trenera do otwierania kodu zaproszenia poza rejestracją.
- Wysyłanie kodu zaproszenia wewnątrz aplikacji.
- Password reset, social login, e-mail verification.
- Pełne wdrożenie wszystkich ekranów z Design poza auth onboardingiem.

## Architecture / Approach

Najpierw backend dostaje stabilny kontrakt `displayName`, relację trener-podopieczny, endpointy kodów zaproszeń i egzekwowanie relacji w shared sessions. Potem Flutter aktualizuje klienta i modele, a na końcu `AuthScreen` dostaje lokalny stan onboardingu oraz oczyszczony konstruktor. Diagnostyczne komponenty nie są kasowane z repo, tylko odpinane od auth UI.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Backend Auth Contract | `displayName`, trainer codes, trainee assignment, shared-session enforcement | Migration/defaults and relationship rules |
| 2. Mobile Auth Contract | Flutter sends/parses auth and pairing contracts | Strict JSON parsing or code normalization drift |
| 3. Mobile Onboarding UI | Product-facing auth and pair flow from Design | Scope creep into dashboards |

**Prerequisites:** Backend should be deployed or run locally with `displayName` and pairing endpoints before testing the updated mobile app.
**Estimated effort:** ~2-3 implementation sessions across 3 phases.

## Open Risks & Assumptions

- Global registration `invitationCode` remains separate from trainer invite codes used for pairing.
- Trainer invite codes use uppercase 6-character unambiguous alphanumeric format.
- Sending trainer invite codes happens outside the app.
- If deployed incrementally, backend must land before the mobile parser requires `displayName`.
- Custom fonts from Design may require a separate asset decision; the plan allows theme fallback.

## Success Criteria (Summary)

- Register/login/me contract includes `displayName`; pairing endpoints generate and claim trainer codes; shared-session creation respects the paired trainer.
- Mobile auth API and widget tests pass with the new onboarding flow.
- Auth UI matches the Design direction and no longer shows technical diagnostics.
