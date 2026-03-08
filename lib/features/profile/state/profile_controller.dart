import 'package:flutter/foundation.dart';
import '../data/profile_api.dart';
import '../data/profile_models.dart';

class ProfileController extends ChangeNotifier {
  final ProfileApi api;
  ProfileController(this.api);

  bool loading = false;
  String? error;

  ProfileMeResponse? meData;

  Future<void> loadMe() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      meData = await api.me();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.update(payload);
      // Update sonrası en sağlam yol: me'yi tekrar çek
      meData = await api.me();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool get needsOnboarding {
    final p = meData?.profile;
    if (p == null) return true;
    return !p.isOnboardingComplete;
  }
}