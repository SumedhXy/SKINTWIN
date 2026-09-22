import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';

void main() {
  group('Comparison Reliability & Uncertainty Model Tests', () {
    test('ComparisonResponse parses full structured reliability details correctly', () {
      final json = {
        'id': 'comp_full_123',
        'skintwin_public_id': 'tw_123',
        'earlier_capture_id': 'cap_1',
        'latest_capture_id': 'cap_2',
        'processing_status': 'completed',
        'alignment_status': 'aligned',
        'alignment_score': 0.88,
        'localization_status': 'segmented',
        'localization_confidence': 0.94,
        'segmentation_model': 'medsam_vit_b',
        'segmentation_model_version': '1.0.0',
        'inference_mode': 'real_medsam',
        'weights_loaded': true,
        'fallback_used': false,
        'earlier_area': 1200.0,
        'latest_area': 1250.0,
        'area_change_percent': 4.17,
        'comparison_status': 'completed',
        'measurement_status': 'measured',
        'reliability_status': 'reliable',
        'overall_reliability': 'high',
        'reliability_score': 0.89,
        'uncertainty_reasons': ['Minor angle variation'],
        'uncertainty_reasons_structured': [
          {
            'category': 'capture_conditions',
            'severity': 'low',
            'message': 'Minor angle variation between captures.',
          }
        ],
        'affected_signals': ['position'],
        'limitations': [
          'The comparison describes image differences, not medical significance.',
        ],
        'reliability_details': {
          'overall_reliability': 'high',
          'reliability_score': 0.89,
          'uncertainty_present': false,
          'uncertainty_reasons': [
            {
              'category': 'capture_conditions',
              'severity': 'low',
              'message': 'Minor angle variation between captures.',
            }
          ],
          'affected_signals': ['position'],
          'limitations': [
            'The comparison describes image differences, not medical significance.',
          ],
          'component_statuses': {
            'image_quality': {
              'name': 'Image Quality',
              'status': 'acceptable',
              'score': 0.95,
              'explanation': 'Sufficient image dimensions and focus.',
            },
            'alignment': {
              'name': 'Alignment',
              'status': 'high',
              'score': 0.88,
              'explanation': 'Keypoints aligned with homography.',
            },
            'segmentation': {
              'name': 'Segmentation',
              'status': 'high',
              'score': 0.94,
              'explanation': 'MedSAM neural segmentation completed.',
              'is_fallback': false,
            },
            'measurement': {
              'name': 'Measurements',
              'status': 'high',
              'score': 1.0,
              'explanation': 'All 5 observable signals extracted.',
            },
          },
          'signal_reliabilities': {
            'area': {
              'name': 'Area',
              'reliability': 'high',
              'uncertainty': false,
              'interpretation': 'Area measured reliably with 4.2% change.',
            },
            'color': {
              'name': 'Color',
              'reliability': 'high',
              'uncertainty': false,
              'interpretation': 'Consistent lighting allows observable color comparison.',
            },
          },
          'disclaimer': 'SkinTwin describes observable image differences only. It does not diagnose medical conditions.',
        },
        'created_at': '2026-09-21T12:00:00Z',
      };

      final response = ComparisonResponse.fromJson(json);

      expect(response.id, 'comp_full_123');
      expect(response.overallReliability, 'high');
      expect(response.reliabilityScore, 0.89);
      expect(response.uncertaintyReasonsStructured?.length, 1);
      expect(response.uncertaintyReasonsStructured?.first.category, 'capture_conditions');
      expect(response.affectedSignals, contains('position'));
      expect(response.limitations?.first, contains('image differences'));

      final rel = response.reliabilityDetails;
      expect(rel, isNotNull);
      expect(rel!.overallReliability, 'high');
      expect(rel.componentStatuses['segmentation']?.isFallback, false);
      expect(rel.componentStatuses['segmentation']?.status, 'high');
      expect(rel.signalReliabilities['area']?.reliability, 'high');
    });

    test('ComparisonResponse parses Fallback CV segmentation disclosures correctly', () {
      final json = {
        'id': 'comp_fallback_123',
        'skintwin_public_id': 'tw_123',
        'earlier_capture_id': 'cap_1',
        'latest_capture_id': 'cap_2',
        'segmentation_model': 'fallback_cv',
        'fallback_used': true,
        'overall_reliability': 'moderate',
        'reliability_status': 'needs_review',
        'reliability_details': {
          'overall_reliability': 'moderate',
          'reliability_score': 0.65,
          'uncertainty_present': true,
          'uncertainty_reasons': [
            {
              'category': 'segmentation',
              'severity': 'moderate',
              'message': 'Fallback computer-vision segmentation was used. Boundary contours have higher variance.',
            }
          ],
          'affected_signals': ['shape', 'overlap'],
          'limitations': [
            'Fallback segmentation uses color/contrast heuristics.',
          ],
          'component_statuses': {
            'segmentation': {
              'name': 'Segmentation',
              'status': 'moderate',
              'score': 0.70,
              'explanation': 'Fallback thresholding segmentation applied.',
              'is_fallback': true,
              'limitation': 'Contour precision is subject to contrast boundaries.',
            },
          },
          'signal_reliabilities': {
            'shape': {
              'name': 'Shape',
              'reliability': 'moderate',
              'uncertainty': true,
              'limitation': 'Fallback contours affect shape geometry.',
              'interpretation': 'Shape contour differences may reflect contrast variations.',
            },
          },
          'disclaimer': 'SkinTwin describes observable image differences only.',
        },
        'created_at': '2026-09-21T12:00:00Z',
      };

      final response = ComparisonResponse.fromJson(json);

      expect(response.overallReliability, 'moderate');
      expect(response.fallbackUsed, true);
      expect(response.reliabilityDetails?.componentStatuses['segmentation']?.isFallback, true);
      expect(response.reliabilityDetails?.uncertaintyPresent, true);
      expect(response.reliabilityDetails?.signalReliabilities['shape']?.uncertainty, true);
    });

    test('ComparisonResponse falls back safely for legacy payloads without structured fields', () {
      final json = {
        'id': 'comp_legacy_123',
        'skintwin_public_id': 'tw_123',
        'earlier_capture_id': 'cap_1',
        'latest_capture_id': 'cap_2',
        'reliability_status': 'reliable',
        'uncertainty_reasons': ['Slight lighting difference'],
        'created_at': '2026-09-21T12:00:00Z',
      };

      final response = ComparisonResponse.fromJson(json);

      expect(response.id, 'comp_legacy_123');
      expect(response.overallReliability, 'high');
      expect(response.uncertaintyReasons?.first, 'Slight lighting difference');
      expect(response.nonDiagnosticDisclaimer, contains('observable image differences'));
    });

    test('Non-diagnostic disclaimer contains no medical confidence or safety claims', () {
      final json = {
        'id': 'comp_safe_123',
        'skintwin_public_id': 'tw_123',
        'earlier_capture_id': 'cap_1',
        'latest_capture_id': 'cap_2',
        'created_at': '2026-09-21T12:00:00Z',
      };

      final response = ComparisonResponse.fromJson(json);
      final disclaimer = response.nonDiagnosticDisclaimer.toLowerCase();

      expect(disclaimer, contains('not diagnose'));
      expect(disclaimer, isNot(contains('100% accurate')));
      expect(disclaimer, isNot(contains('medically safe')));
      expect(disclaimer, isNot(contains('rules out cancer')));
    });
  });
}
