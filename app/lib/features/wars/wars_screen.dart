import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/war.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _warsProvider = FutureProvider.autoDispose<List<War>>((ref) async {
  final res = await api.dio.get('/api/wars');
  return (res.data as List).map((e) => War.fromJson(e as Map<String, dynamic>)).toList();
});

class WarsScreen extends ConsumerWidget {
  const WarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wars = ref.watch(_warsProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final fmt  = NumberFormat('#,###', 'ro_RO');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'diamond_sword', size: 24),
          const SizedBox(width: 10),
          Text('Războaie', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_warsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDeclare(context, ref),
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        icon: const McItem(item: 'diamond_sword', size: 20),
        label: Text('Declară Război', style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
      ),
      body: IceBackground(
        child: wars.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error:   (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.red))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const McItem(item: 'diamond_sword', size: 56),
                  const SizedBox(height: 14),
                  Text('Niciun război activ.',
                      style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]))
              : RefreshIndicator(
                  color: AppColors.ice,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(_warsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final w         = list[i];
                      final isTarget  = auth?.username?.toLowerCase() == w.targetName.toLowerCase();
                      final isPending = w.status == 'pending';
                      final isActive  = w.status == 'active';

                      return IceCard(
                        borderColor: AppColors.red,
                        borderOpacity: 0.2,
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _WarBadge(status: w.status),
                            const Spacer(),
                            if (w.stake > 0)
                              Row(children: [
                                const McItem(item: 'gold_ingot', size: 14),
                                const SizedBox(width: 4),
                                Text('${fmt.format(w.stake)} C', style: GoogleFonts.exo2(
                                  color: AppColors.gold, fontWeight: FontWeight.w700,
                                )),
                              ]),
                          ]),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(w.challengerName, style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary,
                            )),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: const McItem(item: 'diamond_sword', size: 20),
                            ),
                            Text(w.targetName, style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary,
                            )),
                          ]),
                          if (isActive) ...[
                            const SizedBox(height: 12),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              _KillCount(name: w.challengerName, kills: w.challengerKills),
                              const McItem(item: 'blaze_powder', size: 18),
                              _KillCount(name: w.targetName, kills: w.targetKills),
                            ]),
                          ],
                          if (isPending && isTarget) ...[
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: OutlinedButton(
                                onPressed: () => _respond(context, ref, w.id, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.red,
                                  side: const BorderSide(color: AppColors.red),
                                ),
                                child: Text('Refuză', style: GoogleFonts.exo2(fontWeight: FontWeight.w600)),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton(
                                onPressed: () => _respond(context, ref, w.id, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                                child: Text('Acceptă', style: GoogleFonts.exo2(
                                  fontWeight: FontWeight.w600, color: Colors.white,
                                )),
                              )),
                            ]),
                          ],
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _respond(BuildContext ctx, WidgetRef ref, int id, bool accept) async {
    try {
      await api.dio.post(accept ? '/api/wars/$id/accept' : '/api/wars/$id/decline');
      ref.invalidate(_warsProvider);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text((e as dynamic).response?.data?['error'] ?? '$e'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  void _showDeclare(BuildContext context, WidgetRef ref) {
    final target = TextEditingController();
    final stake  = TextEditingController(text: '0');
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
            const McItem(item: 'diamond_sword', size: 36),
            const SizedBox(height: 8),
            Text('Declară Război', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(controller: target,
                decoration: const InputDecoration(labelText: 'Username adversar'),
                textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            TextField(controller: stake,
                decoration: const InputDecoration(
                    labelText: 'Miză coins (0 = fără miză)', suffixText: 'C'),
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
                    backgroundColor: AppColors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  try {
                    await api.dio.post('/api/wars/declare', data: {
                      'target_name': target.text.trim(),
                      'stake': int.tryParse(stake.text.trim()) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_warsProvider);
                  } catch (e) {
                    setState(() => error = (e as dynamic).response?.data?['error'] ?? '$e');
                  }
                },
                child: Text('Declară', style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WarBadge extends StatelessWidget {
  final String status;
  const _WarBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('În așteptare', AppColors.gold),
      'active'  => ('Activ', AppColors.red),
      _         => ('Încheiat', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: GoogleFonts.exo2(
        color: color, fontSize: 11, fontWeight: FontWeight.w700,
      )),
    );
  }
}

class _KillCount extends StatelessWidget {
  final String name;
  final int kills;
  const _KillCount({required this.name, required this.kills});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$kills', style: GoogleFonts.exo2(
      fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.red,
    )),
    Text(name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
  ]);
}
