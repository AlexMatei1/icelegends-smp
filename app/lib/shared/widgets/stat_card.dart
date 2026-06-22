import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'ice_card.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ice;
    return IceCard(
      borderColor: c,
      borderOpacity: 0.15,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: c, size: 15),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500,
            )),
          ]),
          Text(value, style: GoogleFonts.exo2(
            color: c, fontSize: 19, fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}
