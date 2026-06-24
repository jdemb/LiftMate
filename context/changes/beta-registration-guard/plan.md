# Bezpieczna i poprawna rejestracja beta — plan implementacji

## Overview

S-07 zamyka publiczną rejestrację jednym współdzielonym kodem beta, pozostawiając logowanie istniejących kont bez zmian. Jednocześnie porządkuje mobilny onboarding: dodaje pole kodu beta do istniejącego formularza, naprawia pokazywanie hasła, stabilizuje wklejanie sześci znaków kodu trenera i zastępuje techniczne błędy spokojnymi komunikatami po polsku.

Kod beta i kod trenera pozostają osobnymi kontraktami. Kod beta jest przedautoryzacyjnym sekretem chroniącym `POST /auth/register`; kod trenera jest poautoryzacyjnym identyfikatorem relacji używanym wyłącznie przez podopiecznego.

## Current State Analysis

- `POST /auth/register` przyjmuje `Email`, `Password`, `Role` i `DisplayName`, po czym tworzy konto bez bramki beta (`apps/api/LiftMate.Api/Auth/AuthContracts.cs`, `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`).
- Endpoint rejestracji zwraca angielskie teksty oraz surowe opisy ASP.NET Identity, a klient Flutter odczytuje tylko pojedyncze `message` lub `error`.
- `AuthApiClient`, `AuthController` i formularz rejestracji nie mają pola kodu beta.
- Tekst `Pokaż` przy haśle jest nieklikalnym `suffixText`; `obscureText` pozostaje zawsze włączone.
- Pole kodu trenera pokazuje sześć pól, ale może przyjąć i wysłać więcej znaków. Dodatkowo pokazuje niepotwierdzony komunikat `Znaleziono kod trenera`.
- Bieżący ekran parowania podopiecznego można opuścić przyciskiem wstecz bez poprawnego kodu, mimo że zamierzonym przebiegiem onboardingu jest skuteczne połączenie konta.
- `TestApplicationFactory` centralnie wstrzykuje konfigurację testową, a `AuthEndpointTests.Register` jest wspólnym helperem używanym przez testy wielu modułów.
- Produkcyjny workflow wdraża API do Azure App Service, ale nie ustawia application settings.

## Desired End State

- Nowe konto trenera lub podopiecznego powstaje tylko po przesłaniu dokładnie zgodnego kodu beta.
- Brak konfiguracji sekretu blokuje wyłącznie rejestrację odpowiedzią `503`; login, refresh i pozostałe API nadal działają.
- Kod beta jest przechowywany wyłącznie w konfiguracji serwera pod `Auth:RegistrationInviteCode`; nie trafia do repozytorium, binarki mobilnej, logów ani odpowiedzi.
- Formularz rejestracji zawiera pole `Kod beta`, bez dodawania osobnego kroku onboardingu.
- Wszystkie błędy rejestracji są prezentowane prostym polskim tekstem bez kodów błędów, nazw wyjątków i technicznych szczegółów.
- `Pokaż` / `Ukryj` faktycznie przełącza widoczność hasła na ekranach logowania i rejestracji.
- Kod trenera przyjmuje dokładnie sześć dozwolonych znaków, normalizuje je do uppercase i nie pokazuje sukcesu przed potwierdzeniem API.
- Nowo zarejestrowany podopieczny pozostaje w bieżącym onboardingu do czasu poprawnego połączenia z trenerem; nie wprowadzamy nowego modelu relacji ani zmian dla wcześniej istniejących kont.

### Key Discoveries

- Nowy PRD świadomie zastępuje wcześniejszą decyzję o otwartej rejestracji, ale nie znosi rozdzielenia kodu beta i kodu trenera.
- Bramka musi działać po stronie API, ponieważ klient mobilny nie jest granicą zaufania.
- Aktualizacja jednego testowego helpera pozwala uniknąć zmian w ponad stu testowych wywołaniach rejestracji.
- Brak migracji bazy danych upraszcza wdrożenie i rollback, ale backend musi być wdrożony przed mobilką.
- `apps/mobile/design/LiftMate.dc.html` pozostaje kontraktem wizualnym; pole kodu beta jest minimalnym dodatkiem do formularza signup, a nie nowym ekranem.

## Key Decisions

