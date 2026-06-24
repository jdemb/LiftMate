# Kopiowanie kodu trenera — Plan Brief

> Full plan: `context/changes/copy-trainer-invite-code/plan.md`

## What & Why

Trener ma móc skopiować aktualny kod zaproszenia zarówno bezpośrednio po rejestracji, jak i później na pulpicie. Obecnie kod jest poprawnie generowany i wyświetlany, ale element porejestracyjny jest tylko dekoracją, a pulpit nie ma akcji kopiowania.

## Starting Point

Backend już dostarcza jeden stabilny, sześcioznakowy kod. Flutter pokazuje go na dwóch istniejących powierzchniach, lecz żadna nie używa systemowego schowka ani nie potwierdza operacji.

## Desired End State

Oba ekrany mają jawny przycisk `Kopiuj kod`. Naciśnięcie kopiuje dokładnie widoczny kod i w czasie krótszym niż sekunda pokazuje `Kod zaproszenia skopiowany.`. Bez dostępnego kodu akcja pozostaje nieaktywna, a awaria schowka nie daje fałszywego sukcesu.

## Key Decisions Made

| Decision | Choice | Why |
| --- | --- | --- |
| Powierzchnie | Ekran porejestracyjny i pulpit | Zapewnia spójne zachowanie w obu miejscach prezentujących kod. |
| Kontrolka | Jawny przycisk `Kopiuj kod` | Jest łatwy do odkrycia i zgodny z designem. |
| Potwierdzenie | `SnackBar` `Kod zaproszenia skopiowany.` | Natychmiastowy, polski i nieblokujący wzorzec już istnieje w aplikacji. |
| Brak kodu | Widoczny przycisk nieaktywny | Zapobiega kopiowaniu placeholdera bez przesuwania układu. |
| Wartość | Bez normalizacji | Do schowka trafia dokładnie aktualny kod otrzymany z API. |
| Backend | Bez zmian | Problem leży wyłącznie w mobilnej obsłudze akcji. |

## Scope

**In scope:**

- Systemowy schowek Fluttera na obu powierzchniach.
- Polski `SnackBar` sukcesu i błędu.
- Nieaktywna akcja podczas ładowania lub bez kodu.
- Dostępna etykieta/tooltip przycisku.
- Testy dokładnej wartości schowka, stanów i układu 412 px.
- Pełne `flutter test` i `flutter analyze`.

**Out of scope:**

- API, baza, migracje i format kodu.
- Regeneracja, rotacja lub wygaszanie kodu.
- Share sheet, SMS, e-mail, QR i deep link.
- Zmiany przepływu parowania lub kodu beta.
- Implementacja CTA `Zaproś podopiecznego`.

## Architecture / Approach

`_AuthScreenState` obsłuży schowek i komunikaty na ekranie porejestracyjnym, a `_AuthenticatedRelationshipShellState` zrobi to samo dla pulpitu. Oba przekażą opcjonalne callbacki do istniejących kart kodu. Karty pozostają prezentacyjne i wyłączają przycisk, gdy nie mają rzeczywistego kodu.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Ekran porejestracyjny | Działający obecny przycisk, schowek, komunikaty i testy. | Zachowanie wyglądu designu oraz brak fałszywego sukcesu. |
| 2. Pulpit i regresja | Stała akcja w karcie kodu oraz pełna weryfikacja mobilna. | Czytelny układ kodu i przycisku na 412 px. |

**Prerequisites:** istniejące S-01 i aktualny kontrakt kodu trenera.

**Estimated effort:** mała zmiana mobilna, około 1–2 sesji implementacyjnych w dwóch fazach.

## Open Risks & Assumptions

- Backend nadal zwraca sześci znakowy, niepusty kod; UI mimo to zabezpiecza pustą wartość.
- Systemowy schowek może wyjątkowo zgłosić błąd, dlatego sukces jest pokazywany dopiero po zakończeniu operacji.
- Odświeżanie pulpitu zachowuje poprzedni kod; widoczny kod pozostaje wtedy możliwy do skopiowania.
- Nie dodajemy wspólnej abstrakcji schowka, ponieważ dwie małe integracje nie uzasadniają nowej warstwy.

## Success Criteria (Summary)

- Oba przyciski kopiują dokładnie aktualny kod i natychmiast pokazują polskie potwierdzenie.
- Placeholder ani pusta wartość nigdy nie trafiają do schowka.
- Testy obu przepływów, pełny zestaw Fluttera i analiza statyczna przechodzą bez overflow na 412 px.
