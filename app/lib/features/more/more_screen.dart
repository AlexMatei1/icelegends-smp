import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).valueOrNull;

    final features = [
      _Feature('crossbow',        'Bounty Board',  'Urmărire & recompense',    AppColors.red,      '/bounties'),
      _Feature('gold_ingot',      'Stocks',        'Piața de acțiuni',         AppColors.gold,     '/stocks'),
      _Feature('ender_pearl',     'Time Capsule',  'Mesaje din viitor',        AppColors.purple,   '/capsule'),
      _Feature('diamond_sword',   'Războaie',      'Conflicte între clanuri',  AppColors.red,      '/wars'),
      _Feature('emerald',         'Magazin',       'Cumpără iteme rare',       AppColors.green,    '/shop'),
      _Feature('iron_chestplate', 'Clanuri',       'Alianțe & teritorii',      AppColors.ice,      '/clans'),
      _Feature('paper',           'Vot',           'Sprijin serverul',         AppColors.green,    '/vote'),
      _Feature('book',            'Contestație',   'Apel ban/mute',            AppColors.textMuted,'/appeal'),
      _Feature('map',             'Anunțuri',      'Noutăți de la staff',      AppColors.iceBlue,  '/announcements'),
      _Feature('spyglass',        'Social',        'Prieteni & feed',          AppColors.purple,   '/social'),
      if (auth?.isAdmin == true)
        _Feature('dragon_egg',    'Admin',         'Panou administrare',       AppColors.red,      '/admin'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Meniu', style: GoogleFonts.exo2(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        )),
      ),
      body: IceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text('FUNCȚII', style: GoogleFonts.exo2(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 2,
            )),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemCount: features.length,
              itemBuilder: (_, i) => _FeatureCard(
                feature: features[i],
                onTap: () => context.go(features[i].route),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final String mcItem;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  const _Feature(this.mcItem, this.title, this.subtitle, this.color, this.route);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final VoidCallback onTap;
  const _FeatureCard({required this.feature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IceCard(
      borderColor: feature.color,
      borderOpacity: 0.22,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            McItem(item: feature.mcItem, size: 30),
            const Spacer(),
            Icon(Icons.chevron_right, color: feature.color.withOpacity(0.5), size: 16),
          ]),
          const Spacer(),
          Text(feature.title, style: GoogleFonts.exo2(
            color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 2),
          Text(feature.subtitle, style: GoogleFonts.inter(
            color: AppColors.textMuted, fontSize: 11,
          )),
        ],
      ),
    );
  }
}
