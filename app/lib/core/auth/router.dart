import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/bounties/bounties_screen.dart';
import '../../features/wars/wars_screen.dart';
import '../../features/missions/missions_screen.dart';
import '../../features/clans/clans_screen.dart';
import '../../features/social/social_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/stocks/stocks_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/announcements/announcements_screen.dart';
import '../../features/capsule/capsule_screen.dart';
import '../../features/vote/vote_screen.dart';
import '../../features/appeal/appeal_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final auth    = authAsync.valueOrNull;
      if (auth == null) return null;
      final loggedIn = auth.status == AuthStatus.authenticated;
      final onAuth   = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',     builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/profile',       builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/missions',      builder: (_, __) => const MissionsScreen()),
          GoRoute(path: '/leaderboard',   builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/more',          builder: (_, __) => const MoreScreen()),
          // Accessible from More menu
          GoRoute(path: '/bounties',      builder: (_, __) => const BountiesScreen()),
          GoRoute(path: '/stocks',        builder: (_, __) => const StocksScreen()),
          GoRoute(path: '/capsule',       builder: (_, __) => const CapsuleScreen()),
          GoRoute(path: '/wars',          builder: (_, __) => const WarsScreen()),
          GoRoute(path: '/shop',          builder: (_, __) => const ShopScreen()),
          GoRoute(path: '/clans',         builder: (_, __) => const ClansScreen()),
          GoRoute(path: '/vote',          builder: (_, __) => const VoteScreen()),
          GoRoute(path: '/appeal',        builder: (_, __) => const AppealScreen()),
          GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen()),
          GoRoute(path: '/social',        builder: (_, __) => const SocialScreen()),
          GoRoute(path: '/admin',         builder: (_, __) => const AdminScreen()),
        ],
      ),
    ],
  );
});
