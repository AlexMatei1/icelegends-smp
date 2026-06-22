import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _voteProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/vote/stats');
  return res.data as Map<String, dynamic>;
});

const _voteSites = [
  _VoteSite('TopG.org', 'https://topg.org/Minecraft/in-19191', '🏆', AppColors.gold),
  _VoteSite('MinecraftServers', 'https://minecraftservers.org/server/669741', '⛏', AppColors.ice),
  _VoteSite('PlanetMinecraft', 'https://www.planetminecraft.com/server/', '🌍', AppColors.green),
];

class VoteScreen extends ConsumerWidget {
  const VoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_voteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'paper', size: 22),
          const SizedBox(width: 10),
          Text('Vot', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.green,
          )),
        ]),
      ),
      body: IceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Vote hero
            IceCard(
              borderColor: AppColors.green,
              borderOpacity: 0.3,
              glow: true,
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const McItem(item: 'paper', size: 56),
                const SizedBox(height: 12),
                stats.when(
                  loading: () => const CircularProgressIndicator(color: AppColors.green),
                  error:   (_, __) => const SizedBox.shrink(),
                  data: (d) => Text(
                    '${d['total'] ?? 0}',
                    style: GoogleFonts.exo2(
                      color: AppColors.green, fontSize: 42, fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: AppColors.green.withOpacity(0.4), blurRadius: 16)],
                    ),
                  ),
                ),
                Text('VOTURI TOTALE', style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 11, letterSpacing: 2,
                )),
                const SizedBox(height: 14),
                Text(
                  'Votează zilnic pe toate site-urile pentru a câștiga recompense și a ajuta serverul să crească!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('SITE-URI DE VOT', style: GoogleFonts.exo2(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 2,
            )),
            const SizedBox(height: 10),
            ..._voteSites.map((site) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IceCard(
                borderColor: site.color,
                borderOpacity: 0.22,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text(site.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(site.name, style: GoogleFonts.exo2(
                        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700,
                      )),
                      Text('Apasă pentru a vota', style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12,
                      )),
                    ],
                  )),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: site.url));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Link copiat! Deschide în browser.',
                            style: GoogleFonts.inter(color: AppColors.textPrimary)),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: site.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: site.color.withOpacity(0.35)),
                      ),
                      child: Text('VOTEAZĂ', style: GoogleFonts.exo2(
                        color: site.color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1,
                      )),
                    ),
                  ),
                ]),
              ),
            )),
            const SizedBox(height: 8),
            IceCard(
              borderColor: AppColors.gold,
              borderOpacity: 0.2,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const McItem(item: 'gold_ingot', size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Recompense: coins, iteme rare, şi XP bonus pentru fiecare vot!',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteSite {
  final String name;
  final String url;
  final String emoji;
  final Color color;
  const _VoteSite(this.name, this.url, this.emoji, this.color);
}
