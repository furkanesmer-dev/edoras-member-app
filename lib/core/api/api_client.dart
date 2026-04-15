import 'dart:io';

import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'auth_events.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;
  final AuthEvents authEvents;

  ApiClient({
    required this.dio,
    required this.tokenStorage,
    required this.authEvents,
    required String baseUrl,
  }) {
    dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final data = error.response?.data;

          // ignore: avoid_print
          print('API ERROR => $status $path\n$data');

          if (status == 401 || status == 403) {
            await tokenStorage.clear();
            authEvents.emitUnauthorized();
          }

          handler.next(error);
        },
      ),
    );
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      error: 'Unexpected response type: ${data.runtimeType}',
      type: DioExceptionType.badResponse,
    );
  }

  /// Backend hem { ok: true, data: ... } hem { success: true, data: ... } döndürebilir.
  /// İkisini de destekleyelim.
  void _throwIfApiNotOk(Map<String, dynamic> json, {RequestOptions? requestOptions}) {
    final ok = json['ok'];
    final success = json['success'];

    final isOk = (ok == true) || (success == true);
    if (isOk) return;

    final msg = (json['msg'] ?? json['error'] ?? json['message'] ?? 'İşlem başarısız')
        .toString();

    throw DioException(
      requestOptions: requestOptions ?? RequestOptions(path: ''),
      error: msg,
      type: DioExceptionType.badResponse,
    );
  }

  Map<String, dynamic> _extractDataAsMap(Response res) {
    final json = _ensureMap(res.data);
    _throwIfApiNotOk(json, requestOptions: res.requestOptions);

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    throw DioException(
      requestOptions: res.requestOptions,
      error: 'Beklenmeyen response: data alanı yok veya Map değil',
      type: DioExceptionType.badResponse,
    );
  }

  // -----------------------------
  // Profile Endpoints
  // -----------------------------
  /// GET /profile/me.php
  Future<Map<String, dynamic>> getProfileMe() async {
    final res = await dio.get('/profile/me.php');
    return _extractDataAsMap(res);
  }

  /// POST /profile/update.php
  Future<void> updateProfile(Map<String, dynamic> payload) async {
    final res = await dio.post('/profile/update.php', data: payload);
    final json = _ensureMap(res.data);
    _throwIfApiNotOk(json, requestOptions: res.requestOptions);
  }

  /// POST /profile/photo_upload.php (multipart/form-data)
  /// Dönen data içinde photo_url ve photo_path bekliyoruz.
  Future<Map<String, dynamic>> uploadProfilePhoto(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final res = await dio.post(
      '/profile/photo_upload.php',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    // Bu endpoint {ok:true, data:{...}} döndüğü için data Map olarak çıkarıyoruz
    return _extractDataAsMap(res);
  }

  // -----------------------------
  // Generic GET (Map response)
  // -----------------------------
  /// GET endpoint that returns { ok/success, data: Map }
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await dio.get(
      path,
      queryParameters: queryParameters,
    );

    final json = _ensureMap(res.data);
    _throwIfApiNotOk(json, requestOptions: res.requestOptions);

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    throw DioException(
      requestOptions: res.requestOptions,
      error: 'Beklenmeyen response: data alanı Map değil',
      type: DioExceptionType.badResponse,
    );
  }
}