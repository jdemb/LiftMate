---
date: 2026-06-23T12:20:15+02:00
researcher: Codex
git_commit: 222a796d6acc05273dd1b905085ef769e072f04a
branch: deploy-2026-05-26
repository: PrototypApka
topic: "Wcześniejsze decyzje i wzorce testowe istotne dla beta-registration-guard"
tags: [research, codebase, auth, registration, flutter, aspnet-core, azure]
status: complete
last_updated: 2026-06-23
last_updated_by: Codex
---

# Research: beta-registration-guard

**Date**: 2026-06-23T12:20:15+02:00  
**Researcher**: Codex  
**Git Commit**: `222a796d6acc05273dd1b905085ef769e072f04a`  
**Branch**: `deploy-2026-05-26`  
**Repository**: `PrototypApka`

## Research Question

Zbadać przekrojowo wcześniejsze decyzje i wzorce testowe istotne dla
`beta-registration-guard`, ze szczególnym uwzględnieniem konfliktu między
wcześniejszym usunięciem registration gate a nowym PRD, polskich błędów,
konfiguracji deploy, test fixtures i minimalnego podziału na fazy.

## Summary

Nowy PRD świadomie nadpisuje wcześniejszą decyzję produktową o otwarciu
rejestracji. Nadal obowiązuje natomiast ważniejsza decyzja architektoniczna:
kod beta i kod trenera są dwoma różnymi pojęciami. Kod beta powinien chronić
wyłącznie utworzenie konta po stronie API, a kod trenera powinien pozostać
osobnym kontraktem parowania po udanej rejestracji.

Obecny kod nie ma żadnego registration gate. `RegisterRequest`, endpoint API,
klient Flutter i kontroler przesyłają tylko e-mail, hasło, rolę i nazwę
wyświetlaną. Testy widgetowe dodatkowo blokują pojawienie się starego kroku
`Kod dostępu` / `Kod rejestracji`. Zmiana musi więc jawnie zaktualizować te
kontrakty i testy, nie przywracając starego osobnego ekranu ani nie mieszając
kodu beta z sześciocyfrowym kodem trenera.

Najmniejszy bezpieczny podział to trzy fazy:

1. API gate, polski kontrakt błędów i wspólne fixtures testowe.
2. Flutter: pole kodu beta, działający toggle hasła i stabilne wklejanie kodu
   trenera wraz z testami klienta/widgetów.
3. Konfiguracja App Service oraz pełna weryfikacja lokalna i wdrożeniowa.

## Detailed Findings

### 1. Konflikt decyzji: usunięcie gate kontra nowy PRD

