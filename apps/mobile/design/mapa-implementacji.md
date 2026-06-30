# Mapa implementacji funkcji LiftMate

Dokument łączy funkcje prezentowane w aplikacji z ekranami designu i dowodami w repozytorium. Relacja jest wiele-do-wielu: jeden ekran może prezentować kilka funkcji, a jedna funkcja może obejmować kilka ekranów.

## Legenda

- **Ekrany:** nazwa oraz identyfikator z `LiftMate.dc.html`.
- **Mobile:** ekran, widget, kontroler albo klient API Fluttera.
- **API:** endpoint, serwis lub model domenowy; `nie dotyczy`, gdy funkcja jest wyłącznie lokalna.
- **Testy:** testy automatyczne potwierdzające zachowanie.
- **Wymagania:** identyfikatory PRD lub roadmapy, jeśli istnieją.

## Rozbieżności

Brak — `LiftMate.dc.html` i `LiftMate.html` zawierają ten sam katalog 17 ekranów, a odpowiadające im stany i przepływy są obecne w aplikacji Flutter. Część ekranów designu jest realizowana przez jeden złożony widget, np. onboarding przez `AuthScreen`, a historia przez `TrainingHistoryFlow`; nie zmienia to pokrycia funkcjonalnego.

## Łatwy start i bezpieczne konto

<a id="start-i-wybor-roli"></a>
### Start dopasowany do roli użytkownika

- **Ekrany:** `Powitanie` (`welcome`), `Wybór roli` (`role`)
- **Mobile:** [`AuthScreen`](../lib/auth/auth_screen.dart), [`AuthController`](../lib/auth/auth_controller.dart)
- **API:** [`ProbeEndpoints`](../../api/LiftMate.Api/Auth/ProbeEndpoints.cs)
- **Testy:** [`auth_screen_test.dart`](../test/auth_screen_test.dart), [`RoleProbeTests.cs`](../../api/LiftMate.Api.Tests/Auth/RoleProbeTests.cs)
- **Wymagania:** `FR-001`, `F-02`

<a id="rejestracja-beta"></a>
### Rejestracja chroniona kodem beta

- **Ekrany:** `Wybór roli` (`role`), `Rejestracja` (`signup`)
- **Mobile:** [`AuthScreen`](../lib/auth/auth_screen.dart), [`AuthApiClient`](../lib/auth/auth_api_client.dart)
- **API:** [`AuthEndpoints`](../../api/LiftMate.Api/Auth/AuthEndpoints.cs), [`RegistrationGate`](../../api/LiftMate.Api/Auth/RegistrationGate.cs)
- **Testy:** [`auth_screen_test.dart`](../test/auth_screen_test.dart), [`AuthEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs)
- **Wymagania:** `FR-001`, `S-07`

<a id="czytelny-formularz"></a>
### Czytelny formularz z polską walidacją

- **Ekrany:** `Rejestracja` (`signup`)
- **Mobile:** [`AuthScreen`](../lib/auth/auth_screen.dart), [`AuthController`](../lib/auth/auth_controller.dart)
- **API:** [`IdentityErrorTranslator`](../../api/LiftMate.Api/Auth/IdentityErrorTranslator.cs), [`AuthEndpoints`](../../api/LiftMate.Api/Auth/AuthEndpoints.cs)
- **Testy:** [`auth_screen_test.dart`](../test/auth_screen_test.dart), [`AuthEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs)
- **Wymagania:** `FR-001`, `S-07`

<a id="trwala-sesja"></a>
### Trwała i automatycznie odnawiana sesja

