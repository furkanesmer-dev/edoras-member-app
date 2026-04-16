// lib/main.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/api/auth_events.dart';
import 'package:edoras_member_app/core/config/app_config.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';

import 'package:edoras_member_app/core/theme/app_theme.dart';

import 'package:edoras_member_app/features/auth/auth_gate.dart';
import 'package:edoras_member_app/features/register/register_screen.dart';
import 'package:edoras_member_app/features/profile/profile_setup_screen.dart';

void main() {
  runApp(EdorasApp());
}

class EdorasApp extends StatelessWidget {
  EdorasApp({super.key});

  final TokenStorage tokenStorage = TokenStorage(const FlutterSecureStorage());
  final AuthEvents authEvents = AuthEvents();

  late final ApiClient apiClient = ApiClient(
    dio: Dio(),
    tokenStorage: tokenStorage,
    authEvents: authEvents,
    baseUrl: AppConfig.baseUrl,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Edoras Üye',

      // ✅ Yeni Theme Sistemi
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      home: AuthGate(
        tokenStorage: tokenStorage,
        authEvents: authEvents,
        apiClient: apiClient,
      ),
      routes: {
        '/register': (_) => RegisterScreen(
              apiClient: apiClient,
              tokenStorage: tokenStorage,
            ),

        // route’u kullanıyorsan kalsın
        '/profile-setup': (_) => _ProfileSetupRoute(apiClient: apiClient),
      },
    );
  }
}

class _ProfileSetupRoute extends StatefulWidget {
  final ApiClient apiClient;
  const _ProfileSetupRoute({required this.apiClient});

  @override
  State<_ProfileSetupRoute> createState() => _ProfileSetupRouteState();
}

class _ProfileSetupRouteState extends State<_ProfileSetupRoute> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _meData = const {};

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.apiClient.getProfileMe();
      if (!mounted) return;
      setState(() {
        _meData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Kurulumu')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loadMe, child: const Text('Tekrar Dene')),
              ],
            ),
          ),
        ),
      );
    }

    return ProfileSetupScreen(
      apiClient: widget.apiClient,
      meData: _meData,
      onSaved: () async {
        await _loadMe();
        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }
}