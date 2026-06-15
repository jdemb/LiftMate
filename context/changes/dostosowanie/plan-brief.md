# Dostosowanie onboardingu auth do projektu Design - Plan Brief

> Full plan: `context/changes/dostosowanie/plan.md`

## What & Why

Dostosowujemy mobilne logowanie i tworzenie konta do projektu z `apps/mobile/design/LiftMate.dc.html`. Po pierwszej implementacji flow działa, ale UI jest tylko inspirowane designem; teraz plan wymaga bliskiego odwzorowania logo, fontów, gradientu tła, poświaty przycisków, kart roli, pól i widocznych komunikatów.

## Starting Point

Flutter ma auth flow z welcome, wyborem roli, loginem, signupem i parowaniem, ale używa natywnych Materialowych przybliżeń zamiast design-systemu z HTML. Dodatkowo globalny kod rejestracji i kod trenera są zbyt łatwe do pomylenia, a kod rejestracji pojawia się w formularzu obok danych użytkownika.

## Desired End State

Użytkownik widzi ciemny onboarding LiftMate możliwie najbliższy projektowi: logo z niebieskim gradientem, Space Grotesk / Manrope, radialny gradient tła, poświata przycisku `Załóż konto`, karty `Jestem podopiecznym` / `Jestem trenerem`, osobny login, signup z imieniem i nazwiskiem oraz ekran parowania. Trener widzi kod dopiero na osobnym ekranie `Zaproś podopiecznego`, a podopieczny wpisuje kod trenera dopiero na osobnym ekranie `Połącz się z trenerem`. Globalny kod rejestracji pozostaje kontraktem backendu, ale UI nie miesza go z kodem trenera.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Auth scope | Full onboarding | Design rozbija auth na kilka ekranów, więc nie ograniczamy się do jednego formularza. |
| Visual fidelity | Close adaptation, not pixel-perfect | Logo, fonts, buttons, fields, glow, gradient and copy should follow the HTML design closely, while allowing small height/scroll adaptations. |
| UI language | Design copy first | Teksty produktowe mają być takie jak w designie tam, gdzie design je definiuje. |
| Name field | Backend extension | Pole z designu ma realnie zapisywać dane, nie być atrapą. |
| Registration gate | Keep backend contract, separate UI | Zachowuje obecną globalną bramkę rejestracji, ale nie miesza jej z kodem trenera. |
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
- Rozdzielenie globalnego kodu rejestracji od kodu trenera; kod trenera pojawia się dopiero na osobnym ekranie parowania.
- Usunięcie diagnostyki API, paneli technicznych i martwych zależności konstrukcyjnych z `AuthScreen`.
- Aktualizacja testów Flutter i API.

**Out of scope:**

- Dashboardy trenera i podopiecznego.
- Przyszłe okno trenera do otwierania kodu zaproszenia poza rejestracją.
- Wysyłanie kodu zaproszenia wewnątrz aplikacji.
- Password reset, social login, e-mail verification.
- Pełne wdrożenie wszystkich ekranów z Design poza auth onboardingiem.
- Pixel-perfect port HTML; Flutter może poprawić scroll i wysokości tam, gdzie eksport HTML ma problemy.

## Architecture / Approach

Backend i mobilny kontrakt auth zostają bez zmiany poza wcześniejszymi rozszerzeniami. Faza korekcyjna skupia się na warstwie Flutter: statyczne fonty, logo/marka jako natywny widget, designowe kontenery i przyciski, oraz jasne rozdzielenie stanu globalnego kodu rejestracji od kodu trenera.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Backend Auth Contract | `displayName`, trainer codes, trainee assignment, shared-session enforcement | Migration/defaults and relationship rules |
| 2. Mobile Auth Contract | Flutter sends/parses auth and pairing contracts | Strict JSON parsing or code normalization drift |
| 3. Mobile Onboarding UI | Product-facing auth and pair flow from Design | Scope creep into dashboards |
| 4. Design Fidelity and Code Separation Fix | Closer visual match plus separated registration/trainer-code screens | Font assets and preserving backend registration gate without UI confusion |

**Prerequisites:** Backend should be deployed or run locally with `displayName` and pairing endpoints before testing the updated mobile app.
**Estimated effort:** ~3-4 implementation sessions across 4 phases.

## Open Risks & Assumptions

- Global registration `invitationCode` remains separate from trainer invite codes used for pairing.
- Trainer invite codes use uppercase 6-character unambiguous alphanumeric format.
- Sending trainer invite codes happens outside the app.
- If deployed incrementally, backend must land before the mobile parser requires `displayName`.
- Custom fonts from Design are now in scope for the auth onboarding surface; use static bundled assets, not runtime downloads.
- The HTML design has imperfect vertical height in places, so Flutter should preserve the visual system while using scroll/layout adjustments for real phones.

## Success Criteria (Summary)

- Register/login/me contract includes `displayName`; pairing endpoints generate and claim trainer codes; shared-session creation respects the paired trainer.
- Mobile auth API and widget tests pass with the new onboarding flow.
- Auth UI closely matches the Design visual system and no longer shows technical diagnostics.
- Global registration invitation code and trainer invite code are visually and logically separate.