- **Ekrany:** `Powitanie` (`welcome`), `Rejestracja` (`signup`)
- **Mobile:** [`AuthController`](../lib/auth/auth_controller.dart), [`AuthenticatedHttpClient`](../lib/auth/authenticated_http_client.dart), [`TokenStore`](../lib/auth/token_store.dart)
- **API:** [`AuthEndpoints`](../../api/LiftMate.Api/Auth/AuthEndpoints.cs), [`TokenService`](../../api/LiftMate.Api/Auth/TokenService.cs)
- **Testy:** [`auth_controller_runtime_refresh_test.dart`](../test/auth_controller_runtime_refresh_test.dart), [`authenticated_http_client_test.dart`](../test/authenticated_http_client_test.dart), [`AuthEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/AuthEndpointTests.cs)
- **Wymagania:** `F-02`

## Relacja trener–podopieczny

<a id="parowanie-kodem"></a>
### Parowanie kont za pomocą kodu

- **Ekrany:** `Parowanie` (`pair`), `Pulpit` (`t_dash`), `Dziś / trening` (`c_home`)
- **Mobile:** [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart), [`RelationshipController`](../lib/relationships/relationship_controller.dart), [`RelationshipApiClient`](../lib/relationships/relationship_api_client.dart)
- **API:** [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`relationship_controller_test.dart`](../test/relationship_controller_test.dart), [`PairingEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs)
- **Wymagania:** `FR-002`, `FR-003`, `S-01`

<a id="kopiowanie-kodu"></a>
### Kopiowanie kodu z natychmiastowym potwierdzeniem

- **Ekrany:** `Parowanie` (`pair`), `Pulpit` (`t_dash`)
- **Mobile:** [`TrainerDashboardScreen`](../lib/relationships/trainer_dashboard_screen.dart), [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart)
- **API:** [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`PairingEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs)
- **Wymagania:** `S-08`

<a id="granice-dostepu"></a>
### Dostęp ograniczony rolą i relacją

- **Ekrany:** `Wybór roli` (`role`), `Pulpit` (`t_dash`), `Podopieczny` (`t_trainee`), `Dziś / trening` (`c_home`)
- **Mobile:** [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart), [`RelationshipApiClient`](../lib/relationships/relationship_api_client.dart)
- **API:** [`ProbeEndpoints`](../../api/LiftMate.Api/Auth/ProbeEndpoints.cs), [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs), [`SharedSessionAccess`](../../api/LiftMate.Api/SharedSessions/SharedSessionAccess.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`PairingEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-002`, `FR-003`, `FR-004`, `FR-005`, `F-02`

## Centrum pracy trenera

<a id="pulpit-podopiecznych"></a>
### Pulpit wielu podopiecznych

- **Ekrany:** `Pulpit` (`t_dash`)
- **Mobile:** [`TrainerDashboardScreen`](../lib/relationships/trainer_dashboard_screen.dart), [`RelationshipController`](../lib/relationships/relationship_controller.dart)
- **API:** [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`relationship_models_test.dart`](../test/relationship_models_test.dart), [`PairingEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs)
- **Wymagania:** `FR-002`, `FR-004`, `S-01`

<a id="regularnosc-tygodniowa"></a>
### Aktualna i najlepsza seria tygodniowa

- **Ekrany:** `Pulpit` (`t_dash`), `Podopieczny` (`t_trainee`), `Dziś / trening` (`c_home`)
- **Mobile:** [`TrainerDashboardScreen`](../lib/relationships/trainer_dashboard_screen.dart), [`TrainerTraineeDetailScreen`](../lib/relationships/trainer_trainee_detail_screen.dart), [`TraineeHomeScreen`](../lib/relationships/trainee_home_screen.dart)
- **API:** [`WeeklyStreakService`](../../api/LiftMate.Api/WeeklyStreaks/WeeklyStreakService.cs), [`WeeklyStreakCalculator`](../../api/LiftMate.Api/WeeklyStreaks/WeeklyStreakCalculator.cs)
- **Testy:** [`weekly_streak_screen_test.dart`](../test/weekly_streak_screen_test.dart), [`WeeklyStreakServiceTests.cs`](../../api/LiftMate.Api.Tests/WeeklyStreaks/WeeklyStreakServiceTests.cs), [`WeeklyStreakCalculatorTests.cs`](../../api/LiftMate.Api.Tests/WeeklyStreaks/WeeklyStreakCalculatorTests.cs)
- **Wymagania:** `S-11`

