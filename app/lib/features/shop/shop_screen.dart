import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/mc_item.dart';

final _shopProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/shop');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(_shopProvider);
    final fmt  = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'emerald', size: 24),
          const SizedBox(width: 10),
          Text('Magazin', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
              onPressed: () => ref.invalidate(_shopProvider)),
        ],
      ),
      body: shop.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (items) {
          final cats = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final cat = item['cat'] as String? ?? 'Altele';
            cats.putIfAbsent(cat, () => []).add(item);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_shopProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: AppColors.gold, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('Trebuie să fii online în joc pentru a cumpăra.',
                        style: TextStyle(color: AppColors.gold, fontSize: 12))),
                  ]),
                ),
                const SizedBox(height: 16),
                ...cats.entries.map((cat) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.key, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
                      ),
                      itemCount: cat.value.length,
                      itemBuilder: (_, i) {
                        final item = cat.value[i];
                        final buy  = (item['buy']  as num?)?.toInt();
                        final sell = (item['sell'] as num?)?.toInt();
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: buy != null ? () => _showBuy(context, ref, item) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item['emoji'] as String? ?? '📦',
                                      style: const TextStyle(fontSize: 28)),
                                  Text(item['name'] as String? ?? '',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary)),
                                  Row(children: [
                                    if (buy != null)
                                      Text('${fmt.format(buy)} C',
                                          style: const TextStyle(color: AppColors.ice, fontSize: 11)),
                                    if (buy != null && sell != null)
                                      Text('  ·  ', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                                    if (sell != null)
                                      Text('${fmt.format(sell)} C',
                                          style: const TextStyle(color: AppColors.gold, fontSize: 11)),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBuy(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    int qty = 1;
    final buy = (item['buy'] as num?)?.toInt() ?? 0;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('${item['emoji']}  ${item['name']}',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: qty > 1 ? () => setState(() => qty--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.ice),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: qty < 64 ? () => setState(() => qty++) : null,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.ice),
              ),
            ]),
            Text('Total: ${(buy * qty)} C',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 18)),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await api.dio.post('/api/shop/buy', data: {'itemId': item['id'], 'qty': qty});
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item['name']} x$qty cumpărat!'),
                            backgroundColor: AppColors.green),
                      );
                    }
                  } catch (e) {
                    setState(() => error = (e as dynamic).response?.data?['error'] ?? '$e');
                  }
                },
                child: const Text('Cumpără'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
