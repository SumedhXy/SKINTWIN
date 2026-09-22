import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';
import 'package:skintwin/core/providers/comparison_provider.dart';
import 'package:skintwin/core/services/comparison_service.dart';

void main() {
  group('Model Parsing Tests', () {
    test('ComparisonResponse preserves positive and negative values', () {
      final json = {
        'id': 'comp_123',
        'skintwin_public_id': 'tw_123',
        'earlier_capture_id': 'cap_1',
        'latest_capture_id': 'cap_2',
        'area_change_percent': -12.4,
        'alignment_score': 0.85,
        'localization_confidence': 0.92,
        'reliability_status': 'reliable',
        'uncertainty_reasons': [],
        'created_at': '2023-01-01T12:00:00Z',
      };

      final response = ComparisonResponse.fromJson(json);

      expect(response.id, 'comp_123');
      expect(response.areaChangePercent, -12.4);
      expect(response.alignmentScore, 0.85);
      expect(response.reliabilityStatus, 'reliable');
    });
  });

  group('ComparisonProvider State Transitions', () {
    late ComparisonProvider provider;

    setUp(() {
      provider = ComparisonProvider(comparisonService: ComparisonService()); // using real or mock? Let's just test states before submission
    });

    test('Initial state is idle', () {
      expect(provider.state, ComparisonState.idle);
    });

    test('startSelectionFlow transitions to selectingCaptures', () {
      provider.startSelectionFlow('tw_123');
      expect(provider.state, ComparisonState.selectingCaptures);
      expect(provider.skintwinPublicId, 'tw_123');
    });

    test('validateSelection fails if captures missing', () {
      provider.startSelectionFlow('tw_123');
      final result = provider.validateSelection();
      
      expect(result, false);
      expect(provider.errorMessage, 'Please select both an earlier and a later capture.');
    });

    test('validateSelection fails if captures are the same', () {
      provider.startSelectionFlow('tw_123');
      final cap = CaptureResponse(
        id: 'cap_1',
        skintwinPublicId: 'tw_123',
        imageObjectKey: 'img_1',
        uploadedAt: DateTime.parse('2023-01-01T12:00:00Z'),
        comparisonEligible: true,
        referenceScaleAvailable: true,
        measurementStatus: 'measured',
        qualityStatus: 'good',
        capturedAt: DateTime.parse('2023-01-01T12:00:00Z'),
      );
      
      provider.selectEarlierCapture(cap);
      provider.selectLatestCapture(cap);
      
      final result = provider.validateSelection();
      
      expect(result, false);
      expect(provider.errorMessage, 'Cannot compare a capture with itself. Please select two distinct captures.');
    });

    test('validateSelection fails if chronological order is wrong', () {
      provider.startSelectionFlow('tw_123');
      final earlierCap = CaptureResponse(
        id: 'cap_1',
        skintwinPublicId: 'tw_123',
        imageObjectKey: 'img_2',
        uploadedAt: DateTime.parse('2023-01-02T12:00:00Z'),
        comparisonEligible: true,
        referenceScaleAvailable: true,
        measurementStatus: 'measured',
        qualityStatus: 'good',
        capturedAt: DateTime.parse('2023-01-02T12:00:00Z'),
      );
      final latestCap = CaptureResponse(
        id: 'cap_2',
        skintwinPublicId: 'tw_123',
        imageObjectKey: 'img_3',
        uploadedAt: DateTime.parse('2023-01-01T12:00:00Z'),
        comparisonEligible: true,
        referenceScaleAvailable: true,
        measurementStatus: 'measured',
        qualityStatus: 'good',
        capturedAt: DateTime.parse('2023-01-01T12:00:00Z'),
      );
      
      provider.selectEarlierCapture(earlierCap);
      provider.selectLatestCapture(latestCap);
      
      final result = provider.validateSelection();
      
      expect(result, false);
      expect(provider.errorMessage, 'The earlier capture must be taken before the later capture.');
    });
  });
}