| Area | Decision | Rationale |
|---|---|---|
| Umiejscowienie kodu beta | Pole w istniejącym formularzu rejestracji | Zachowuje obecny onboarding i design bez dodatkowego kroku. |
| Porównanie kodu beta | Dokładne, case-sensitive, bez normalizacji | Kontrakt jest jednoznaczny i nie osłabia sekretu. |
| Brak konfiguracji | `503` tylko dla rejestracji | Fail-closed bez odcinania istniejących użytkowników. |
| Komunikaty | Wszystkie błędy rejestracji po polsku, bez technicznych oznaczeń | Użytkownik dostaje jasną instrukcję zamiast szczegółów implementacyjnych. |
| Kod trenera | Poprawny kod obowiązkowy w bieżącym onboardingu podopiecznego | Zachowuje zamierzony przepływ po rejestracji i usuwa obejście przyciskiem wstecz. |
| Wklejanie kodu trenera | Dokładnie 6 dozwolonych znaków, trim + uppercase | Widok i payload zawsze reprezentują tę samą wartość. |
| Konfiguracja | `Auth:RegistrationInviteCode` / `Auth__RegistrationInviteCode` | Przywraca istniejący historyczny kontrakt operacyjny bez przechowywania sekretu w kodzie. |
| Kolejność wdrożenia | Backend i setting przed mobilką | Stary backend nie rozumie nowego pola i nie egzekwuje bramki. |

## What We're NOT Doing

- Nie edytujemy `context/archive/`.
- Nie dodajemy indywidualnych kodów beta, limitów użycia, dat wygaśnięcia ani panelu zarządzania kodami.
- Nie dodajemy weryfikacji e-mail, CAPTCHA, rate limitingu ani pełnego systemu anty-abuse.
- Nie przechowujemy kodu beta w bazie danych ani aplikacji mobilnej.
- Nie łączymy kodu beta z sześciocyfrowym kodem trenera.
- Nie przebudowujemy modelu trener–podopieczny ani endpointów relacji poza zachowaniem obowiązkowego kroku bieżącego onboardingu.
- Nie tłumaczymy wszystkich błędów całego API; stabilny polski kontrakt dotyczy rejestracji i obsługi kodu trenera w tym przepływie.
- Nie implementujemy kopiowania kodu trenera; to osobny slice S-08.
- Nie zmieniamy logowania, tokenów, refreshu, logoutu ani uprawnień istniejących kont.

## Implementation Approach

Zmiana będzie wykonana w trzech fazach. Najpierw API otrzyma serwerową bramkę, stabilny kontrakt błędów i kompatybilne fixtures testowe. Następnie Flutter rozszerzy pionowy kontrakt rejestracji i naprawi zachowanie formularzy. Ostatnia faza obejmie konfigurację sekretu, pełną regresję oraz ręczną weryfikację wdrożonego przepływu.

Każda faza powinna być wdrażana test-first i zakończona osobnym commitem. Manualne pozycje w `## Progress` pozostają niezaznaczone do jawnego potwierdzenia użytkownika.

## Critical Implementation Details

### Kolejność walidacji kodu beta

Endpoint sprawdza dostępność konfiguracji, a następnie poprawność kodu beta przed wyszukaniem użytkownika po e-mailu. Osoba bez kodu nie powinna móc używać endpointu do sprawdzania, które adresy są już zarejestrowane.

Porównanie używa semantyki ordinal i jest case-sensitive. Wartość nie jest trimowana po stronie API ani mobile przed porównaniem; przypadkowa spacja oznacza niepoprawny kod i czytelny komunikat.

### Bezpieczne komunikaty rejestracji

Endpoint zwraca jeden stabilny kształt `{ "error": "<polski tekst>" }`. Błędy ASP.NET Identity są mapowane po stabilnych kodach na komunikaty użytkowe; ich angielskie opisy, nazwy kodów i wyjątki nie trafiają do odpowiedzi.

Brak lub zły kod beta zwraca ten sam komunikat. Brak konfiguracji zwraca neutralne `Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później.` bez ujawniania, że brakuje sekretu.

### Granica obowiązkowego parowania

Po utworzeniu konta podopiecznego bieżąca sesja onboardingu kończy się dopiero po sukcesie `/trainee/trainer-link`. Przycisk wstecz nie może wyczyścić `_pendingPairRole` ani otworzyć pulpitu.

Stan niedokończonego onboardingu jest zapisywany lokalnie dla identyfikatora nowo utworzonego podopiecznego i odtwarzany po restarcie aplikacji. Znacznik nie jest czyszczony przez restart, wylogowanie ani nieudane parowanie; usuwa go wyłącznie skuteczne `/trainee/trainer-link` dla tego użytkownika. Istniejące konta bez takiego znacznika zachowują obecne zachowanie. Jest to ochrona przebiegu oficjalnej aplikacji, a nie serwerowe wymaganie relacji po reinstalacji lub użyciu API poza aplikacją.

