import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ice_background.dart';
import '../../shared/widgets/ice_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).login(
      _user.text.trim(), _pass.text.trim(),
    );
    if (!mounted) return;
    if (err != null) setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      body: IceBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ice.withOpacity(0.28), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: AppColors.ice.withOpacity(0.14), blurRadius: 28, spreadRadius: 0),
                      ],
                      gradient: RadialGradient(
                        colors: [AppColors.ice.withOpacity(0.08), Colors.transparent],
                      ),
                    ),
                    child: const Center(child: Text('❄', style: TextStyle(fontSize: 42))),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'IceLegends',
                    style: GoogleFonts.exo2(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ice,
                      letterSpacing: 2,
                      shadows: [Shadow(color: AppColors.ice.withOpacity(0.35), blurRadius: 14)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'S M P  P A N E L',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 44),

                  // Login card
                  IceCard(
                    padding: const EdgeInsets.all(24),
                    glow: true,
                    child: Column(children: [
                      _Field(
                        controller: _user,
                        label: 'Username Minecraft',
                        icon: Icons.person_outline,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _pass,
                        label: 'Parolă',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        action: TextInputAction.done,
                        onSubmit: (_) => _login(),
                        suffix: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted, size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.red.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.red, size: 14),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: GoogleFonts.inter(color: AppColors.red, fontSize: 13))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: _loading
                            ? Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.ice.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.ice.withOpacity(0.25)),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ice),
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: AppColors.ice,
                                  foregroundColor: AppColors.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text('Autentificare',
                                    style: GoogleFonts.exo2(
                                      fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5,
                                      color: AppColors.background,
                                    )),
                              ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(
                      'Nu ai cont? Înregistrează-te cu /registerweb',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmit;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.action,
    this.onSubmit,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmit,
      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
