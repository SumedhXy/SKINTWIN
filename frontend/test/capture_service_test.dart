import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/services/capture_service.dart';

void main() {
  group('CaptureService Tests', () {
    test('CaptureService initializes properly', () {
      final service = CaptureService();
      expect(service, isNotNull);
    });
  });
}
