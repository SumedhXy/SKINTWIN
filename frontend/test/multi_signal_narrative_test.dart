import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';
import 'package:skintwin/core/providers/comparison_provider.dart';

void main() {
  group('Multi-Signal Change Narrative Model Tests', () {
    test('AIExplanationResponse parses structured multi-signal narrative correctly', () {
      final json = {
        'narrative_summary': {
          'title': 'Observable differences detected',
          'description': 'Some measured image features differ between the selected captures.',
          'status': 'observable_difference',
        },
        'signals': [
          {
            'name': 'Area',
            'baseline_value': 120.4,
            'followup_value': 135.8,
            'change_value': 12.8,
            'change_unit': 'percent',
            'direction': 'increased',
            'status': 'observable_difference',
            'reliability': 'moderate',
            'explanation': 'The measured segmented area appears larger in the follow-up image.',
          },
          {
            'name': 'Shape',
            'baseline_value': 140.5,
            'followup_value': 148.2,
            'change_value': 0.042,
            'change_unit': 'score',
            'direction': 'stable',
            'status': 'stable',
            'reliability': 'high',
            'explanation': 'Contour shape is consistent between captures.',
          },
          {
            'name': 'Color',
            'baseline_value': [120, 130, 140],
            'followup_value': [125, 135, 145],
            'change_value': 8.6,
            'change_unit': 'delta_e',
            'direction': 'differed',
            'status': 'observable_difference',
            'reliability': 'moderate',
            'explanation': 'Color variations detected across the segmented area.',
          },
          {
            'name': 'Position',
            'baseline_value': [150, 150],
            'followup_value': [152, 151],
            'change_value': 2.2,
            'change_unit': 'px',
            'direction': 'stable',
            'status': 'stable',
            'reliability': 'high',
            'explanation': 'Centroid position is stable between captures.',
          },
          {
            'name': 'Segmentation Overlap',
            'baseline_value': null,
            'followup_value': null,
            'change_value': 0.88,
            'change_unit': 'iou',
            'direction': 'stable',
            'status': 'stable',
            'reliability': 'high',
            'explanation': 'High mask overlap (88.0% IoU).',
          }
        ],
        'narrative_reliability': {
          'overall': 'moderate',
          'quality_status': 'acceptable',
          'alignment_status': 'acceptable',
          'segmentation_status': 'completed',
          'limitations': ['Lighting conditions may affect color comparison.'],
        },
        'narrative_uncertainty': {
          'present': true,
          'explanation': 'Some differences may be influenced by capture conditions.',
        },
        'safety_message': 'This is an analysis of observable image differences and is not a medical diagnosis.',
        'recommended_next_step': 'If you notice concerning changes, consider consulting a qualified healthcare professional.',
        'summary': 'Legacy summary text',
        'observations': [],
        'reliability': {'status': 'needs_review', 'explanation': 'Needs review'},
        'limitations': ['Lighting conditions may affect color comparison.'],
        'missing_information': [],
        'recommended_next_steps': ['Continue tracking.'],
        'medical_disclaimer': 'Not a medical diagnosis.',
        'model_metadata': {
          'model_name': 'medsam_vit_b',
          'model_version': '1.0.0',
          'inference_mode': 'real_medsam',
        },
      };

      final resp = AIExplanationResponse.fromJson(json);

      expect(resp.narrativeSummary.title, 'Observable differences detected');
      expect(resp.narrativeSummary.status, 'observable_difference');
      expect(resp.signals.length, 5);

      final areaSignal = resp.signals.firstWhere((s) => s.name == 'Area');
      expect(areaSignal.direction, 'increased');
      expect(areaSignal.changeValue, 12.8);
      expect(areaSignal.changeUnit, 'percent');
      expect(areaSignal.reliability, 'moderate');

      expect(resp.narrativeReliability.overall, 'moderate');
      expect(resp.narrativeReliability.limitations.length, 1);
      expect(resp.narrativeUncertainty.present, isTrue);
      expect(resp.safetyMessage, contains('not a medical diagnosis'));
      expect(resp.recommendedNextStep, contains('healthcare professional'));
    });

    test('AIExplanationResponse falls back safely when only legacy payload is present', () {
      final legacyJson = {
        'summary': 'Legacy summary',
        'observations': [
          {
            'metric': 'area',
            'status': 'changed',
            'value': '+15.2%',
            'explanation': 'Area changed.',
          }
        ],
        'reliability': {'status': 'reliable', 'explanation': 'Good alignment'},
        'limitations': [],
        'missing_information': [],
        'recommended_next_steps': ['Follow up as needed.'],
        'medical_disclaimer': 'Not a medical diagnosis.',
        'model_metadata': {
          'model_name': 'medsam_vit_b',
          'model_version': '1.0.0',
          'inference_mode': 'real_medsam',
        },
      };

      final resp = AIExplanationResponse.fromJson(legacyJson);

      expect(resp.narrativeSummary.title, isNotEmpty);
      expect(resp.signals.length, 1);
      expect(resp.signals[0].name, 'AREA');
      expect(resp.signals[0].direction, 'differed');
      expect(resp.narrativeReliability.overall, 'high');
      expect(resp.narrativeUncertainty.present, isFalse);
    });

    test('ComparisonProvider exposes multi-signal narrative getters', () {
      final provider = ComparisonProvider();
      expect(provider.signals, isEmpty);
      expect(provider.narrativeSummary, isNull);
      expect(provider.narrativeReliability, isNull);
      expect(provider.narrativeUncertainty, isNull);
    });
  });
}
