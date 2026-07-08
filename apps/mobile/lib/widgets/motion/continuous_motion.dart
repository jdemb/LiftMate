import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';

class ContinuousSheen extends StatefulWidget {
  const ContinuousSheen({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
    super.key,
  });

  static const transformKey = ValueKey('continuous-sheen-transform');

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<ContinuousSheen> createState() => _ContinuousSheenState();
}

class _ContinuousSheenState extends State<ContinuousSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  Timer? _startDelay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  void _syncLoop() {
    if (MotionScope.continuousAnimationsEnabled(context)) {
      if (!_controller.isAnimating && _startDelay == null) {
        _startDelay = Timer(const Duration(milliseconds: 1200), () {
          _startDelay = null;
          if (mounted && MotionScope.continuousAnimationsEnabled(context)) {
            _controller.repeat();
          }
        });
      }
      return;
    }
    _startDelay?.cancel();
    _startDelay = null;
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final width = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 0.0;
                        final offset =
                            width * (-0.63 + 2.25 * _controller.value);
                        return Transform.translate(
                          key: ContinuousSheen.transformKey,
                          offset: Offset(offset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: width * 0.45,
                              child: Transform(
                                transform: Matrix4.skewX(-20 * math.pi / 180),
                                alignment: Alignment.center,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0x52FFFFFF),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AmbientOrb extends StatefulWidget {
  const AmbientOrb({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    super.key,
  });

  static const transformKey = ValueKey('ambient-orb-transform');

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<AmbientOrb> createState() => _AmbientOrbState();
}

class _AmbientOrbState extends State<AmbientOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final Animation<Offset> _offset = TweenSequence<Offset>([
    TweenSequenceItem(
      tween: Tween(
        begin: Offset.zero,
        end: const Offset(7, -16),
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: const Offset(7, -16),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 50,
    ),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.continuousAnimationsEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Transform.translate(
                      key: AmbientOrb.transformKey,
                      offset: _offset.value,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: FractionallySizedBox(
                          widthFactor: 0.62,
                          heightFactor: 0.9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(
                                    0xFF3A82F6,
                                  ).withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
