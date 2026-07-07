import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/theme/motion.dart';
import 'package:liftmate/widgets/motion/motion_reveals.dart';

void main() {
  test('motion tokens match the LiftMate prototype', () {
    expect(LiftMateMotion.fast, const Duration(milliseconds: 180));
    expect(LiftMateMotion.base, const Duration(milliseconds: 300));
    expect(LiftMateMotion.screen, const Duration(milliseconds: 500));
    expect(LiftMateMotion.reveal, const Duration(milliseconds: 550));
    expect(LiftMateMotion.staggerStep, const Duration(milliseconds: 60));
    expect(LiftMateMotion.maxStaggerPosition, 10);
    expect(LiftMateMotion.standard, const Cubic(0.16, 0.84, 0.44, 1));
    expect(LiftMateMotion.spring, Curves.easeOutBack);
  });

  testWidgets('reduced motion resolves durations to zero', (tester) async {
    late Duration duration;
    late bool transformsEnabled;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = LiftMateMotion.duration(
                context,
                LiftMateMotion.screen,
              );
              transformsEnabled = LiftMateMotion.transformsEnabled(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(duration, Duration.zero);
    expect(transformsEnabled, isFalse);
  });

  testWidgets('continuous motion requires an enabled production scope', (
    tester,
  ) async {
    Future<bool> readContinuousMotion({
      required bool includeScope,
      bool disableAnimations = false,
      bool tickerEnabled = true,
    }) async {
      late bool enabled;
      Widget child = Builder(
        builder: (context) {
          enabled = MotionScope.continuousAnimationsEnabled(context);
          return const SizedBox();
        },
      );
      child = TickerMode(enabled: tickerEnabled, child: child);
      if (includeScope) {
        child = MotionScope(allowContinuousAnimations: true, child: child);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: child,
          ),
        ),
      );
      return enabled;
    }

    expect(await readContinuousMotion(includeScope: false), isFalse);
    expect(await readContinuousMotion(includeScope: true), isTrue);
    expect(
      await readContinuousMotion(
        includeScope: true,
        disableAnimations: true,
      ),
      isFalse,
    );
    expect(
      await readContinuousMotion(
        includeScope: true,
        tickerEnabled: false,
      ),
      isFalse,
    );
  });

  test('stagger positions are capped after the tenth item', () {
    expect(LiftMateMotion.staggerPosition(0), 0);
    expect(LiftMateMotion.staggerPosition(8), 8);
    expect(LiftMateMotion.staggerPosition(10), 10);
    expect(LiftMateMotion.staggerPosition(25), 10);
  });

  testWidgets('same view key updates without an outgoing transition', (
    tester,
  ) async {
    final value = ValueNotifier(0);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: value,
          builder: (context, current, _) => MotionSwitcher(
            child: KeyedSubtree(
              key: const ValueKey('stable-view'),
              child: Text('value-$current'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    value.value = 1;
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(const ValueKey('stable-view')), findsOneWidget);
    expect(find.text('value-0'), findsNothing);
    expect(find.text('value-1'), findsOneWidget);
  });

  testWidgets('reduced motion switches views immediately', (tester) async {
    final value = ValueNotifier(0);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<int>(
            valueListenable: value,
            builder: (context, current, _) => MotionSwitcher(
              child: Text('view-$current', key: ValueKey(current)),
            ),
          ),
        ),
      ),
    );

    value.value = 1;
    await tester.pump();

    expect(find.text('view-0'), findsNothing);
    expect(find.text('view-1'), findsOneWidget);
  });
}
