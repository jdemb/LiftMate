# Konfiguracja odpoczynku i korekty aktywnej sesji

## Cel

Umożliwić trenerowi ustawienie czasu odpoczynku podczas tworzenia i edycji zestawu, wykorzystać tę wartość w rozpoczętej sesji oraz poprawić nagłówek i układ aktywnego treningu trenera.

## Zakres

Zmiana obejmuje:

- ustawienie czasu odpoczynku dla całego zestawu;
- zapis migawki czasu odpoczynku w sesji;
- pierwsze imię podopiecznego i nazwę zestawu w nagłówku aktywnej sesji;
- stale widoczny, kompaktowy pasek odpoczynku;
- automatyczny start odpoczynku po pomyślnym ukończeniu serii.

Zmiana nie obejmuje osobnych czasów odpoczynku dla ćwiczeń lub serii ani modyfikowania czasu w już rozpoczętej sesji przez późniejszą edycję zestawu.

## Model danych i API

`WorkoutSet` otrzyma pole `RestSeconds`:

- wartość domyślna: 90 sekund;
- dozwolony zakres: 15–600 sekund;
- interfejs zmienia wartość co 15 sekund;
- API waliduje zakres niezależnie od klienta.

Pole zostanie dodane do kontraktów tworzenia, edycji i odczytu zestawu, w tym do danych zestawu przypisanego podopiecznemu.

`SharedSession` również otrzyma pole `RestSeconds`. Podczas rozpoczęcia sesji z zestawu API skopiuje bieżące `WorkoutSet.RestSeconds` do sesji. Sesja zachowa tę wartość jako migawkę, dlatego późniejsza edycja zestawu nie zmieni trwającej ani zakończonej sesji.

Sesje tworzone bez zestawu otrzymają 90 sekund. Migracja bazy przypisze 90 sekund istniejącym zestawom i sesjom.

## Kreator zestawu

Pod polem nazwy zestawu pojawi się sekcja „Czas odpoczynku”. Będzie zawierała:

- przycisk zmniejszenia o 15 sekund;
- aktualną wartość w formacie `mm:ss`;
- przycisk zwiększenia o 15 sekund.

Nowy zestaw rozpoczyna z wartością `01:30`. Edycja istniejącego zestawu wczytuje zapisaną wartość. Przyciski nie przekraczają granic 15 i 600 sekund. Zapis zestawu przesyła wartość razem z nazwą i seriami.

## Nagłówek aktywnej sesji

W edytowalnej sesji trenera:

- tytułem będzie pierwsze imię wybranego podopiecznego, np. `Anna`;
- podtytułem będzie `Zestaw <nazwa>`, np. `Zestaw Push A`;
- identyfikator zestawu nie będzie prezentowany użytkownikowi;
- licznik czasu trwania sesji pozostanie bez zmian.

`LiveSessionScreen` otrzyma nazwę podopiecznego z aktualnie wybranego rekordu relacji. Jeżeli nazwa jest pusta lub niedostępna, ekran użyje e-maila z sesji jako bezpiecznego fallbacku. Nazwa zestawu pochodzi z istniejącego `SharedSession.workoutSetName`.

## Przypięty pasek odpoczynku

Duża karta odpoczynku zostanie usunięta z przewijanej listy. Pod listą, a nad przyciskiem „Zakończ i zapisz trening”, pojawi się kompaktowy pasek stale widoczny bez przewijania.

Pasek zawiera:

- etykietę „Odpoczynek”;
- pozostały czas w formacie `mm:ss`;
- sterowanie start/pauza;
- przycisk `+15 s`;
- reset do wartości zapisanej w sesji.

Pasek nie ma stałej wartości 90 sekund. Jego wartością bazową jest `SharedSession.restSeconds`.

## Automatyczne uruchamianie

Po kliknięciu oznaczenia serii jako ukończonej ekran czeka na wynik zapisu w API.

- Jeżeli zapis się powiedzie i seria zmieni się z nieukończonej na ukończoną, timer zostaje ustawiony na pełne `session.restSeconds` i natychmiast startuje.
- Jeżeli timer już działa, zostaje zresetowany do pełnej wartości i uruchomiony od początku.
- Cofnięcie ukończenia serii nie uruchamia ani nie resetuje timera.
- Nieudany zapis nie zmienia timera.

Obsługa wyniku pozostanie w stanie `LiveSessionScreen`. Karta serii zgłosi żądanie zmiany i poczeka na `SharedSessionApiResult`, dzięki czemu efekt interfejsu zależy od potwierdzonego zapisu, a nie od samego kliknięcia.

## Reconnect i zmiany sesji

Po ponownym połączeniu ekran odczytuje bazowy czas odpoczynku z migawki sesji. Lokalny stan aktualnego odliczania nie jest synchronizowany przez API i po ponownym otwarciu ekranu zaczyna od pełnej wartości, bez automatycznego startu.

Jeżeli kontroler przełączy ekran na inną sesję, lokalny timer zostanie zatrzymany i zresetowany do `restSeconds` nowej sesji.

## Obsługa błędów

- API odrzuca `RestSeconds` poza zakresem 15–600.
- Klient mobilny traktuje brak pola w starszej odpowiedzi jako 90 sekund, aby zachować kompatybilność podczas wdrożenia.
- Brak nazwy podopiecznego używa e-maila sesji.
- Brak lub pusta nazwa zestawu używa etykiety `Trening`.
- Błąd ukończenia serii korzysta z istniejącego komunikatu synchronizacji i nie uruchamia odpoczynku.

## Testy

### API

- tworzenie i edycja zestawu zapisuje `RestSeconds`;
- wartości poza zakresem są odrzucane;
- odpowiedzi zestawów zawierają czas odpoczynku;
- rozpoczęcie sesji kopiuje czas odpoczynku z zestawu;
- późniejsza edycja zestawu nie zmienia migawki istniejącej sesji;
- sesja bez zestawu oraz dane po migracji używają 90 sekund.

### Flutter

- modele i żądania zestawów obsługują `restSeconds` z fallbackiem 90;
- kreator nowego zestawu pokazuje `01:30` i zmienia wartość co 15 sekund;
- edycja wczytuje istniejącą wartość;
- nagłówek pokazuje pierwsze imię i nazwę zestawu zamiast e-maila oraz ID;
- pasek odpoczynku jest widoczny przy dolnej krawędzi bez przewijania;
- pomyślne ukończenie serii uruchamia lub resetuje timer do wartości sesji;
- cofnięcie serii i błąd API nie uruchamiają timera;
- reset przywraca wartość sesji, a `+15 s` zwiększa bieżące odliczanie.

## Kryteria akceptacji

1. Trener może ustawić czas odpoczynku zestawu od 15 do 600 sekund w kroku 15 sekund.
2. Sesja używa wartości obowiązującej w chwili jej rozpoczęcia.
3. Aktywna sesja trenera pokazuje pierwsze imię podopiecznego oraz nazwę zestawu.
4. Kompaktowy timer odpoczynku pozostaje widoczny bez przewijania.
5. Ukończenie serii po udanym zapisie resetuje i uruchamia timer.
6. Cofnięcie serii lub błąd zapisu nie uruchamia timera.
7. Istniejące zestawy i sesje zachowują domyślne 90 sekund.
