# Aplikacja mobilna treningowa dla trenera i podopiecznego 
### Główny problem 
Podopieczny nie chce w trakcie treningu na siłowni śledzić swojego progressu ciężarów/liczby powtórzeń, ani zastanawiać się nad tym jakie kolejne ćwiczenie miałby wykonywać. Wolałby, żeby trener pilnował wszystkiego za niego. 

### Najmniejszy zestaw funkcjonalności
- Prosty system kont użytkowników z podziałem na role trener/podopieczny 
- Każdy trener może podpiąć pod siebie liczbę podopiecznych
- Każdy trener ma wgląd i możliwość edycji danych swoich podopiecznych
- Każdy podopieczny ma wgląd i możliwość edycji swoich własnych danych
- Trener może budować zestaw ćwiczeń do wykonania dla podopiecznego jako szablon indywidualny lub szablon globalny, który może potem przydzielić liczbie podopiecznych
- Aplikacja będzie przechowywać ćwiczenia stworzone przez trenera. Każdy trener będzie widział tylko swoje ćwiczenia. 
- Ćwiczenie można zbudować podając nazwę i typ. W zależności od typu otrzymamy dodatkowe parametry do utworzenia ćwiczenia. Typy: powtórzenia+waga, same powtórzenia, czas. 
- Zestaw ćwiczeń będzie składał się z ćwiczeń i ich parametrów np. liczba setów, powtórzeń na set i wagi. 

### Co nie wchodzi w zakres aplikacji
- Aplikacja webowa czy desktopowa, budujemy tylko wersję mobilną 
- Algorytm dobierania ćwiczeń pod czyjeś potrzeby
- Eksport danych
- Interakcje między podpiecznymi i między trenerami (tylko podopieczny-trener)

### Kryteria sukcesu
- Podopieczni i trenerzy mogą zakładać swoje konta i łączyć się w pary ( w przypadku trenerów 1 do wielu podopiecznych)
- Możemy stworzyć poprawny przepływ trener tworzy listę ćwiczeń -> buduje zestaw -> ustawia go podopiecznemu do wykonania -> edytuje dane w trakcie treningu -> zapisane nowe wartości będą do wykonania na kolejnym treningu
- Użytkownicy mają wgląd w swoje dane