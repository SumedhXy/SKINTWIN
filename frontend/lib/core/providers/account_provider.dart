import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_models.dart';
import '../network/dio_client.dart';

/// States for the AccountProvider state machine.
enum AccountState {
  idle,
  loading,
  saving,
  exporting,
  deletingAccount,
  success,
  failed,
}

/// Manages account profile, password, data export, and account deletion.
/// All mutating operations enforce the authenticated session via the Dio
/// interceptor (Bearer token). The backend never accepts user_id from the client.
class AccountProvider extends ChangeNotifier {
  final DioClient _dioClient;

  AccountState _state = AccountState.idle;
  UserProfile? _profile;
  UserExportData? _lastExport;
  String? _errorMessage;
  bool _isDisposed = false;

  AccountProvider({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  AccountState get state => _state;
  UserProfile? get profile => _profile;
  UserExportData? get lastExport => _lastExport;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AccountState.loading;
  bool get isBusy => _state != AccountState.idle &&
      _state != AccountState.success &&
      _state != AccountState.failed;

  // ─── Profile ───────────────────────────────────────────────────────────────

  /// Fetch the authenticated user's profile from the backend.
  Future<void> loadProfile() async {
    if (_state == AccountState.loading) return;
    _setState(AccountState.loading);
    _errorMessage = null;
    try {
      final res = await _dioClient.dio.get('/auth/me');
      if (res.statusCode == 200) {
        _profile = UserProfile.fromJson(res.data as Map<String, dynamic>);
        _setState(AccountState.idle);
      } else {
        _fail('Could not load profile.');
      }
    } on DioException catch (e) {
      _fail(_mapDioError(e, fallback: 'Could not load your profile. Please try again.'));
    } catch (_) {
      _fail('An unexpected error occurred while loading your profile.');
    }
  }

  /// Update the authenticated user's display name.
  Future<bool> updateName(String newName) async {
    if (isBusy) return false;
    _setState(AccountState.saving);
    _errorMessage = null;
    try {
      final res = await _dioClient.dio.patch('/users/me', data: {
        'full_name': newName.trim().isEmpty ? null : newName.trim(),
      });
      if (res.statusCode == 200) {
        _profile = UserProfile.fromJson(res.data as Map<String, dynamic>);
        _setState(AccountState.success);
        return true;
      }
      _fail('Could not update your name.');
      return false;
    } on DioException catch (e) {
      _fail(_mapDioError(e, fallback: 'Could not update your name. Please try again.'));
      return false;
    } catch (_) {
      _fail('An unexpected error occurred.');
      return false;
    }
  }

  // ─── Password ──────────────────────────────────────────────────────────────

  /// Change the authenticated user's password.
  /// [currentPassword] and [newPassword] are transmitted over HTTPS.
  /// Never logged, never stored locally.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isBusy) return false;
    // Client-side validation
    if (newPassword.length < 8) {
      _errorMessage = 'New password must be at least 8 characters.';
      notifyListeners();
      return false;
    }
    if (newPassword == currentPassword) {
      _errorMessage = 'New password must be different from the current password.';
      notifyListeners();
      return false;
    }
    _setState(AccountState.saving);
    _errorMessage = null;
    try {
      final res = await _dioClient.dio.post('/users/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      if (res.statusCode == 204) {
        _setState(AccountState.success);
        return true;
      }
      _fail('Could not change your password.');
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _fail('Current password is incorrect.');
      } else if (e.response?.statusCode == 400) {
        final code = e.response?.data?['error']?['code'];
        if (code == 'PASSWORD_UNCHANGED') {
          _fail('New password must be different from the current password.');
        } else {
          _fail('Could not change your password.');
        }
      } else {
        _fail(_mapDioError(e, fallback: 'Could not change your password. Please try again.'));
      }
      return false;
    } catch (_) {
      _fail('An unexpected error occurred.');
      return false;
    }
  }

  // ─── Export ────────────────────────────────────────────────────────────────

  /// Export personal data as a JSON snapshot.
  /// Does not include password hashes, secrets, or raw image files.
  Future<UserExportData?> exportData() async {
    if (isBusy) return null;
    _setState(AccountState.exporting);
    _errorMessage = null;
    try {
      final res = await _dioClient.dio.get('/users/me/export');
      if (res.statusCode == 200) {
        _lastExport = UserExportData.fromJson(res.data as Map<String, dynamic>);
        _setState(AccountState.success);
        return _lastExport;
      }
      _fail('Could not export your data.');
      return null;
    } on DioException catch (e) {
      _fail(_mapDioError(e, fallback: 'Could not export your data. Please try again.'));
      return null;
    } catch (_) {
      _fail('An unexpected error occurred during export.');
      return null;
    }
  }

  // ─── Account Deletion ──────────────────────────────────────────────────────

  /// Permanently delete the account. Requires password re-authentication.
  /// Returns true on success — the caller MUST clear tokens and navigate to login.
  /// Uses a guard to prevent duplicate submissions.
  Future<bool> deleteAccount(String password) async {
    if (_state == AccountState.deletingAccount) return false;
    _setState(AccountState.deletingAccount);
    _errorMessage = null;
    try {
      final res = await _dioClient.dio.delete('/users/me', data: {
        'password': password,
      });
      if (res.statusCode == 204) {
        // Do NOT update state — caller will navigate away and dispose this provider
        return true;
      }
      _fail('Account deletion failed. Please try again.');
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _fail('Password is incorrect. Account deletion requires valid credentials.');
      } else {
        _fail(_mapDioError(e, fallback: 'Could not delete account. Please try again.'));
      }
      return false;
    } catch (_) {
      _fail('An unexpected error occurred. Please try again.');
      return false;
    }
  }

  // ─── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    _state = AccountState.idle;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  void _setState(AccountState s) {
    _state = s;
    if (!_isDisposed) notifyListeners();
  }

  void _fail(String message) {
    _state = AccountState.failed;
    _errorMessage = message;
    if (!_isDisposed) notifyListeners();
  }

  String _mapDioError(DioException e, {required String fallback}) {
    if (e.response?.statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (e.response?.statusCode == 429) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'The request timed out. Please check your connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to the server. Please check your connection.';
    }
    return fallback;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