Pierwotny foundation auth zakładał serwerowy kod zaproszenia z konfiguracji,
ponieważ publiczny endpoint może zostać wywołany poza aplikacją mobilną
([archived plan:39](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-02-authenticated-role-boundary/plan.md#L39),
[plan:51](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-02-authenticated-role-boundary/plan.md#L51)).
Gate miał być kontrolą prywatnej bety, nie pełnym zabezpieczeniem przed
nadużyciami
([plan:558-565](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-02-authenticated-role-boundary/plan.md#L558-L565)).

Późniejsze `dostosowanie` usunęło gate, ponieważ ówczesnym kontraktem był
design bez ekranu `Kod dostępu`. Plan jawnie zmienił `RegisterRequest` do
czterech pól i usunął zależność od `Auth:RegistrationInviteCode`
([dostosowanie plan:393-407](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/changes/dostosowanie/plan.md#L393-L407)).
Testy miały blokować ponowne dodanie starego kodu
([plan:447-463](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/changes/dostosowanie/plan.md#L447-L463)).

Nowy zaakceptowany shaping i PRD zmieniają wymaganie:

- każda nowa rejestracja wymaga jednego wspólnego kodu beta dla obu ról
  ([shape-notes-expansion.md:27-30](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/foundation/shape-notes-expansion.md#L27-L30));
- brakujący lub błędny kod blokuje utworzenie konta, a istniejące konta nadal
  logują się bez kodu
  ([prd-expansion.md:108-121](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/foundation/prd-expansion.md#L108-L121));
- kod jest wspólny, wielokrotnego użycia, bez indywidualnych limitów
  ([prd-expansion.md:175-184](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/foundation/prd-expansion.md#L175-L184)).

**Obowiązująca decyzja:** nowy PRD nadpisuje decyzję „rejestracja otwarta”.
Nie nadpisuje rozdzielenia kodów. Kod beta jest przedautoryzacyjnym sekretem
rejestracji; kod trenera pozostaje poautoryzacyjnym identyfikatorem relacji.
Archiwalny pairing wprost traktuje usunięty globalny kod i kod trenera jako
oddzielne kontrakty
([trainer-trainee plan:16](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-15-trainer-trainee-pairing/plan.md#L16),
[plan:69](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-15-trainer-trainee-pairing/plan.md#L69)).

### 2. Aktualny kontrakt kodu wymaga pełnej zmiany pionowej

Backendowy `RegisterRequest` nie zawiera kodu beta
([AuthContracts.cs:3-7](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/api/LiftMate.Api/Auth/AuthContracts.cs#L3-L7)).
Endpoint od razu sprawdza rolę, e-mail, display name i Identity, bez kontroli
konfiguracji
([AuthEndpoints.cs:22-61](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/api/LiftMate.Api/Auth/AuthEndpoints.cs#L22-L61)).

Klient Flutter również wysyła tylko cztery pola
([auth_api_client.dart:48-64](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_api_client.dart#L48-L64)),
a `AuthController` i `AuthScreen` nie mają stanu kodu beta
([auth_controller.dart:85-99](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_controller.dart#L85-L99),
[auth_screen.dart:101-112](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L101-L112)).

**Obowiązująca decyzja:** API musi wymuszać kod. Walidacja wyłącznie w UI nie
spełnia PRD ani wcześniejszej zasady, że zaufana granica znajduje się w API.
Brak konfiguracji powinien zamykać rejestrację (fail closed), nie otwierać ją.
Nie jest potrzebna migracja bazy danych.

### 3. Polskie błędy wymagają stabilnego kontraktu

Aktualny endpoint zwraca angielskie komunikaty dla roli, duplikatu e-maila i
braku display name, a błędy Identity zwraca jako tablicę `errors`
([AuthEndpoints.cs:28-59](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/api/LiftMate.Api/Auth/AuthEndpoints.cs#L28-L59)).
Klient mobilny odczytuje tylko pojedyncze pola `message` albo `error`, więc
tablica Identity kończy się ogólnym `API returned HTTP 400`
([auth_api_client.dart:347-364](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_api_client.dart#L347-L364)).
Widget test utrwala dziś angielskie `Registration failed.`
([auth_screen_test.dart:267-290](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/test/auth_screen_test.dart#L267-L290)).

**Obowiązująca decyzja:** dla rejestracji zwracać jeden stabilny, polski
`error`; błędy Identity mapować po kodach, nie przekazywać ich angielskich
opisów. Zachować zasadę nieujawniania hasła i kodów w komunikatach/logach.
Zakres S-07 nie wymaga tłumaczenia wszystkich istniejących endpointów domenowych.

### 4. Password toggle jest obecnie tylko tekstem

Login i signup ustawiają `obscureText: true` i suffix `Pokaż`
([auth_screen.dart:553-565](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L553-L565),
[auth_screen.dart:644-649](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L644-L649)).
`_DesignedField` jest stateless, a suffix jest renderowany jako `suffixText`,
bez callbacku
([auth_screen.dart:993-1039](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L993-L1039)).

**Obowiązująca decyzja:** toggle musi zmieniać faktyczne `obscureText` i mieć
test dla pokazania oraz ponownego ukrycia hasła. Powinien działać osobno na
ekranie loginu i rejestracji.

### 5. Wklejanie kodu trenera ma istniejący wzorzec, ale brak regresji paste

Kod trenera jest osobnym kontrolerem, normalizowanym przed wysłaniem
([auth_screen.dart:149-166](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L149-L166)).
UI wyświetla sześć pól nad przezroczystym `TextFormField`; nie ma limitera
długości ani testu wklejenia całego kodu
([auth_screen.dart:1045-1097](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/lib/auth/auth_screen.dart#L1045-L1097)).
Istniejący test wpisuje ciąg programowo i potwierdza normalizację/claim, ale
nie sprawdza geometrii ani overflow
([auth_screen_test.dart:248-264](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/test/auth_screen_test.dart#L248-L264)).

**Obowiązująca decyzja:** zachować osobny endpoint `/trainee/trainer-link` i
normalizację trim + uppercase. Dodać ograniczenie do sześciu dozwolonych
znaków oraz widget test wklejenia na małym viewportcie, który sprawdza brak
wyjątku/overflow i poprawny payload.

### 6. Test fixtures mają jeden centralny punkt aktualizacji

`TestApplicationFactory` używa `AddInMemoryCollection` dla testowej
konfiguracji i trzyma połączenie SQLite in-memory przy życiu przez fixture
([TestApplicationFactory.cs:20-46](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs#L20-L46)).
`AuthEndpointTests.Register` jest wspólnym helperem tworzenia kont używanym
przez testy auth, pairing, workout sets, shared sessions i training history
([AuthEndpointTests.cs:138-153](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs#L138-L153)).
W repo istnieją 123 wywołania tego helpera.

**Obowiązująca decyzja:** dodać jeden testowy kod beta do
`TestApplicationFactory` i domyślnie używać go w helperze `Register`; nie
edytować 123 call sites. Tylko testy negatywne powinny budować payload z
brakiem/błędnym kodem albo nadpisywać konfigurację. Zachować
`WebApplicationFactory` + SQLite in-memory, bo sprawdzają realny pipeline HTTP,
Identity i routing.

Po stronie Flutter obecne testy klienta asertywnie porównują cały JSON
rejestracji
([auth_api_client_test.dart:17-52](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/test/auth_api_client_test.dart#L17-L52)),
a widget tests porównują payload dla obu ról
([auth_screen_test.dart:124-157](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/test/auth_screen_test.dart#L124-L157),
[auth_screen_test.dart:160-202](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/apps/mobile/test/auth_screen_test.dart#L160-L202)).
To są właściwe miejsca do zablokowania nowego pola i rozdzielenia obu kodów.

### 7. Deploy i sekrety

Aktualny workflow wdraża API automatycznie tylko z gałęzi
`deploy-2026-05-26`, dla zmian w `apps/api/**`, i przed deployem uruchamia
migracje
([deploy-api-azure.yml:3-9](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/.github/workflows/deploy-api-azure.yml#L3-L9),
[deploy-api-azure.yml:47-69](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/.github/workflows/deploy-api-azure.yml#L47-L69)).
Workflow nie ustawia App Service application settings.

Foundation nakazuje trzymać API secrets w App Service configuration i wymaga
zgody człowieka na zmianę sekretów/deploy
([infrastructure.md:80-83](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/foundation/infrastructure.md#L80-L83)).
Historyczny checklist używał `Auth__RegistrationInviteCode` i ręcznie
sprawdzał accept/reject na wdrożonym API
([azure-auth-checklist.md:8-13](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-02-authenticated-role-boundary/azure-auth-checklist.md#L8-L13),
[checklist:22-26](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/archive/2026-06-02-authenticated-role-boundary/azure-auth-checklist.md#L22-L26)).

**Obowiązująca decyzja:** kod beta jest sekretem App Service, nie wartością
w repo ani w binarce mobilnej. Można przywrócić stabilną nazwę
`Auth:RegistrationInviteCode` / `Auth__RegistrationInviteCode`, aby wykorzystać
historyczny kontrakt operacyjny. Workflow nie powinien zawierać wartości
sekretu. Przed wdrożeniem backendu człowiek ustawia setting; po deployu trzeba
sprawdzić poprawny, błędny i brakujący kod oraz logowanie istniejącego konta.

Backend musi zostać wdrożony przed mobilką, zgodnie z istniejącą zasadą
kompatybilności kontraktów
([dostosowanie plan:526-534](https://github.com/jdemb/PrototypApka/blob/222a796d6acc05273dd1b905085ef769e072f04a/context/changes/dostosowanie/plan.md#L526-L534)).

## Minimal Phase Split

### Phase 1: API registration gate and test foundation

- rozszerzyć `RegisterRequest` o kod beta;
- sprawdzać kod przed zapisem użytkownika i zamykać rejestrację przy braku
  konfiguracji;
- zwracać stabilne polskie błędy rejestracji;
- dodać testową konfigurację do `TestApplicationFactory`;
- zaktualizować centralny `Register` helper;
- testy: poprawny kod dla obu ról, brak, błędny kod, config missing, duplikat,
  rola, display name, słabe hasło, brak regresji loginu.

### Phase 2: Mobile registration and form stability

- dodać kod beta do klienta, kontrolera i formularza signup;
- zachować kod trenera jako osobny krok/parowanie;
- wdrożyć rzeczywisty toggle hasła;
- ograniczyć i ustabilizować paste kodu trenera;
- testy klienta pełnego payloadu, polskich błędów, obu ról, toggle
  show/hide, paste na małym viewportcie i brak wycieku sekretów.

### Phase 3: Deployment gate and end-to-end verification

- ustawić `Auth__RegistrationInviteCode` w App Service configuration;
- wdrożyć API przed nową mobilką;
- uruchomić pełne `dotnet test`, targeted/full Flutter tests i
  `flutter analyze`;
- ręcznie potwierdzić valid/invalid/missing beta code, login istniejącego
  konta, oba role oraz pairing kodem trenera.

## Architecture Insights

- Security gate należy do API; UI jedynie zbiera wartość.
- Kod beta nie powinien być mylony z kodem trenera ani przechowywany w bazie.
- Wspólny helper rejestracji jest krytycznym fixture; jego aktualizacja
  izoluje większość testów domenowych od zmiany kontraktu.
- Polskie komunikaty powinny być stabilnym kontraktem rejestracji, nie
  surowymi opisami Identity.
- Brak migracji danych pozwala dostarczyć zmianę backend-first i łatwo wycofać
  kod, ale usunięcie settingu bez rollbacku aplikacji zamknie rejestrację.

## Historical Context

- `authenticated-role-boundary` dostarczył poprawny wzorzec: server-side gate,
  test config, `WebApplicationFactory`, manual App Service secret gate.
- `dostosowanie` poprawnie usunęło pomieszanie globalnego kodu z kodem trenera,
  ale jego decyzja o otwartej rejestracji została superseded przez PRD v2.
- `trainer-trainee-pairing` utrwalił osobny, poautoryzacyjny kontrakt kodu
  trenera i nie powinien być przebudowywany przez S-07.

## Open Questions

- Brak pytania blokującego plan. Plan powinien jawnie nazwać kod beta
  `registrationInviteCode` lub `betaCode`; rekomendowane jest zachowanie
  istniejącej operacyjnej nazwy konfiguracji `Auth:RegistrationInviteCode`.
- Copy pola może zostać ustalone w planie/design review. Nie należy ponownie
  wprowadzać osobnego ekranu `Kod dostępu`; pole może być częścią signup.
