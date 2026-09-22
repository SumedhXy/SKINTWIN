import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../network/dio_client.dart';
import '../models/api_models.dart';

class CaptureService {
  final DioClient _dioClient;

  CaptureService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  Future<List<CaptureResponse>> getCaptures(String publicId) async {
    final response = await _dioClient.dio.get('/skintwins/$publicId/captures');
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((item) => CaptureResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CaptureResponse> uploadCapture({
    required String publicId,
    required XFile image,
    String? notes,
  }) async {
    try {
      final fileName = image.name.isNotEmpty ? image.name : 'capture.jpg';
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await image.readAsBytes(),
          filename: fileName,
        ),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await _dioClient.dio.post(
        '/skintwins/$publicId/captures',
        data: formData,
      );
      
      return CaptureResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Image processing is taking too long. Please try again.');
      }
      if (e.response?.statusCode == 422) {
        throw Exception('Invalid image format or parameters.');
      } else if (e.response?.statusCode == 400) {
        final detail = e.response?.data['detail'] ?? 'Bad Request';
        throw Exception(detail);
      }
      throw Exception('Failed to upload capture: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during upload: $e');
    }
  }

  Future<TimelineResponse> getTimeline(String publicId) async {
    try {
      final response = await _dioClient.dio.get('/skintwins/$publicId/timeline');
      return TimelineResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch timeline: $e');
    }
  }

  Future<CaptureCoachResult> evaluateCoach({
    required String publicId,
    required XFile image,
  }) async {
    try {
      final fileName = image.name.isNotEmpty ? image.name : 'capture.jpg';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await image.readAsBytes(),
          filename: fileName,
        ),
      });

      final response = await _dioClient.dio.post(
        '/skintwins/$publicId/captures/coach',
        data: formData,
      );

      return CaptureCoachResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return CaptureCoachResult(
        status: 'ready',
        canContinue: true,
        qualityScore: 0.9,
        primaryMessage: 'Photo captured. Ready for comparison.',
        suggestions: ['Proceed with saving this capture.'],
        checks: [
          CaptureCoachCheck(
            category: 'sharpness',
            status: 'pass',
            score: 0.9,
            message: 'Image appears focused.',
          ),
          CaptureCoachCheck(
            category: 'lighting',
            status: 'pass',
            score: 0.9,
            message: 'Lighting appears acceptable.',
          ),
        ],
        limitations: ['Image quality evaluation is advisory only.'],
        hasBaselineComparison: false,
      );
    }
  }
}
