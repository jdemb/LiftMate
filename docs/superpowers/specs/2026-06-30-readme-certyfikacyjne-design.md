# README certyfikacyjne LiftMate

## Cel

Zastąpić minimalny główny `README.md` czytelną stroną wejściową do projektu LiftMate dla egzaminatorów kursu, deweloperów i rekruterów. Dokument ma najpierw pokazać wartość produktu i umożliwić jego obejrzenie lub instalację, a następnie dostarczyć kompletne informacje techniczne potrzebne do uruchomienia i oceny repozytorium.

README będzie napisany po polsku. Nazwy technologii, komend i ustawień konfiguracyjnych pozostaną zgodne z kodem.

## Układ product-first

Sekcje wystąpią w następującej kolejności:

1. nazwa LiftMate i krótka obietnica wartości;
2. główne odnośniki: publiczna prezentacja oraz pobranie APK;
3. galeria czterech reprezentatywnych ekranów;
4. opis produktu oraz jego dwóch grup użytkowników;
5. najważniejsze funkcje;
6. architektura Flutter + ASP.NET Core;
7. struktura monorepo;
8. wymagania środowiskowe i konfiguracja;
9. uruchamianie API i aplikacji mobilnej;
10. komendy weryfikacji i testów;
11. odnośniki do dokumentacji projektowej;
12. ograniczenia i status platform.

Publiczna prezentacja pod `https://jdemb.github.io/liftmate-demo` będzie głównym CTA, ponieważ pozwala zapoznać się z aplikacją bez instalacji. Link do APK będzie drugim CTA i poprowadzi bezpośrednio do zasobu w GitHub Release.

## Galeria ekranów

W README pojawi się układ 2×2 z czterema obrazami:

- Pulpit trenera;
- Podopieczny — szczegóły z podpowiedziami;
- Sesja na żywo;
- Progres ćwiczenia.

Obrazy zostaną wyrenderowane z `apps/mobile/design/LiftMate - prezentacja.html`, przycięte do czytelnego zakresu i zapisane jako pliki PNG pod `docs/assets/readme/`. Każdy obraz otrzyma zwięzły tekst alternatywny oraz podpis. Źródłowy HTML nie będzie modyfikowany.

## Treść produktowa

Opis przedstawi LiftMate jako mobilną aplikację łączącą trenera personalnego z podopiecznym i prowadzącą przez cały przepływ: przygotowanie planu, przypisanie, wykonanie treningu, feedback i ocenę progresu.

Główne grupy użytkowników:

- trener zarządzający wieloma podopiecznymi, planami i aktywnymi sesjami;
- podopieczny wykonujący trening prowadzony przez trenera albo samodzielnie.

Lista głównych funkcji obejmie:

- relację jeden trener–wielu podopiecznych;
- tworzenie, edycję, usuwanie i wielokrotne przypisywanie planów;
- wspólną sesję synchronizowaną w czasie rzeczywistym;
- samodzielny trening podopiecznego;
- zapis wyników jako punkt startowy kolejnego treningu;
- historię sesji i progres ćwiczeń;
- feedback po treningu;
- aktualną i najlepszą serię tygodniową;
- podpowiedzi dla trenera o stagnacji i obniżonym samopoczuciu.

Deklaracje będą zgodne z `apps/mobile/design/mapa-implementacji.md`. README nie będzie kopiował pełnego katalogu 28 funkcji; zamiast tego odeśle do dokumentu szczegółowego.

## Architektura

README użyje niewielkiego diagramu Mermaid pokazującego przepływ:

```text
Flutter mobile → REST API i SignalR → ASP.NET Core → EF Core → Azure SQL
```

Opis rozdzieli odpowiedzialności:

- Flutter: interfejs, stan aplikacji, bezpieczne przechowywanie tokenów i klient realtime;
- ASP.NET Core: uwierzytelnianie, autoryzacja ról i relacji, logika treningowa oraz hub SignalR;
- EF Core i Azure SQL: persystencja, migracje oraz dane kont, planów, sesji i progresu;
- Azure App Service: publiczne środowisko API i automatyczne wdrożenie przez GitHub Actions.

## Wymagania i konfiguracja

