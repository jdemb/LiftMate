# Warstwa prezentacji funkcji LiftMate

## Cel

Przygotować dwa polskojęzyczne dokumenty pokazujące egzaminatorowi zakres ukończonej aplikacji LiftMate. Pierwszy dokument ma atrakcyjnie komunikować wartość produktu, a drugi umożliwiać szybkie sprawdzenie, gdzie dana funkcja została zaimplementowana i przetestowana.

## Źródła prawdy

- `apps/mobile/design/LiftMate.dc.html` — czytelny katalog ekranów, ich nazwy i projektowane przepływy.
- `apps/mobile/design/LiftMate.html` — kontrola zgodności kompletności względem drugiego artefaktu designu.
- `apps/mobile/lib/` — rzeczywiste ekrany i widgety Fluttera.
- `apps/api/` — endpointy i logika serwerowa wspierająca prezentowane funkcje.
- `apps/mobile/test/` oraz testy API — dowody zachowania.
- `context/foundation/prd.md` i `context/foundation/roadmap.md` — uzasadnienie produktowe i identyfikatory wymagań.

Opis trafia do dokumentów tylko wtedy, gdy funkcję można potwierdzić w aktualnym kodzie. Rozbieżność między designem a implementacją zostanie jawnie oznaczona w mapie technicznej, zamiast przedstawiona jako ukończona funkcja.

## Dokument prezentacyjny

Plik: `apps/mobile/design/prezentacja-funkcji.md`.

Treść zostanie ułożona według ścieżek użytkownika: rozpoczęcie pracy, codzienna praca trenera, przygotowanie planu, wspólny trening na żywo oraz historia i progres. Najmocniejsze wyróżniki produktu pojawią się na początku, a pełny indeks ekranów zapewni kompletność.

Każdy ekran może zawierać dowolną liczbę funkcji. Każda funkcja otrzyma atrakcyjny tytuł, wskazanie powiązanego ekranu lub ekranów oraz opis liczący maksymalnie trzy zdania. Jedna funkcja może również obejmować kilka ekranów, jeżeli dopiero cały przepływ pokazuje jej wartość.

Dokument nie będzie zawierał ścieżek do kodu, nazw klas, endpointów ani szczegółów testów.

## Mapa implementacji

Plik: `apps/mobile/design/mapa-implementacji.md`.

Każdy wpis funkcji będzie powiązany z:

- identyfikatorem i nazwą ekranu z designu;
- ekranem, widgetem lub kontrolerem Fluttera;
- endpointem albo elementem logiki API, jeśli funkcja korzysta z backendu;
- odpowiednimi testami automatycznymi;
- wymaganiem produktowym lub elementem roadmapy, jeśli istnieje.

Mapa będzie odsyłała do konkretnych plików repozytorium za pomocą względnych linków Markdown. Brak danego rodzaju dowodu zostanie zapisany jako `nie dotyczy`, aby odróżnić świadomy brak zależności od niepełnej analizy.

## Model powiązań

Dokumentacja przyjmie relację wiele-do-wielu:

- ekran może prezentować kilka osobnych funkcji;
- funkcja może wykorzystywać kilka ekranów;
- widget, endpoint lub test może być dowodem dla kilku funkcji.

Podstawową jednostką opisu jest funkcja, nie ekran. Indeks ekranów na końcu obu dokumentów umożliwi jednak sprawdzenie, czy każdy ekran z obu plików HTML został uwzględniony.

## Weryfikacja

Przed ukończeniem zostaną wykonane:

1. porównanie list ekranów w obu plikach HTML;
2. sprawdzenie każdej funkcji w kodzie Fluttera i, gdy dotyczy, w API;
3. kontrola istnienia wszystkich linkowanych plików;
4. kontrola pokrycia każdego ekranu co najmniej jednym wpisem;
5. kontrola limitu trzech zdań w opisach prezentacyjnych;
6. przegląd języka pod kątem korzyści dla użytkownika i braku niepotwierdzonych deklaracji.

## Poza zakresem

Na tym etapie nie powstają zrzuty ekranów, slajdy, materiały graficzne ani zmiany w aplikacji i artefaktach HTML.
