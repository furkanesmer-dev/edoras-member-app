import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    Center(
                      child: Image.asset(
                        'assets/icons/edoras_logo_black_transparent_1024.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Edoras Akademi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: Colors.black,
                            ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Center(
                      child: Text(
                        'Hesap oluştur',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: Colors.black,
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Bilgilerini girerek kayıt ol.',
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 22),

                    _NiceFormField(
                      controller: _adCtrl,
                      label: 'Ad',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad zorunlu' : null,
                    ),
                    const SizedBox(height: 14),

                    _NiceFormField(
                      controller: _soyadCtrl,
                      label: 'Soyad',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Soyad zorunlu' : null,
                    ),
                    const SizedBox(height: 14),

                    _NiceFormField(
                      controller: _phoneCtrl,
                      label: 'Telefon',
                      hintText: '05xx xxx xx xx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Telefon zorunlu';
                        if (_normalizePhone(s).length < 10) return 'Telefon numarası geçersiz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _NiceFormField(
                      controller: _emailCtrl,
                      label: 'E-posta',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'E-posta zorunlu';
                        if (!s.contains('@') || !s.contains('.')) return 'Geçerli bir e-posta gir';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _NiceFormField(
                      controller: _passCtrl,
                      label: 'Parola',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return 'Parola zorunlu';
                        if (s.length < 6) return 'Parola en az 6 karakter olmalı';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: Colors.white, // ✅ yazı garanti görünür
                          disabledBackgroundColor: scheme.primary.withOpacity(0.6),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Üye Ol',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                      child: const Text(
                        'Zaten hesabın var mı? Giriş Yap',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NiceFormField extends StatelessWidget {
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

  const _NiceFormField({
    required this.controller,
    required this.label,
    required this.icon,
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
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF2F4F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
    );
  }
}