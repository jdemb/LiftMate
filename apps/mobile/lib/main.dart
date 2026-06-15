import 'package:flutter/material.dart';

import 'app_config.dart';
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
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: SecureTokenStore(),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    required this.authController,
    super.key,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _liftMateTheme(),
      home: AuthScreen(
        authController: authController,
      ),
    );
  }
}

ThemeData _liftMateTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2F80ED),
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF07111F),
    fontFamily: 'Roboto',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF101B2D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
