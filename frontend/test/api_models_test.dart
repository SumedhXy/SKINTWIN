import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';

void main() {
  group('API Models Parsing Tests', () {
    test('SkinTwinResponse.fromJson parses correctly', () {
      final json = {
        'public_id': 'tw_123456',
        'name': 'Test Spot',
        'body_location': 'Left Arm',
        'status': 'active',
        'capture_count': 3,
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-02T10:00:00Z',
        'last_capture_at': '2024-01-02T10:00:00Z',
      };

      final model = SkinTwinResponse.fromJson(json);
      expect(model.publicId, 'tw_123456');
      expect(model.name, 'Test Spot');
      expect(model.bodyLocation, 'Left Arm');
      expect(model.captureCount, 3);
      expect(model.createdAt.year, 2024);
      expect(model.lastCaptureAt, isNotNull);
    });

    test('CaptureResponse.fromJson parses correctly', () {
      final json = {
        'id': 'cap_123',
        'skintwin_public_id': 'tw_123456',
        'image_object_key': 'test.jpg',
        'captured_at': '2024-01-01T10:00:00Z',
        'uploaded_at': '2024-01-01T10:00:05Z',
        'quality_status': 'good',
        'quality_score': 0.95,
        'comparison_eligible': true,
        'reference_scale_available': false,
        'measurement_status': 'unknown',
      };

      final model = CaptureResponse.fromJson(json);
      expect(model.id, 'cap_123');
      expect(model.skintwinPublicId, 'tw_123456');
      expect(model.qualityStatus, 'good');
      expect(model.qualityScore, 0.95);
      expect(model.comparisonEligible, true);
    });
  });
}