Wersje narzędzi zostaną odczytane z repozytorium i zweryfikowane lokalnymi komendami przed wpisaniem do README. Sekcja rozróżni minimum wynikające z projektu od wersji użytych podczas weryfikacji.

Konfiguracja obejmie:

- `API_BASE_URL` dla Fluttera przez `--dart-define` oraz domyślny `apps/mobile/config/app_config.json`;
- adres hosta `10.0.2.2` dla Android Emulatora korzystającego z lokalnego API;
- `ConnectionStrings:DefaultConnection` dla API;
- ustawienia JWT: issuer, audience, signing key i czasy życia tokenów;
- `Auth:RegistrationInviteCode` jako sekret lokalny lub ustawienie środowiska;
- migracje EF Core.

README pokaże wyłącznie nazwy ustawień i wartości przykładowe. Nie ujawni rzeczywistych sekretów, danych uwierzytelniających ani produkcyjnego kodu rejestracji.

## Uruchamianie i testy

Instrukcja API będzie wykonywana z `apps/api` i obejmie restore, konfigurację user-secrets, migracje, build oraz `dotnet run`. Instrukcja mobilna będzie wykonywana z `apps/mobile` i obejmie `flutter pub get`, wybór urządzenia oraz `flutter run` z właściwym `API_BASE_URL`.

Sekcja testów poda gotowe do skopiowania komendy:

- `flutter analyze`;
- `flutter test`;
- `dotnet restore LiftMate.slnx`;
- `dotnet build LiftMate.slnx --no-restore`;
- `dotnet test LiftMate.slnx --no-build --verbosity minimal`;
- kontrolę podatnych pakietów .NET.

## Dokumentacja

README podlinkuje co najmniej:

- `context/foundation/prd.md`;
- `context/foundation/prd-expansion.md`;
- `context/foundation/roadmap.md`;
- `context/foundation/infrastructure.md`;
- `context/foundation/tech-stack.md`;
- `context/foundation/tech-stack-api.md`;
- `apps/mobile/design/prezentacja-funkcji.md`;
- `apps/mobile/design/mapa-implementacji.md`.

## Android Release

Z bieżącego, zweryfikowanego kodu zostanie zbudowany nowy APK release. Artefakt będzie miał nazwę `LiftMate-v1.0.0-android.apk` i zostanie opublikowany w GitHub Release:

- tag: `v1.0.0`;
- nazwa: `LiftMate MVP — wersja certyfikacyjna`;
- treść: krótki opis wersji, link do prezentacji, wymaganie Androida i informacja o ręcznej instalacji spoza Google Play;
- asset: `LiftMate-v1.0.0-android.apk`.

README użyje stałego linku do tego zasobu. APK nie zostanie dodany do historii Git. Przed publikacją zostanie obliczony SHA-256, a Release i link pobierania zostaną sprawdzone po utworzeniu.

Publikacja wymaga działającego uwierzytelnienia GitHub CLI. Obecna sesja `gh` zwraca błąd 401, więc przed utworzeniem Release trzeba odświeżyć logowanie.

## Status iOS

README poda dokładne ograniczenie:

> Aplikacja nie była testowana na fizycznych urządzeniach z systemem iOS z powodu braku dostępu do wymaganego środowiska Apple.

Tekst nie będzie sugerował, że Flutterowa implementacja iOS nie istnieje ani że projekt nie może zostać zbudowany na odpowiednio skonfigurowanym środowisku macOS/Xcode.

## Weryfikacja

Przed ukończeniem zostaną sprawdzone:

1. istnienie wszystkich linków repozytorium i zasobów graficznych;
2. odpowiedź HTTP publicznej prezentacji i publicznego API, o ile środowisko sieciowe na to pozwoli;
3. poprawność diagramu i renderowania README na GitHubie;
4. zgodność komend z faktycznymi ścieżkami i wersjami projektu;
5. brak sekretów i lokalnych ścieżek w README;
6. czytelność czterech obrazów przy szerokości README;
7. `flutter analyze`, `flutter test` oraz testy API;
8. świeży build APK release;
9. istnienie Release `v1.0.0` i możliwość pobrania zasobu;
10. czysty zakres zmian w Git: README, cztery obrazy i dokumenty procesu — bez APK oraz bez modyfikacji aplikacji.
