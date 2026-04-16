import 'package:edoras_member_app/core/api/api_client.dart';

class BeslenmeApi {
  final ApiClient apiClient;

  BeslenmeApi({required this.apiClient});

  Future<Map<String, dynamic>> gunlukGet({String? tarih}) async {
    return apiClient.getMap(
      '/beslenme/gunluk_get.php',
      queryParameters: tarih != null ? {'tarih': tarih} : null,
    );
  }

  Future<Map<String, dynamic>> gunlukEkle({
    required String tarih,
    required int meal,
    required int besinId,
    int? porsiyonId,
    double? adet,
    double? gram,
    String? besinAd,
    double? kalori,
    double? protein,
    double? karbonhidrat,
    double? yag,
  }) async {
    final res = await apiClient.dio.post(
      '/beslenme/gunluk_ekle.php',
      data: {
        'tarih': tarih,
        'meal': meal,
        'besin_id': besinId,
        if (porsiyonId != null && porsiyonId > 0) 'porsiyon_id': porsiyonId,
        if (adet != null) 'adet': adet,
        if (gram != null) 'gram': gram,
        if (besinAd != null) 'besin_ad': besinAd,
        if (kalori != null) 'kalori': kalori,
        if (protein != null) 'protein': protein,
        if (karbonhidrat != null) 'karbonhidrat': karbonhidrat,
        if (yag != null) 'yag': yag,
      },
    );

    final raw = res.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final ok = map['ok'] == true || map['success'] == true;
      if (!ok) {
        final msg = map['message']?.toString() ??
            map['error']?.toString() ??
            'Yemek eklenemedi';
        throw Exception(msg);
      }
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data']);
      }
      return map;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> gunlukSil({
    int? ogeId,
    String? tarih,
    int? meal,
    int? besinId,
  }) async {
    final res = await apiClient.dio.post(
      '/beslenme/gunluk_sil.php',
      data: {
        if (ogeId != null && ogeId > 0) 'oge_id': ogeId,
        if (tarih != null) 'tarih': tarih,
        if (meal != null) 'meal': meal,
        if (besinId != null) 'besin_id': besinId,
      },
    );

    final raw = res.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final ok = map['ok'] == true || map['success'] == true;
      if (!ok) {
        final msg = map['message']?.toString() ??
            map['error']?.toString() ??
            'Yemek silinemedi';
        throw Exception(msg);
      }
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data']);
      }
      return map;
    }
    return <String, dynamic>{};
  }
}