Zmiana nie wprowadza atomowego tworzenia konta i relacji, nie usuwa wcześniej istniejących kont bez trenera i nie zmienia post-auth endpointów relacji.

### Stabilne wklejanie kodu trenera

Widocznych i wysyłanych jest zawsze tych samych sześć znaków. Input dopuszcza wyłącznie litery ASCII i cyfry, ogranicza długość do sześciu znaków, a wartość do API jest trimowana i zamieniana na uppercase. Samo osiągnięcie sześciu znaków nie oznacza sukcesu; potwierdzenie pojawia się dopiero po odpowiedzi API.

---

## Phase 1: API Registration Gate And Friendly Errors

### Overview

Dodać serwerową kontrolę kodu beta, polskie błędy rejestracji i centralne wsparcie testów bez wpływu na login oraz pozostałe moduły.

### Changes Required

#### 1. Registration Contract And Gate

**Files**:

- `apps/api/LiftMate.Api/Auth/AuthContracts.cs`
- `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`
- `apps/api/LiftMate.Api/Auth/RegistrationGate.cs` (new)
- `apps/api/LiftMate.Api/Program.cs`
- `apps/api/LiftMate.Api/appsettings.json`

**Intent**: Wymusić wspólny kod beta w zaufanej warstwie API i zamknąć rejestrację przy brakującej konfiguracji bez zatrzymywania całej aplikacji.

**Contract**:

- `RegisterRequest` otrzymuje nullable `RegistrationInviteCode`.
- `RegistrationGate` odczytuje `Auth:RegistrationInviteCode` i rozróżnia: brak konfiguracji, poprawny kod, niepoprawny kod.
- Brak konfiguracji zwraca `503`; brak lub niezgodność kodu zwraca `400`.
- Kod jest porównywany dokładnie i case-sensitive.
- Sprawdzenie gate następuje przed sprawdzeniem zajętości e-maila i przed zapisem użytkownika.
- `appsettings.json` może deklarować pusty niesekretny klucz, ale nie zawiera wartości produkcyjnej.

#### 2. Polish Registration Error Contract

**Files**:

- `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`
- `apps/api/LiftMate.Api/Auth/IdentityErrorTranslator.cs` (new, jeśli wydzielenie poprawia czytelność)

**Intent**: Zwracać spokojne, konkretne komunikaty po polsku bez ujawniania szczegółów frameworka.

**Contract**:

- Wszystkie kontrolowane błędy rejestracji używają pojedynczego pola `error`.
- Zakres obejmuje kod beta, niedostępną rejestrację, rolę, pustą nazwę, zajęty lub niepoprawny e-mail oraz wymagania hasła.
- Błędy Identity są mapowane według kodu; nieznany błąd otrzymuje neutralny komunikat o nieudanej rejestracji.
- Odpowiedzi nie zawierają hasła, kodu beta, kodu Identity, stack trace ani tekstu wyjątku.

#### 3. API Test Foundation And Registration Coverage

**Files**:

- `apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs`
- `apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs`

**Intent**: Pokryć nowy kontrakt i zachować zgodność testów domenowych korzystających ze wspólnego helpera.

**Contract**:

- Fabryka udostępnia stały testowy `Auth:RegistrationInviteCode`.
- `AuthEndpointTests.Register(client, role)` zachowuje obecną sygnaturę i automatycznie wysyła poprawny kod.
- Bezpośrednie testy rejestracji obejmują obie role, brak kodu, błędny kod, różną wielkość liter, brak konfiguracji, duplikat e-maila, rolę, nazwę, e-mail i słabe hasło.
- Test braku konfiguracji potwierdza, że istniejące konto nadal może się zalogować.
- Odrzucona rejestracja nie zapisuje użytkownika.
- Testy asertywnie sprawdzają polskie komunikaty i brak technicznych szczegółów.

### Success Criteria

#### Automated Verification

- Poprawny kod beta tworzy konto trenera i podopiecznego.
- Brak, błędny kod i kod o innej wielkości liter nie tworzą konta.
- Brak konfiguracji zwraca przyjazne `503`, a login istniejącego konta nadal działa.
- Walidacje roli, e-maila, nazwy i hasła zwracają pojedynczy polski `error` bez technicznych kodów.
- Wspólny helper rejestracji utrzymuje pozostałe testy API bez zmian w call sites.
- `dotnet restore LiftMate.slnx` kończy się sukcesem.
- `dotnet build LiftMate.slnx --no-restore` przechodzi.
- `dotnet test LiftMate.slnx --no-build --filter "FullyQualifiedName~AuthEndpointTests"` przechodzi.
- Pełne `dotnet test LiftMate.slnx --no-build` przechodzi.

