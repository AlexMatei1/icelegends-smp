import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/clan.dart';
import '../../shared/widgets/mc_item.dart';

final _clansProvider = FutureProvider.autoDispose<List<Clan>>((ref) async {
  final res = await api.dio.get('/api/clans');
  return (res.data as List).map((e) => Clan.fromJson(e as Map<String, dynamic>)).toList();
});

final _myClanProvider = FutureProvider.autoDispose<Clan?>((ref) async {
  try {
    final res = await api.dio.get('/api/player/clan');
    if (res.data == null) return null;
    return Clan.fromJson(res.data as Map<String, dynamic>);
  } catch (_) { return null; }
});

class ClansScreen extends ConsumerWidget {
  const ClansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clans   = ref.watch(_clansProvider);
    final myClan  = ref.watch(_myClanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'iron_chestplate', size: 24),
          const SizedBox(width: 10),
          Text('Clanuri', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
              onPressed: () { ref.invalidate(_clansProvider); ref.invalidate(_myClanProvider); }),
        ],
      ),
      body: Column(
        children: [
          // My clan banner
          myClan.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (c) => c == null
                ? _NoClanBanner(onCreate: () => _showCreateClan(context, ref))
                : _MyClanBanner(clan: c, onLeave: () => _leave(context, ref, c)),
          ),
          // All clans list
          Expanded(
            child: clans.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('$e')),
              data: (list) => RefreshIndicator(
                onRefresh: () async { ref.invalidate(_clansProvider); ref.invalidate(_myClanProvider); },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.ice.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.ice.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('[${c.tag}]',
                                style: const TextStyle(color: AppColors.ice,
                                    fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        ),
                        title: Text(c.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${c.members} membri · ${c.wins} victorii',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        trailing: myClan.valueOrNull == null
                            ? TextButton(
                                onPressed: () => _join(context, ref, c),
                                child: const Text('Alătură-te'),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, Clan clan) async {
    try {
      await api.dio.post('/api/clans/${clan.id}/join');
      ref.invalidate(_clansProvider);
      ref.invalidate(_myClanProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Te-ai alăturat clanului ${clan.name}!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((e as dynamic).response?.data?['error'] ?? '$e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Clan clan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Părăsești clanul?'),
        content: Text('Ești sigur că vrei să părăsești ${clan.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulează')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Părăsește', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.dio.post('/api/clans/${clan.id}/leave');
      ref.invalidate(_clansProvider);
      ref.invalidate(_myClanProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((e as dynamic).response?.data?['error'] ?? '$e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _showCreateClan(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final tag  = TextEditingController();
    final desc = TextEditingController();
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
            Text('Crează Clan', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nume clan (3–30 caractere)'), textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            TextField(controller: tag,  decoration: const InputDecoration(labelText: 'Tag (2–5 litere)'), textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descriere (opțional)')),
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
                    await api.dio.post('/api/clans', data: {
                      'name': name.text.trim(), 'tag': tag.text.trim(), 'description': desc.text.trim(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_clansProvider);
                    ref.invalidate(_myClanProvider);
                  } catch (e) {
                    setState(() => error = (e as dynamic).response?.data?['error'] ?? '$e');
                  }
                },
                child: const Text('Crează'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MyClanBanner extends StatelessWidget {
  final Clan clan;
  final VoidCallback onLeave;
  const _MyClanBanner({required this.clan, required this.onLeave});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.ice.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.ice.withOpacity(0.3)),
    ),
    child: Row(children: [
      const McItem(item: 'iron_chestplate', size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Clanul tău: ${clan.name}',
              style: const TextStyle(color: AppColors.ice, fontWeight: FontWeight.w700)),
          Text('[${clan.tag}] · ${clan.members} membri',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      TextButton(
        onPressed: onLeave,
        child: const Text('Ieși', style: TextStyle(color: AppColors.red)),
      ),
    ]),
  );
}

class _NoClanBanner extends StatelessWidget {
  final VoidCallback onCreate;
  const _NoClanBanner({required this.onCreate});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      const McItem(item: 'iron_chestplate', size: 22),
      const SizedBox(width: 10),
      const Expanded(child: Text('Nu ești în niciun clan.',
          style: TextStyle(color: AppColors.textMuted))),
      TextButton(onPressed: onCreate, child: const Text('Crează')),
    ]),
  );
}
