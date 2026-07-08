import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/widgets/motion/pressable_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('press scales the child, emits one haptic and preserves tap', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    var taps = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressableScale(
            key: const ValueKey('pressable'),
            child: FilledButton(
              onPressed: () => taps += 1,
              child: const Text('Action'),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(_scaleOf(tester, find.byKey(const ValueKey('pressable'))), closeTo(0.94, 0.001));
    expect(
      platformCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(_scaleOf(tester, find.byKey(const ValueKey('pressable'))), closeTo(1, 0.001));
  });

  testWidgets('disabled pressable neither scales nor emits haptic', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PressableScale(
            key: ValueKey('pressable'),
            enabled: false,
            child: Text('Disabled'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Disabled')),
    );
    await tester.pump(const Duration(milliseconds: 180));

    expect(_scaleOf(tester, find.byKey(const ValueKey('pressable'))), 1);
    expect(
      platformCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
      isEmpty,
    );

    await gesture.up();
  });

  testWidgets('reduced motion keeps scale at one but preserves haptic', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: PressableScale(
              key: ValueKey('pressable'),
              child: Text('Reduced'),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Reduced')));
    await tester.pump();

    expect(_scaleOf(tester, find.byKey(const ValueKey('pressable'))), 1);
    expect(
      platformCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );

    await gesture.up();
  });
}

double _scaleOf(WidgetTester tester, Finder ancestor) {
  final transitions = find.descendant(
    of: ancestor,
    matching: find.byType(ScaleTransition),
  );
  return tester.widget<ScaleTransition>(transitions.first).scale.value;
}
