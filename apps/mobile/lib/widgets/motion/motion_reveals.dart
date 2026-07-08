import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../theme/motion.dart';

class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    required this.child,
    this.duration = LiftMateMotion.screen,
    this.verticalOffset = 18,
    this.scaleFrom = 0.985,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final double verticalOffset;
  final double scaleFrom;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = LiftMateMotion.duration(context, widget.duration);
    if (_controller.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transformEnabled = LiftMateMotion.transformsEnabled(context);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: LiftMateMotion.standard,
    );
    return FadeTransition(
      opacity: animation,
      alwaysIncludeSemantics: true,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: transformEnabled
              ? Offset(0, widget.verticalOffset / 450)
              : Offset.zero,
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: transformEnabled ? widget.scaleFrom : 1,
            end: 1,
          ).animate(animation),
          child: widget.child,
        ),
      ),
    );
  }
}

class MotionPop extends StatefulWidget {
  const MotionPop({required this.child, super.key});

  final Widget child;

  @override
  State<MotionPop> createState() => _MotionPopState();
}

class _MotionPopState extends State<MotionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.4), weight: 150),
    TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 303),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 247),
  ]).animate(_controller);
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 150),
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 550),
  ]).animate(_controller);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = LiftMateMotion.duration(
      context,
      const Duration(milliseconds: 700),
    );
    if (_controller.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      alwaysIncludeSemantics: true,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class MotionCheckPop extends StatefulWidget {
  const MotionCheckPop({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<MotionCheckPop> createState() => _MotionCheckPopState();
}

class _MotionCheckPopState extends State<MotionCheckPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1.25), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1), weight: 40),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = LiftMateMotion.duration(
      context,
      const Duration(milliseconds: 420),
    );
    if (_controller.duration == Duration.zero || !widget.active) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant MotionCheckPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (oldWidget.active && !widget.active) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    required this.position,
    required this.child,
    this.verticalOffset = 20,
    super.key,
  });

  final int position;
  final Widget child;
  final double verticalOffset;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;
  double _delayFraction = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (LiftMateMotion.animationsDisabled(context)) {
      _controller.value = 1;
      return;
    }

    final delayMilliseconds =
        LiftMateMotion.staggerStep.inMilliseconds *
        LiftMateMotion.staggerPosition(widget.position);
    final totalMilliseconds =
        delayMilliseconds + LiftMateMotion.reveal.inMilliseconds;
    _delayFraction = delayMilliseconds / totalMilliseconds;
    _controller.duration = Duration(milliseconds: totalMilliseconds);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(_delayFraction, 1, curve: LiftMateMotion.standard),
    );
    return AnimationConfiguration.staggeredList(
      position: LiftMateMotion.staggerPosition(widget.position),
      duration: LiftMateMotion.reveal,
      child: SlideAnimation(
        verticalOffset: widget.verticalOffset,
        curve: LiftMateMotion.standard,
        child: FadeTransition(
          opacity: animation,
          alwaysIncludeSemantics: true,
          child: widget.child,
        ),
      ),
    );
  }
}

class MotionStaggerScope extends StatelessWidget {
  const MotionStaggerScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (LiftMateMotion.animationsDisabled(context)) return child;
    return AnimationLimiter(child: child);
  }
}

class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transformEnabled = LiftMateMotion.transformsEnabled(context);
    return AnimatedSwitcher(
      duration: LiftMateMotion.duration(context, LiftMateMotion.screen),
      switchInCurve: LiftMateMotion.standard,
      switchOutCurve: LiftMateMotion.standard,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          alwaysIncludeSemantics: true,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: transformEnabled ? const Offset(0, 0.04) : Offset.zero,
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: transformEnabled ? 0.985 : 1,
                end: 1,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      child: child,
    );
  }
}
