import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/bounty.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _bountiesProvider = FutureProvider.autoDispose<List<Bounty>>((ref) async {
  final res = await api.dio.get('/api/bounties');
  return (res.data as List).map((e) => Bounty.fromJson(e as Map<String, dynamic>)).toList();
});

class BountiesScreen extends ConsumerWidget {
  const BountiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bounties = ref.watch(_bountiesProvider);
    final auth     = ref.watch(authProvider).valueOrNull;
    final fmt      = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'crossbow', size: 24),
          const SizedBox(width: 10),
          Text('Bounty Board', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_bountiesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlaceBounty(context, ref),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        icon: const McItem(item: 'crossbow', size: 20),
        label: Text('Pune Bounty', style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
      ),
      body: IceBackground(
        child: bounties.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error: (e, _) => Center(child: Text('Eroare: $e',
              style: GoogleFonts.inter(color: AppColors.red))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const McItem(item: 'crossbow', size: 56),
                  const SizedBox(height: 14),
                  Text('Nicio recompensă activă.',
                      style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]))
              : RefreshIndicator(
                  color: AppColors.ice,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(_bountiesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final b    = list[i];
                      final isMe = auth?.username?.toLowerCase() == b.targetName.toLowerCase();
                      return IceCard(
                        borderColor: isMe ? AppColors.red : AppColors.gold,
                        borderOpacity: isMe ? 0.35 : 0.15,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const McItem(item: 'crossbow', size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(b.targetName, style: GoogleFonts.exo2(
                                fontWeight: FontWeight.w700,
                                color: isMe ? AppColors.red : AppColors.textPrimary,
                                fontSize: 15,
                              )),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('PE TINE', style: GoogleFonts.exo2(
                                    color: AppColors.red, fontSize: 9, fontWeight: FontWeight.w700,
                                  )),
                                ),
                              ],
                            ]),
                            Text('Pus de ${b.placerName}',
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${fmt.format(b.amount)} C', style: GoogleFonts.exo2(
                              color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 17,
                            )),
                            Text('recompensă',
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _showPlaceBounty(BuildContext context, WidgetRef ref) {
    final target = TextEditingController();
    final amount = TextEditingController();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const McItem(item: 'crossbow', size: 36),
            const SizedBox(height: 8),
            Text('Pune Bounty', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(controller: target,
                decoration: const InputDecoration(labelText: 'Username țintă'),
                textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            TextField(controller: amount,
                decoration: const InputDecoration(
                    labelText: 'Recompensă (min. 100 coins)', suffixText: 'C'),
                keyboardType: TextInputType.number),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold, foregroundColor: AppColors.background),
                onPressed: () async {
                  try {
                    await api.dio.post('/api/bounties', data: {
                      'target_name': target.text.trim(),
                      'amount':      int.tryParse(amount.text.trim()) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_bountiesProvider);
                  } catch (e) {
                    setState(() => error = (e as dynamic).response?.data?['error'] ?? e.toString());
                  }
                },
                child: Text('Confirmă', style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
