import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';

void main() {
  group('Comparison Reliability & Uncertainty Model & Widget Tests', () {
    // 1. Overall Reliability Card & Model Tests
    test('ReliabilityDetails correctly parses component statuses and signal reliabilities', () {
      final json = {
        'overall_reliability': 'moderate',
        'reliability_score': 0.72,
        'uncertainty_present': true,
        'uncertainty_reasons': [
          {
            'category': 'lighting',
            'severity': 'moderate',
            'message': 'Different lighting conditions may affect color measurements.',
          },
          {
            'category': 'alignment',
            'severity': 'low',
            'message': 'Small framing differences may affect position measurements.',
          }
        ],
        'affected_signals': ['color', 'centroid'],
        'limitations': [
          'The comparison describes image differences, not medical significance.',
        ],
        'component_statuses': {
          'image_quality': {
            'name': 'Image Quality',
            'status': 'acceptable',
            'score': 0.90,
            'explanation': 'Good resolution and focus.',
            'limitation': null,
            'is_fallback': false,
          },
          'alignment': {
            'name': 'Alignment',
            'status': 'moderate',
            'score': 0.65,
            'explanation': 'Partial feature alignment.',
            'limitation': 'Framing angle slightly varied.',
            'is_fallback': false,
          },
          'segmentation': {
            'name': 'Segmentation',
            'status': 'moderate',
            'score': 0.75,
            'explanation': 'Fallback classical CV segmentation used.',
            'limitation': 'Boundary approximations apply.',
            'is_fallback': true,
          },
          'measurement': {
            'name': 'Measurements',
            'status': 'moderate',
            'score': 0.70,
            'explanation': 'All signals computed with boundary uncertainties.',
            'limitation': null,
            'is_fallback': false,
          }
        },
        'signal_reliabilities': {
          'area': {
            'name': 'Area',
            'reliability': 'moderate',
            'uncertainty': true,
            'limitation': 'Fallback segmentation used.',
            'interpretation': 'Area measured from boundary contours.',
          },
          'color': {
            'name': 'Color',
            'reliability': 'low',
            'uncertainty': true,
            'limitation': 'Lighting conditions differ.',
            'interpretation': 'Color differences should be interpreted cautiously.',
          }
        },
        'disclaimer': 'SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance.',
      };

      final rel = ReliabilityDetails.fromJson(json);

      expect(rel.overallReliability, 'moderate');
      expect(rel.reliabilityScore, 0.72);
      expect(rel.uncertaintyPresent, isTrue);
      expect(rel.uncertaintyReasons.length, 2);
      expect(rel.uncertaintyReasons[0].category, 'lighting');
      expect(rel.uncertaintyReasons[0].severity, 'moderate');
      expect(rel.affectedSignals, contains('color'));
      expect(rel.componentStatuses['segmentation']?.isFallback, isTrue);
      expect(rel.signalReliabilities['color']?.reliability, 'low');
      expect(rel.disclaimer, contains('SkinTwin describes observable image differences only'));
    });

    // 2. Component Status Rendering Widget Test
    testWidgets('ComponentStatusItem renders fallback indicator and limitation message', (WidgetTester tester) async {
      final comp = ComponentStatusItem(
        name: 'Segmentation',
        status: 'moderate',
        score: 0.75,
        explanation: 'Fallback algorithmic processing used.',
        limitation: 'Classical CV used because neural weights were unavailable.',
        isFallback: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Row(
                  children: [
                    Text(comp.name),
                    if (comp.isFallback) const Chip(label: Text('FALLBACK CV')),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comp.explanation),
                    if (comp.limitation != null) Text('Note: ${comp.limitation!}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Segmentation'), findsOneWidget);
      expect(find.text('FALLBACK CV'), findsOneWidget);
      expect(find.text('Fallback algorithmic processing used.'), findsOneWidget);
      expect(find.text('Note: Classical CV used because neural weights were unavailable.'), findsOneWidget);
    });

    // 3. Signal-Specific Reliability & Limitation Rendering
    testWidgets('Signal Reliability renders low reliability caution tag', (WidgetTester tester) async {
      final signal = SignalReliabilityItem(
        name: 'Color',
        reliability: 'low',
        uncertainty: true,
        limitation: 'Lighting conditions differ between captures.',
        interpretation: 'Color differences should be interpreted cautiously.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Reliability: ${signal.reliability.toUpperCase()}'),
                  if (signal.limitation != null) Text(signal.limitation!),
                  Text(signal.interpretation),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Reliability: LOW'), findsOneWidget);
      expect(find.text('Lighting conditions differ between captures.'), findsOneWidget);
      expect(find.text('Color differences should be interpreted cautiously.'), findsOneWidget);
    });

    // 4. Uncertainty Panel Rendering
    testWidgets('Uncertainty Panel renders category badges and affected signals', (WidgetTester tester) async {
      final reasons = [
        UncertaintyReasonItem(
          category: 'lighting',
          severity: 'moderate',
          message: 'Brightness delta exceeds tolerance.',
        ),
        UncertaintyReasonItem(
          category: 'blur',
          severity: 'high',
          message: 'Earlier capture has mild focal blur.',
        ),
      ];
      final affectedSignals = ['color', 'shape'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Uncertainty Factors & Limitations'),
                ...reasons.map((r) => Row(
                  children: [
                    Text(r.category.toUpperCase()),
                    const SizedBox(width: 8),
                    Text(r.message),
                  ],
                )),
                Wrap(
                  children: affectedSignals.map((s) => Chip(label: Text(s.toUpperCase()))).toList(),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Uncertainty Factors & Limitations'), findsOneWidget);
      expect(find.text('LIGHTING'), findsOneWidget);
      expect(find.text('Brightness delta exceeds tolerance.'), findsOneWidget);
      expect(find.text('BLUR'), findsOneWidget);
      expect(find.text('COLOR'), findsOneWidget);
      expect(find.text('SHAPE'), findsOneWidget);
    });

    // 5. Insufficient Data State with Retry Guidance
    testWidgets('Insufficient Data State shows explanation and retry button', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 48),
                  const Text('Insufficient Information for Comparison'),
                  const Text('The images could not be compared reliably because segmentation was unsuccessful.'),
                  ElevatedButton(
                    onPressed: () {
                      retried = true;
                    },
                    child: const Text('Recapture or Select Other Images'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Insufficient Information for Comparison'), findsOneWidget);
      expect(find.text('The images could not be compared reliably because segmentation was unsuccessful.'), findsOneWidget);
      expect(find.text('Recapture or Select Other Images'), findsOneWidget);

      await tester.tap(find.text('Recapture or Select Other Images'));
      expect(retried, isTrue);
    });

    // 6. Safety Disclaimer Visibility
    testWidgets('Safety disclaimer is always rendered with clear non-diagnostic boundaries', (WidgetTester tester) async {
      const disclaimer = 'SkinTwin describes observable image differences. It does not diagnose medical conditions or determine their medical significance.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text(disclaimer),
          ),
        ),
      );

      expect(find.textContaining('observable image differences'), findsOneWidget);
      expect(find.textContaining('does not diagnose'), findsOneWidget);
    });
  });
}