#### Manual Verification

- Lokalny request z poprawnym kodem tworzy konto, a brakujący lub błędny kod pokazuje czytelny polski komunikat.
- Po usunięciu lokalnego settingu rejestracja jest niedostępna, ale istniejące konto nadal się loguje.

**Implementation Note**: Po przejściu testów API można rozpocząć fazę mobilną. Sekret produkcyjny nie jest jeszcze ustawiany w tej fazie.

---

## Phase 2: Mobile Registration And Form Stability

### Overview

Rozszerzyć mobilny kontrakt rejestracji, naprawić widoczność hasła i ustabilizować obowiązkowe parowanie kodem trenera na telefonowym viewportcie.

### Changes Required

#### 1. Mobile Registration Contract

**Files**:

- `apps/mobile/lib/auth/auth_api_client.dart`
- `apps/mobile/lib/auth/auth_controller.dart`
- `apps/mobile/test/auth_api_client_test.dart`

**Intent**: Przenieść kod beta z formularza do nowego pola requestu bez zapisywania go w stanie sesji lub logach.

**Contract**:

- `register` w kliencie i kontrolerze przyjmuje wymagany `registrationInviteCode`.
- JSON `/auth/register` zawiera `registrationInviteCode` obok istniejących pól.
- Kod nie jest zapisywany w token store, modelu użytkownika ani komunikacie błędu.
- Parser błędów preferuje bezpieczny tekst `error`; nie pokazuje surowego wyjątku ani payloadu requestu.
- Status `503` zachowuje tekst odpowiedzi i może pozostać ogólnym statusem błędu klienta.

#### 2. Signup Field And Password Toggle

**Files**:

- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/test/auth_screen_test.dart`

**Intent**: Dodać kod beta do istniejącego formularza zgodnie z jego stylem i uruchomić prawdziwe pokazywanie/ukrywanie hasła.

**Contract**:

- `_AuthScreenState` posiada osobny kontroler kodu beta, czyszczony i usuwany razem z pozostałym stanem formularza.
- Signup pokazuje pole `Kod beta` po polu hasła; nie powstaje osobny ekran `Kod dostępu`.
- Puste pole zatrzymuje submit lokalnym polskim komunikatem.
- Kod jest wysyłany dokładnie tak, jak wpisano; bez trim i zmiany wielkości liter.
- Login i signup mają niezależny stan widoczności hasła.
- Akcja suffix przełącza `obscureText` i etykietę `Pokaż` / `Ukryj` bez utraty wartości oraz pozycji formularza.
- Układ pozostaje scrollowalny i czytelny przy otwartej klawiaturze.

#### 3. Friendly Mobile Error Presentation

**Files**:

- `apps/mobile/lib/auth/auth_api_client.dart`
- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/test/auth_api_client_test.dart`
- `apps/mobile/test/auth_screen_test.dart`

**Intent**: Pokazywać komunikaty użytkowe, a awarie transportu lub nieoczekiwane odpowiedzi sprowadzać do neutralnego tekstu.

**Contract**:

- Znane polskie `error` z API są pokazywane bez zmian.
- Timeout i offline mają krótki komunikat po polsku z sugestią ponowienia.
- Niepoprawny JSON, `error.toString()` i techniczne statusy HTTP nie są wyświetlane użytkownikowi wprost.
- Hasło, kod beta i kod trenera nie pojawiają się w komunikatach.
- Angielskie błędy `/trainee/trainer-link` są mapowane lokalnie w onboardingowym `AuthScreen` na spokojne polskie komunikaty według statusu odpowiedzi. Wspólny `AuthApiClient`, `AuthController.claimTrainerInviteCode` i post-auth relationship flow zachowują obecny kontrakt.

#### 4. Trainer Code Paste And Mandatory Onboarding Step

**Files**:

