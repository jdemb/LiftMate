import 'package:flutter/material.dart';

import 'app_config.dart';
import 'api_health_client.dart';
import 'auth/auth_api_client.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screen.dart';
import 'auth/token_store.dart';
import 'shared_sessions/shared_session_api_client.dart';
import 'shared_sessions/shared_session_realtime_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  final authApiClient = AuthApiClient(baseUrl: config.apiBaseUrl);
  final sharedSessionApiClient = SharedSessionApiClient(baseUrl: config.apiBaseUrl);
  runApp(
    MainApp(
      apiHealthClient: ApiHealthClient(baseUrl: config.apiBaseUrl),
      authApiClient: authApiClient,
      sharedSessionApiClient: sharedSessionApiClient,
      sharedSessionRealtimeClientFactory: () =>
          SignalRSharedSessionRealtimeClient(baseUrl: config.apiBaseUrl),
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: SecureTokenStore(),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    required this.apiHealthClient,
    required this.authApiClient,
    required this.sharedSessionApiClient,
    required this.sharedSessionRealtimeClientFactory,
    required this.authController,
    super.key,
  });

  final ApiHealthClient apiHealthClient;
  final AuthApiClient authApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final SharedSessionRealtimeClientFactory sharedSessionRealtimeClientFactory;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthScreen(
        authController: authController,
        authApiClient: authApiClient,
        sharedSessionApiClient: sharedSessionApiClient,
        sharedSessionRealtimeClientFactory: sharedSessionRealtimeClientFactory,
        healthUri: apiHealthClient.healthUri,
        checkHealth: apiHealthClient.check,
      ),
    );
  }
}
