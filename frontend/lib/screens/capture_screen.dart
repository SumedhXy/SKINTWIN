import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_store.dart';
import '../core/models/api_models.dart';
import '../core/widgets/adaptive_capture_coach_viewer.dart';
import '../core/widgets/authenticated_image.dart';
import 'live_camera_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  bool _isFlashOn = false;
  bool _isCaptured = false;
  bool _isSaving = false;
  bool _isEvaluatingCoach = false;
  bool _showCoachGuidance = false;
  bool _showGhostFramingGuide = true;
  String? _capturedImagePath;
  XFile? _capturedImage;
  CaptureCoachResult? _coachResult;
  late AnimationController _pulseController;
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _twinId; // passed from SkinTwins screen

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Receive twinId from route arguments
    _twinId ??= ModalRoute.of(context)?.settings.arguments as String?;
    if (_twinId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDefaultTwin());
    }
  }

  Future<void> _resolveDefaultTwin() async {
    final store = context.read<AppStore>();
    if (store.twins.isEmpty) await store.fetchTwins();
    if (!mounted || _twinId != null) return;
    if (store.twins.isNotEmpty) {
      setState(() => _twinId = store.twins.first.publicId);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    SkinTwinResponse? twin = _twinId != null ? store.findById(_twinId!) : null;
    final isBaselineCapture = twin == null || twin.captureCount == 0;
    final baselineCaptureId = twin?.baselineCaptureId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Actions Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        twin != null ? twin.name : "Adaptive Capture Coach",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isCaptured ? Icons.check_circle : Icons.psychology_outlined,
                            color: _isCaptured ? AppTheme.successGreen : AppTheme.primaryBlue,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isCaptured
                                ? (_coachResult?.status == 'blocked'
                                    ? "Action Required"
                                    : "Quality Evaluated")
                                : "Capture Coach Active",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Toggle Capture Guidance",
                        icon: Icon(
                          _showCoachGuidance ? Icons.info : Icons.info_outline,
                          color: _showCoachGuidance ? AppTheme.primaryBlue : Colors.white,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _showCoachGuidance = !_showCoachGuidance),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _isFlashOn ? Colors.amber : Colors.white,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pre-capture guidance card if toggled or pre-capture
            if (_showCoachGuidance)
              AdaptiveCaptureCoachPreCaptureCard(
                hasBaseline: !isBaselineCapture,
                onDismiss: () => setState(() => _showCoachGuidance = false),
              ),

            // Twin context pill
            if (twin != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, color: AppTheme.primaryBlue, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            "${twin.name} · ${twin.captureCount} captures",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (!isBaselineCapture && baselineCaptureId != null && !_isCaptured) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showGhostFramingGuide = !_showGhostFramingGuide),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _showGhostFramingGuide
                                ? const Color(0xFF059669).withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _showGhostFramingGuide
                                  ? const Color(0xFF059669).withValues(alpha: 0.5)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers,
                                size: 12,
                                color: _showGhostFramingGuide ? const Color(0xFF10B981) : Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Ghost Guide",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _showGhostFramingGuide ? const Color(0xFF10B981) : Colors.white60,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Camera Viewfinder Area / Post-Capture Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: _isCaptured
                        ? (_coachResult?.isBlocked == true
                            ? const Color(0xFFEF4444)
                            : _coachResult?.needsAdjustment == true
                                ? const Color(0xFFF59E0B)
                                : AppTheme.successGreen)
                        : Colors.white24,
                    width: _isCaptured ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isCaptured ? AppTheme.successGreen : AppTheme.primaryBlue)
                          .withValues(alpha: 0.15),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Image preview or HUD
                      if (_capturedImagePath != null)
                        Positioned.fill(
                          child: kIsWeb
                              ? Image.network(_capturedImagePath!, fit: BoxFit.cover)
                              : Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
                        )
                      else
                        // Animated alignment & framing HUD (isolated with RepaintBoundary)
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final pulse = _pulseController.value * 0.12 + 0.88;
                              return Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Ghost Framing Reference from Baseline if enabled
                                    if (!isBaselineCapture &&
                                        baselineCaptureId != null &&
                                        _showGhostFramingGuide)
                                      Opacity(
                                        opacity: 0.28,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: AuthenticatedImage(
                                            captureId: baselineCaptureId,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      width: 260 * pulse,
                                      height: 260 * pulse,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 160,
                                          height: 200,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(100),
                                            border: Border.all(
                                              color: AppTheme.successGreen,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.successGreen.withValues(alpha: 0.3),
                                                blurRadius: 15,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.center_focus_strong, color: AppTheme.successGreen, size: 36),
                                                const SizedBox(height: 8),
                                                Text(
                                                  "Tap camera button\nto start capture",
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      // Quality Feedback & Status Banner (Top overlay)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCaptured
                                  ? (_coachResult?.isBlocked == true
                                      ? const Color(0xFFEF4444)
                                      : _coachResult?.needsAdjustment == true
                                          ? const Color(0xFFF59E0B)
                                          : AppTheme.successGreen)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isCaptured
                                    ? (_coachResult?.isBlocked == true
                                        ? Icons.cancel
                                        : _coachResult?.needsAdjustment == true
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle)
                                    : Icons.psychology_outlined,
                                color: _isCaptured
                                    ? (_coachResult?.isBlocked == true
                                        ? const Color(0xFFEF4444)
                                        : _coachResult?.needsAdjustment == true
                                            ? const Color(0xFFF59E0B)
                                            : AppTheme.successGreen)
                                    : AppTheme.primaryBlue,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isEvaluatingCoach
                                      ? "Evaluating photo quality..."
                                      : _isCaptured
                                          ? (_coachResult?.primaryMessage ?? "Quality evaluated.")
                                          : "Adaptive Capture Coach Active",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Retake button if captured
                      if (_isCaptured)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () {
                              _pulseController.repeat(reverse: true);
                              setState(() {
                                _isCaptured = false;
                                _capturedImagePath = null;
                                _capturedImage = null;
                                _coachResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.refresh, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Retake",
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Review sheet trigger if captured
                      if (_isCaptured && _coachResult != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: GestureDetector(
                            onTap: () => _showCoachReviewModal(context, store, twin),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.checklist, color: AppTheme.primaryBlue, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Review Quality Checks",
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Note field (after capture)
            if (_isCaptured) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _noteCtrl,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Add note (e.g. lighting, finding sensation) (optional)",
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ],

            // Camera Controls Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Gallery Picker
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),

                  // Main Capture / Save Action Button
                  GestureDetector(
                    key: const Key('capture_main_action_button'),
                    onTap: _isCaptured
                        ? () => _handleSaveWithCoachValidation(context, store, twin)
                        : () => _pickImage(ImageSource.camera),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isCaptured
                              ? (_coachResult?.isBlocked == true
                                  ? const Color(0xFFEF4444)
                                  : _coachResult?.needsAdjustment == true
                                      ? const Color(0xFFF59E0B)
                                      : AppTheme.successGreen)
                              : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isCaptured ? AppTheme.successGreen : AppTheme.primaryBlue)
                                .withValues(alpha: 0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _isCaptured
                                ? (_coachResult?.isBlocked == true
                                    ? const Color(0xFFEF4444)
                                    : _coachResult?.needsAdjustment == true
                                        ? const Color(0xFFF59E0B)
                                        : AppTheme.successGreen)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _isSaving || _isEvaluatingCoach
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : Icon(
                                  _isCaptured ? Icons.check : Icons.camera_alt,
                                  color: _isCaptured ? Colors.white : AppTheme.primaryBlue,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Camera flip / reload
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
            ),

            // Non-Diagnostic Disclaimer Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Text(
                "Capture Coach supports photographic consistency. It does not provide medical diagnosis or confirm biological changes.",
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final XFile? image = source == ImageSource.camera
          ? await navigator.push<XFile>(
              MaterialPageRoute(builder: (_) => const LiveCameraScreen()),
            )
          : await _picker.pickImage(
              source: source,
              maxWidth: 1920,
              maxHeight: 1920,
              imageQuality: 92,
            );

      if (image != null) {
        _pulseController.stop();
        setState(() {
          _capturedImagePath = image.path;
          _capturedImage = image;
          _isCaptured = true;
          _isEvaluatingCoach = true;
        });
        HapticFeedback.heavyImpact();

        // Run Coach Evaluation
        if (_twinId != null && mounted) {
          final store = context.read<AppStore>();
          final result = await store.evaluateCaptureCoach(_twinId!, image: image);
          if (mounted) {
            setState(() {
              _coachResult = result;
              _isEvaluatingCoach = false;
            });
            // Automatically open review sheet if issues detected or on demand
            _showCoachReviewModal(context, store, store.findById(_twinId!));
          }
        } else {
          if (mounted) setState(() => _isEvaluatingCoach = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEvaluatingCoach = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Camera or gallery access failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showCoachReviewModal(BuildContext context, AppStore store, SkinTwinResponse? twin) {
    if (_coachResult == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AdaptiveCaptureCoachReviewSheet(
        coachResult: _coachResult!,
        onRetake: () {
          Navigator.pop(context);
          _pulseController.repeat(reverse: true);
          setState(() {
            _isCaptured = false;
            _capturedImagePath = null;
            _capturedImage = null;
            _coachResult = null;
          });
        },
        onContinue: () {
          Navigator.pop(context);
          _saveCapture(context, store, twin);
        },
        isSaving: _isSaving,
      ),
    );
  }

  void _handleSaveWithCoachValidation(BuildContext context, AppStore store, SkinTwinResponse? twin) {
    if (_coachResult?.isBlocked == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot save: ${_coachResult?.primaryMessage ?? 'Photo quality is below minimum threshold.'}"),
          backgroundColor: const Color(0xFFEF4444),
          action: SnackBarAction(
            label: "Review",
            textColor: Colors.white,
            onPressed: () => _showCoachReviewModal(context, store, twin),
          ),
        ),
      );
      return;
    }

    if (_coachResult?.needsAdjustment == true) {
      _showCoachReviewModal(context, store, twin);
      return;
    }

    _saveCapture(context, store, twin);
  }

  Future<void> _saveCapture(BuildContext context, AppStore store, SkinTwinResponse? twin) async {
    if (_isSaving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_twinId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Create a SkinTwin before saving a capture.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    if (_twinId != null && _capturedImage != null) {
      try {
        final capture = await store.addCapture(
          _twinId!,
          image: _capturedImage!,
          note: _noteCtrl.text.trim(),
        );

        if (mounted) {
          navigator.pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                twin != null
                    ? "Capture saved to ${twin.name} — Quality: ${capture?.qualityStatus}"
                    : "Capture logged.",
              ),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
}
