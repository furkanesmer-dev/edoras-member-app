import 'package:flutter/material.dart';

import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';

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
  final _passCtl = TextEditingController();

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
    final pass = _passCtl.text;

    if (login.isEmpty || pass.isEmpty) {
      setState(() => _error = 'E-posta/telefon ve şifre zorunlu.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = widget.apiClient;

      final res = await api.dio.post(
        '/auth/login.php',
        data: {
          'login': login,
          'password': pass,
        },
      );

      final data = res.data;
      final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      final inner = (map['data'] is Map) ? Map<String, dynamic>.from(map['data']) : <String, dynamic>{};

      final token = (map['token'] ??
              map['access_token'] ??
              map['jwt'] ??
              inner['token'] ??
              inner['access_token'] ??
              inner['jwt'])
          ?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('Token alınamadı. Response: $data');
      }

      await widget.tokenStorage.writeToken(token);

      if (widget.onLoggedIn != null) {
        await widget.onLoggedIn!();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Giriş başarısız: $e');
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // ✅ Logo (siyah, şeffaf arka plan)
                  Center(
                    child: Image.asset(
                      'assets/icons/edoras_logo_black_transparent_1024.png',
                      height: 130,
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

                  const SizedBox(height: 26),

                  // ✅ Inputlar
                  _NiceField(
                    controller: _loginCtl,
                    label: 'E-posta veya Telefon',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _NiceField(
                    controller: _passCtl,
                    label: 'Şifre',
                    icon: Icons.lock_outline,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _doLogin(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                      ),
                    ),

                  // ✅ Buton (yazı görünmeme fix: foregroundColor)
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
                      onPressed: _loading ? null : _doLogin,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Giriş Yap',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/register'),
                    child: const Text(
                      'Hesabın yok mu? Üye Ol',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

class _NiceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const _NiceField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
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