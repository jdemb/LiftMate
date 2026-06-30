# Warstwa prezentacji funkcji LiftMate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Utworzyć prezentacyjny katalog funkcji LiftMate oraz techniczną mapę dowodów, z pełnym pokryciem ekranów designu i relacją wiele-do-wielu między ekranami a funkcjami.

**Architecture:** Najpierw powstaje zweryfikowana mapa implementacji oparta na obu plikach HTML, kodzie Fluttera, API i testach. Dokument prezentacyjny jest następnie redagowany na podstawie potwierdzonych wpisów mapy, dzięki czemu atrakcyjny język nie rozszerza faktycznego zakresu produktu.

**Tech Stack:** Markdown, Flutter/Dart, ASP.NET Core/C#, ripgrep, Git.

---

## Struktura plików

- Create: `apps/mobile/design/mapa-implementacji.md` — techniczne źródło prawdy dla funkcji, ekranów i dowodów.
- Create: `apps/mobile/design/prezentacja-funkcji.md` — krótka, egzaminacyjna prezentacja wartości produktu.
- Reference: `apps/mobile/design/LiftMate.dc.html` — źródłowy indeks 17 ekranów i identyfikatorów.
- Reference: `apps/mobile/design/LiftMate.html` — kontrola zgodności drugiego artefaktu designu.
- Reference: `apps/mobile/lib/` i `apps/mobile/test/` — implementacja oraz dowody mobilne.
- Reference: `apps/api/LiftMate.Api/` i `apps/api/LiftMate.Api.Tests/` — implementacja oraz dowody serwerowe.
- Reference: `context/foundation/prd.md` i `context/foundation/roadmap.md` — wymagania oraz ukończone zakresy produktu.

### Task 1: Zbudowanie kompletnego inwentarza ekranów i funkcji

**Files:**
- Inspect: `apps/mobile/design/LiftMate.dc.html:988`
- Inspect: `apps/mobile/design/LiftMate.dc.html:1149`
- Inspect: `apps/mobile/design/LiftMate.html`
- Inspect: `apps/mobile/lib/`
- Inspect: `apps/api/LiftMate.Api/`

- [ ] **Step 1: Wyodrębnij kanoniczną listę ekranów**

Run:

```powershell
rg -n "navGroups|mk\('" apps/mobile/design/LiftMate.dc.html
```

Expected: 17 identyfikatorów w trzech grupach: `welcome`, `role`, `signup`, `pair`, `t_dash`, `t_trainee`, `t_sets`, `t_builder`, `t_addex`, `t_assign`, `t_live`, `c_home`, `c_live`, `feedback`, `c_history`, `c_session`, `c_exprogress`.

- [ ] **Step 2: Potwierdź zgodność listy z artefaktem zbiorczym**

Run:

```powershell
rg -o "mk\('[^']+', '[^']+'" apps/mobile/design/LiftMate.dc.html apps/mobile/design/LiftMate.html
```

Expected: oba pliki zawierają ten sam zestaw 17 par etykieta–identyfikator. Każdą różnicę zapisz później w sekcji „Rozbieżności” mapy technicznej.

- [ ] **Step 3: Zidentyfikuj klasy ekranów, kontrolerów i klientów API Fluttera**

Run:

```powershell
rg -n "^class .*?(Screen|View|Shell|Controller|ApiClient)" apps/mobile/lib
```

Expected: wyniki co najmniej z modułów `auth`, `relationships`, `workout_sets`, `shared_sessions`, `post_workout_feedback`, `training_history` i `trainer_guidance`.

- [ ] **Step 4: Zidentyfikuj endpointy i serwisy API**

Run:

```powershell
rg -n "Map(Get|Post|Put|Patch|Delete)|MapHub|class .*?(Service|Evaluator|Projector)" apps/api/LiftMate.Api
```

Expected: dowody dla rejestracji i parowania, zestawów, wspólnych sesji, feedbacku, historii, progresu, podpowiedzi i tygodniowej serii.

- [ ] **Step 5: Zbuduj roboczą macierz wiele-do-wielu**

Macierz musi uwzględnić co najmniej następujące potwierdzane obszary:

```text
Onboarding: powitanie, wybór roli, rejestracja i logowanie, bezpieczne odświeżanie sesji
Relacja: kod zaproszenia, kopiowanie kodu, parowanie, rozłączanie, dostęp zależny od roli
Pulpit trenera: lista podopiecznych, stan przypisania, ostatnia aktywność, tygodniowa seria
Szczegóły podopiecznego: przypisany plan, rozpoczęcie sesji, historia, feedback, podpowiedzi trenerskie
Zestawy: lista, tworzenie, usuwanie, odpoczynek, typy ćwiczeń, przypisanie wielu osobom
Trening: start, wspólna sesja, synchronizacja realtime, edycja serii, licznik odpoczynku, ponowne połączenie, zakończenie
Podopieczny: plan na dziś, samodzielny trening, widok treningu prowadzonego, wartości zapisane na kolejną sesję
Feedback: ocena 1–5, komentarz, pominięcie, późniejszy odczyt
Historia i progres: lista sesji, szczegóły, serie i wartości, progres ćwiczenia, regularność
```

