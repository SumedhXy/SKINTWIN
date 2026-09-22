import '../network/dio_client.dart';
import '../models/api_models.dart';

class SkinTwinService {
  final DioClient _dioClient;

  SkinTwinService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  Future<List<SkinTwinResponse>> getSkinTwins() async {
    try {
      final response = await _dioClient.dio.get('/skintwins');
      final data = response.data;
      if (data != null && data['items'] != null) {
        final list = data['items'] as List;
        return list.map((item) => SkinTwinResponse.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load SkinTwins: $e');
    }
  }

  Future<SkinTwinResponse> createSkinTwin({
    required String name,
    required String bodyLocation,
    String? bodySide,
    String? description,
  }) async {
    try {
      final response = await _dioClient.dio.post('/skintwins', data: {
        'name': name,
        'body_location': bodyLocation,
        if (bodySide != null) 'body_side': bodySide,
        if (description != null) 'description': description,
      });
      return SkinTwinResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create SkinTwin: $e');
    }
  }

  Future<SkinTwinResponse> getSkinTwin(String publicId) async {
    try {
      final response = await _dioClient.dio.get('/skintwins/$publicId');
      return SkinTwinResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load SkinTwin details: $e');
    }
  }
}
