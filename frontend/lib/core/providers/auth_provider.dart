import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isAuthenticated = false;
  bool _isLoading = true; // Start loading to check session on startup
  Map<String, dynamic>? _currentUser;
  String? _errorMessage;

  AuthProvider({AuthService? authService}) 
      : _authService = authService ?? AuthService() {
    _checkSession();
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  Future<void> _checkSession() async {
    _setLoading(true);
    final hasToken = await _authService.hasToken();
    if (hasToken) {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _isAuthenticated = true;
        _currentUser = user;
      } else {
        // Token might be expired
        _isAuthenticated = false;
      }
    }
    _setLoading(false);
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.login(email, password);
      // Wait for login to set token, then fetch user
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _isAuthenticated = true;
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'Failed to load user profile.';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    _isAuthenticated = false;
    _setLoading(false);
    return false;
  }

  Future<bool> register(String email, String password, String fullName) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.register(email, password, fullName);
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _isAuthenticated = true;
        _currentUser = user;
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    _isAuthenticated = false;
    _setLoading(false);
    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
