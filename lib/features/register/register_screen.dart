import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  const RegisterScreen({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _adCtrl = TextEditingController();
  final _soyadCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'\D+'), '');

  Future<void> _register() async {
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final ad = _adCtrl.text.trim();
      final soyad = _soyadCtrl.text.trim();
      final phone = _normalizePhone(_phoneCtrl.text.trim());
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final res = await widget.apiClient.dio.post(
        '/auth/register.php',
        data: {
          'ad': ad,
          'soyad': soyad,
          'phone': phone,
          'email': email,
          'password': password,
        },
      );

      final json = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      final ok = json['ok'] == true || json['success'] == true;
      if (!ok) {
        throw Exception(
          json['msg'] ?? json['message'] ?? 'Kayıt başarısız.',
        );
      }

      final token = (json['data'] is Map ? (json['data'] as Map)['token'] : null) ?? json['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Token alınamadı.');
      }

      await widget.tokenStorage.writeToken(token.toString());

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withOpacity(isDark ? 0.18 : 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.secondary.withOpacity(isDark ? 0.14 : 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Logo
                        Center(
                          child: ColorFiltered(
                            colorFilter: isDark
                                ? const ColorFilter.matrix([
                                    -1, 0, 0, 0, 255,
                                    0, -1, 0, 0, 255,
                                    0, 0, -1, 0, 255,
                                    0, 0, 0, 1, 0,
                                  ])
                                : const ColorFilter.mode(
                                    Colors.transparent, BlendMode.multiply),
                            child: Image.asset(
                              'assets/icons/edoras_logo_black_transparent_1024.png',
                              height: 110,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Hesap Oluştur',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.1,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bilgilerini girerek kayıt ol',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                          ),
                        ),

                        const SizedBox(height: 28),

                        _FormField(controller: _adCtrl, label: 'Ad', icon: Icons.badge_outlined, textInputAction: TextInputAction.next, isDark: isDark,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad zorunlu' : null,
                        ),
                        const SizedBox(height: 12),
                        _FormField(controller: _soyadCtrl, label: 'Soyad', icon: Icons.badge_outlined, textInputAction: TextInputAction.next, isDark: isDark,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Soyad zorunlu' : null,
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          controller: _phoneCtrl, label: 'Telefon', hintText: '05xx xxx xx xx',
                          icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next, isDark: isDark,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Telefon zorunlu';
                            if (_normalizePhone(s).length < 10) return 'Telefon numarası geçersiz';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          controller: _emailCtrl, label: 'E-posta',
                          icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next, isDark: isDark,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'E-posta zorunlu';
                            if (!s.contains('@') || !s.contains('.')) return 'Geçerli bir e-posta gir';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          controller: _passCtrl, label: 'Parola',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          isDark: isDark,
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            ),
                          ),
                          validator: (v) {
                            final s = v ?? '';
                            if (s.isEmpty) return 'Parola zorunlu';
                            if (s.length < 6) return 'Parola en az 6 karakter olmalı';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

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
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Üye ol butonu
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _loading ? null : _register,
                              child: _loading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Text(
                                      'Üye Ol',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.2),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                              ),
                              children: [
                                const TextSpan(text: 'Zaten hesabın var mı?  '),
                                TextSpan(
                                  text: 'Giriş Yap',
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool isDark;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.hintText,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}