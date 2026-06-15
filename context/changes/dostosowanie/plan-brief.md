# Dostosowanie onboardingu auth do projektu Design - Plan Brief

> Full plan: `context/changes/dostosowanie/plan.md`

## What & Why

Dostosowujemy mobilne logowanie i tworzenie konta do projektu z `apps/mobile/design/LiftMate.dc.html`. Po pierwszej implementacji flow działa, ale UI i kontrakt rejestracji nadal odbiegały od designu: pojawił się nieistniejący ekran `Kod dostępu`, dodatkowy tekst na welcome i błędne rozróżnienie globalnego kodu rejestracji od kodu trenera.

## Starting Point

Flutter ma auth flow z welcome, wyborem roli, loginem, signupem i parowaniem, ale nadal zawierał sztuczny krok `Kod dostępu`, którego nie ma w `LiftMate.dc.html`. Backend i mobile miały też stary globalny `invitationCode` w kontrakcie `/auth/register`, przez co UI nie mógł być naprawdę 1:1 z designem.

## Desired End State

Użytkownik widzi ciemny onboarding LiftMate możliwie najbliższy projektowi: logo z niebieskim gradientem, Space Grotesk / Manrope, radialny gradient tła, poświata przycisku `Załóż konto`, karty `Jestem podopiecznym` / `Jestem trenerem`, osobny login, signup z imieniem i nazwiskiem oraz ekran parowania. Po signupie trener od razu widzi `Zaproś podopiecznego` z wygenerowanym kodem trenera, a podopieczny od razu widzi `Połącz się z trenerem`, gdzie wpisuje ten kod. Nie ma ekranu `Kod dostępu` ani globalnego kodu rejestracji w onboardingowym kontrakcie.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Auth scope | Full onboarding | Design rozbija auth na kilka ekranów, więc nie ograniczamy się do jednego formularza. |
| Visual fidelity | Close adaptation, not pixel-perfect | Logo, fonts, buttons, fields, glow, gradient and copy should follow the HTML design closely, while allowing small height/scroll adaptations. |
| UI language | Design copy first | Teksty produktowe mają być takie jak w designie tam, gdzie design je definiuje. |
| Name field | Backend extension | Pole z designu ma realnie zapisywać dane, nie być atrapą. |
| Registration gate | Remove global registration code | `LiftMate.dc.html` nie ma ekranu `Kod dostępu`; jedyny kod w onboardingu to kod trenera. |
| Pairing | Separate trainer-code screens | Ekrany `Zaproś podopiecznego` i `Połącz się z trenerem` są osobne w designie i w implementacji. |
| Code format | 6 uppercase unambiguous chars | Jeden kontrakt dla backendu, mobile i testów zapobiega driftowi walidacji. |
| Diagnostics | Remove from auth UI | Auth ma być produktem, nie ekranem smoke-testowym. |
| Post-auth | Temporary authenticated panel | Nie rozszerzamy tej zmiany o dashboardy trenera i podopiecznego. |

## Scope

**In scope:**

- Backend `displayName` w `ApplicationUser`, DTO, token/me responses, migracji i testach.
- Backend kodów zaproszeń trenera, przypisania podopiecznego do trenera i egzekwowania tej relacji przy tworzeniu shared sessions.
- Mobile `displayName` w modelach, kliencie API, kontrolerze i testach.
- Mobile API calls dla wygenerowania kodu trenera i wprowadzenia kodu przez podopiecznego.
- Nowy onboarding auth: welcome, role, login, signup, pair.
- Korekta UI do bliskiej zgodności z designem: logo, fonty, gradient, poświata CTA, karty roli, pola i kopia ekranów.
- Usunięcie globalnego kodu rejestracji z `/auth/register`, mobile clienta i auth UI.
- Kod trenera pojawia się dopiero na osobnym ekranie parowania: `Zaproś podopiecznego` albo `Połącz się z trenerem`.
- Usunięcie diagnostyki API, paneli technicznych i martwych zależności konstrukcyjnych z `AuthScreen`.
- Aktualizacja testów Flutter i API.

**Out of scope:**

- Dashboardy trenera i podopiecznego.
- Przyszłe okno trenera do otwierania kodu zaproszenia poza rejestracją.
- Wysyłanie kodu zaproszenia wewnątrz aplikacji.
- Weryfikacja, akceptacja lub zatwierdzanie kont trenerów przez admina.
- Password reset, social login, e-mail verification.
- Pełne wdrożenie wszystkich ekranów z Design poza auth onboardingiem.
- Pixel-perfect port HTML; Flutter może poprawić scroll i wysokości tam, gdzie eksport HTML ma problemy.

## Architecture / Approach

Phase 5 koryguje kontrakt backend/mobile: `/auth/register` przyjmuje tylko dane widoczne w designowym signupie i nie wymaga globalnego `invitationCode`. Warstwa Flutter usuwa sztuczny ekran `Kod dostępu`, poprawia welcome do projektu HTML i prowadzi po signupie bezpośrednio do `Zaproś podopiecznego` albo `Połącz się z trenerem`.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Backend Auth Contract | `displayName`, trainer codes, trainee assignment, shared-session enforcement | Migration/defaults and relationship rules |
| 2. Mobile Auth Contract | Flutter sends/parses auth and pairing contracts | Strict JSON parsing or code normalization drift |
| 3. Mobile Onboarding UI | Product-facing auth and pair flow from Design | Scope creep into dashboards |
| 4. Design Fidelity and Code Separation Fix | Closer visual match plus separated registration/trainer-code screens | Font assets and remaining old access-code assumptions |
| 5. Auth Flow Correction to Match Design | Removes the non-design access-code gate and routes signup directly to trainer/trainee pair screens | Backend/mobile contract drift during rollout |

**Prerequisites:** Backend should be deployed or run locally with `displayName` and pairing endpoints before testing the updated mobile app.
**Estimated effort:** ~4-5 implementation sessions across 5 phases.

## Open Risks & Assumptions

- Registration no longer uses a global `invitationCode`; any deployed backend/mobile pair must agree on that contract.
- Trainer registration is intentionally open in this phase; future trainer verification or approval is out of scope.
- Trainer invite codes use uppercase 6-character unambiguous alphanumeric format.
- Sending trainer invite codes happens outside the app.
- If deployed incrementally, backend must land before the mobile parser requires `displayName`.
- Custom fonts from Design are now in scope for the auth onboarding surface; use static bundled assets, not runtime downloads.
- The HTML design has imperfect vertical height in places, so Flutter should preserve the visual system while using scroll/layout adjustments for real phones.

## Success Criteria (Summary)

- Register/login/me contract includes `displayName` and no global registration invitation code; pairing endpoints generate and claim trainer codes; shared-session creation respects the paired trainer.
- Mobile auth API and widget tests pass with the new onboarding flow.
- Auth UI closely matches the Design visual system and no longer shows technical diagnostics.
- There is no `Kod dostępu`/global registration-code step; the only onboarding code is the trainer invite code.
