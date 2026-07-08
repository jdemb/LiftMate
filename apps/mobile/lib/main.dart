import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth/auth_api_client.dart';
import 'auth/authenticated_http_client.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screen.dart';
import 'auth/onboarding_state_store.dart';
import 'auth/token_store.dart';
import 'post_workout_feedback/post_workout_feedback_api_client.dart';
import 'relationships/relationship_api_client.dart';
import 'shared_sessions/shared_session_api_client.dart';
import 'shared_sessions/shared_session_realtime_client.dart';
import 'training_history/training_history_api_client.dart';
import 'trainer_guidance/trainer_guidance_api_client.dart';
import 'theme/motion.dart';
import 'workout_sets/workout_set_api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  final authApiClient = AuthApiClient(baseUrl: config.apiBaseUrl);
  final authController = AuthController(
    authApiClient: authApiClient,
    tokenStore: SecureTokenStore(),
  );
  final authenticatedHttpClient = AuthenticatedHttpClient(
    authController: authController,
    inner: http.Client(),
  );
  final relationshipApiClient = RelationshipApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  final workoutSetApiClient = WorkoutSetApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  final sharedSessionApiClient = SharedSessionApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  final trainingHistoryApiClient = TrainingHistoryApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  final postWorkoutFeedbackApiClient = PostWorkoutFeedbackApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  final trainerGuidanceApiClient = TrainerGuidanceApiClient(
    httpClient: authenticatedHttpClient,
    baseUrl: config.apiBaseUrl,
  );
  runApp(
    MainApp(
      authController: authController,
      onboardingStateStore: SecureOnboardingStateStore(),
      relationshipApiClient: relationshipApiClient,
      workoutSetApiClient: workoutSetApiClient,
      sharedSessionApiClient: sharedSessionApiClient,
      trainingHistoryApiClient: trainingHistoryApiClient,
      trainerGuidanceApiClient: trainerGuidanceApiClient,
      postWorkoutFeedbackApiClient: postWorkoutFeedbackApiClient,
      sharedSessionRealtimeClientFactory: () {
        return SignalRSharedSessionRealtimeClient(
          baseUrl: config.apiBaseUrl,
          accessTokenProvider: () async {
            final accessToken = await authController.getValidAccessToken();
            if (accessToken == null) {
              throw StateError('User is not authenticated.');
            }
            return accessToken;
          },
        );
      },
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    required this.authController,
    required this.onboardingStateStore,
    required this.relationshipApiClient,
    required this.workoutSetApiClient,
    required this.sharedSessionApiClient,
    required this.trainingHistoryApiClient,
    required this.trainerGuidanceApiClient,
    required this.postWorkoutFeedbackApiClient,
    required this.sharedSessionRealtimeClientFactory,
    super.key,
  });

  final AuthController authController;
  final OnboardingStateStore onboardingStateStore;
  final RelationshipApiClient relationshipApiClient;
  final WorkoutSetApiClient workoutSetApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final TrainingHistoryApiClient trainingHistoryApiClient;
  final TrainerGuidanceApiClient trainerGuidanceApiClient;
  final PostWorkoutFeedbackApiClient postWorkoutFeedbackApiClient;
  final SharedSessionRealtimeClientFactory sharedSessionRealtimeClientFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _liftMateTheme(),
      builder: (context, child) => MotionScope(
        allowContinuousAnimations: true,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AuthScreen(
        authController: authController,
        onboardingStateStore: onboardingStateStore,
        relationshipApiClient: relationshipApiClient,
        workoutSetApiClient: workoutSetApiClient,
        sharedSessionApiClient: sharedSessionApiClient,
        trainingHistoryApiClient: trainingHistoryApiClient,
        trainerGuidanceApiClient: trainerGuidanceApiClient,
        postWorkoutFeedbackApiClient: postWorkoutFeedbackApiClient,
        sharedSessionRealtimeClientFactory: sharedSessionRealtimeClientFactory,
      ),
    );
  }
}

ThemeData _liftMateTheme() {
  const primary = Color(0xFF3A82F6);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF101216),
    fontFamily: 'Manrope',
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: const Color(0xFFF3F4F6),
      displayColor: const Color(0xFFF3F4F6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF191C22),
      labelStyle: const TextStyle(
        color: Color(0xFF969BA3),
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF3F4F6),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
