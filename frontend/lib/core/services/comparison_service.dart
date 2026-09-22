import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../models/api_models.dart';

class ComparisonService {
  final DioClient _dioClient;

  ComparisonService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  /// Create a comparison
  Future<ComparisonResponse> createComparison({
    required String publicId,
    required ComparisonCreateRequest request,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/skintwins/$publicId/comparisons',
        data: request.toJson(),
      );
      return ComparisonResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to create comparison');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// List all comparisons for a SkinTwin
  Future<ComparisonListResponse> getComparisons(String publicId) async {
    try {
      final response = await _dioClient.dio.get('/skintwins/$publicId/comparisons');
      return ComparisonListResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to list comparisons');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Get a single comparison
  Future<ComparisonResponse> getComparison(String comparisonId) async {
    try {
      final response = await _dioClient.dio.get('/comparisons/$comparisonId');
      return ComparisonResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to get comparison details');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Delete a comparison
  Future<void> deleteComparison(String comparisonId) async {
    try {
      await _dioClient.dio.delete('/comparisons/$comparisonId');
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to delete comparison');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Get AI Explanation
  Future<AIExplanationResponse> getExplanation(String comparisonId) async {
    try {
      final response = await _dioClient.dio.get('/comparisons/$comparisonId/explanation');
      return AIExplanationResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to get AI explanation');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Regenerate AI Explanation
  Future<AIExplanationResponse> regenerateExplanation(String comparisonId) async {
    try {
      final response = await _dioClient.dio.post('/comparisons/$comparisonId/explanation');
      return AIExplanationResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleDioError(e, 'Failed to regenerate AI explanation');
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Centralized Error Handler
  void _handleDioError(DioException e, String defaultMessage) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      throw Exception('The request timed out. Please try again.');
    }
    
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      String? detail;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        detail = data['detail'];
      }

      if (statusCode == 400) {
        throw Exception(detail ?? 'Invalid request parameters.');
      } else if (statusCode == 401) {
        throw Exception('Unauthorized session. Please log in again.');
      } else if (statusCode == 403) {
        throw Exception('You do not have permission to access this resource.');
      } else if (statusCode == 404) {
        throw Exception(detail ?? 'The requested resource was not found.');
      } else if (statusCode == 409) {
        throw Exception(detail ?? 'A conflict occurred (e.g., duplicate request).');
      } else if (statusCode == 422) {
        throw Exception('Validation error on request data.');
      } else if (statusCode == 429) {
        throw Exception('Too many requests. Please wait a moment.');
      } else if (statusCode != null && statusCode >= 500) {
        throw Exception('Server error occurred. Please try again later.');
      }
    }
    
    throw Exception('$defaultMessage: ${e.message}');
  }
}
