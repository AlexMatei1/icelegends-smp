import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  final String uuid;
  final double size;
  final bool glow;

  const PlayerAvatar({super.key, required this.uuid, this.size = 40, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.ice.withOpacity(0.35), width: 1.5),
        boxShadow: glow
            ? [BoxShadow(color: AppColors.ice.withOpacity(0.25), blurRadius: 12)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22 - 1.5),
        child: CachedNetworkImage(
          imageUrl: 'https://craftatar.com/avatars/$uuid?size=64&overlay',
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppColors.surfaceAlt,
            child: const Center(child: Icon(Icons.person, color: AppColors.textDim, size: 16)),
          ),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.surfaceAlt,
            child: const Center(child: Icon(Icons.person, color: AppColors.textDim, size: 16)),
          ),
        ),
      ),
    );
  }
}