- `apps/mobile/lib/auth/auth_screen.dart`
- `apps/mobile/lib/auth/onboarding_state_store.dart` (new)
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/auth/auth_api_client.dart`
- `apps/mobile/test/auth_screen_test.dart`
- `apps/mobile/test/auth_api_client_test.dart`
- `apps/mobile/test/onboarding_state_store_test.dart`

**Intent**: Sprawić, by wklejony kod był zgodny z sześciopolowym widokiem i by podopieczny nie kończył bieżącego onboardingu bez potwierdzonego połączenia.

**Contract**:

- Input przyjmuje maksymalnie sześć liter ASCII lub cyfr; wyświetla uppercase.
- Klient nadal normalizuje kod przez trim + uppercase przed `/trainee/trainer-link`.
- Przycisk połączenia jest aktywny dopiero dla sześciu znaków i odporny na podwójny submit.
- Nie ma komunikatu `Znaleziono kod trenera` przed odpowiedzią API.
- Lokalny `OnboardingStateStore`, oparty o używane już bezpieczne storage, przechowuje wyłącznie identyfikator podopiecznego z niedokończonym onboardingiem; nie zapisuje kodu beta ani kodu trenera.
- `AuthScreen` otrzymuje store przez konstruktor, a `main.dart` przekazuje implementację opartą o bezpieczne storage; widget testy używają implementacji in-memory.
- Po udanej rejestracji podopiecznego ekran zapisuje znacznik przed przejściem do parowania. Inicjalizacja ekranu czeka na odczyt znacznika przed pokazaniem authenticated shell i odtwarza parowanie, jeśli identyfikator zalogowanego użytkownika odpowiada znacznikowi.
- Sukces API usuwa `_pendingPairRole` i lokalny znacznik, po czym otwiera aplikację; błąd pozostawia oba stany bez zmian i pokazuje lokalnie zmapowany polski komunikat.
- Przycisk wstecz podopiecznego nie kończy parowania ani nie otwiera pulpitu.
- Wylogowanie nie usuwa znacznika niedokończonego onboardingu; ponowne zalogowanie tego samego podopiecznego wraca do parowania.
- Przepływ trenera, który po rejestracji otrzymuje własny kod i przechodzi do pulpitu, pozostaje bez zmian.
- Testy pokrywają wklejenie pełnego kodu oraz nadmiarowych/niedozwolonych znaków na małym viewportcie bez overflow.
- `_register()` posiada jawny single-flight guard ustawiany przed pierwszym `await` i czyszczony w `finally`; opóźniony test HTTP potwierdza, że dwa szybkie tapnięcia wysyłają jeden request.

### Success Criteria

#### Automated Verification

- Klient wysyła kod beta w pełnym payloadzie rejestracji dla obu ról.
- Formularz blokuje pusty kod beta i pokazuje polski komunikat.
- Kod beta zachowuje wielkość liter i spacje zgodnie z dokładnym kontraktem.
- `Pokaż` i `Ukryj` działają osobno dla loginu oraz signup.
- Znane błędy rejestracji i parowania w onboardingu są czytelne po polsku, a błędy techniczne są zastąpione neutralnym tekstem.
- Kod trenera jest ograniczony do sześciu dozwolonych znaków i payload odpowiada widocznym polom.
- Podopieczny nie może opuścić bieżącego onboardingu przed sukcesem parowania, również po restarcie lub ponownym logowaniu.
- Jawne single-flight guardy sprawiają, że podwójne tapnięcie nie wysyła dwóch rejestracji ani dwóch requestów parowania.
- Widget test na małym viewportcie nie raportuje overflow po wklejeniu kodu i otwarciu klawiatury.
- `flutter test --reporter compact test/auth_api_client_test.dart test/auth_screen_test.dart test/onboarding_state_store_test.dart` przechodzi.
- Pełne `flutter test --reporter compact` przechodzi.
- `flutter analyze` przechodzi.

#### Manual Verification

- Na telefonie pole kodu beta pasuje do formularza i pozostaje widoczne po otwarciu klawiatury.
- `Pokaż` / `Ukryj` działa w loginie i rejestracji bez przesuwania lub czyszczenia formularza.
- Wklejenie poprawnego kodu trenera nie tworzy paska, pikselizacji ani overflow.
- Błędny kod trenera pozostawia podopiecznego na ekranie parowania z czytelnym komunikatem.
- Poprawny kod trenera kończy onboarding i otwiera właściwy ekran podopiecznego.

**Implementation Note**: Mobilka nie powinna zostać przekazana testerom przed wdrożeniem kompatybilnego backendu i ustawieniem sekretu z fazy 3.

---

## Phase 3: Deployment Configuration And End-To-End Verification

### Overview

Skonfigurować produkcyjny sekret poza repozytorium, wdrożyć backend przed aplikacją mobilną i potwierdzić cały przepływ beta bez regresji istniejących kont.

### Changes Required

#### 1. Operational Configuration

**Files**:

- Azure App Service application settings (external state)
- `context/changes/beta-registration-guard/plan.md` (progress only during implementation)

**Intent**: Dostarczyć wartość `Auth__RegistrationInviteCode` bez umieszczania sekretu w repozytorium lub workflow.

**Contract**:

- Człowiek zatwierdza i ustawia wspólny kod w konfiguracji właściwego App Service.
- Wartość nie trafia do `.github/workflows`, `appsettings*.json`, logów, dokumentacji ani historii Git.
- Zmiana settingu jest wykonana przed wdrożeniem backendu lub w tym samym kontrolowanym oknie.
- Rollback aplikacji nie usuwa settingu automatycznie; usunięcie settingu przy nowym backendzie celowo zamyka rejestrację.

#### 2. Backend-First Deployment And Smoke Verification

**Files**:

- `.github/workflows/deploy-api-azure.yml` (bez zmiany, chyba że implementacja ujawni potrzebę niesekretnej walidacji)
- deployed API and mobile build

**Intent**: Potwierdzić kompatybilność wdrożonego kontraktu przed udostępnieniem mobilki.

**Contract**:

- API jest wdrażane przed buildem mobilnym wymagającym `registrationInviteCode`.
- Smoke test obejmuje poprawny, błędny i brakujący kod beta dla obu ról.
- Istniejące konto loguje się bez kodu beta.
- Nowy podopieczny przechodzi obowiązkowe parowanie osobnym kodem trenera.
- Testy i wyniki nie wypisują wartości sekretu.

#### 3. Final Regression And Bookkeeping

**Files**:

- `context/changes/beta-registration-guard/change.md`
- `context/foundation/roadmap.md`
- `context/changes/beta-registration-guard/plan.md`

**Intent**: Zamknąć S-07 dopiero po automatycznej i ręcznej akceptacji.

**Contract**:

- Pełne testy API, Flutter i analiza przechodzą na finalnym kodzie.
- Przed ręcznym QA `change.md` pozostaje w stanie implementacji, roadmapa S-07 nie jest `done`, a manualne pozycje Progress są niezaznaczone.
- Po jawnym potwierdzeniu ręcznego QA można ustawić `change.md` na `implemented`, roadmapę S-07 na `done` i zaznaczyć odpowiednie manualne pozycje.
- Archiwizacja pozostaje osobnym `/10x-archive beta-registration-guard`.

### Success Criteria

#### Automated Verification

- `dotnet restore LiftMate.slnx` kończy się sukcesem.
- `dotnet build LiftMate.slnx --no-restore` przechodzi.
- Pełne `dotnet test LiftMate.slnx --no-build --verbosity minimal` przechodzi.
- Pełne `flutter test --reporter compact` przechodzi.
- `flutter analyze` przechodzi.
- Skan śledzonych plików nie znajduje niepustej, zahardkodowanej wartości `RegistrationInviteCode`, a secret scanner nie raportuje nowego sekretu; kontrola nie używa produkcyjnej wartości kodu jako wzorca.
- Roadmapa S-07 pozostaje niedomknięta przed ręcznym potwierdzeniem.

#### Manual Verification

- Wdrożone API odrzuca brakujący, błędny i różniący się wielkością liter kod beta przyjaznym komunikatem.
- Wdrożone API tworzy konto trenera i podopiecznego z poprawnym kodem beta.
- Istniejący trener i podopieczny nadal logują się bez kodu beta.
- Nowy podopieczny nie kończy onboardingu bez poprawnego kodu trenera.
- Rejestracja, toggle hasła i wklejenie kodu trenera są czytelne na obsługiwanym telefonie.
- Po wszystkich kontrolach użytkownik zatwierdza zamknięcie S-07.

---

## Testing Strategy

### API Unit And Integration Tests

- Trzy wyniki gate: configured-valid, configured-invalid i configuration-missing.
- Dokładne porównanie kodu, w tym różna wielkość liter i spacje.
- Brak enumeracji e-maila bez poprawnego kodu.
- Brak zapisu użytkownika dla każdego odrzuconego requestu.
- Przyjazne mapowanie wszystkich obecnych kodów Identity używanych przez konfigurację projektu.
- Nieznany błąd Identity otrzymuje neutralny fallback.
- Nieprzerwany login, refresh, logout i `/auth/me`.
- Kompatybilność wszystkich testów korzystających z centralnego helpera `Register`.

### Flutter Unit And Widget Tests

- Pełny JSON rejestracji dla trenera i podopiecznego.
- Brak wycieku hasła oraz obu kodów w błędach.
- Lokalne wymaganie kodu beta.
- Toggle hasła w obu formularzach i ponowne ukrycie wartości.
- Mapowanie polskich błędów API oraz neutralnych błędów transportowych.
- Lokalne mapowanie angielskich błędów kodu trenera wyłącznie w onboardingowym ekranie.
- Sześci znakowy input kodu trenera, filtrowanie i normalizacja.
- Brak fałszywego sukcesu przed odpowiedzią API.
- Odporność na podwójny submit przez guard ustawiany przed pierwszym `await`.
- Trwały lokalny znacznik obowiązkowego parowania, odtwarzany po restarcie i ponownym logowaniu oraz czyszczony dopiero po sukcesie.
- Brak overflow na małym viewportcie i przy otwartej klawiaturze.

### Manual Testing Steps

1. Otwórz signup trenera i sprawdź pole `Kod beta`, walidację oraz toggle hasła.
2. Wyślij brakujący, błędny, różniący się wielkością liter i poprawny kod beta.
3. Powtórz rejestrację dla roli podopiecznego.
4. Wklej kod trenera zawierający małe litery i skrajne spacje; potwierdź poprawne połączenie.
5. Wklej więcej niż sześć znaków i znaki niedozwolone; potwierdź stabilny widok i zgodny payload.
6. Spróbuj cofnąć się lub wielokrotnie nacisnąć CTA przed poprawnym parowaniem.
7. Zaloguj istniejące konta obu ról bez kodu beta.
8. Usuń setting w kontrolowanym środowisku i potwierdź, że tylko rejestracja staje się niedostępna.

## Performance Considerations

- Gate wykonuje jedno odczytanie konfiguracji i porównanie stringów przed dostępem do bazy.
- Brak nowych tabel, migracji, zewnętrznych usług i wywołań sieciowych.
- Rejestracja nie jest automatycznie ponawiana, co ogranicza ryzyko podwójnego tworzenia kont.
- Mobilne formatters działają lokalnie i nie zmieniają liczby requestów.

## Migration Notes

- Brak migracji bazy danych.
- Backend jest wdrażany przed aplikacją mobilną.
- Wartość `Auth__RegistrationInviteCode` jest ustawiana ręcznie w App Service Configuration.
- Wycofanie backendu do poprzedniej wersji ponownie otworzy endpoint rejestracji; rollback musi więc uwzględniać ryzyko bezpieczeństwa.
- Pozostawienie nowego backendu bez settingu zamyka rejestrację, ale nie wpływa na istniejące konta.
- Stare buildy mobilne bez pola kodu otrzymają przyjazne odrzucenie rejestracji; login pozostanie kompatybilny.
- Lokalny znacznik niedokończonego onboardingu chroni oficjalny przepływ po restarcie i ponownym logowaniu, ale nie jest serwerową blokadą po reinstalacji aplikacji ani dla klientów wywołujących API bezpośrednio.

## References

- Change identity: `context/changes/beta-registration-guard/change.md`
- Research: `context/changes/beta-registration-guard/research.md`
- Roadmap S-07: `context/foundation/roadmap.md`
- Expansion PRD US-04: `context/foundation/prd-expansion.md`
- Expansion shaping decisions: `context/foundation/shape-notes-expansion.md`
- Mobile design contract: `apps/mobile/design/LiftMate.dc.html`
- Current API auth contract: `apps/api/LiftMate.Api/Auth/AuthContracts.cs`
- Current API registration: `apps/api/LiftMate.Api/Auth/AuthEndpoints.cs`
- Current API fixtures: `apps/api/LiftMate.Api.Tests/TestApplicationFactory.cs`
- Current auth integration tests: `apps/api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs`
- Current mobile auth screen: `apps/mobile/lib/auth/auth_screen.dart`
- Current mobile auth client: `apps/mobile/lib/auth/auth_api_client.dart`
- Current mobile auth tests: `apps/mobile/test/auth_screen_test.dart`, `apps/mobile/test/auth_api_client_test.dart`
- Deployment workflow: `.github/workflows/deploy-api-azure.yml`
- Secret policy: `context/foundation/infrastructure.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: API Registration Gate And Friendly Errors

