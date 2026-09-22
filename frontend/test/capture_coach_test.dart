import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/api_models.dart';
import 'package:skintwin/core/widgets/adaptive_capture_coach_viewer.dart';

void main() {
  group('AdaptiveCaptureCoachPreCaptureCard Tests', () {
    testWidgets('Renders pre-capture guidance and tips', (WidgetTester tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCaptureCoachPreCaptureCard(
              hasBaseline: true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Adaptive Capture Coach'), findsOneWidget);
      expect(find.textContaining('Use soft, uniform ambient lighting'), findsOneWidget);
      expect(find.textContaining('Hold steady and rest elbows'), findsOneWidget);
      expect(find.textContaining('Keep the skin finding centered'), findsOneWidget);
      expect(find.textContaining('Match the camera distance and angle of your baseline photo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('AdaptiveCaptureCoachReviewSheet Tests', () {
    testWidgets('Renders Ready status with green banner and enabled continue button', (WidgetTester tester) async {
      bool continued = false;
      final readyResult = CaptureCoachResult(
        status: 'ready',
        canContinue: true,
        qualityScore: 0.95,
        primaryMessage: 'Capture is clear, well-framed, and ready for comparison.',
        suggestions: ['Proceed with saving this capture.'],
        checks: [
          CaptureCoachCheck(
            category: 'sharpness',
            status: 'pass',
            score: 1.0,
            message: 'Image focus is sharp.',
          ),
          CaptureCoachCheck(
            category: 'lighting',
            status: 'pass',
            score: 1.0,
            message: 'Optimal lighting.',
          ),
        ],
        limitations: ['Image quality evaluation is advisory only.'],
        hasBaselineComparison: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCaptureCoachReviewSheet(
              coachResult: readyResult,
              onRetake: () {},
              onContinue: () => continued = true,
            ),
          ),
        ),
      );

      expect(find.text('Capture Ready for Comparison'), findsOneWidget);
      expect(find.text('Quality Score: 95%'), findsOneWidget);
      expect(find.text('Capture is clear, well-framed, and ready for comparison.'), findsOneWidget);
      expect(find.text('Sharpness & Focus'), findsOneWidget);
      expect(find.text('Lighting & Exposure'), findsOneWidget);
      expect(find.textContaining('Capture Coach evaluates photographic consistency'), findsOneWidget);

      final continueButton = find.byKey(const Key('coach_continue_button'));
      expect(continueButton, findsOneWidget);
      await tester.tap(continueButton);
      await tester.pump();
      expect(continued, isTrue);
    });

    testWidgets('Renders Needs Adjustment status with warning and override confirmation dialog', (WidgetTester tester) async {
      bool continued = false;
      final warningResult = CaptureCoachResult(
        status: 'needs_adjustment',
        canContinue: true,
        qualityScore: 0.72,
        primaryMessage: 'Suboptimal lighting or contrast detected.',
        suggestions: ['Use soft, even lighting across the skin area.'],
        checks: [
          CaptureCoachCheck(
            category: 'lighting',
            status: 'warning',
            score: 0.7,
            message: 'Suboptimal contrast.',
          ),
        ],
        limitations: ['Minor differences may reduce comparison precision.'],
        hasBaselineComparison: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCaptureCoachReviewSheet(
              coachResult: warningResult,
              onRetake: () {},
              onContinue: () => continued = true,
            ),
          ),
        ),
      );

      expect(find.text('Adjustment Recommended'), findsOneWidget);
      expect(find.text('Use Anyway'), findsOneWidget);
      expect(find.text('Suboptimal lighting or contrast detected.'), findsOneWidget);
      expect(find.text('Use soft, even lighting across the skin area.'), findsOneWidget);

      // Tap Use Anyway -> should open confirmation dialog
      await tester.tap(find.byKey(const Key('coach_continue_button')));
      await tester.pumpAndSettle();

      expect(find.text('Proceed with Limitations?'), findsOneWidget);
      expect(find.text('Proceed Anyway'), findsOneWidget);

      await tester.tap(find.text('Proceed Anyway'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });

    testWidgets('Renders Blocked status with disabled continue button and active retake', (WidgetTester tester) async {
      bool retaken = false;
      final blockedResult = CaptureCoachResult(
        status: 'blocked',
        canContinue: false,
        qualityScore: 0.25,
        primaryMessage: 'Image appears blurry. Sharpness is below minimum threshold.',
        suggestions: ['Hold phone steady and tap to focus.', 'Clean camera lens.'],
        checks: [
          CaptureCoachCheck(
            category: 'sharpness',
            status: 'fail',
            score: 0.2,
            message: 'Laplacian variance below 50.',
          ),
        ],
        limitations: ['Blurry images cannot be reliably aligned.'],
        hasBaselineComparison: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveCaptureCoachReviewSheet(
              coachResult: blockedResult,
              onRetake: () => retaken = true,
              onContinue: () {},
            ),
          ),
        ),
      );

      expect(find.text('Action Required · Photo Blocked'), findsOneWidget);
      expect(find.text('Image appears blurry. Sharpness is below minimum threshold.'), findsOneWidget);
      expect(find.text('Hold phone steady and tap to focus.'), findsOneWidget);

      final continueButton = tester.widget<ElevatedButton>(find.byKey(const Key('coach_continue_button')));
      expect(continueButton.onPressed, isNull); // Disabled

      final retakeButton = find.byKey(const Key('coach_retake_button'));
      expect(retakeButton, findsOneWidget);
      await tester.tap(retakeButton);
      await tester.pump();
      expect(retaken, isTrue);
    });
  });
}
