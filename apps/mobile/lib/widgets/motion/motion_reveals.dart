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

class MotionPop extends StatelessWidget {
  const MotionPop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MotionEntrance(
      duration: LiftMateMotion.reveal,
      verticalOffset: 0,
      scaleFrom: 0.4,
      child: child,
    );
  }
}

class StaggeredReveal extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (LiftMateMotion.animationsDisabled(context)) return child;
    return AnimationConfiguration.staggeredList(
      position: LiftMateMotion.staggerPosition(position),
      duration: LiftMateMotion.reveal,
      child: SlideAnimation(
        verticalOffset: verticalOffset,
        curve: LiftMateMotion.standard,
        child: FadeInAnimation(
          curve: LiftMateMotion.standard,
          child: child,
        ),
      ),
    );
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
      child: child,
    );
  }
}
