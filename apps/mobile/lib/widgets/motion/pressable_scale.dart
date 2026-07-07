import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';

enum PressableHaptic { selection, none }

class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.94,
    this.haptic = PressableHaptic.selection,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final PressableHaptic haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    if (widget.haptic == PressableHaptic.selection) {
      HapticFeedback.selectionClick();
    }
  }

  void _release() {
    if (!mounted || !_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final transformsEnabled = LiftMateMotion.transformsEnabled(context);
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: transformsEnabled && _pressed ? widget.pressedScale : 1,
        duration: LiftMateMotion.duration(context, LiftMateMotion.fast),
        curve: LiftMateMotion.spring,
        child: widget.child,
      ),
    );
  }
}
