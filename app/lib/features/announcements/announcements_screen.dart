import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _announcementsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/announcements');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ann = ref.watch(_announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'map', size: 24),
          const SizedBox(width: 10),
          Text('Anunțuri', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_announcementsProvider),
          ),
        ],
      ),
      body: IceBackground(
        child: ann.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
          error:   (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.red))),
          data: (list) => list.isEmpty
              ? Center(child: Text('Niciun anunț.',
                  style: GoogleFonts.inter(color: AppColors.textMuted)))
              : RefreshIndicator(
                  color: AppColors.ice,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(_announcementsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final a      = list[i];
                      final pinned = (a['pinned'] as num?)?.toInt() == 1;
                      final ts     = DateTime.fromMillisecondsSinceEpoch(
                          ((a['created_at'] as num).toInt()) * 1000);

                      return IceCard(
                        borderColor: pinned ? AppColors.gold : AppColors.border,
                        borderOpacity: pinned ? 0.40 : 0.8,
                        glow: pinned,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (pinned) ...[
                                const McItem(item: 'ender_eye', size: 14),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(a['title'] as String? ?? '',
                                    style: GoogleFonts.exo2(
                                      fontWeight: FontWeight.w700, fontSize: 15,
                                      color: pinned ? AppColors.gold : AppColors.textPrimary,
                                    )),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              '${a['author']} · ${timeago.format(ts, locale: 'ro')}',
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            Text(a['body'] as String? ?? '',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary, height: 1.5, fontSize: 13,
                                )),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