Każdy ekran musi wskazywać co najmniej jedną funkcję, ale liczba funkcji przypisanych ekranowi nie ma górnego limitu.

### Task 2: Utworzenie technicznej mapy implementacji

**Files:**
- Create: `apps/mobile/design/mapa-implementacji.md`
- Inspect: `apps/mobile/lib/**/*.dart`
- Inspect: `apps/mobile/test/**/*_test.dart`
- Inspect: `apps/api/LiftMate.Api/**/*.cs`
- Inspect: `apps/api/LiftMate.Api.Tests/**/*.cs`

- [ ] **Step 1: Utwórz nagłówek i legendę mapy**

Użyj dokładnej struktury:

```markdown
# Mapa implementacji funkcji LiftMate

Dokument łączy funkcje prezentowane w aplikacji z ekranami designu i dowodami w repozytorium. Relacja jest wiele-do-wielu: jeden ekran może prezentować kilka funkcji, a jedna funkcja może obejmować kilka ekranów.

## Legenda

- **Ekrany:** nazwa oraz identyfikator z `LiftMate.dc.html`.
- **Mobile:** ekran, widget, kontroler albo klient API Fluttera.
- **API:** endpoint, serwis lub model domenowy; `nie dotyczy`, gdy funkcja jest wyłącznie lokalna.
- **Testy:** testy automatyczne potwierdzające zachowanie.
- **Wymagania:** identyfikatory PRD lub roadmapy, jeśli istnieją.

## Rozbieżności

Brak — oba artefakty designu i implementacja prezentują ten sam katalog ekranów.
```

Jeżeli Task 1 wykryje różnicę, zastąp zdanie „Brak” konkretnym opisem bez deklarowania niepotwierdzonej funkcji.

- [ ] **Step 2: Dodaj wpis dla każdej potwierdzonej funkcji**

Każdy wpis ma format:

```markdown
### [Atrakcyjny, jednoznaczny tytuł funkcji]

- **Ekrany:** `[etykieta]` (`[id]`), `[etykieta]` (`[id]`)
- **Mobile:** [`NazwaKlasy`](../lib/sciezka/do/pliku.dart)
- **API:** [`NazwaEndpointuLubSerwisu`](../../api/LiftMate.Api/sciezka/do/pliku.cs) albo `nie dotyczy`
- **Testy:** [`nazwa_testu.dart`](../test/nazwa_testu.dart), [`NazwaTests.cs`](../../api/LiftMate.Api.Tests/sciezka/NazwaTests.cs)
- **Wymagania:** `FR-...`, `US-...`, `S-...`
```

Ścieżki są względne względem `apps/mobile/design/`. Nie wpisuj nazwy klasy, endpointu ani testu bez otwarcia wskazanego pliku i potwierdzenia symbolu.

- [ ] **Step 3: Dodaj indeks pokrycia ekranów**

Użyj tabeli:

```markdown
## Indeks ekranów

| Grupa | Ekran | ID | Prezentowane funkcje |
|---|---|---|---|
| Onboarding | Powitanie | `welcome` | [tytuły funkcji jako kotwice] |
```

Tabela ma mieć dokładnie 17 wierszy danych i może wskazywać wiele funkcji w ostatniej kolumnie.

- [ ] **Step 4: Sprawdź wszystkie linkowane pliki**

Run:

```powershell
$doc = Get-Content -Raw apps/mobile/design/mapa-implementacji.md
$links = [regex]::Matches($doc, '\]\(([^)#]+)(?:#[^)]+)?\)')
$base = Resolve-Path apps/mobile/design
$missing = foreach ($link in $links) {
  $path = Join-Path $base $link.Groups[1].Value
  if (-not (Test-Path $path)) { $link.Groups[1].Value }
}
$missing
```

Expected: brak wyniku.

### Task 3: Utworzenie dokumentu prezentacyjnego

**Files:**
- Create: `apps/mobile/design/prezentacja-funkcji.md`
- Reference: `apps/mobile/design/mapa-implementacji.md`

- [ ] **Step 1: Utwórz otwarcie dokumentu i wyróżniki**

Użyj struktury:

```markdown
# LiftMate — najważniejsze funkcje

LiftMate prowadzi podopiecznego przez trening, zachowuje ciągłość progresu i daje trenerowi kontrolę nad planem oraz wspólną sesją. Poniższe funkcje zostały pogrupowane według rzeczywistych ścieżek użytkownika.

## Co wyróżnia LiftMate
```

Na początku wyróżnij 3–5 najmocniejszych, potwierdzonych funkcji: wspólną sesję realtime, prowadzenie wielu podopiecznych, planowanie i przypisywanie zestawów, historię progresu oraz feedback/podpowiedzi.

