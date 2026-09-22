import 'dart:async';
import 'package:flutter/material.dart';
import '../models/api_models.dart';
import '../services/comparison_service.dart';

enum ComparisonState {
  idle,
  selectingCaptures,
  validatingSelection,
  processing,
  resultsLoaded,
  explanationLoading,
  completed,
  failed,
}

class ComparisonProvider extends ChangeNotifier {
  final ComparisonService _comparisonService;

  ComparisonState _state = ComparisonState.idle;
  ComparisonState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _skintwinPublicId;
  String? get skintwinPublicId => _skintwinPublicId;

  CaptureResponse? _earlierCapture;
  CaptureResponse? get earlierCapture => _earlierCapture;

  CaptureResponse? _latestCapture;
  CaptureResponse? get latestCapture => _latestCapture;

  ComparisonResponse? _comparisonResult;
  ComparisonResponse? get comparisonResult => _comparisonResult;

  AIExplanationResponse? _aiExplanation;
  AIExplanationResponse? get aiExplanation => _aiExplanation;

  List<SignalItem> get signals => _aiExplanation?.signals ?? [];
  NarrativeSummary? get narrativeSummary => _aiExplanation?.narrativeSummary;
  NarrativeReliability? get narrativeReliability => _aiExplanation?.narrativeReliability;
  NarrativeUncertainty? get narrativeUncertainty => _aiExplanation?.narrativeUncertainty;

  ComparisonProvider({ComparisonService? comparisonService})
      : _comparisonService = comparisonService ?? ComparisonService();

  void _setState(ComparisonState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _setState(ComparisonState.failed);
  }

  void startSelectionFlow(String skintwinId) {
    _reset();
    _skintwinPublicId = skintwinId;
    _setState(ComparisonState.selectingCaptures);
  }

  void selectEarlierCapture(CaptureResponse capture) {
    _earlierCapture = capture;
    notifyListeners();
  }

  void selectLatestCapture(CaptureResponse capture) {
    _latestCapture = capture;
    notifyListeners();
  }

  bool validateSelection() {
    _setState(ComparisonState.validatingSelection);
    _errorMessage = null;

    if (_earlierCapture == null || _latestCapture == null) {
      _setError('Please select both an earlier and a later capture.');
      return false;
    }

    if (_earlierCapture!.id == _latestCapture!.id) {
      _setError('Cannot compare a capture with itself. Please select two distinct captures.');
      return false;
    }

    if (_earlierCapture!.capturedAt.isAfter(_latestCapture!.capturedAt)) {
      _setError('The earlier capture must be taken before the later capture.');
      return false;
    }

    _setState(ComparisonState.selectingCaptures); // Go back to selecting or ready
    return true;
  }

  Future<void> submitComparison() async {
    if (!validateSelection()) return;
    
    // Prevent duplicate submissions
    if (_state == ComparisonState.processing) return;

    _setState(ComparisonState.processing);

    try {
      final request = ComparisonCreateRequest(
        earlierCaptureId: _earlierCapture!.id,
        latestCaptureId: _latestCapture!.id,
      );

      _comparisonResult = await _comparisonService.createComparison(
        publicId: _skintwinPublicId!,
        request: request,
      );

      _setState(ComparisonState.resultsLoaded);
      unawaited(loadExplanation());
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> loadExplanation() async {
    if (_comparisonResult == null) return;
    _setState(ComparisonState.explanationLoading);

    try {
      _aiExplanation = await _comparisonService.getExplanation(_comparisonResult!.id);
      _setState(ComparisonState.completed);
    } catch (e) {
      // If AI Explanation fails, we still have comparison results
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(ComparisonState.completed); // Consider it done but UI can show fallback/error
    }
  }

  Future<void> regenerateExplanation() async {
    if (_comparisonResult == null || _state == ComparisonState.explanationLoading) return;
    
    _setState(ComparisonState.explanationLoading);
    _errorMessage = null;
    
    try {
      _aiExplanation = await _comparisonService.regenerateExplanation(_comparisonResult!.id);
      _setState(ComparisonState.completed);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(ComparisonState.completed);
    }
  }

  Future<bool> deleteComparison() async {
    if (_comparisonResult == null) return false;
    
    try {
      await _comparisonService.deleteComparison(_comparisonResult!.id);
      _reset();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void _reset() {
    _skintwinPublicId = null;
    _earlierCapture = null;
    _latestCapture = null;
    _comparisonResult = null;
    _aiExplanation = null;
    _errorMessage = null;
    _state = ComparisonState.idle;
    notifyListeners();
  }

  void clearState() {
    _reset();
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }
}
