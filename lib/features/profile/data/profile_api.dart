import 'package:dio/dio.dart';
import 'profile_models.dart';

class ProfileApi {
  final Dio dio;
  ProfileApi(this.dio);

  Future<ProfileMeResponse> me() async {
    final res = await dio.get('/profile/me.php');
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Profil alınamadı');
    }
    return ProfileMeResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> payload) async {
    final res = await dio.post('/profile/update.php', data: payload);
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Profil güncellenemedi');
    }
    return data['data'] as Map<String, dynamic>;
  }
}