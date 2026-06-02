import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/api_health_client.dart';
import 'package:liftmate/api_smoke_screen.dart';

void main() {
  const endpoint = 'https://api.example.test/health';

  testWidgets('shows checking state while health check is in flight', (tester) async {
    final completer = Completer<ApiHealthResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: ApiSmokeScreen(
          healthUri: Uri.parse(endpoint),
          checkHealth: () => completer.future,
        ),
      ),
    );

    expect(find.text('Checking API'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(endpoint), findsOneWidget);

    completer.complete(
      ApiHealthResult(
        status: ApiHealthStatus.online,
        checkedUri: Uri.parse(endpoint),
        message: 'API is reachable.',
        statusCode: 200,
      ),
    );
    await tester.pump();
  });

  testWidgets('shows online state when health check succeeds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ApiSmokeScreen(
          healthUri: Uri.parse(endpoint),
          checkHealth: () async => ApiHealthResult(
            status: ApiHealthStatus.online,
            checkedUri: Uri.parse(endpoint),
            message: 'API is reachable.',
            statusCode: 200,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('API online'), findsOneWidget);
    expect(find.text('API is reachable.'), findsOneWidget);
    expect(find.text(endpoint), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows offline state when health check fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ApiSmokeScreen(
          healthUri: Uri.parse(endpoint),
          checkHealth: () async => ApiHealthResult(
            status: ApiHealthStatus.offline,
            checkedUri: Uri.parse(endpoint),
            message: 'API returned HTTP 503.',
            statusCode: 503,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('API offline'), findsOneWidget);
    expect(find.text('API returned HTTP 503.'), findsOneWidget);
  });

  testWidgets('shows error state and retries health check', (tester) async {
    var calls = 0;
    final retryCompleter = Completer<ApiHealthResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: ApiSmokeScreen(
          healthUri: Uri.parse(endpoint),
          checkHealth: () async {
            calls += 1;
            if (calls == 2) {
              return retryCompleter.future;
            }

            return ApiHealthResult(
              status: ApiHealthStatus.error,
              checkedUri: Uri.parse(endpoint),
              message: 'API health check timed out.',
            );
          },
        ),
      ),
    );

    await tester.pump();
    expect(find.text('API error'), findsOneWidget);
    expect(find.text('API health check timed out.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Checking API'), findsOneWidget);

    retryCompleter.complete(
      ApiHealthResult(
        status: ApiHealthStatus.online,
        checkedUri: Uri.parse(endpoint),
        message: 'API is reachable.',
        statusCode: 200,
      ),
    );
    await tester.pump();
    expect(find.text('API online'), findsOneWidget);
    expect(calls, 2);
  });
}
