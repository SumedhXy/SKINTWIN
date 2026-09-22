import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/widgets/ghost_overlay_viewer.dart';

Widget _mockImageBuilder(String captureId, BoxFit fit) {
  return Container(
    key: Key('mock_img_$captureId'),
    color: Colors.blueGrey,
    child: Center(child: Text(captureId)),
  );
}

void main() {
  group('GhostOverlayViewer Widget Tests', () {
    testWidgets('Renders GhostOverlayViewer with header, tabs, and default opacity mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                earlierDate: DateTime(2026, 1, 15),
                latestDate: DateTime(2026, 3, 20),
                alignmentStatus: 'aligned',
                alignmentScore: 0.92,
                alignmentMethod: 'ORB + RANSAC',
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      // Verify header and mode tabs
      expect(find.text('Ghost Overlay Comparison'), findsOneWidget);
      expect(find.text('Opacity Overlay'), findsOneWidget);
      expect(find.text('Blink Comparison'), findsOneWidget);
      expect(find.text('Side-by-Side'), findsOneWidget);
      expect(find.text('Split Swipe'), findsOneWidget);

      // Verify alignment verified banner
      expect(find.text('Alignment Verified'), findsOneWidget);
      expect(find.textContaining('ORB + RANSAC'), findsOneWidget);

      // Verify opacity controls
      expect(find.text('50/50 Blend'), findsOneWidget);
      expect(find.text('Solo Follow-up'), findsOneWidget);
      expect(find.text('Solo Baseline'), findsOneWidget);

      // Verify non-diagnostic disclaimer
      expect(find.textContaining('Ghost Overlay supports visual comparison of photographs'), findsOneWidget);
    });

    testWidgets('Switches to Side-by-Side mode and renders capture date badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                earlierDate: DateTime(2026, 1, 15),
                latestDate: DateTime(2026, 3, 20),
                alignmentStatus: 'aligned',
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      // Switch to Side-by-Side
      await tester.tap(find.text('Side-by-Side'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Baseline: 2026-01-15'), findsOneWidget);
      expect(find.textContaining('Follow-up: 2026-03-20'), findsOneWidget);
      expect(find.textContaining('zoom and pan'), findsOneWidget);
    });

    testWidgets('Switches to Blink mode and starts/stops blink timer', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                alignmentStatus: 'aligned',
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      // Switch to Blink Comparison
      await tester.tap(find.text('Blink Comparison'));
      await tester.pumpAndSettle();

      expect(find.text('Start Blink'), findsOneWidget);
      expect(find.text('Step Swap'), findsOneWidget);

      // Tap Start Blink
      await tester.tap(find.text('Start Blink'));
      await tester.pump();

      expect(find.text('Pause Blink'), findsOneWidget);

      // Tap Pause Blink
      await tester.tap(find.text('Pause Blink'));
      await tester.pump();

      expect(find.text('Start Blink'), findsOneWidget);
    });

    testWidgets('Displays warning banner when alignment is limited or failed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                alignmentStatus: 'partially_aligned',
                alignmentScore: 0.35,
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alignment Limited'), findsOneWidget);
      expect(find.textContaining('Differences in position may be influenced by framing'), findsOneWidget);
    });

    testWidgets('Displays unavailable banner when alignment failed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                alignmentStatus: 'failed',
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alignment Unavailable'), findsOneWidget);
      expect(find.textContaining('Use Side-by-Side view for visual reference'), findsOneWidget);
    });

    testWidgets('Reset button restores default opacity and view state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhostOverlayViewer(
                earlierCaptureId: 'cap_early_1',
                latestCaptureId: 'cap_late_2',
                alignmentStatus: 'aligned',
                imageBuilder: _mockImageBuilder,
              ),
            ),
          ),
        ),
      );

      // Tap Solo Follow-up (opacity = 0.0)
      await tester.tap(find.text('Solo Follow-up'));
      await tester.pump();

      // Tap Reset View
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pump();

      expect(find.text('50/50 Blend'), findsOneWidget);
    });
  });
}
