import 'package:flutter/material.dart';

import 'app_config.dart';
import 'api_health_client.dart';
import 'api_smoke_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  runApp(
    MainApp(
      apiHealthClient: ApiHealthClient(baseUrl: config.apiBaseUrl),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    required this.apiHealthClient,
    super.key,
  });

  final ApiHealthClient apiHealthClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ApiSmokeScreen(
        healthUri: apiHealthClient.healthUri,
        checkHealth: apiHealthClient.check,
      ),
    );
  }
}