#### Automated

- [x] 1.1 Poprawny kod beta tworzy konto trenera i podopiecznego.
- [x] 1.2 Brak, błędny kod i kod o innej wielkości liter nie tworzą konta.
- [x] 1.3 Brak konfiguracji zwraca przyjazne `503`, a login istniejącego konta nadal działa.
- [x] 1.4 Walidacje roli, e-maila, nazwy i hasła zwracają pojedynczy polski `error` bez technicznych kodów.
- [x] 1.5 Wspólny helper rejestracji utrzymuje pozostałe testy API bez zmian w call sites.
- [x] 1.6 `dotnet restore LiftMate.slnx` kończy się sukcesem.
- [x] 1.7 `dotnet build LiftMate.slnx --no-restore` przechodzi.
- [x] 1.8 `dotnet test LiftMate.slnx --no-build --filter "FullyQualifiedName~AuthEndpointTests"` przechodzi.
- [x] 1.9 Pełne `dotnet test LiftMate.slnx --no-build` przechodzi.

#### Manual

- [ ] 1.10 Lokalny request z poprawnym kodem tworzy konto, a brakujący lub błędny kod pokazuje czytelny polski komunikat.
- [ ] 1.11 Po usunięciu lokalnego settingu rejestracja jest niedostępna, ale istniejące konto nadal się loguje.

