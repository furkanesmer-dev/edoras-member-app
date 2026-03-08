import 'package:edoras_member_app/core/api/api_client.dart';

class BeslenmeApi {
  final ApiClient apiClient;

  BeslenmeApi({required this.apiClient});

  /// GET /beslenme/gunluk_get.php?tarih=YYYY-MM-DD
  /// Amaç:
  /// Eğitmenin tanımladığı plan öğelerinden hangilerinin
  /// kullanıcı tarafından tüketilmiş / işaretlenmiş olduğunu almak.
  Future<Map<String, dynamic>> gunlukGet({String? tarih}) async {
    return apiClient.getMap(
      '/beslenme/gunluk_get.php',
      queryParameters: tarih != null ? {'tarih': tarih} : null,
    );
  }
}