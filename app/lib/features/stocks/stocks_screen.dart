import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/mc_item.dart';
import '../../shared/widgets/player_avatar.dart';

final _stocksProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/stocks');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final _holdingsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/stocks/holdings');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});
  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'gold_ingot', size: 24),
          const SizedBox(width: 10),
          Text('Bursa', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted), onPressed: () {
            ref.invalidate(_stocksProvider);
            ref.invalidate(_holdingsProvider);
          }),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.ice,
          labelColor: AppColors.ice,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Piață'), Tab(text: 'Portofoliu')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_MarketTab(ref: ref), _PortfolioTab(ref: ref)],
      ),
    );
  }
}

class _MarketTab extends StatelessWidget {
  final WidgetRef ref;
  const _MarketTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final stocks = ref.watch(_stocksProvider);
    final auth   = ref.watch(authProvider).valueOrNull;
    final fmt    = NumberFormat('#,###', 'ro_RO');

    return stocks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s      = list[i];
          final uuid   = s['uuid'] as String;
          final name   = s['name'] as String;
          final price  = (s['price'] as num).toDouble();
          final isMe   = auth?.uuid == uuid;

          return Card(
            child: ListTile(
              leading: PlayerAvatar(uuid: uuid, size: 40),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: isMe ? const Text('Propriile acțiuni',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)) : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(price.toInt())} C',
                      style: const TextStyle(color: AppColors.green,
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const Text('/ acțiune',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
              onTap: isMe ? null : () => _showTrade(context, ref, s),
            ),
          );
        },
      ),
    );
  }

  void _showTrade(BuildContext context, WidgetRef ref, Map<String, dynamic> stock) {
    int qty = 1;
    bool buying = true;
    final price = (stock['price'] as num).toDouble();
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Acțiuni ${stock['name']}', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true,  label: Text('Cumpără'), icon: Icon(Icons.trending_up)),
                ButtonSegment(value: false, label: Text('Vinde'),   icon: Icon(Icons.trending_down)),
              ],
              selected: {buying},
              onSelectionChanged: (s) => setState(() { buying = s.first; error = null; }),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: qty > 1 ? () => setState(() => qty--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.ice),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              IconButton(
                onPressed: qty < 100 ? () => setState(() => qty++) : null,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.ice),
              ),
            ]),
            Text('Total: ${(price * qty).toStringAsFixed(0)} C',
                style: TextStyle(
                  color: buying ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.w700, fontSize: 18,
                )),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buying ? AppColors.green : AppColors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  try {
                    final endpoint = buying ? '/api/stocks/buy' : '/api/stocks/sell';
                    await api.dio.post(endpoint, data: {'stock_uuid': stock['uuid'], 'shares': qty});
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_stocksProvider);
                    ref.invalidate(_holdingsProvider);
                  } catch (e) {
                    setState(() => error = (e as dynamic).response?.data?['error'] ?? '$e');
                  }
                },
                child: Text(buying ? 'Cumpără $qty acțiuni' : 'Vinde $qty acțiuni'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PortfolioTab extends StatelessWidget {
  final WidgetRef ref;
  const _PortfolioTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(_holdingsProvider);
    final fmt      = NumberFormat('#,###', 'ro_RO');

    return holdings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const McItem(item: 'gold_ingot', size: 48),
              const SizedBox(height: 12),
              Text('Niciun activ în portofoliu.',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h         = list[i];
                final uuid      = h['stock_uuid'] as String;
                final name      = h['stock_name'] as String;
                final shares    = (h['shares'] as num).toInt();
                final avgPrice  = (h['avg_price'] as num).toDouble();
                final curPrice  = (h['current_price'] as num).toDouble();
                final value     = curPrice * shares;
                final pnl       = (curPrice - avgPrice) * shares;
                final pnlPos    = pnl >= 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      PlayerAvatar(uuid: uuid, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('$shares acțiuni · avg ${avgPrice.toStringAsFixed(0)} C',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${fmt.format(value.toInt())} C',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${pnlPos ? '+' : ''}${pnl.toStringAsFixed(0)} C',
                            style: TextStyle(
                              color: pnlPos ? AppColors.green : AppColors.red,
                              fontSize: 12, fontWeight: FontWeight.w600,
                            )),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
