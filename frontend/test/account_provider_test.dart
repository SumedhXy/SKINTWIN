import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/user_models.dart';
import 'package:skintwin/core/providers/account_provider.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'full_name': 'Test User',
        'is_active': true,
        'account_status': 'active',
        'created_at': '2025-01-01T00:00:00Z',
        'last_login_at': '2025-06-01T12:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'test@example.com');
      expect(profile.fullName, 'Test User');
      expect(profile.isActive, true);
      expect(profile.accountStatus, 'active');
      expect(profile.lastLoginAt, isNotNull);
    });

    test('parses safely with null optional fields', () {
      final json = {
        'id': 'user-456',
        'email': 'noname@example.com',
        'is_active': true,
        'account_status': 'active',
        'created_at': '2025-01-01T00:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.fullName, isNull);
      expect(profile.lastLoginAt, isNull);
    });

    test('displayName returns fullName when set', () {
      final json = {
        'id': 'u1',
        'email': 'user@example.com',
        'full_name': 'Dr. Smith',
        'is_active': true,
        'account_status': 'active',
        'created_at': '2025-01-01T00:00:00Z',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.displayName, 'Dr. Smith');
    });

    test('displayName falls back to email prefix when fullName is null', () {
      final json = {
        'id': 'u2',
        'email': 'johndoe@example.com',
        'is_active': true,
        'account_status': 'active',
        'created_at': '2025-01-01T00:00:00Z',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.displayName, 'johndoe');
    });

    test('displayName falls back to email prefix when fullName is whitespace-only', () {
      final json = {
        'id': 'u3',
        'email': 'whitespace@example.com',
        'full_name': '   ',
        'is_active': true,
        'account_status': 'active',
        'created_at': '2025-01-01T00:00:00Z',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.displayName, 'whitespace');
    });
  });

  group('UserExportData Model Tests', () {
    test('parses export response correctly', () {
      final json = {
        'exported_at': '2025-09-01T10:00:00Z',
        'profile': {
          'id': 'u1',
          'email': 'export@example.com',
          'is_active': true,
          'account_status': 'active',
          'created_at': '2025-01-01T00:00:00Z',
        },
        'skintwins': [],
        'captures': [],
        'total_skintwins': 0,
        'total_captures': 0,
        'export_notes': ['No image files are included.'],
      };

      final export = UserExportData.fromJson(json);

      expect(export.totalSkinTwins, 0);
      expect(export.totalCaptures, 0);
      expect(export.exportNotes.length, 1);
      expect(export.profile.email, 'export@example.com');
    });

    test('export_notes defaults to empty list when missing', () {
      final json = {
        'exported_at': '2025-09-01T10:00:00Z',
        'profile': {
          'id': 'u1',
          'email': 'test@example.com',
          'is_active': true,
          'account_status': 'active',
          'created_at': '2025-01-01T00:00:00Z',
        },
        'total_skintwins': 2,
        'total_captures': 5,
      };

      final export = UserExportData.fromJson(json);
      expect(export.exportNotes, isEmpty);
      expect(export.totalSkinTwins, 2);
      expect(export.totalCaptures, 5);
    });
  });

  group('AccountProvider State Machine Tests', () {
    test('initial state is idle', () {
      final provider = AccountProvider();
      expect(provider.state, AccountState.idle);
      expect(provider.profile, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.isBusy, isFalse);
    });

    test('client-side password validation rejects short new password', () async {
      final provider = AccountProvider();
      final result = await provider.changePassword(
        currentPassword: 'OldPass123',
        newPassword: 'short',
      );
      expect(result, isFalse);
      expect(provider.errorMessage, contains('8 characters'));
    });

    test('client-side password validation rejects identical passwords', () async {
      final provider = AccountProvider();
      final result = await provider.changePassword(
        currentPassword: 'SamePass123',
        newPassword: 'SamePass123',
      );
      expect(result, isFalse);
      expect(provider.errorMessage, contains('different'));
    });

    test('isBusy returns false when idle', () {
      final provider = AccountProvider();
      expect(provider.isBusy, isFalse);
    });

    test('all expected states exist', () {
      expect(AccountState.values, containsAll([
        AccountState.idle,
        AccountState.loading,
        AccountState.saving,
        AccountState.exporting,
        AccountState.deletingAccount,
        AccountState.success,
        AccountState.failed,
      ]));
    });

    test('reset clears error and returns to idle', () async {
      final provider = AccountProvider();
      // Trigger a client-side error
      await provider.changePassword(currentPassword: 'x', newPassword: 'short');
      expect(provider.errorMessage, isNotNull);

      provider.reset();
      expect(provider.state, AccountState.idle);
      expect(provider.errorMessage, isNull);
    });

    // NOTE: Network-dependent tests (loadProfile, updateName, exportData, deleteAccount)
    // require a running backend and are validated via physical device testing.
    // Timeout and 401 error-mapping behavior is tested via comparison_service_test.dart patterns.
  });
}