### Phase 2: Mobile Registration And Form Stability

#### Automated

- [ ] 2.1 Klient wysyła kod beta w pełnym payloadzie rejestracji dla obu ról.
- [ ] 2.2 Formularz blokuje pusty kod beta i pokazuje polski komunikat.
- [ ] 2.3 Kod beta zachowuje wielkość liter i spacje zgodnie z dokładnym kontraktem.
- [ ] 2.4 `Pokaż` i `Ukryj` działają osobno dla loginu oraz signup.
- [ ] 2.5 Znane błędy rejestracji i parowania w onboardingu są czytelne po polsku, a błędy techniczne są zastąpione neutralnym tekstem.
- [ ] 2.6 Kod trenera jest ograniczony do sześciu dozwolonych znaków i payload odpowiada widocznym polom.
- [ ] 2.7 Podopieczny nie może opuścić bieżącego onboardingu przed sukcesem parowania, również po restarcie lub ponownym logowaniu.
- [ ] 2.8 Jawne single-flight guardy sprawiają, że podwójne tapnięcie nie wysyła dwóch rejestracji ani dwóch requestów parowania.
- [ ] 2.9 Widget test na małym viewportcie nie raportuje overflow po wklejeniu kodu i otwarciu klawiatury.
- [ ] 2.10 `flutter test --reporter compact test/auth_api_client_test.dart test/auth_screen_test.dart test/onboarding_state_store_test.dart` przechodzi.
- [ ] 2.11 Pełne `flutter test --reporter compact` przechodzi.
- [ ] 2.12 `flutter analyze` przechodzi.

