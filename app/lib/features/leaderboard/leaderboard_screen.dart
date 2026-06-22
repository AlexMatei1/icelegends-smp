import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';
import '../../shared/widgets/player_avatar.dart';

final _lbProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/leaderboard');
  return res.data as Map<String, dynamic>;
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lb  = ref.watch(_lbProvider);
    final fmt = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'gold_ingot', size: 24),
          const SizedBox(width: 10),
          Text('Clasament', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_lbProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Bogăție'), Tab(text: 'Timp jucat')],
        ),
      ),
      body: IceBackground(
        child: lb.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error:   (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.red))),
          data: (d) {
            final balances = (d['balances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final playtime = (d['playtime'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            return TabBarView(controller: _tabs, children: [
              _buildList(balances, (e) => '${fmt.format((e['balance'] as num).toInt())} C', AppColors.gold),
              _buildList(playtime, (e) {
                final m = (e['minutes'] as num).toInt();
                return '${m ~/ 60}h ${m % 60}m';
              }, AppColors.ice),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list,
      String Function(Map<String, dynamic>) valueFn, Color color) {
    const medals = ['🥇', '🥈', '🥉'];
    return RefreshIndicator(
      color: AppColors.ice,
      backgroundColor: AppColors.surface,
      onRefresh: () async => ref.invalidate(_lbProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e    = list[i];
          final name = e['name'] as String? ?? '';
          final uuid = e['uuid'] as String?;
          return IceCard(
            borderColor: i == 0 ? AppColors.gold : (i == 1 ? AppColors.textMuted : color),
            borderOpacity: i < 3 ? 0.35 : 0.10,
            glow: i == 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              SizedBox(
                width: 30,
                child: Text(
                  i < 3 ? medals[i] : '#${i + 1}',
                  style: TextStyle(
                    fontSize: i < 3 ? 20 : 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (uuid != null) PlayerAvatar(uuid: uuid, size: 36, glow: i == 0)
              else const McItem(item: 'totem', size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: GoogleFonts.exo2(
                fontWeight: FontWeight.w600,
                color: i == 0 ? AppColors.gold : AppColors.textPrimary,
                fontSize: 14,
              ))),
              Text(valueFn(e), style: GoogleFonts.exo2(
                color: color, fontWeight: FontWeight.w700, fontSize: 14,
              )),
            ]),
          );
        },
      ),
    );
  }
}
