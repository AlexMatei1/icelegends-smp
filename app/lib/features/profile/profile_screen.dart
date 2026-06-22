import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';
import '../../shared/widgets/player_avatar.dart';

final _profileProvider = FutureProvider.autoDispose((ref) async {
  final auth = ref.watch(authProvider).valueOrNull;
  if (auth?.username == null) return null;
  final res = await api.dio.get('/api/player/profile/${auth!.username}');
  return res.data as Map<String, dynamic>;
});

final _achievementsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/achievements');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile      = ref.watch(_profileProvider);
    final achievements = ref.watch(_achievementsProvider);
    final auth         = ref.watch(authProvider).valueOrNull;
    final fmt          = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'totem', size: 22),
          const SizedBox(width: 10),
          Text('Profilul meu', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20),
            color: AppColors.textMuted,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: IceBackground(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error:   (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.red))),
          data: (d) {
            if (d == null) return const SizedBox.shrink();
            final levels   = (d['levels'] as Map<String, dynamic>?) ?? {};
            final balance  = (d['balance'] as num?)?.toDouble() ?? 0;
            final playtime = (d['playtime'] as num?)?.toInt() ?? 0;
            final clan     = d['clan'] as Map<String, dynamic>?;

            return RefreshIndicator(
              color: AppColors.ice,
              backgroundColor: AppColors.surface,
              onRefresh: () async => ref.invalidate(_profileProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Hero header
                  IceCard(
                    glow: true,
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      if (auth?.uuid != null)
                        PlayerAvatar(uuid: auth!.uuid!, size: 72, glow: true),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['name'] as String? ?? '', style: GoogleFonts.exo2(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 6),
                          _RoleBadge(role: d['group'] as String? ?? 'jucator'),
                          if (clan != null) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              const McItem(item: 'iron_chestplate', size: 14),
                              const SizedBox(width: 4),
                              Text('[${clan['tag']}] ${clan['name']}',
                                  style: GoogleFonts.inter(color: AppColors.ice, fontSize: 12)),
                            ]),
                          ],
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Balance + playtime
                  Row(children: [
                    Expanded(child: IceCard(
                      borderColor: AppColors.gold,
                      borderOpacity: 0.2,
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const McItem(item: 'gold_ingot', size: 14),
                          const SizedBox(width: 6),
                          Text('BALANȚĂ', style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5,
                          )),
                        ]),
                        const SizedBox(height: 6),
                        Text('${fmt.format(balance.toInt())} C',
                            style: GoogleFonts.exo2(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: IceCard(
                      borderColor: AppColors.ice,
                      borderOpacity: 0.2,
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const McItem(item: 'feather', size: 14),
                          const SizedBox(width: 6),
                          Text('TIMP JUCAT', style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5,
                          )),
                        ]),
                        const SizedBox(height: 6),
                        Text('${playtime ~/ 60}h ${playtime % 60}m',
                            style: GoogleFonts.exo2(color: AppColors.ice, fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // Skills
                  Text('ABILITĂȚI', style: GoogleFonts.exo2(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 2,
                  )),
                  const SizedBox(height: 10),
                  IceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: _skillMeta.entries.map((e) {
                      final lv  = (levels[e.key] as num?)?.toInt() ?? 0;
                      final pct = (lv / 100.0).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            McItem(item: e.value.$1, size: 16),
                            const SizedBox(width: 8),
                            Text(e.key, style: GoogleFonts.exo2(
                              color: e.value.$2, fontSize: 13, fontWeight: FontWeight.w600,
                            )),
                            const Spacer(),
                            Text('Lv $lv', style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 12,
                            )),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct, minHeight: 5,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(e.value.$2),
                            ),
                          ),
                        ]),
                      );
                    }).toList()),
                  ),
                  const SizedBox(height: 14),

                  // Radar chart
                  IceCard(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(height: 200, child: _SkillsRadar(levels: levels)),
                  ),
                  const SizedBox(height: 20),

                  // Achievements
                  Text('REALIZĂRI', style: GoogleFonts.exo2(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 2,
                  )),
                  const SizedBox(height: 10),
                  achievements.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
                    error:   (_, __) => const SizedBox.shrink(),
                    data: (list) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.88,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _AchievementCard(a: list[i]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// (mcItem, color)
const _skillMeta = {
  'Pamant': ('diamond',       AppColors.gold),
  'Foc':    ('blaze_powder',  AppColors.red),
  'Viata':  ('golden_apple',  AppColors.green),
  'Apa':    ('ender_pearl',   AppColors.ice),
  'Vant':   ('feather',       AppColors.purple),
};

class _SkillsRadar extends StatelessWidget {
  final Map<String, dynamic> levels;
  const _SkillsRadar({required this.levels});

  @override
  Widget build(BuildContext context) {
    final keys = _skillMeta.keys.toList();
    return RadarChart(RadarChartData(
      radarShape: RadarShape.polygon,
      tickCount: 4,
      ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
      gridBorderData:  const BorderSide(color: AppColors.border, width: 1),
      radarBorderData: const BorderSide(color: AppColors.border),
      titlePositionPercentageOffset: 0.2,
      titleTextStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
      getTitle: (i, _) => RadarChartTitle(text: keys[i]),
      dataSets: [RadarDataSet(
        fillColor:   AppColors.ice.withOpacity(0.15),
        borderColor: AppColors.ice,
        borderWidth: 2,
        entryRadius: 3,
        dataEntries: keys.map((k) {
          final lv = (levels[k] as num?)?.toDouble() ?? 0;
          return RadarEntry(value: lv.clamp(0, 100));
        }).toList(),
      )],
    ));
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  static const _colors = {
    'owner':     AppColors.red,
    'admin':     AppColors.red,
    'moderator': AppColors.purple,
    'helper':    AppColors.green,
  };
  @override
  Widget build(BuildContext context) {
    final color = _colors[role] ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(role.toUpperCase(), style: GoogleFonts.exo2(
        color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
      )),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Map<String, dynamic> a;
  const _AchievementCard({required this.a});
  @override
  Widget build(BuildContext context) {
    final unlocked = a['unlocked'] as bool? ?? false;
    return IceCard(
      borderColor: unlocked ? AppColors.gold : AppColors.border,
      borderOpacity: unlocked ? 0.45 : 0.8,
      padding: const EdgeInsets.all(10),
      glow: unlocked,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(a['icon'] as String? ?? '?', style: TextStyle(
          fontSize: 28, color: unlocked ? null : AppColors.textDim,
        )),
        const SizedBox(height: 6),
        Text(a['name'] as String? ?? '', textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: unlocked ? AppColors.textPrimary : AppColors.textDim,
            )),
      ]),
    );
  }
}