#### Manual

- [ ] 2.13 Na telefonie pole kodu beta pasuje do formularza i pozostaje widoczne po otwarciu klawiatury.
- [ ] 2.14 `Pokaż` / `Ukryj` działa w loginie i rejestracji bez przesuwania lub czyszczenia formularza.
- [ ] 2.15 Wklejenie poprawnego kodu trenera nie tworzy paska, pikselizacji ani overflow.
- [ ] 2.16 Błędny kod trenera pozostawia podopiecznego na ekranie parowania z czytelnym komunikatem.
- [ ] 2.17 Poprawny kod trenera kończy onboarding i otwiera właściwy ekran podopiecznego.

### Phase 3: Deployment Configuration And End-To-End Verification

#### Automated

- [ ] 3.1 `dotnet restore LiftMate.slnx` kończy się sukcesem.
- [ ] 3.2 `dotnet build LiftMate.slnx --no-restore` przechodzi.
- [ ] 3.3 Pełne `dotnet test LiftMate.slnx --no-build --verbosity minimal` przechodzi.
- [ ] 3.4 Pełne `flutter test --reporter compact` przechodzi.
- [ ] 3.5 `flutter analyze` przechodzi.
- [ ] 3.6 Skan śledzonych plików nie znajduje niepustej, zahardkodowanej wartości `RegistrationInviteCode`, a secret scanner nie raportuje nowego sekretu; kontrola nie używa produkcyjnej wartości kodu jako wzorca.
- [ ] 3.7 Roadmapa S-07 pozostaje niedomknięta przed ręcznym potwierdzeniem.

#### Manual

- [ ] 3.8 Wdrożone API odrzuca brakujący, błędny i różniący się wielkością liter kod beta przyjaznym komunikatem.
- [ ] 3.9 Wdrożone API tworzy konto trenera i podopiecznego z poprawnym kodem beta.
- [ ] 3.10 Istniejący trener i podopieczny nadal logują się bez kodu beta.
- [ ] 3.11 Nowy podopieczny nie kończy onboardingu bez poprawnego kodu trenera.
- [ ] 3.12 Rejestracja, toggle hasła i wklejenie kodu trenera są czytelne na obsługiwanym telefonie.
- [ ] 3.13 Po wszystkich kontrolach użytkownik zatwierdza zamknięcie S-07.
