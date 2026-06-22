import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class IceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderOpacity;
  final VoidCallback? onTap;
  final double radius;
  final bool glow;

  const IceCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderOpacity = 0.18,
    this.onTap,
    this.radius = 16,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final bc = (borderColor ?? AppColors.ice).withOpacity(borderOpacity);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF060F20).withOpacity(0.82),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: bc, width: 1),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (glow) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: (borderColor ?? AppColors.ice).withOpacity(0.10),
              blurRadius: 22,
              spreadRadius: 0,
            ),
          ],
        ),
        child: card,
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
