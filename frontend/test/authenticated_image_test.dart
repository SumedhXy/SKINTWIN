import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/widgets/authenticated_image.dart';

void main() {
  test('AuthenticatedImage properties are set correctly', () {
    const image = AuthenticatedImage(
      captureId: 'test_123',
      width: 100,
      height: 200,
    );

    expect(image.captureId, 'test_123');
    expect(image.width, 100);
    expect(image.height, 200);
  });
}
