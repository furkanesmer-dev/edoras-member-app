import 'package:flutter/material.dart';

import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final Future<void> Function()? onLoggedIn;

  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
    this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtl = TextEditingController();
  final _passCtl  = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _loginCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final login = _loginCtl.text.trim();
    final pass  = _passCtl.text;

    if (login.isEmpty || pass.isEmpty) {
      setState(() => _error = 'E-posta/telefon ve şifre zorunlu.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final res = await widget.apiClient.dio.post(
        '/auth/login.php',
        data: {'login': login, 'password': pass},
      );

      final data  = res.data;
      final map   = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final inner = (map['data'] is Map) ? Map<String, dynamic>.from(map['data']) : <String, dynamic>{};

      final token = (map['token'] ?? map['access_token'] ?? map['jwt'] ??
                     inner['token'] ?? inner['access_token'] ?? inner['jwt'])?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('Token alınamadı. Response: $data');
      }

      await widget.tokenStorage.writeToken(token);
      if (widget.onLoggedIn != null) await widget.onLoggedIn!();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Giriş başarısız: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          // Arka plan dekor
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.20 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(isDark ? 0.14 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Logo
                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            isDark
                                ? 'assets/icons/edoras_logo_black_transparent_1024.png'
                                : 'assets/icons/edoras_logo_black_transparent_1024.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Başlık
                      Text(
                        'Tekrar\nHoş Geldin!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          height: 1.1,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hesabına giriş yap ve devam et',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Alan: E-posta/telefon
                      _Field(
                        controller: _loginCtl,
                        label: 'E-posta veya Telefon',
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _passCtl,
                        label: 'Şifre',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _doLogin(),
                        isDark: isDark,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Hata
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.danger.withOpacity(0.30)),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Giriş butonu (gradient)
                      SizedBox(
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _loading ? null : AppColors.primaryGradient,
                            color: _loading ? AppColors.primary.withOpacity(0.4) : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _loading
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.40),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _loading ? null : _doLogin,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Kayıt ol
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/register'),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            ),
                            children: [
                              const TextSpan(text: 'Hesabın yok mu?  '),
                              TextSpan(
                                text: 'Üye Ol',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final bool isDark;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}