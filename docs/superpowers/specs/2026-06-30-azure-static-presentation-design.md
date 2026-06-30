# Jednorazowa publikacja prezentacji LiftMate w Azure

## Cel

Udostępnić publicznie plik `apps/mobile/design/LiftMate - prezentacja.html` pod adresem HTTPS w bezpłatnym planie Azure, bez automatycznego wdrażania z GitHuba i bez zmian w działaniu aplikacji mobilnej lub API.

## Architektura

- Usługa: Azure Static Web Apps.
- Plan: Free.
- Nazwa zasobu: `liftmate-prezentacja-jdemb`, o ile nazwa jest dostępna globalnie; w przeciwnym razie zostanie użyta najbliższa jednoznaczna nazwa z krótkim sufiksem.
- Grupa zasobów: istniejąca `rg-liftmate-dev`.
- Region: West Europe.
- Zawartość: pojedynczy plik prezentacji opublikowany jako `index.html`.
- Integracja z repozytorium: brak GitHub Actions, webhooków i plików konfiguracyjnych wdrożenia.

## Przebieg wdrożenia

1. Utworzyć zasób Static Web App w planie Free.
2. Przygotować poza repozytorium tymczasowy katalog publikacji i skopiować do niego prezentację pod nazwą `index.html`.
3. Pobrać token wdrożeniowy tylko na czas procesu i przekazać go narzędziu wdrożeniowemu bez zapisywania w repozytorium ani komunikatach końcowych.
4. Wdrożyć katalog jako środowisko produkcyjne.
5. Odczytać publiczny adres hosta i zweryfikować stronę przez HTTPS.

## Bezpieczeństwo i koszty

- Zasób zostanie utworzony jawnie w SKU `Free`.
- Token wdrożeniowy nie zostanie zapisany w plikach projektu ani wyświetlony użytkownikowi.
- Nie zostanie skonfigurowana niestandardowa domena, uwierzytelnianie ani backend.
- Istniejący App Service i API LiftMate pozostaną niezmienione.

## Weryfikacja

- Azure raportuje zasób jako `Microsoft.Web/staticSites` ze SKU `Free`.
- Publiczny adres odpowiada przez HTTPS kodem 200.
- Załadowana strona ma tytuł i interaktywną zawartość prezentacji LiftMate.
- Repozytorium nie zawiera tokenu, workflow wdrożeniowego ani kopii pliku `index.html` utworzonej wyłącznie na potrzeby publikacji.

## Poza zakresem

- Automatyczne wdrożenia po kolejnych commitach.
- Własna domena.
- Ochrona strony hasłem lub logowaniem.
- Publikacja aplikacji Flutter albo API.
