import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_api_client.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_controller.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_models.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_screen.dart';

void main() {
  testWidgets('rating labels do not overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller(_FakeFeedbackApiClient.success());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, textScaleFactor: 1.1));

    expect(find.text('Bardzo dobrze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a rating and exposes all rating semantics', (
    tester,
  ) async {
    final controller = _controller(_FakeFeedbackApiClient.success());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Wyślij feedback'),
    );
    expect(submit.onPressed, isNull);
    expect(find.bySemanticsLabel('1 Bardzo źle'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Źle'), findsOneWidget);
    expect(find.bySemanticsLabel('3 W porządku'), findsOneWidget);
    expect(find.bySemanticsLabel('4 Dobrze'), findsOneWidget);
    expect(find.bySemanticsLabel('5 Bardzo dobrze'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('feedback-rating-4')));
    await tester.pump();

    expect(controller.state.wellbeingRating, 4);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Wyślij feedback'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('comment counter enforces the 1000 character limit', (
    tester,
  ) async {
    final controller = _controller(_FakeFeedbackApiClient.success());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));

    expect(find.text('0/1000'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('feedback-comment')),
      'x' * 1001,
    );
    await tester.pump();

    expect(controller.state.comment, hasLength(1000));
    expect(find.text('1000/1000'), findsOneWidget);
  });

  testWidgets('error preserves fields and retry submits the same data', (
    tester,
  ) async {
    final apiClient = _FakeFeedbackApiClient.failOnce();
    final controller = _controller(apiClient);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('feedback-rating-2')));
    await tester.enterText(
      find.byKey(const ValueKey('feedback-comment')),
      'Ciężki trening',
    );
    await tester.tap(find.text('Wyślij feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Brak połączenia.'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
    expect(controller.state.wellbeingRating, 2);
    expect(controller.state.comment, 'Ciężki trening');

    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pump();

    expect(apiClient.submitCalls, 2);
    expect(apiClient.lastRequest?.wellbeingRating, 2);
    expect(apiClient.lastRequest?.comment, 'Ciężki trening');
    expect(find.text('Dzięki! Feedback został zapisany.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('loading blocks duplicate submit', (tester) async {
    final apiClient = _CompletingFeedbackApiClient();
    final controller = _controller(apiClient);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('feedback-rating-5')));
    await tester.pump();
    await tester.tap(find.text('Wyślij feedback'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Wyślij feedback'),
    );
    expect(submit.onPressed, isNull);
    await tester.tap(find.text('Wyślij feedback'), warnIfMissed: false);
    expect(apiClient.submitCalls, 1);

    apiClient.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets(
    'shows success confirmation before invoking navigation callback',
    (tester) async {
      final controller = _controller(_FakeFeedbackApiClient.success());
      addTearDown(controller.dispose);
      var saved = false;

      await tester.pumpWidget(
        _app(controller, onSaved: () async => saved = true),
      );
      await tester.tap(find.byKey(const ValueKey('feedback-rating-4')));
      await tester.pump();
      await tester.tap(find.text('Wyślij feedback'));
      await tester.pump();

      expect(find.text('Dzięki! Feedback został zapisany.'), findsOneWidget);
      expect(saved, isFalse);

      await tester.pump(const Duration(milliseconds: 700));
      expect(saved, isTrue);
    },
  );

  testWidgets('skip CTA and system back require confirmation', (tester) async {
    final controller = _controller(_FakeFeedbackApiClient.success());
    addTearDown(controller.dispose);
    var skipped = 0;

    await tester.pumpWidget(
      _app(controller, onSkipped: () async => skipped += 1),
    );

    await tester.tap(find.text('Pomiń'));
    await tester.pumpAndSettle();
    expect(find.text('Pominąć feedback?'), findsOneWidget);
    await tester.tap(find.text('Wróć'));
    await tester.pumpAndSettle();
    expect(skipped, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pominąć feedback?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Pomiń').last);
    await tester.pumpAndSettle();
    expect(skipped, 1);
  });
}

PostWorkoutFeedbackController _controller(
  PostWorkoutFeedbackApiClient apiClient,
) {
  return PostWorkoutFeedbackController(
    sessionId: 'session-1',
    apiClient: apiClient,
    accessTokenProvider: () => 'access-token',
  );
}

Widget _app(
  PostWorkoutFeedbackController controller, {
  Future<void> Function()? onSaved,
  Future<void> Function()? onSkipped,
  double textScaleFactor = 1,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: child!,
    ),
    home: PostWorkoutFeedbackScreen(
      controller: controller,
      onSaved: onSaved ?? () async {},
      onSkipped: onSkipped ?? () async {},
    ),
  );
}

class _FakeFeedbackApiClient extends PostWorkoutFeedbackApiClient {
  _FakeFeedbackApiClient._({this.failureCount = 0})
    : super(baseUrl: 'https://api.example.test');

  factory _FakeFeedbackApiClient.success() => _FakeFeedbackApiClient._();

  factory _FakeFeedbackApiClient.failOnce() =>
      _FakeFeedbackApiClient._(failureCount: 1);

  int failureCount;
  int submitCalls = 0;
  PostWorkoutFeedbackRequest? lastRequest;

  @override
  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>> submit({
    required String accessToken,
    required String sessionId,
    required PostWorkoutFeedbackRequest request,
  }) async {
    submitCalls += 1;
    lastRequest = request;
    if (failureCount > 0) {
      failureCount -= 1;
      return const PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.offline,
        message: 'Brak połączenia.',
      );
    }
    return PostWorkoutFeedbackApiResult(
      status: PostWorkoutFeedbackApiStatus.success,
      message: 'ok',
      statusCode: 201,
      data: PostWorkoutFeedbackResponse(
        sharedSessionId: sessionId,
        wellbeingRating: request.wellbeingRating,
        comment: request.comment,
        submittedAt: DateTime.utc(2026, 6, 24, 12),
      ),
    );
  }
}

class _CompletingFeedbackApiClient extends PostWorkoutFeedbackApiClient {
  _CompletingFeedbackApiClient() : super(baseUrl: 'https://api.example.test');

  final _completer =
      Completer<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>>();
  int submitCalls = 0;

  @override
  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>> submit({
    required String accessToken,
    required String sessionId,
    required PostWorkoutFeedbackRequest request,
  }) {
    submitCalls += 1;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.success,
        message: 'ok',
        statusCode: 201,
        data: PostWorkoutFeedbackResponse(
          sharedSessionId: 'session-1',
          wellbeingRating: 5,
          comment: null,
          submittedAt: DateTime.utc(2026, 6, 24, 12),
        ),
      ),
    );
  }
}
