import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _missionsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/missions/me');
  return res.data as Map<String, dynamic>;
});

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_missionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'arrow', size: 22),
          const SizedBox(width: 10),
          Text('Contracte zilnice', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            color: AppColors.textMuted,
            onPressed: () => ref.invalidate(_missionsProvider),
          ),
        ],
      ),
      body: IceBackground(
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error:   (e, _) => Center(child: Text('$e',
              style: GoogleFonts.inter(color: AppColors.red))),
          data: (d) {
            final today    = d['today']  as Map<String, dynamic>?;
            final active   = d['active'] as Map<String, dynamic>?;
            final missions = (today?['missions'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];

            return RefreshIndicator(
              color: AppColors.ice,
              backgroundColor: AppColors.surface,
              onRefresh: () async => ref.invalidate(_missionsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (active != null) ...[
                    _ActiveCard(mission: active, ref: ref),
                    const SizedBox(height: 22),
                  ],
                  Text('CONTRACTE AZI', style: GoogleFonts.exo2(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 2,
                  )),
                  const SizedBox(height: 10),
                  ...missions.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MissionCard(
                      slot: e.key + 1,
                      mission: e.value,
                      isActive: active != null,
                      ref: ref,
                    ),
                  )),
                  if (missions.isEmpty)
                    Text('Niciun contract disponibil.',
                        style: GoogleFonts.inter(color: AppColors.textMuted)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  final WidgetRef ref;
  const _ActiveCard({required this.mission, required this.ref});

  @override
  Widget build(BuildContext context) {
    final progress = (mission['progress'] as num?)?.toInt() ?? 0;
    final goal     = (mission['goal'] as num?)?.toInt() ?? 1;
    final reward   = (mission['reward'] as num?)?.toInt() ?? 0;
    final done     = mission['done'] as bool? ?? false;
    final pct      = (progress / goal).clamp(0.0, 1.0);
    final color    = done ? AppColors.green : AppColors.ice;

    return IceCard(
      borderColor: color,
      borderOpacity: 0.35,
      glow: true,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          McItem(item: done ? 'totem' : 'arrow', size: 18),
          const SizedBox(width: 8),
          Text(done ? 'Contract completat!' : 'Contract activ',
              style: GoogleFonts.exo2(
                color: color, fontWeight: FontWeight.w700, fontSize: 14,
              )),
          const Spacer(),
          Text('+$reward C', style: GoogleFonts.exo2(
            color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 14,
          )),
        ]),
        const SizedBox(height: 10),
        Text(mission['desc'] as String? ?? '',
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text('$progress / $goal  (${(pct * 100).toStringAsFixed(0)}%)',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
      ]),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final int slot;
  final Map<String, dynamic> mission;
  final bool isActive;
  final WidgetRef ref;

  const _MissionCard({
    required this.slot,
    required this.mission,
    required this.isActive,
    required this.ref,
  });

  static const _diffColors = {
    'Comun': AppColors.textMuted,
    'Rar':   AppColors.ice,
    'Epic':  AppColors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final diff   = mission['diff']   as String? ?? 'Comun';
    final amount = (mission['amount'] as num?)?.toInt() ?? 0;
    final reward = (mission['reward'] as num?)?.toInt() ?? 0;
    final desc   = mission['desc']   as String? ?? '';
    final color  = _diffColors[diff] ?? AppColors.textMuted;

    return IceCard(
      borderColor: color,
      borderOpacity: 0.18,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(child: Text('$slot',
              style: GoogleFonts.exo2(
                color: color, fontWeight: FontWeight.w800, fontSize: 14,
              ))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$amount $desc', style: GoogleFonts.inter(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14,
          )),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(diff, style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.w600,
              )),
            ),
            const SizedBox(width: 8),
            Text('+$reward C', style: GoogleFonts.exo2(
              color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700,
            )),
          ]),
        ])),
        if (!isActive)
          TextButton(
            onPressed: () => _accept(context, slot),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ice,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.ice.withOpacity(0.3)),
              ),
            ),
            child: Text('Acceptă', style: GoogleFonts.inter(
              color: AppColors.ice, fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ),
      ]),
    );
  }

  Future<void> _accept(BuildContext context, int slot) async {
    try {
      await api.dio.post('/api/player/missions/accept', data: {'slot': slot});
      ref.invalidate(_missionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Folosește /ia-contract $slot în joc!',
              style: GoogleFonts.inter(color: AppColors.textPrimary)),
        ));
      }
    }
  }
}
