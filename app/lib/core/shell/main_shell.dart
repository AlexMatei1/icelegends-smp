import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_provider.dart';
import '../theme/app_theme.dart';
import '../../shared/widgets/mc_item.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab('/dashboard',   'diamond',    'Home'),
    _Tab('/profile',     'totem',      'Profil'),
    _Tab('/missions',    'arrow',      'Misiuni'),
    _Tab('/leaderboard', 'gold_ingot', 'Clasament'),
    _Tab('/more',        'ender_eye',  'Meniu'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final loc = GoRouterState.of(context).matchedLocation;

    const moreRoutes = {
      '/bounties', '/stocks', '/capsule', '/wars', '/shop',
      '/clans', '/vote', '/appeal', '/announcements', '/social', '/admin',
    };

    int idx = _tabs.indexWhere((t) => loc.startsWith(t.path));
    if (idx < 0 && moreRoutes.any((r) => loc.startsWith(r))) idx = 4;
    final selected = idx < 0 ? 0 : idx;

    return Scaffold(
      body: child,
      bottomNavigationBar: _IceNavBar(
        tabs: _tabs,
        selected: selected,
        onSelect: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}

class _IceNavBar extends StatelessWidget {
  final List<_Tab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _IceNavBar({required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.deep,
        border: Border(top: BorderSide(color: AppColors.ice.withOpacity(0.12), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i      = entry.key;
              final tab    = entry.value;
              final active = selected == i;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: active ? AppColors.ice.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: active
                              ? [BoxShadow(color: AppColors.ice.withOpacity(0.2), blurRadius: 14)]
                              : null,
                        ),
                        child: active
                            ? McItem(item: tab.mcItem, size: 22)
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.3, 0.3, 0.3, 0, 0,
                                  0.3, 0.3, 0.3, 0, 0,
                                  0.3, 0.3, 0.3, 0, 0,
                                  0,   0,   0,   1, 0,
                                ]),
                                child: McItem(item: tab.mcItem, size: 22),
                              ),
                      ),
                      const SizedBox(height: 3),
                      Text(tab.label, style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? AppColors.ice : AppColors.textMuted,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String mcItem;
  final String label;
  const _Tab(this.path, this.mcItem, this.label);
}