<a id="centrum-podopiecznego"></a>
### Szczegóły podopiecznego jako centrum decyzji

- **Ekrany:** `Pulpit` (`t_dash`), `Podopieczny` (`t_trainee`)
- **Mobile:** [`TrainerTraineeDetailScreen`](../lib/relationships/trainer_trainee_detail_screen.dart), [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart)
- **API:** [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs)
- **Testy:** [`trainer_trainee_detail_screen_test.dart`](../test/trainer_trainee_detail_screen_test.dart), [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`PairingEndpointTests.cs`](../../api/LiftMate.Api.Tests/Auth/PairingEndpointTests.cs)
- **Wymagania:** `FR-004`, `FR-010`, `S-03`

<a id="podpowiedzi-trenerskie"></a>
### Podpowiedzi o stagnacji i samopoczuciu

- **Ekrany:** `Podopieczny` (`t_trainee`), `Szczegóły sesji` (`c_session`)
- **Mobile:** [`TrainerTraineeDetailScreen`](../lib/relationships/trainer_trainee_detail_screen.dart), [`TrainerGuidanceController`](../lib/trainer_guidance/trainer_guidance_controller.dart), [`TrainerGuidanceApiClient`](../lib/trainer_guidance/trainer_guidance_api_client.dart)
- **API:** [`TrainerGuidanceEvaluator`](../../api/LiftMate.Api/TrainerGuidance/TrainerGuidanceEvaluator.cs), [`TrainerGuidanceEndpoints`](../../api/LiftMate.Api/TrainerGuidance/TrainerGuidanceEndpoints.cs)
- **Testy:** [`trainer_trainee_detail_screen_test.dart`](../test/trainer_trainee_detail_screen_test.dart), [`trainer_guidance_controller_test.dart`](../test/trainer_guidance_controller_test.dart), [`TrainerGuidanceEndpointTests.cs`](../../api/LiftMate.Api.Tests/TrainerGuidance/TrainerGuidanceEndpointTests.cs), [`TrainerGuidanceEvaluatorTests.cs`](../../api/LiftMate.Api.Tests/TrainerGuidance/TrainerGuidanceEvaluatorTests.cs)
- **Wymagania:** `S-10`

## Planowanie i przypisywanie zestawów

<a id="biblioteka-zestawow"></a>
### Wielokrotnego użytku biblioteka zestawów

- **Ekrany:** `Biblioteka zestawów` (`t_sets`), `Kreator zestawu` (`t_builder`)
- **Mobile:** [`TrainerWorkoutSetsScreen`](../lib/workout_sets/trainer_workout_sets_screen.dart), [`WorkoutSetBuilderScreen`](../lib/workout_sets/workout_set_builder_screen.dart), [`WorkoutSetController`](../lib/workout_sets/workout_set_controller.dart)
- **API:** [`WorkoutSetEndpoints`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs)
- **Testy:** [`workout_set_trainer_screens_test.dart`](../test/workout_set_trainer_screens_test.dart), [`workout_set_controller_test.dart`](../test/workout_set_controller_test.dart), [`WorkoutSetEndpointTests.cs`](../../api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs)
- **Wymagania:** `FR-008`, `S-02`

<a id="bezpieczna-edycja-zestawu"></a>
### Edycja i bezpieczne usuwanie zestawów

- **Ekrany:** `Biblioteka zestawów` (`t_sets`), `Kreator zestawu` (`t_builder`)
- **Mobile:** [`TrainerWorkoutSetsScreen`](../lib/workout_sets/trainer_workout_sets_screen.dart), [`WorkoutSetBuilderScreen`](../lib/workout_sets/workout_set_builder_screen.dart), [`WorkoutSetApiClient`](../lib/workout_sets/workout_set_api_client.dart)
- **API:** [`WorkoutSetEndpoints`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs), [`WorkoutSetValidation`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetValidation.cs)
- **Testy:** [`workout_set_trainer_screens_test.dart`](../test/workout_set_trainer_screens_test.dart), [`workout_set_api_client_test.dart`](../test/workout_set_api_client_test.dart), [`WorkoutSetEndpointTests.cs`](../../api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs)
- **Wymagania:** `FR-008`

