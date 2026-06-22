import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class IceBackground extends StatelessWidget {
  final Widget child;
  const IceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        // Aurora top-left: ice glow
        Positioned(
          left: -80,
          top: -80,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.ice.withOpacity(0.07), Colors.transparent],
              ),
            ),
          ),
        ),
        // Aurora bottom-right: blue glow
        Positioned(
          right: -120,
          bottom: 60,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.iceBlue.withOpacity(0.04), Colors.transparent],
              ),
            ),
          ),
        ),
        // Aurora mid: subtle purple tint
        Positioned(
          right: 20,
          top: 220,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.purple.withOpacity(0.025), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
