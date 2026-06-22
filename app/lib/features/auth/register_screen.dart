import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _user  = TextEditingController();
  final _token = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _user.dispose(); _token.dispose(); _pass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await api.dio.post('/api/player/claim', data: {
        'username': _user.text.trim(),
        'token':    _token.text.trim(),
        'password': _pass.text.trim(),
      });
      // Auto-login after claim
      await ref.read(authProvider.notifier).login(
        _user.text.trim(), _pass.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = (e as dynamic).response?.data?['error'] ?? e.toString();
      setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Înregistrare')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ice.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ice.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.ice, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Rulează /registerweb în joc pentru a obține codul tău unic.',
                  style: TextStyle(color: AppColors.ice, fontSize: 13),
                )),
              ]),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username Minecraft'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Cod din /registerweb',
                hintText: '123456',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Alege o parolă (min. 6 caractere)'),
              onSubmitted: (_) => _register(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Text(_success!, style: const TextStyle(color: AppColors.green, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : const Text('Creează cont'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Ai deja cont? Autentifică-te',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
