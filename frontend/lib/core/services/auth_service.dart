import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/dio_client.dart';

class AuthService {
  final DioClient _dioClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  Future<void> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        if (token != null) {
          await _secureStorage.write(key: 'jwt_token', value: token);
        }
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        throw Exception('Invalid email or password.');
      } else if (e.response != null && e.response?.statusCode == 429) {
        throw Exception('Too many login attempts. Please try again later.');
      }
      throw Exception('An error occurred during login. Please check your connection.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    try {
      final response = await _dioClient.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      });

      if (response.statusCode == 201) {
        // Automatically login after successful registration
        await login(email, password);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 409) {
        throw Exception('An account with this email address already exists.');
      }
      throw Exception('An error occurred during registration.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _dioClient.dio.get('/auth/me');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null; // Will trigger logout if it's a 401
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt_token');
  }

  Future<bool> hasToken() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    return token != null;
  }
}
