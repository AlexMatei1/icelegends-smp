import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/player_avatar.dart';

final _feedProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/feed');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final _friendsProvider = FutureProvider.autoDispose((ref) async {
  final res = await api.dio.get('/api/player/friends');
  return res.data as Map<String, dynamic>;
});

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});
  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.ice,
          labelColor: AppColors.ice,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Feed'), Tab(text: 'Prieteni')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedTab(ref: ref),
          _FriendsTab(ref: ref),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final WidgetRef ref;
  const _FeedTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(_feedProvider);
    final auth = ref.watch(authProvider).valueOrNull;

    return Column(children: [
      _PostComposer(ref: ref),
      Expanded(
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('$e')),
          data: (posts) => posts.isEmpty
              ? const Center(child: Text('Niciun post. Adaugă prieteni sau postează primul!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted)))
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_feedProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PostCard(
                      post: posts[i],
                      myUsername: auth?.username ?? '',
                      ref: ref,
                    ),
                  ),
                ),
        ),
      ),
    ]);
  }
}

class _PostComposer extends StatefulWidget {
  final WidgetRef ref;
  const _PostComposer({required this.ref});
  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await api.dio.post('/api/player/feed/post', data: {'content': text});
      _ctrl.clear();
      widget.ref.invalidate(_feedProvider);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _ctrl,
          maxLength: 280,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Ce mai faci pe server?',
            counterText: '',
            isDense: true,
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _posting ? null : _post,
        icon: _posting
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send, color: AppColors.ice),
      ),
    ]),
  );
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String myUsername;
  final WidgetRef ref;
  const _PostCard({required this.post, required this.myUsername, required this.ref});

  @override
  Widget build(BuildContext context) {
    final author   = post['author_name'] as String? ?? '';
    final content  = post['content'] as String? ?? '';
    final likes    = (post['likes'] as num?)?.toInt() ?? 0;
    final likedMe  = (post['liked_by_me'] as num?)?.toInt() ?? 0;
    final ts       = DateTime.fromMillisecondsSinceEpoch(
        ((post['created_at'] as num).toInt()) * 1000);
    final isMe = author.toLowerCase() == myUsername.toLowerCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(author, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ice)),
            const Spacer(),
            Text(timeago.format(ts, locale: 'ro'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            if (isMe) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () async {
                  await api.dio.delete('/api/player/feed/${post['id']}');
                  ref.invalidate(_feedProvider);
                },
                child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(children: [
            GestureDetector(
              onTap: () async {
                await api.dio.post('/api/player/feed/like/${post['id']}');
                ref.invalidate(_feedProvider);
              },
              child: Row(children: [
                Icon(likedMe > 0 ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: likedMe > 0 ? AppColors.red : AppColors.textMuted),
                const SizedBox(width: 4),
                Text('$likes', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  final WidgetRef ref;
  const _FriendsTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(_friendsProvider);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (d) {
        final accepted = (d['accepted'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final incoming = (d['incoming'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_friendsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AddFriendBar(ref: ref),
              if (incoming.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Cereri primite (${incoming.length})',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...incoming.map((f) => _FriendRequestTile(f: f, ref: ref)),
              ],
              const SizedBox(height: 16),
              Text('Prieteni (${accepted.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (accepted.isEmpty)
                const Text('Niciun prieten încă.',
                    style: TextStyle(color: AppColors.textMuted))
              else
                ...accepted.map((f) => _FriendTile(f: f, ref: ref)),
            ],
          ),
        );
      },
    );
  }
}

class _AddFriendBar extends StatefulWidget {
  final WidgetRef ref;
  const _AddFriendBar({required this.ref});
  @override
  State<_AddFriendBar> createState() => _AddFriendBarState();
}

class _AddFriendBarState extends State<_AddFriendBar> {
  final _ctrl = TextEditingController();
  String? _msg;
  Color _color = AppColors.green;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(
        child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            hintText: 'Adaugă prieten după username',
            isDense: true,
          ),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: () async {
          try {
            await api.dio.post('/api/player/friends/add', data: {'target': _ctrl.text.trim()});
            setState(() { _msg = 'Cerere trimisă!'; _color = AppColors.green; });
            _ctrl.clear();
            widget.ref.invalidate(_friendsProvider);
          } catch (e) {
            setState(() { _msg = (e as dynamic).response?.data?['error'] ?? '$e'; _color = AppColors.red; });
          }
        },
        child: const Text('Adaugă'),
      ),
    ]),
    if (_msg != null) Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(_msg!, style: TextStyle(color: _color, fontSize: 12)),
    ),
  ]);
}

class _FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> f;
  final WidgetRef ref;
  const _FriendRequestTile({required this.f, required this.ref});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(f['name'] as String? ?? ''),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
          onPressed: () async {
            await api.dio.delete('/api/player/friends/${f['name']}');
            ref.invalidate(_friendsProvider);
          },
          child: const Text('Refuză', style: TextStyle(color: AppColors.red)),
        ),
        ElevatedButton(
          onPressed: () async {
            await api.dio.post('/api/player/friends/accept/${f['id']}');
            ref.invalidate(_friendsProvider);
          },
          child: const Text('Acceptă'),
        ),
      ]),
    ),
  );
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> f;
  final WidgetRef ref;
  const _FriendTile({required this.f, required this.ref});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.person, color: AppColors.ice),
    title: Text(f['name'] as String? ?? ''),
    trailing: IconButton(
      icon: const Icon(Icons.person_remove_outlined, color: AppColors.textMuted),
      onPressed: () async {
        await api.dio.delete('/api/player/friends/${f['name']}');
        ref.invalidate(_friendsProvider);
      },
    ),
  );
}
