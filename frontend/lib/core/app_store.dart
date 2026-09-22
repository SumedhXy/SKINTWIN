import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/api_models.dart';
import 'services/skintwin_service.dart';
import 'services/capture_service.dart';
import 'services/comparison_service.dart';

/// Central data store — ChangeNotifier for reactive UI updates.
class AppStore extends ChangeNotifier {
  static const _profileKey = 'user_profile';
  static const _onboardedKey = 'is_onboarded';

  final SkinTwinService _skinTwinService = SkinTwinService();
  final CaptureService _captureService = CaptureService();
  final ComparisonService _comparisonService = ComparisonService();

  List<SkinTwinResponse> _twins = [];
  final Map<String, List<CaptureResponse>> _capturesByTwin = {};
  Map<String, dynamic>? _profile;
  bool _isOnboarded = false;
  bool _isLoaded = false;
  bool _isLoadingTwins = false;
  final Set<String> _comparisonRequestsInFlight = {};

  List<SkinTwinResponse> get twins => List.unmodifiable(_twins);
  Map<String, dynamic>? get profile => _profile;
  bool get isOnboarded => _isOnboarded;
  bool get isLoaded => _isLoaded;
  bool get isLoadingTwins => _isLoadingTwins;

  List<CaptureResponse> capturesFor(String twinId) =>
      List.unmodifiable(_capturesByTwin[twinId] ?? const []);

  Future<void> refreshUserData() async {
    await fetchTwins();
    if (_twins.isNotEmpty) {
      await Future.wait(_twins.map((twin) => fetchCaptures(twin.publicId)));
    }
  }

  void clearSessionData() {
    _twins = [];
    _capturesByTwin.clear();
    notifyListeners();
  }

  /// Load profile and onboarding data from SharedPreferences
  Future<void> load() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();

    final profileJson = prefs.getString(_profileKey);
    if (profileJson != null) {
      _profile = jsonDecode(profileJson);
    }

    _isOnboarded = prefs.getBool(_onboardedKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> fetchTwins() async {
    _isLoadingTwins = true;
    notifyListeners();
    try {
      _twins = await _skinTwinService.getSkinTwins();
    } catch (e) {
      // Handle error gracefully, possibly expose to UI
      debugPrint('Error fetching twins: $e');
    } finally {
      _isLoadingTwins = false;
      notifyListeners();
    }
  }

  Future<void> fetchCaptures(String twinId) async {
    try {
      _capturesByTwin[twinId] = await _captureService.getCaptures(twinId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching captures: $e');
    }
  }

  Future<void> _persistProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (_profile != null) {
      await prefs.setString(_profileKey, jsonEncode(_profile!));
    }
  }

  // ─── SkinTwin CRUD ───────────────────────────────────────────────

  Future<SkinTwinResponse?> createTwin({
    required String title,
    required String detailedLocation,
  }) async {
    try {
      final twin = await _skinTwinService.createSkinTwin(
        name: title,
        bodyLocation: detailedLocation,
      );
      _twins.insert(0, twin);
      notifyListeners();
      return twin;
    } catch (e) {
      debugPrint('Error creating twin: $e');
      return null;
    }
  }

  Future<CaptureResponse?> addCapture(
    String twinId, {
    required XFile image,
    String? note,
  }) async {
    try {
      final capture = await _captureService.uploadCapture(
        publicId: twinId,
        image: image,
        notes: note,
      );
      
      // Refresh twins to update capture count and status
      await fetchTwins();
      await fetchCaptures(twinId);
      unawaited(_processLatestComparison(twinId));
      return capture;
    } catch (e) {
      debugPrint('Error uploading capture: $e');
      rethrow;
    }
  }

  Future<CaptureCoachResult> evaluateCaptureCoach(
    String twinId, {
    required XFile image,
  }) async {
    return _captureService.evaluateCoach(
      publicId: twinId,
      image: image,
    );
  }

  Future<void> _processLatestComparison(String twinId) async {
    if (_comparisonRequestsInFlight.contains(twinId)) return;
    _comparisonRequestsInFlight.add(twinId);

    try {
      final captures = [...capturesFor(twinId)]
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      if (captures.length < 2) return;

      final earlier = captures[captures.length - 2];
      final latest = captures.last;

      final existing = await _comparisonService.getComparisons(twinId);
      final alreadyProcessed = existing.items.any(
        (item) => item.earlierCaptureId == earlier.id && item.latestCaptureId == latest.id,
      );
      if (alreadyProcessed) return;

      await _comparisonService.createComparison(
        publicId: twinId,
        request: ComparisonCreateRequest(
          earlierCaptureId: earlier.id,
          latestCaptureId: latest.id,
        ),
      );

      debugPrint('Auto comparison queued for $twinId without fetching explanation to reduce app lag.');
    } catch (e) {
      debugPrint('Automatic comparison failed: $e');
    } finally {
      _comparisonRequestsInFlight.remove(twinId);
    }
  }

  SkinTwinResponse? findById(String id) {
    try {
      return _twins.firstWhere((t) => t.publicId == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Profile ─────────────────────────────────────────────────────

  Future<void> setProfile(Map<String, dynamic> userProfile) async {
    _profile = userProfile;
    await _persistProfile();
    notifyListeners();
  }

  Future<void> updateProfile({bool? notificationsEnabled, int? captureReminderDays}) async {
    if (_profile != null) {
      if (notificationsEnabled != null) _profile!['notificationsEnabled'] = notificationsEnabled;
      if (captureReminderDays != null) _profile!['captureReminderDays'] = captureReminderDays;
      await _persistProfile();
      notifyListeners();
    }
  }

  // ─── Analytics ───────────────────────────────────────────────────

  int get totalCaptures => _twins.fold(0, (sum, t) => sum + t.captureCount);
  int get followUpDueCount => _twins.where((t) => t.status == 'needs_review').length;
  int get activeCount => _twins.where((t) => t.status == 'active').length;
}
