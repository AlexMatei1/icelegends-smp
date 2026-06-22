import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';
import '../../shared/widgets/player_avatar.dart';

final _statusProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final ctrl = StreamController<Map<String, dynamic>>();
  Future<void> fetch() async {
    try {
      final res = await api.dio.get('/api/status');
      if (!ctrl.isClosed) ctrl.add(res.data as Map<String, dynamic>);
    } catch (_) {
      if (!ctrl.isClosed) ctrl.add({'online': false, 'players': 0});
    }
  }
  fetch();
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => fetch());
  ref.onDispose(() { timer.cancel(); ctrl.close(); });
  return ctrl.stream;
});

final _meProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/me');
  return res.data as Map<String, dynamic>;
});

final _eventsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/events');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_statusProvider);
    final me     = ref.watch(_meProvider);
    final events = ref.watch(_eventsProvider);
    final auth   = ref.watch(authProvider).valueOrNull;
    final fmt    = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'diamond', size: 22),
          const SizedBox(width: 10),
          Text('IceLegends', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ice,
            shadows: [Shadow(color: AppColors.ice.withOpacity(0.4), blurRadius: 8)],
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            color: AppColors.textMuted,
            onPressed: () {
              ref.invalidate(_statusProvider);
              ref.invalidate(_meProvider);
              ref.invalidate(_eventsProvider);
            },
          ),
          if (auth?.uuid != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => context.go('/profile'),
                child: PlayerAvatar(uuid: auth!.uuid!, size: 34, glow: true),
              ),
            ),
        ],
      ),
      body: IceBackground(
        child: RefreshIndicator(
          color: AppColors.ice,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(_statusProvider);
            ref.invalidate(_meProvider);
            ref.invalidate(_eventsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              status.when(
                loading: () => _StatusBanner(loading: true, online: false, players: 0),
                error:   (_, __) => _StatusBanner(loading: false, online: false, players: 0),
                data:    (s) => _StatusBanner(
                  loading: false,
                  online:  s['online'] as bool? ?? false,
                  players: (s['players'] as num?)?.toInt() ?? 0,
                  tps:     (s['tps'] as num?)?.toDouble(),
                ),
              ),
              const SizedBox(height: 22),

              me.when(
                loading: () => const SizedBox(height: 80, child: Center(
                    child: CircularProgressIndicator(color: AppColors.ice))),
                error: (_, __) => const SizedBox.shrink(),
                data: (d) {
                  final stats   = d['stats'] as Map<String, dynamic>? ?? {};
                  final balance = (stats['balance'] as num?)?.toDouble() ?? 0;
                  final mins    = (stats['playtime'] as num?)?.toInt() ?? 0;
                  final kills   = (stats['kills'] as num?)?.toInt() ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('STATISTICI'),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.65,
                        children: [
                          _StatTile('Balanță', '${fmt.format(balance.toInt())} C',
                              'gold_ingot', AppColors.gold),
                          _StatTile('Timp jucat', '${mins ~/ 60}h',
                              'feather', AppColors.ice),
                          _StatTile('Ucideri', '$kills',
                              'diamond_sword', AppColors.red),
                          _StatTile('Rang',
                              (d['role'] as String? ?? 'jucator').toUpperCase(),
                              'dragon_egg', AppColors.purple),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              _SectionLabel('ACTIVITATE RECENTĂ'),
              const SizedBox(height: 10),

              events.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
                error:   (_, __) => Text('Nu s-au putut încărca evenimentele.',
                    style: GoogleFonts.inter(color: AppColors.textMuted)),
                data: (list) => list.isEmpty
                    ? Text('Nicio activitate recentă.',
                        style: GoogleFonts.inter(color: AppColors.textMuted))
                    : IceCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Column(
                          children: list.reversed.take(20)
                              .map((e) => _EventTile(event: e))
                              .toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.exo2(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: AppColors.textMuted, letterSpacing: 2,
  ));
}

class _StatusBanner extends StatelessWidget {
  final bool loading;
  final bool online;
  final int players;
  final double? tps;
  const _StatusBanner({required this.loading, required this.online, required this.players, this.tps});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.green : (loading ? AppColors.textMuted : AppColors.red);
    return IceCard(
      borderColor: color,
      borderOpacity: 0.30,
      glow: online,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(width: 20, height: 20, child: Stack(alignment: Alignment.center, children: [
          if (online) Container(
            width: 18, height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.green.withOpacity(0.12)),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: online ? [BoxShadow(color: AppColors.green.withOpacity(0.5), blurRadius: 6)] : null,
            ),
          ),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Text(
          loading ? 'Verificare server...'
              : (online ? 'mc.ice4legends.com — Online' : 'Server Offline'),
          style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 14),
        )),
        if (online) ...[
          Text('$players online', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          if (tps != null) ...[
            const SizedBox(width: 10),
            _TpsChip(tps: tps!),
          ],
        ],
      ]),
    );
  }
}

class _TpsChip extends StatelessWidget {
  final double tps;
  const _TpsChip({required this.tps});
  @override
  Widget build(BuildContext context) {
    final color = tps >= 18 ? AppColors.green : (tps >= 15 ? AppColors.gold : AppColors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('${tps.toStringAsFixed(1)} TPS',
          style: GoogleFonts.exo2(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String mcItem;
  final Color color;
  const _StatTile(this.label, this.value, this.mcItem, this.color);

  @override
  Widget build(BuildContext context) {
    return IceCard(
      borderColor: color,
      borderOpacity: 0.14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            McItem(item: mcItem, size: 16),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
          ]),
          Text(value, style: GoogleFonts.exo2(
            color: color, fontSize: 18, fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  // (mcItem, color)
  static const _meta = {
    'KILL':           ('diamond_sword',    AppColors.red),
    'BOUNTY':         ('crossbow',         AppColors.gold),
    'BOUNTY_CLAIMED': ('crossbow',         AppColors.gold),
    'WAR_DECLARED':   ('diamond_sword',    AppColors.red),
    'WAR_STARTED':    ('blaze_powder',     AppColors.red),
    'WAR_ENDED':      ('totem',            AppColors.purple),
    'CLAN_CREATE':    ('iron_chestplate',  AppColors.ice),
    'QUEST':          ('arrow',            AppColors.green),
    'STOCK_BUY':      ('gold_ingot',       AppColors.green),
    'STOCK_SELL':     ('gold_ingot',       AppColors.red),
  };

  @override
  Widget build(BuildContext context) {
    final type   = event['type']   as String? ?? '';
    final actor  = event['actor']  as String? ?? '';
    final target = event['target'] as String? ?? '';
    final detail = event['detail'] as String? ?? '';
    final m      = _meta[type] ?? ('ender_eye', AppColors.textMuted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: m.$2.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: McItem(item: m.$1, size: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: actor, style: GoogleFonts.inter(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
          )),
          if (target.isNotEmpty) ...[
            TextSpan(text: ' → ', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            TextSpan(text: target, style: GoogleFonts.inter(color: AppColors.ice, fontSize: 13)),
          ],
          if (detail.isNotEmpty)
            TextSpan(text: '  $detail', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ]))),
      ]),
    );
  }
}
