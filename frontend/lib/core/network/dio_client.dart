import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart';

class DioClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api/v1');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  DioClient({String? baseUrl}) {
    final effectiveBaseUrl = baseUrl ?? defaultBaseUrl;
    _dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Auto-inject JWT token if available
          final token = await _secureStorage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Centralized 401 handling (e.g. token expired)
          if (e.response?.statusCode == 401) {
            // Token is expired or invalid. Let the AuthProvider clear the state.
            await _secureStorage.delete(key: 'jwt_token');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
