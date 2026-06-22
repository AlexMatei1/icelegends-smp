import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kBase = 'https://mc.ice4legends.com/img/mc';

class McItem extends StatelessWidget {
  final String item;
  final double size;

  const McItem({super.key, required this.item, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: '$_kBase/$item.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none, // pixel-art crisp rendering
      placeholder: (_, __) => SizedBox(width: size, height: size),
      errorWidget: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}
