import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/mc_item.dart';

final _adminStatusProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/admin/status');
  return res.data as Map<String, dynamic>;
});

final _onlinePlayersProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final res = await api.dio.get('/api/player/admin/players');
  return (res.data as List).cast<String>();
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const McItem(item: 'dragon_egg', size: 24),
          const SizedBox(width: 10),
          Text('Admin', style: GoogleFonts.exo2(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.red,
          )),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.red,
          labelColor: AppColors.red,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Server'),
            Tab(text: 'Jucători'),
            Tab(text: 'Consolă'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _ServerTab(ref: ref),
        _PlayersTab(ref: ref),
        const _ConsoleTab(),
      ]),
    );
  }
}

class _ServerTab extends StatelessWidget {
  final WidgetRef ref;
  const _ServerTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(_adminStatusProvider);
    final msgCtrl = TextEditingController();

    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (d) {
        final tps     = (d['tps'] as List?)?.cast<num>() ?? [];
        final memUsed = (d['memUsed'] as num?)?.toInt() ?? 0;
        final memMax  = (d['memMax']  as num?)?.toInt() ?? 0;
        final players = (d['players'] as List?)?.cast<String>() ?? [];
        final memPct  = memMax > 0 ? memUsed / memMax : 0.0;
        final tps1    = tps.isNotEmpty ? tps.last.toDouble() : 0.0;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_adminStatusProvider),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // TPS card
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TPS', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: tps.map((t) {
                  final v = t.toDouble();
                  final color = v >= 18 ? AppColors.green : v >= 15 ? AppColors.gold : AppColors.red;
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(v.toStringAsFixed(1),
                        style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
                  );
                }).toList()),
                const SizedBox(height: 4),
                const Text('1m  5m  15m', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ))),
            const SizedBox(height: 12),
            // Memory card
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('RAM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const Spacer(),
                  Text('$memUsed / $memMax MB',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: memPct.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                        memPct > 0.85 ? AppColors.red : memPct > 0.65 ? AppColors.gold : AppColors.green),
                  ),
                ),
              ],
            ))),
            const SizedBox(height: 12),
            // Players online
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Online (${players.length})',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                if (players.isEmpty)
                  const Text('Niciun jucător.', style: TextStyle(color: AppColors.textMuted))
                else
                  Wrap(spacing: 8, runSpacing: 6, children: players.map((p) => Chip(
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.surfaceAlt,
                    side: const BorderSide(color: AppColors.border),
                  )).toList()),
              ],
            ))),
            const SizedBox(height: 16),
            // Broadcast
            Text('Broadcast', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: msgCtrl,
                  decoration: const InputDecoration(hintText: 'Mesaj pentru toți jucătorii', isDense: true))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.background),
                onPressed: () async {
                  if (msgCtrl.text.trim().isEmpty) return;
                  try {
                    await api.dio.post('/api/player/admin/broadcast', data: {'message': msgCtrl.text.trim()});
                    msgCtrl.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Broadcast trimis!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e'), backgroundColor: AppColors.red),
                      );
                    }
                  }
                },
                child: const Text('Trimite'),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final WidgetRef ref;
  const _PlayersTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(_onlinePlayersProvider);

    return players.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_onlinePlayersProvider),
        child: list.isEmpty
            ? const Center(child: Text('Niciun jucător online.',
                style: TextStyle(color: AppColors.textMuted)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    leading: const McItem(item: 'totem', size: 32),
                    title: Text(p),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Kick',
                        icon: const Icon(Icons.logout, color: AppColors.gold, size: 20),
                        onPressed: () => _kick(context, p),
                      ),
                      IconButton(
                        tooltip: 'Ban',
                        icon: const Icon(Icons.block, color: AppColors.red, size: 20),
                        onPressed: () => _ban(context, p),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _kick(BuildContext context, String name) async {
    final reason = await _askReason(context, 'Kick $name', 'Motiv kick');
    if (reason == null) return;
    await api.dio.post('/api/player/admin/players/$name/kick', data: {'reason': reason});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name a fost dat afară.')));
    }
  }

  Future<void> _ban(BuildContext context, String name) async {
    final reason = await _askReason(context, 'Ban $name', 'Motiv ban');
    if (reason == null) return;
    await api.dio.post('/api/player/admin/players/$name/ban', data: {'reason': reason});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name a fost banat.'), backgroundColor: AppColors.red));
    }
  }

  Future<String?> _askReason(BuildContext context, String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(controller: ctrl,
            decoration: InputDecoration(hintText: hint), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Confirmă')),
        ],
      ),
    );
  }
}

class _ConsoleTab extends StatefulWidget {
  const _ConsoleTab();
  @override
  State<_ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<_ConsoleTab> {
  final _lines   = <String>[];
  final _cmdCtrl = TextEditingController();
  final _scroll  = ScrollController();
  WebSocketChannel? _ws;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final token = await api.getToken();
    if (token == null) return;
    try {
      _ws = WebSocketChannel.connect(
        Uri.parse('wss://mc.ice4legends.com/ws/console?token=$token'),
      );
      setState(() => _connected = true);
      _ws!.stream.listen(
        (msg) {
          // Server sends JSON envelopes: {type, text}
          String line;
          try {
            final obj = jsonDecode(msg.toString()) as Map<String, dynamic>;
            line = obj['text']?.toString() ?? msg.toString();
          } catch (_) {
            line = msg.toString();
          }
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;
          setState(() => _lines.add(trimmed));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
        },
        onDone: () => setState(() => _connected = false),
        onError: (_) => setState(() => _connected = false),
      );
    } catch (_) { setState(() => _connected = false); }
  }

  void _send() {
    final cmd = _cmdCtrl.text.trim();
    if (cmd.isEmpty || _ws == null) return;
    _ws!.sink.add('{"cmd":"$cmd"}');
    _cmdCtrl.clear();
  }

  @override
  void dispose() { _ws?.sink.close(); _cmdCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: AppColors.surfaceAlt,
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(
                color: _connected ? AppColors.green : AppColors.red,
                shape: BoxShape.circle,
              )),
          const SizedBox(width: 8),
          Text(_connected ? 'Consolă conectată' : 'Deconectat',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          if (!_connected)
            TextButton(onPressed: _connect, child: const Text('Reconectează')),
        ]),
      ),
      Expanded(
        child: Container(
          color: const Color(0xFF0A0E14),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(10),
            itemCount: _lines.length,
            itemBuilder: (_, i) {
              final line = _lines[i];
              Color color = const Color(0xFFCDD9E5);
              if (line.contains('ERROR') || line.contains('WARN')) color = AppColors.gold;
              if (line.contains('SEVERE') || line.contains('Exception')) color = AppColors.red;
              return Text(line, style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, color: color, height: 1.4));
            },
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        color: AppColors.surface,
        child: Row(children: [
          const Text('> ', style: TextStyle(color: AppColors.green, fontFamily: 'monospace')),
          Expanded(
            child: TextField(
              controller: _cmdCtrl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Comandă server...',
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send, color: AppColors.green, size: 20),
              onPressed: _send),
        ]),
      ),
    ]);
  }
}