- [ ] **Step 2: Opisz funkcje według ścieżek użytkownika**

Zastosuj sekcje w tej kolejności:

```markdown
## Łatwy start i bezpieczne konto
## Centrum pracy trenera
## Plan dopasowany do podopiecznego
## Wspólny trening na żywo
## Feedback, historia i mierzalny progres
```

Każdy wpis ma format:

```markdown
### [Tytuł funkcjonalności]

**Ekrany:** [jedna lub kilka nazw]

[Maksymalnie trzy krótkie zdania opisujące działanie, wartość dla użytkownika i — jeśli istotne — przewagę rozwiązania. Bez nazw plików, klas, endpointów i testów.]
```

Nie łącz funkcji tylko dlatego, że występują na tym samym ekranie. Nie rozdzielaj funkcji obejmującej spójny przepływ tylko dlatego, że przechodzi przez kilka ekranów.

- [ ] **Step 3: Dodaj pełny indeks ekranów**

Na końcu dodaj:

```markdown
## Indeks ekranów

| Grupa | Ekran | Powiązane funkcje |
|---|---|---|
| Onboarding | Powitanie | [tytuły funkcji jako kotwice] |
```

Tabela ma mieć dokładnie 17 wierszy danych i odsyłać do wszystkich funkcji przypisanych danemu ekranowi.

- [ ] **Step 4: Skontroluj limit długości i styl**

Przeczytaj każdy opis pod kątem następujących reguł:

```text
maksymalnie 3 zdania na funkcję
język korzyści zamiast listy kontrolek
brak twierdzeń nieobecnych w mapie implementacji
brak żargonu technicznego
brak powtarzania tego samego opisu pod różnymi ekranami
```

### Task 4: Weryfikacja kompletności obu dokumentów

**Files:**
- Verify: `apps/mobile/design/mapa-implementacji.md`
- Verify: `apps/mobile/design/prezentacja-funkcji.md`
- Verify: `docs/superpowers/specs/2026-06-30-warstwa-prezentacji-funkcji-design.md`

- [ ] **Step 1: Sprawdź obecność wszystkich identyfikatorów ekranów**

Run:

```powershell
$ids = 'welcome','role','signup','pair','t_dash','t_trainee','t_sets','t_builder','t_addex','t_assign','t_live','c_home','c_live','feedback','c_history','c_session','c_exprogress'
foreach ($file in 'apps/mobile/design/mapa-implementacji.md','apps/mobile/design/prezentacja-funkcji.md') {
  $text = Get-Content -Raw $file
  $missing = $ids | Where-Object { $text -notmatch [regex]::Escape($_) }
  if ($missing) { "$file MISSING: $($missing -join ', ')" } else { "$file OK: 17/17" }
}
```

Expected:

```text
apps/mobile/design/mapa-implementacji.md OK: 17/17
apps/mobile/design/prezentacja-funkcji.md OK: 17/17
```

- [ ] **Step 2: Sprawdź brak placeholderów i jakość Markdown**

Run:

```powershell
rg -n "TBD|TODO|uzupełnić|placeholder|brak danych" apps/mobile/design/mapa-implementacji.md apps/mobile/design/prezentacja-funkcji.md
git diff --check
```

Expected: `rg` bez wyniku; `git diff --check` bez błędów.

- [ ] **Step 3: Porównaj dokumenty ze specyfikacją**

Potwierdź kolejno:

```text
dwa osobne dokumenty istnieją w apps/mobile/design/
prezentacja nie zawiera szczegółów technicznych
mapa zawiera względne linki do kodu i testów
relacja ekran–funkcja jest wiele-do-wielu
każdy ekran znajduje się w obu indeksach
rozbieżności są jawne albo sekcja potwierdza ich brak
```

- [ ] **Step 4: Sprawdź stan repozytorium**

Run:

```powershell
git status --short
git diff -- apps/mobile/design/mapa-implementacji.md apps/mobile/design/prezentacja-funkcji.md
```

Expected: tylko dwa planowane dokumenty są nowe; diff nie zawiera zmian w plikach HTML ani kodzie aplikacji.

### Task 5: Zapisanie dokumentacji w historii Git

**Files:**
- Add: `apps/mobile/design/mapa-implementacji.md`
- Add: `apps/mobile/design/prezentacja-funkcji.md`

- [ ] **Step 1: Dodaj oba dokumenty do indeksu**

Run:

```powershell
git add apps/mobile/design/mapa-implementacji.md apps/mobile/design/prezentacja-funkcji.md
```

Expected: oba pliki są oznaczone jako `A` w `git status --short`.

- [ ] **Step 2: Utwórz commit bez dodatkowych autorów**

Run:

```powershell
git commit -m "docs: opisz funkcje LiftMate"
```

Expected: commit obejmuje dokładnie dwa nowe dokumenty i nie zawiera stopki `Co-authored-by`.
