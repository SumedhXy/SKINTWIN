import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../models/provider_models.dart';

class FindCareService {
  final DioClient _dioClient;

  FindCareService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  Future<ProviderListResponse> searchProviders({
    double? latitude,
    double? longitude,
    double radiusKm = 50.0,
    String? specialty,
    String? consultationType,
    String? search,
    String? language,
    double? minFee,
    double? maxFee,
    String sort = 'relevance',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'radius_km': radiusKm,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (specialty != null && specialty != 'All') 'specialty': specialty,
        if (consultationType != null && consultationType != 'All') 'consultation_mode': consultationType,
        if (language != null && language != 'All') 'language': language,
        if (minFee != null) 'min_fee': minFee,
        if (maxFee != null) 'max_fee': maxFee,
        'sort': sort,
        'page': page,
        'page_size': limit,
      };

      final response = await _dioClient.dio.get(
        '/find-care/providers',
        queryParameters: queryParams,
      );

      return ProviderListResponse.fromJson(response.data);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<ProviderListResponse> searchOpenMapNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final response = await _dioClient.dio.get('/find-care/providers/nearby-open', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    });
    return ProviderListResponse.fromJson(response.data);
  }

  Future<ProviderResponse> getProviderDetails(String providerId) async {
    try {
      final response = await _dioClient.dio.get('/find-care/providers/$providerId');
      return ProviderResponse.fromJson(response.data);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<SpecialtyListResponse> getSpecialties() async {
    try {
      final response = await _dioClient.dio.get('/find-care/specialties');
      return SpecialtyListResponse.fromJson(response.data);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.connectionTimeout) {
        throw Exception('The request timed out. Please try again.');
      }
      
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        throw Exception('Unauthorized session. Please log in again.');
      } else if (statusCode == 403) {
        throw Exception('You do not have permission to perform this action.');
      } else if (statusCode == 404) {
        throw Exception('Provider or resource not found.');
      } else if (statusCode == 429) {
        throw Exception('Too many requests. Please wait a moment.');
      } else if (statusCode == 422) {
        throw Exception('Invalid location or search parameters.');
      }
      
      final detail = error.response?.data?['detail'];
      if (detail != null) {
        throw Exception(detail.toString());
      }
    }
    
    if (kDebugMode) {
      print("FindCareService Error: $error");
    }
    throw Exception('Failed to connect to provider network. Please try again later.');
  }
}
