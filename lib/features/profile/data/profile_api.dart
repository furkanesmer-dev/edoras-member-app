import 'package:dio/dio.dart';
import 'profile_models.dart';

class ProfileApi {
  final Dio dio;
  ProfileApi(this.dio);

  Future<ProfileMeResponse> me() async {
    final res = await dio.get('/profile/me.php');
    final raw = res.data;
    final data = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (data['success'] != true && data['ok'] != true) {
      throw Exception(
        data['message']?.toString() ?? data['msg']?.toString() ?? 'Profil alınamadı',
      );
    }
    final inner = data['data'];
    if (inner is! Map) throw Exception('Profil verisi alınamadı');
    return ProfileMeResponse.fromJson(Map<String, dynamic>.from(inner));
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> payload) async {
    final res = await dio.post('/profile/update.php', data: payload);
    final raw = res.data;
    final data = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (data['success'] != true && data['ok'] != true) {
      throw Exception(
        data['message']?.toString() ?? data['msg']?.toString() ?? 'Profil güncellenemedi',
      );
    }
    final inner = data['data'];
    return (inner is Map) ? Map<String, dynamic>.from(inner) : <String, dynamic>{};
  }
}