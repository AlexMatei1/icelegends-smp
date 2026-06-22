import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';
import '../../shared/widgets/mc_item.dart';

final _capsulesProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/capsules');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class CapsuleScreen extends ConsumerStatefulWidget {
  const CapsuleScreen({super.key});
  @override
  ConsumerState<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends ConsumerState<CapsuleScreen> {
  final _msg = TextEditingController();
  DateTime _deliverAt = DateTime.now().add(const Duration(days: 7));
  bool _sending = false;

  @override
  void dispose() { _msg.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await api.dio.post('/api/capsules', data: {
        'message':    _msg.text.trim(),
        'deliver_at': _deliverAt.toIso8601String(),
      });
      _msg.clear();
      ref.invalidate(_capsulesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Capsula a fost trimisă!',
              style: GoogleFonts.inter(color: AppColors.textPrimary)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Eroare: $e',
              style: GoogleFonts.inter(color: AppColors.red)),
        ));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deliverAt,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.ice, surface: AppColors.dark),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _deliverAt = d);
  }

  @override
  Widget build(BuildContext context) {
    final capsules = ref.watch(_capsulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'ender_pearl', size: 22),
          const SizedBox(width: 10),
          Text('Time Capsule', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.purple,
          )),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_capsulesProvider),
          ),
        ],
      ),
      body: IceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            IceCard(
              borderColor: AppColors.purple,
              borderOpacity: 0.25,
              glow: true,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trimite o capsulă', style: GoogleFonts.exo2(
                  color: AppColors.purple, fontSize: 14, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 4),
                Text('Mesajul va fi livrat ție în viitor.',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: _msg,
                  maxLines: 4,
                  maxLength: 500,
                  style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mesajul tău pentru viitor...',
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
                      borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickDate,
                  child: IceCard(
                    borderColor: AppColors.purple,
                    borderOpacity: 0.2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.purple, size: 16),
                      const SizedBox(width: 8),
                      Text('Livrare: ${_deliverAt.day}.${_deliverAt.month}.${_deliverAt.year}',
                          style: GoogleFonts.inter(color: AppColors.purple, fontSize: 13)),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, color: AppColors.textDim, size: 14),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('TRIMITE CAPSULA', style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1,
                          )),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('CAPSULELE MELE', style: GoogleFonts.exo2(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 2,
            )),
            const SizedBox(height: 10),
            capsules.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.purple)),
              error:   (_, __) => Text('Nu s-au putut încărca capsulele.',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
              data: (list) => list.isEmpty
                  ? Text('Nicio capsulă trimisă.',
                      style: GoogleFonts.inter(color: AppColors.textMuted))
                  : Column(
                      children: list.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IceCard(
                          borderColor: AppColors.purple,
                          borderOpacity: 0.15,
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            const McItem(item: 'ender_pearl', size: 28),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['message'] as String? ?? '',
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textPrimary, fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    )),
                                const SizedBox(height: 4),
                                Text(
                                  c['deliver_at'] != null
                                      ? 'Livrare: ${c['deliver_at'].toString().substring(0, 10)}'
                                      : '',
                                  style: GoogleFonts.inter(
                                    color: AppColors.purple, fontSize: 11, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )),
                          ]),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
