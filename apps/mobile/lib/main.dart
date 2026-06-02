import 'package:flutter/material.dart';

import 'app_config.dart';
import 'api_health_client.dart';
import 'auth/auth_api_client.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screen.dart';
import 'auth/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  final authApiClient = AuthApiClient(baseUrl: config.apiBaseUrl);
  runApp(
    MainApp(
      apiHealthClient: ApiHealthClient(baseUrl: config.apiBaseUrl),
      authApiClient: authApiClient,
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
    required this.authController,
    super.key,
  });

  final ApiHealthClient apiHealthClient;
  final AuthApiClient authApiClient;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthScreen(
        authController: authController,
        authApiClient: authApiClient,
        healthUri: apiHealthClient.healthUri,
        checkHealth: apiHealthClient.check,
      ),
    );
  }
}
