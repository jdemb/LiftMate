# Korekty czasu sesji i historii treningów

## Zakres

Zmiana obejmuje pięć niewielkich korekt istniejącego przepływu sesji i historii:

1. Potwierdzić, że czas treningu w historii jest liczony od rozpoczęcia do zakończenia sesji.
2. Zastąpić etykietę `żywo` w edytowalnym widoku sesji trenera czasem sesji w formacie `mm:ss`.
3. Poprawnie odmieniać komunikat o liczbie ukończonych serii.
4. Zastąpić słowo `progres` słowem `postęp` w tekstach historii.
5. Dodać powrót z pierwszego poziomu historii trenera do szczegółów wybranego podopiecznego.

## Czas treningu

API historii pozostaje bez zmian. `durationSeconds` jest już obliczane jako różnica pomiędzy `SharedSession.ClosedAt` i `SharedSession.CreatedAt`, czyli od utworzenia aktywnej sesji do jej zakończenia. Wartość `0 min` jest poprawnym wynikiem prezentacji dla sesji krótszej niż 60 sekund.

Test API ma nadal potwierdzać obliczanie czasu z tych dwóch znaczników. Nie zaokrąglamy sesji krótszych niż minuta do jednej minuty.

## Timer sesji trenera

Edytowalny ekran sesji trenera pokaże czas, który upłynął od serwerowego `session.createdAt` do bieżącego czasu. Timer:

- startuje od rzeczywistego wieku sesji, a nie od wejścia na ekran;
- aktualizuje się raz na sekundę;
- używa formatu `mm:ss`, również po przekroczeniu 59 minut;
- zostaje zatrzymany przy usunięciu widoku;
- zastępuje badge `żywo`, bez zmian w działaniu SignalR i sesji.

## Polska odmiana serii

Komunikat w widoku tylko do odczytu użyje wspólnego formatowania:

- `1 ukończona seria`;
- `2 ukończone serie`;
- `5 ukończonych serii`;
- reguła uwzględni liczby 12–14 jako `ukończonych serii`.

## Teksty historii

W tekstach widocznych dla użytkownika:

- `progres ›` zostanie zastąpione przez `postęp ›`;
- `Progres ćwiczenia` zostanie zastąpione przez `Postęp ćwiczenia`.

Nazwy klas, endpointów i modeli pozostają bez zmian, ponieważ jest to wyłącznie korekta polskiego copy.

## Powrót w historii trenera

Pierwszy poziom historii dostanie opcjonalny przycisk powrotu. Dla podopiecznego nadal będzie używana dolna nawigacja `Dziś`. Dla trenera przycisk `Wróć` zamknie historię i przywróci szczegóły tego samego wybranego podopiecznego, zamiast pulpitu trenera.

## Weryfikacja

Testy obejmą:

- obliczanie czasu historii z `CreatedAt` i `ClosedAt`;
- start timera od wieku sesji i aktualizację sekund;
- wszystkie istotne formy odmiany ukończonych serii;
- brak słowa `progres` w historii;
- powrót trenera z poziomu 1 historii do szczegółów wybranego podopiecznego;
- pełny `flutter test`, `flutter analyze` oraz testy API historii.

## Poza zakresem

- zmiana sposobu zapisu czasu sesji w bazie;
- zaokrąglanie krótkich treningów do jednej minuty;
- zmiany transportu realtime;
- zmiana nazw technicznych modeli `ExerciseProgress`;
- przebudowa pozostałej nawigacji trenera lub podopiecznego.
