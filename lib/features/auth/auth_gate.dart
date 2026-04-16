import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/api/auth_events.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';

import 'package:edoras_member_app/features/login/login_screen.dart';
import 'package:edoras_member_app/features/shell/main_shell.dart';
import 'package:edoras_member_app/features/profile/profile_setup_screen.dart';

class AuthGate extends StatefulWidget {
  final TokenStorage tokenStorage;
  final AuthEvents authEvents;
  final ApiClient apiClient;

  const AuthGate({
    super.key,
    required this.tokenStorage,
    required this.authEvents,
    required this.apiClient,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<void>? _sub;

  bool _ready = false;
  bool _loggedIn = false;

  bool _loadingMe = false;
  String? _meError;

  Map<String, dynamic>? _meData; // {profile, subscription, targets}

  @override
  void initState() {
    super.initState();

    _sub = widget.authEvents.onUnauthorized.listen((_) async {
      // Guard: Birden fazla 401 yanıtı (örn. home_screen Future.wait) tekrar tetikleyebilir.
      // Zaten logout olunmuşsa işlem yapma.
      if (!_loggedIn) return;
      await widget.tokenStorage.clear();
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _meData = null;
        _meError = null;
        _loadingMe = false;
        _ready = true;
      });
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await widget.tokenStorage.readToken();
    if (!mounted) return;

    final logged = token != null && token.isNotEmpty;

    setState(() {
      _loggedIn = logged;
      _ready = true;
      _meData = null;
      _meError = null;
      _loadingMe = false;
    });

    if (logged) {
      await _loadMe();
    }
  }

  Future<void> _handleLoggedIn() async {
    await _bootstrap();
  }

  Future<void> _logout() async {
    await widget.tokenStorage.clear();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _meData = null;
      _meError = null;
      _loadingMe = false;
      _ready = true;
    });
  }

  Future<void> _loadMe() async {
    setState(() {
      _loadingMe = true;
      _meError = null;
      _meData = null;
    });

    try {
      final data = await widget.apiClient.getProfileMe();
      if (!mounted) return;
      // Race condition guard: _loadMe beklenirken onUnauthorized tetiklenmiş
      // ve _loggedIn = false yapılmış olabilir. Stale data set etme.
      if (!_loggedIn) return;
      setState(() {
        _meData = data;
        _loadingMe = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_loggedIn) return;
      setState(() {
        _meError = _friendlyAuthError(e);
        _loadingMe = false;
      });
    }
  }

  /// Kullanıcıya gösterilecek auth hata mesajı — teknik detayları gizler.
  String _friendlyAuthError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edin.';
      }
      // e.error içinde backend mesajı olabilir ama URL/path barındırmıyorsa göster
      final msg = e.error?.toString() ?? '';
      if (msg.isNotEmpty &&
          !msg.contains('http') &&
          !msg.contains('DioException') &&
          !msg.contains('SocketException')) {
        return msg;
      }
      return 'Profil bilgisi alınamadı. Lütfen tekrar deneyin.';
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  bool _isProfileComplete(Map<String, dynamic> meData) {
    final pRaw = meData['profile'];
    if (pRaw is! Map) return false;
    final p = Map<String, dynamic>.from(pRaw);

    bool hasStr(String key) {
      final v = p[key];
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty && s != 'null';
    }

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    final boy = asDouble(p['boy_cm']);
    final kilo = asDouble(p['kilo_kg']);

    final hasAge = hasStr('dogum_tarihi') ||
        (p['yas'] != null && int.tryParse(p['yas'].toString()) != null);

    return hasStr('cinsiyet') &&
        hasAge &&
        (boy != null && boy > 0) &&
        (kilo != null && kilo > 0) &&
        hasStr('aktivite_seviyesi') &&
        hasStr('kilo_hedefi') &&
        hasStr('hedef_tempo');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_loggedIn) {
      return LoginScreen(
        apiClient: widget.apiClient,
        tokenStorage: widget.tokenStorage,
        onLoggedIn: _handleLoggedIn,
      );
    }

    if (_loadingMe && _meData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_meError != null && _meData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profil alınamadı:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_meError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMe, child: const Text('Tekrar Dene')),
              const SizedBox(height: 10),
              TextButton(onPressed: _logout, child: const Text('Çıkış Yap')),
            ],
          ),
        ),
      );
    }

    final me = _meData!;
    final complete = _isProfileComplete(me);

    if (!complete) {
      return ProfileSetupScreen(
        apiClient: widget.apiClient,
        meData: me,
        onSaved: () async {
          await _loadMe();
        },
      );
    }

    return MainShell(apiClient: widget.apiClient,tokenStorage: widget.tokenStorage,);
  }
}