import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../widgets/motion/pressable_scale.dart';

const lmBackground = Color(0xFF101216);
const lmSurface = Color(0xFF191C22);
const lmSurfaceAlt = Color(0xFF22262E);
const lmText = Color(0xFFF3F4F6);
const lmMuted = Color(0xFF969BA3);
const lmMutedDark = Color(0xFF686D75);
const lmBlue = Color(0xFF3A82F6);
const lmBlueSoft = Color(0xFF9CC1FB);
const lmGreen = Color(0xFF21C97A);

String initialsFor(String nameOrEmail) {
  final source = nameOrEmail.trim().isEmpty ? '?' : nameOrEmail.trim();
  final parts = source
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
}

class RelationshipCard extends StatelessWidget {
  const RelationshipCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: LiftMateMotion.duration(context, LiftMateMotion.fast),
      curve: LiftMateMotion.standard,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? lmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: child,
    );
  }
}

class RelationshipAvatar extends StatelessWidget {
  const RelationshipAvatar({
    required this.label,
    this.size = 46,
    super.key,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lmBlue, Color(0xFF2F6FD6)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        initialsFor(label),
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
          color: Colors.white,
        ),
      ),
    );
  }
}

class RelationshipSectionLabel extends StatelessWidget {
  const RelationshipSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: lmMutedDark,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class RelationshipBottomNav extends StatelessWidget {
  const RelationshipBottomNav({
    required this.items,
    super.key,
  });

  final List<RelationshipBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }
}

class RelationshipBottomNavItem extends StatelessWidget {
  const RelationshipBottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? lmBlue : lmMutedDark;
    return PressableScale(
      enabled: onTap != null,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(64, 44),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
