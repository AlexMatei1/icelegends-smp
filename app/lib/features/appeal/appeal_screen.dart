import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _appealsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/appeals/mine');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key});
  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _reason = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Motivul trebuie să aibă cel puțin 20 de caractere.',
            style: GoogleFonts.inter(color: AppColors.red)),
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      await api.dio.post('/api/appeals', data: {'reason': _reason.text.trim()});
      _reason.clear();
      ref.invalidate(_appealsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Contestația a fost trimisă!',
              style: GoogleFonts.inter(color: AppColors.textPrimary)),
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = (e as dynamic).response?.data?['error'] ?? e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$msg', style: GoogleFonts.inter(color: AppColors.red)),
        ));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final appeals = ref.watch(_appealsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'book', size: 22),
          const SizedBox(width: 10),
          Text('Contestație Ban', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        ]),
      ),
      body: IceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Warning banner
            IceCard(
              borderColor: AppColors.gold,
              borderOpacity: 0.3,
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_outlined, color: AppColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Contestațiile false sau cu insulte vor fi respinse automat și pot duce la ban permanent.',
                  style: GoogleFonts.inter(color: AppColors.gold, fontSize: 12, height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Form
            IceCard(
              borderColor: AppColors.ice,
              borderOpacity: 0.2,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trimite contestație', style: GoogleFonts.exo2(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 4),
                Text('Explică de ce crezi că ban-ul a fost nedrept.',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: _reason,
                  maxLines: 5,
                  maxLength: 1000,
                  style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Motivul contestației...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textDim),
                    counterStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11),
                    filled: true, fillColor: AppColors.dark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.ice, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                        : Text('TRIMITE CONTESTAȚIA', style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1,
                            color: AppColors.background,
                          )),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            Text('CONTESTAȚIILE MELE', style: GoogleFonts.exo2(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 2,
            )),
            const SizedBox(height: 10),
            appeals.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ice)),
              error:   (_, __) => Text('Nu s-au putut încărca contestațiile.',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
              data: (list) => list.isEmpty
                  ? Text('Nicio contestație trimisă.',
                      style: GoogleFonts.inter(color: AppColors.textMuted))
                  : Column(
                      children: list.map((a) {
                        final status = a['status'] as String? ?? 'pending';
                        final color = status == 'approved'
                            ? AppColors.green
                            : status == 'rejected' ? AppColors.red : AppColors.gold;
                        final label = status == 'approved'
                            ? 'Aprobat' : status == 'rejected' ? 'Respins' : 'În așteptare';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: IceCard(
                            borderColor: color,
                            borderOpacity: 0.2,
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color.withOpacity(0.4)),
                                  ),
                                  child: Text(label, style: GoogleFonts.exo2(
                                    color: color, fontSize: 10, fontWeight: FontWeight.w700,
                                  )),
                                ),
                                const Spacer(),
                                Text(
                                  a['created_at']?.toString().substring(0, 10) ?? '',
                                  style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Text(a['reason'] as String? ?? '',
                                  maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 13,
                                  )),
                              if (a['note'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.dark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const McItem(item: 'dragon_egg', size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(a['note'] as String,
                                        style: GoogleFonts.inter(
                                          color: AppColors.textPrimary, fontSize: 12,
                                        ))),
                                  ]),
                                ),
                              ],
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
