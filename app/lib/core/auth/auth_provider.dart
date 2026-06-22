import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? username;
  final String? uuid;
  final String? role;

  const AuthState({
    required this.status,
    this.username,
    this.uuid,
    this.role,
  });

  bool get isAdmin =>
      role == 'moderator' || role == 'admin' || role == 'owner';
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await api.getToken();
    if (token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    return _fetchMe();
  }

  Future<AuthState> _fetchMe() async {
    try {
      final res = await api.dio.get('/api/player/me');
      final d = res.data as Map<String, dynamic>;
      return AuthState(
        status:   AuthStatus.authenticated,
        username: d['username'] as String?,
        uuid:     d['uuid'] as String?,
        role:     d['role'] as String?,
      );
    } catch (_) {
      await api.clearToken();
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<String?> login(String username, String password) async {
    try {
      final res = await api.dio.post('/api/player/login', data: {
        'username': username,
        'password': password,
      });
      final token = res.data['token'] as String?;
      if (token != null) {
        await api.saveToken(token);
        state = AsyncData(await _fetchMe());
        return null;
      }
      // Panel sets cookie; also check Authorization header fallback
      // If no token in body, try fetching me directly (cookie-based)
      state = AsyncData(await _fetchMe());
      return null;
    } on Exception catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> logout() async {
    await api.clearToken();
    try { await api.dio.post('/api/player/logout'); } catch (_) {}
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
