import 'package:flutter/material.dart';

import 'api_health_client.dart';
import 'api_smoke_screen.dart';

void main() {
  runApp(MainApp(apiHealthClient: ApiHealthClient()));
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