<a id="typy-cwiczen"></a>
### Trzy typy ćwiczeń i właściwe parametry

- **Ekrany:** `Kreator zestawu` (`t_builder`), `Dodaj ćwiczenie` (`t_addex`)
- **Mobile:** [`AddWorkoutSetExerciseScreen`](../lib/workout_sets/add_workout_set_exercise_screen.dart), [`WorkoutSetDraft`](../lib/workout_sets/workout_set_draft.dart), [`WorkoutSetRow`](../lib/workout_sets/workout_set_models.dart)
- **API:** [`WorkoutSetRowRequest`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetContracts.cs), [`WorkoutSetValidation`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetValidation.cs)
- **Testy:** [`workout_set_trainer_screens_test.dart`](../test/workout_set_trainer_screens_test.dart), [`workout_set_models_test.dart`](../test/workout_set_models_test.dart), [`WorkoutSetEndpointTests.cs`](../../api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs)
- **Wymagania:** `FR-007`, `S-02`

<a id="odpoczynek-w-planie"></a>
### Konfigurowalny czas odpoczynku

- **Ekrany:** `Kreator zestawu` (`t_builder`), `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`WorkoutSetBuilderScreen`](../lib/workout_sets/workout_set_builder_screen.dart), [`LiveSessionScreen`](../lib/shared_sessions/live_session_screen.dart)
- **API:** [`WorkoutSetEndpoints`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs), [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs)
- **Testy:** [`workout_set_trainer_screens_test.dart`](../test/workout_set_trainer_screens_test.dart), [`live_session_screen_test.dart`](../test/live_session_screen_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `S-02`, `S-03`

<a id="przypisanie-wielu-osobom"></a>
### Przypisanie jednego planu wielu osobom

- **Ekrany:** `Przypisz zestaw` (`t_assign`), `Podopieczny` (`t_trainee`), `Dziś / trening` (`c_home`)
- **Mobile:** [`AssignWorkoutSetScreen`](../lib/workout_sets/assign_workout_set_screen.dart), [`WorkoutSetController`](../lib/workout_sets/workout_set_controller.dart), [`TraineeAssignedWorkoutSetView`](../lib/workout_sets/trainee_assigned_workout_set_view.dart)
- **API:** [`WorkoutSetEndpoints`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs)
- **Testy:** [`workout_set_trainer_screens_test.dart`](../test/workout_set_trainer_screens_test.dart), [`trainee_assigned_workout_sets_screen_test.dart`](../test/trainee_assigned_workout_sets_screen_test.dart), [`WorkoutSetEndpointTests.cs`](../../api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs)
- **Wymagania:** `FR-008`, `FR-010`, `S-02`

## Trening na żywo

<a id="plan-na-dzis"></a>
### Przejrzysty plan na dzisiejszy trening

- **Ekrany:** `Dziś / trening` (`c_home`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`TraineeHomeScreen`](../lib/relationships/trainee_home_screen.dart), [`TraineeAssignedWorkoutSetView`](../lib/workout_sets/trainee_assigned_workout_set_view.dart)
- **API:** [`WorkoutSetEndpoints`](../../api/LiftMate.Api/WorkoutSets/WorkoutSetEndpoints.cs), [`PairingEndpoints`](../../api/LiftMate.Api/Auth/PairingEndpoints.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`trainee_assigned_workout_sets_screen_test.dart`](../test/trainee_assigned_workout_sets_screen_test.dart), [`WorkoutSetEndpointTests.cs`](../../api/LiftMate.Api.Tests/WorkoutSets/WorkoutSetEndpointTests.cs)
- **Wymagania:** `FR-005`, `FR-010`, `S-02`

<a id="start-z-przypisanego-planu"></a>
### Start sesji bez przepisywania planu

- **Ekrany:** `Podopieczny` (`t_trainee`), `Dziś / trening` (`c_home`), `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart), [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart), [`SharedSessionApiClient`](../lib/shared_sessions/shared_session_api_client.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs), [`SharedSessionMapping`](../../api/LiftMate.Api/SharedSessions/SharedSessionMapping.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`shared_session_controller_test.dart`](../test/shared_session_controller_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-010`, `FR-012`, `S-03`

<a id="synchronizacja-realtime"></a>
### Jedna sesja synchronizowana w czasie rzeczywistym

- **Ekrany:** `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`LiveSessionScreen`](../lib/shared_sessions/live_session_screen.dart), [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart), [`SharedSessionRealtimeClient`](../lib/shared_sessions/shared_session_realtime_client.dart)
- **API:** [`SharedSessionHub`](../../api/LiftMate.Api/SharedSessions/SharedSessionHub.cs), [`SharedSessionBroadcaster`](../../api/LiftMate.Api/SharedSessions/SharedSessionBroadcaster.cs), [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs)
- **Testy:** [`live_session_screen_test.dart`](../test/live_session_screen_test.dart), [`shared_session_realtime_client_test.dart`](../test/shared_session_realtime_client_test.dart), [`SharedSessionHubTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionHubTests.cs), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-012`, `US-03`, `F-03`, `S-04`

<a id="prowadzenie-przez-trenera"></a>
### Edycja przez trenera i czytelny widok podopiecznego

- **Ekrany:** `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`LiveSessionScreen`](../lib/shared_sessions/live_session_screen.dart), [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs), [`SharedSessionAccess`](../../api/LiftMate.Api/SharedSessions/SharedSessionAccess.cs)
- **Testy:** [`live_session_screen_test.dart`](../test/live_session_screen_test.dart), [`shared_session_controller_test.dart`](../test/shared_session_controller_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-004`, `FR-012`, `S-04`

<a id="samodzielny-trening"></a>
### Samodzielny trening z edycją własnych wartości

- **Ekrany:** `Dziś / trening` (`c_home`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`TraineeHomeScreen`](../lib/relationships/trainee_home_screen.dart), [`LiveSessionScreen`](../lib/shared_sessions/live_session_screen.dart), [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs)
- **Testy:** [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`live_session_screen_test.dart`](../test/live_session_screen_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-005`, `FR-011`, `S-06`

<a id="ciaglosc-sesji"></a>
### Automatyczny powrót do aktywnej sesji

- **Ekrany:** `Dziś / trening` (`c_home`), `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart), [`SharedSessionRealtimeClient`](../lib/shared_sessions/shared_session_realtime_client.dart), [`AuthenticatedRelationshipShell`](../lib/relationships/authenticated_relationship_shell.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs), [`SharedSessionHub`](../../api/LiftMate.Api/SharedSessions/SharedSessionHub.cs)
- **Testy:** [`shared_session_controller_test.dart`](../test/shared_session_controller_test.dart), [`shared_session_realtime_client_test.dart`](../test/shared_session_realtime_client_test.dart), [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart)
- **Wymagania:** `F-03`, `S-04`

<a id="sterowanie-przebiegiem"></a>
### Kontrola serii, ćwiczeń i odpoczynku

- **Ekrany:** `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`)
- **Mobile:** [`LiveSessionScreen`](../lib/shared_sessions/live_session_screen.dart), [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs)
- **Testy:** [`live_session_screen_test.dart`](../test/live_session_screen_test.dart), [`shared_session_controller_test.dart`](../test/shared_session_controller_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs)
- **Wymagania:** `FR-011`, `S-04`

