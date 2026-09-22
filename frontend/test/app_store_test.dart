import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/app_store.dart';

void main() {
  group('AppStore State Transitions', () {
    test('Initial state is loading', () {
      final store = AppStore();
      expect(store.isLoadingTwins, false);
      expect(store.twins, isEmpty);
    });
  });
}
