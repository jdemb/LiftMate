import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class LiftMateMotion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 300);
  static const screen = Duration(milliseconds: 500);
  static const reveal = Duration(milliseconds: 550);
  static const staggerStep = Duration(milliseconds: 60);
  static const maxStaggerPosition = 10;

  static const standard = Cubic(0.16, 0.84, 0.44, 1);
  static const spring = Curves.easeOutBack;

  static bool animationsDisabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static bool transformsEnabled(BuildContext context) {
    return !animationsDisabled(context);
  }

  static Duration duration(BuildContext context, Duration normal) {
    return animationsDisabled(context) ? Duration.zero : normal;
  }

  static int staggerPosition(int position) {
    return math.min(math.max(position, 0), maxStaggerPosition);
  }
}

class MotionScope extends InheritedWidget {
  const MotionScope({
    required this.allowContinuousAnimations,
    required super.child,
    super.key,
  });

  final bool allowContinuousAnimations;

  static MotionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MotionScope>();
  }

  static bool continuousAnimationsEnabled(BuildContext context) {
    return maybeOf(context)?.allowContinuousAnimations == true &&
        !LiftMateMotion.animationsDisabled(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) {
    return allowContinuousAnimations != oldWidget.allowContinuousAnimations;
  }
}