<a id="progres-na-kolejna-sesje"></a>
### Zapis wyników jako punkt startowy kolejnej sesji

- **Ekrany:** `Sesja na żywo` (`t_live`), `Sesja (widok)` (`c_live`), `Szczegóły sesji` (`c_session`), `Progres ćwiczenia` (`c_exprogress`)
- **Mobile:** [`SharedSessionController`](../lib/shared_sessions/shared_session_controller.dart), [`TrainingHistoryFlow`](../lib/training_history/training_history_flow.dart), [`WorkoutSetController`](../lib/workout_sets/workout_set_controller.dart)
- **API:** [`SharedSessionEndpoints`](../../api/LiftMate.Api/SharedSessions/SharedSessionEndpoints.cs), [`WorkoutProgressProjector`](../../api/LiftMate.Api/TrainingProgress/WorkoutProgressProjector.cs)
- **Testy:** [`shared_session_controller_test.dart`](../test/shared_session_controller_test.dart), [`training_history_flow_test.dart`](../test/training_history_flow_test.dart), [`SharedSessionEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/SharedSessionEndpointTests.cs), [`WorkoutProgressPersistenceTests.cs`](../../api/LiftMate.Api.Tests/TrainingProgress/WorkoutProgressPersistenceTests.cs)
- **Wymagania:** `FR-011`, `US-02`, `S-05`

## Feedback, historia i progres

<a id="feedback-po-treningu"></a>
### Ocena samopoczucia po treningu

- **Ekrany:** `Feedback po treningu` (`feedback`), `Szczegóły sesji` (`c_session`)
- **Mobile:** [`PostWorkoutFeedbackScreen`](../lib/post_workout_feedback/post_workout_feedback_screen.dart), [`PostWorkoutFeedbackController`](../lib/post_workout_feedback/post_workout_feedback_controller.dart), [`PostWorkoutFeedbackApiClient`](../lib/post_workout_feedback/post_workout_feedback_api_client.dart)
- **API:** [`PostWorkoutFeedbackEndpoints`](../../api/LiftMate.Api/SharedSessions/PostWorkoutFeedbackEndpoints.cs)
- **Testy:** [`post_workout_feedback_screen_test.dart`](../test/post_workout_feedback_screen_test.dart), [`post_workout_feedback_controller_test.dart`](../test/post_workout_feedback_controller_test.dart), [`PostWorkoutFeedbackEndpointTests.cs`](../../api/LiftMate.Api.Tests/SharedSessions/PostWorkoutFeedbackEndpointTests.cs)
- **Wymagania:** `S-09`

<a id="feedback-dla-trenera"></a>
### Feedback dostępny trenerowi bez możliwości zmiany

- **Ekrany:** `Podopieczny` (`t_trainee`), `Szczegóły sesji` (`c_session`)
- **Mobile:** [`TrainingHistoryFlow`](../lib/training_history/training_history_flow.dart), [`TrainerTraineeDetailScreen`](../lib/relationships/trainer_trainee_detail_screen.dart)
- **API:** [`TrainingHistoryEndpoints`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs), [`TrainingHistoryAccess`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryAccess.cs)
- **Testy:** [`training_history_flow_test.dart`](../test/training_history_flow_test.dart), [`post_auth_relationship_screen_test.dart`](../test/post_auth_relationship_screen_test.dart), [`TrainingHistoryEndpointTests.cs`](../../api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs)
- **Wymagania:** `S-09`

<a id="historia-sesji"></a>
### Historia treningów od listy do każdej serii

- **Ekrany:** `Historia treningów` (`c_history`), `Szczegóły sesji` (`c_session`), `Podopieczny` (`t_trainee`)
- **Mobile:** [`TrainingHistoryFlow`](../lib/training_history/training_history_flow.dart), [`TrainingHistoryController`](../lib/training_history/training_history_controller.dart), [`TrainingHistoryApiClient`](../lib/training_history/training_history_api_client.dart)
- **API:** [`TrainingHistoryEndpoints`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs), [`TrainingHistoryAccess`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryAccess.cs)
- **Testy:** [`training_history_flow_test.dart`](../test/training_history_flow_test.dart), [`training_history_controller_test.dart`](../test/training_history_controller_test.dart), [`TrainingHistoryEndpointTests.cs`](../../api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs)
- **Wymagania:** `FR-004`, `FR-005`, `FR-011`, `US-02`

<a id="progres-cwiczenia"></a>
### Progres pojedynczego ćwiczenia w czasie

- **Ekrany:** `Szczegóły sesji` (`c_session`), `Progres ćwiczenia` (`c_exprogress`)
- **Mobile:** [`TrainingHistoryFlow`](../lib/training_history/training_history_flow.dart), [`TrainingHistoryController`](../lib/training_history/training_history_controller.dart), [`ExerciseProgress`](../lib/training_history/training_history_models.dart)
- **API:** [`TrainingHistoryEndpoints`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryEndpoints.cs), [`ExerciseProgressResponse`](../../api/LiftMate.Api/TrainingHistory/TrainingHistoryContracts.cs)
- **Testy:** [`training_history_flow_test.dart`](../test/training_history_flow_test.dart), [`training_history_models_test.dart`](../test/training_history_models_test.dart), [`TrainingHistoryEndpointTests.cs`](../../api/LiftMate.Api.Tests/TrainingHistory/TrainingHistoryEndpointTests.cs)
- **Wymagania:** `FR-011`, `US-02`, `S-05`

## Indeks ekranów

| Grupa | Ekran | ID | Prezentowane funkcje |
|---|---|---|---|
| Onboarding | Powitanie | `welcome` | [Start dopasowany do roli użytkownika](#start-i-wybor-roli), [Trwała i automatycznie odnawiana sesja](#trwala-sesja) |
| Onboarding | Wybór roli | `role` | [Start dopasowany do roli użytkownika](#start-i-wybor-roli), [Rejestracja chroniona kodem beta](#rejestracja-beta), [Dostęp ograniczony rolą i relacją](#granice-dostepu) |
| Onboarding | Rejestracja | `signup` | [Rejestracja chroniona kodem beta](#rejestracja-beta), [Czytelny formularz z polską walidacją](#czytelny-formularz), [Trwała i automatycznie odnawiana sesja](#trwala-sesja) |
| Onboarding | Parowanie | `pair` | [Parowanie kont za pomocą kodu](#parowanie-kodem), [Kopiowanie kodu z natychmiastowym potwierdzeniem](#kopiowanie-kodu) |
| Trener | Pulpit | `t_dash` | [Parowanie kont za pomocą kodu](#parowanie-kodem), [Kopiowanie kodu z natychmiastowym potwierdzeniem](#kopiowanie-kodu), [Dostęp ograniczony rolą i relacją](#granice-dostepu), [Pulpit wielu podopiecznych](#pulpit-podopiecznych), [Aktualna i najlepsza seria tygodniowa](#regularnosc-tygodniowa), [Szczegóły podopiecznego jako centrum decyzji](#centrum-podopiecznego) |
| Trener | Podopieczny | `t_trainee` | [Dostęp ograniczony rolą i relacją](#granice-dostepu), [Aktualna i najlepsza seria tygodniowa](#regularnosc-tygodniowa), [Szczegóły podopiecznego jako centrum decyzji](#centrum-podopiecznego), [Podpowiedzi o stagnacji i samopoczuciu](#podpowiedzi-trenerskie), [Przypisanie jednego planu wielu osobom](#przypisanie-wielu-osobom), [Start sesji bez przepisywania planu](#start-z-przypisanego-planu), [Feedback dostępny trenerowi bez możliwości zmiany](#feedback-dla-trenera), [Historia treningów od listy do każdej serii](#historia-sesji) |
| Trener | Biblioteka zestawów | `t_sets` | [Wielokrotnego użytku biblioteka zestawów](#biblioteka-zestawow), [Edycja i bezpieczne usuwanie zestawów](#bezpieczna-edycja-zestawu) |
| Trener | Kreator zestawu | `t_builder` | [Wielokrotnego użytku biblioteka zestawów](#biblioteka-zestawow), [Edycja i bezpieczne usuwanie zestawów](#bezpieczna-edycja-zestawu), [Trzy typy ćwiczeń i właściwe parametry](#typy-cwiczen), [Konfigurowalny czas odpoczynku](#odpoczynek-w-planie) |
| Trener | Dodaj ćwiczenie | `t_addex` | [Trzy typy ćwiczeń i właściwe parametry](#typy-cwiczen) |
| Trener | Przypisz zestaw | `t_assign` | [Przypisanie jednego planu wielu osobom](#przypisanie-wielu-osobom) |
| Trener | Sesja na żywo | `t_live` | [Konfigurowalny czas odpoczynku](#odpoczynek-w-planie), [Start sesji bez przepisywania planu](#start-z-przypisanego-planu), [Jedna sesja synchronizowana w czasie rzeczywistym](#synchronizacja-realtime), [Edycja przez trenera i czytelny widok podopiecznego](#prowadzenie-przez-trenera), [Automatyczny powrót do aktywnej sesji](#ciaglosc-sesji), [Kontrola serii, ćwiczeń i odpoczynku](#sterowanie-przebiegiem), [Zapis wyników jako punkt startowy kolejnej sesji](#progres-na-kolejna-sesje) |
| Podopieczny | Dziś / trening | `c_home` | [Parowanie kont za pomocą kodu](#parowanie-kodem), [Dostęp ograniczony rolą i relacją](#granice-dostepu), [Aktualna i najlepsza seria tygodniowa](#regularnosc-tygodniowa), [Przypisanie jednego planu wielu osobom](#przypisanie-wielu-osobom), [Przejrzysty plan na dzisiejszy trening](#plan-na-dzis), [Start sesji bez przepisywania planu](#start-z-przypisanego-planu), [Samodzielny trening z edycją własnych wartości](#samodzielny-trening), [Automatyczny powrót do aktywnej sesji](#ciaglosc-sesji) |
| Podopieczny | Sesja (widok) | `c_live` | [Konfigurowalny czas odpoczynku](#odpoczynek-w-planie), [Przejrzysty plan na dzisiejszy trening](#plan-na-dzis), [Start sesji bez przepisywania planu](#start-z-przypisanego-planu), [Jedna sesja synchronizowana w czasie rzeczywistym](#synchronizacja-realtime), [Edycja przez trenera i czytelny widok podopiecznego](#prowadzenie-przez-trenera), [Samodzielny trening z edycją własnych wartości](#samodzielny-trening), [Automatyczny powrót do aktywnej sesji](#ciaglosc-sesji), [Kontrola serii, ćwiczeń i odpoczynku](#sterowanie-przebiegiem), [Zapis wyników jako punkt startowy kolejnej sesji](#progres-na-kolejna-sesje) |
| Podopieczny | Feedback po treningu | `feedback` | [Ocena samopoczucia po treningu](#feedback-po-treningu) |
| Podopieczny | Historia treningów | `c_history` | [Historia treningów od listy do każdej serii](#historia-sesji) |
| Podopieczny | Szczegóły sesji | `c_session` | [Podpowiedzi o stagnacji i samopoczuciu](#podpowiedzi-trenerskie), [Zapis wyników jako punkt startowy kolejnej sesji](#progres-na-kolejna-sesje), [Ocena samopoczucia po treningu](#feedback-po-treningu), [Feedback dostępny trenerowi bez możliwości zmiany](#feedback-dla-trenera), [Historia treningów od listy do każdej serii](#historia-sesji), [Progres pojedynczego ćwiczenia w czasie](#progres-cwiczenia) |
| Podopieczny | Progres ćwiczenia | `c_exprogress` | [Zapis wyników jako punkt startowy kolejnej sesji](#progres-na-kolejna-sesje), [Progres pojedynczego ćwiczenia w czasie](#progres-cwiczenia) |
