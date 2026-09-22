import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'authenticated_image.dart';

enum GhostOverlayMode {
  sideBySide,
  opacity,
  blink,
  splitSwipe,
}

class GhostOverlayViewer extends StatefulWidget {
  final String earlierCaptureId;
  final String latestCaptureId;
  final DateTime? earlierDate;
  final DateTime? latestDate;
  final String alignmentStatus; // aligned, partially_aligned, failed, not_evaluated
  final double? alignmentScore;
  final String? alignmentMethod;
  final bool hasSegmentationMask;
  final Widget Function(String captureId, BoxFit fit)? imageBuilder;

  const GhostOverlayViewer({
    super.key,
    required this.earlierCaptureId,
    required this.latestCaptureId,
    this.earlierDate,
    this.latestDate,
    this.alignmentStatus = 'aligned',
    this.alignmentScore,
    this.alignmentMethod,
    this.hasSegmentationMask = false,
    this.imageBuilder,
  });


  @override
  State<GhostOverlayViewer> createState() => _GhostOverlayViewerState();
}

class _GhostOverlayViewerState extends State<GhostOverlayViewer> {
  GhostOverlayMode _mode = GhostOverlayMode.opacity;

  // Opacity slider state (0.0 = 100% Latest, 0.5 = 50/50 blend, 1.0 = 100% Earlier)
  double _opacity = 0.5;

  // Split Swipe state
  double _splitRatio = 0.5;

  // Blink state
  bool _isBlinking = false;
  bool _blinkShowEarlier = true;
  Timer? _blinkTimer;
  int _blinkIntervalMs = 800; // default 800ms

  // Reference outline layer toggle
  bool _showReferenceOutline = false;

  // Transformation controller for zoom/pan
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  void _toggleBlink() {
    if (_isBlinking) {
      _stopBlink();
    } else {
      _startBlink();
    }
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    setState(() {
      _isBlinking = true;
    });
    _blinkTimer = Timer.periodic(Duration(milliseconds: _blinkIntervalMs), (timer) {
      if (mounted) {
        setState(() {
          _blinkShowEarlier = !_blinkShowEarlier;
        });
      }
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    setState(() {
      _isBlinking = false;
    });
  }

  void _setBlinkSpeed(int intervalMs) {
    setState(() {
      _blinkIntervalMs = intervalMs;
    });
    if (_isBlinking) {
      _startBlink();
    }
  }

  void _resetView() {
    setState(() {
      _opacity = 0.5;
      _splitRatio = 0.5;
      _showReferenceOutline = false;
      _transformController.value = Matrix4.identity();
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "Unknown Date";
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isAligned = widget.alignmentStatus.toLowerCase() == 'aligned';
    final bool isPartial = widget.alignmentStatus.toLowerCase() == 'partially_aligned';
    final bool isFailed = widget.alignmentStatus.toLowerCase() == 'failed' ||
        widget.alignmentStatus.toLowerCase() == 'not_evaluated' ||
        widget.alignmentStatus.toLowerCase() == 'unavailable';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Mode Switcher
          _buildHeader(),
          const SizedBox(height: 14),

          // 2. Alignment Status Banner
          _buildAlignmentBanner(isAligned, isPartial, isFailed),
          const SizedBox(height: 14),

          // 3. Main Viewer Canvas
          _buildViewerCanvas(),
          const SizedBox(height: 14),

          // 4. Mode-Specific Controls
          _buildModeControls(),
          const SizedBox(height: 12),

          // 5. Educational Guidance & Non-Diagnostic Disclaimer
          _buildFooterGuidance(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.layers_outlined, color: AppTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ghost Overlay Comparison",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      "Longitudinal Visual Inspection",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 22, color: AppTheme.textMuted),
              tooltip: "Reset View",
              onPressed: _resetView,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mode Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModeTab("Opacity Overlay", GhostOverlayMode.opacity, Icons.opacity),
              const SizedBox(width: 8),
              _buildModeTab("Blink Comparison", GhostOverlayMode.blink, Icons.motion_photos_on_outlined),
              const SizedBox(width: 8),
              _buildModeTab("Side-by-Side", GhostOverlayMode.sideBySide, Icons.view_column_outlined),
              const SizedBox(width: 8),
              _buildModeTab("Split Swipe", GhostOverlayMode.splitSwipe, Icons.compare),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab(String label, GhostOverlayMode mode, IconData icon) {
    final bool selected = _mode == mode;
    return InkWell(
      onTap: () {
        if (_isBlinking && mode != GhostOverlayMode.blink) {
          _stopBlink();
        }
        setState(() {
          _mode = mode;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentBanner(bool isAligned, bool isPartial, bool isFailed) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String title;
    String desc;

    if (isAligned) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      text = const Color(0xFF166534);
      icon = Icons.check_circle_outline;
      title = "Alignment Verified";
      desc = "Feature registration succeeded with verified homography (${widget.alignmentMethod ?? 'ORB + RANSAC'}).";
    } else if (isPartial) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFF92400E);
      icon = Icons.warning_amber_rounded;
      title = "Alignment Limited";
      desc = "Differences in position may be influenced by framing or camera perspective. Interpret overlay cautiously.";
    } else {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      text = const Color(0xFF991B1B);
      icon = Icons.info_outline;
      title = "Alignment Unavailable";
      desc = "Images could not be geometrically registered. Use Side-by-Side view for visual reference.";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: text),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(fontSize: 11, color: text, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerCanvas() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 280,
        width: double.infinity,
        color: const Color(0xFF0F172A), // Dark studio canvas background
        child: Stack(
          children: [
            // Mode Canvas
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.8,
              maxScale: 3.5,
              child: Center(
                child: _buildModeSpecificContent(),
              ),
            ),

            // Reference Outline Layer (if toggled)
            if (_showReferenceOutline)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Estimated image-analysis region",
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Badges & Overlay Indicators
            _buildCanvasBadges(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String captureId, BoxFit fit) {
    if (widget.imageBuilder != null) {
      return widget.imageBuilder!(captureId, fit);
    }
    return AuthenticatedImage(captureId: captureId, fit: fit);
  }

  Widget _buildModeSpecificContent() {
    switch (_mode) {
      case GhostOverlayMode.sideBySide:
        return Row(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(widget.earlierCaptureId, BoxFit.contain),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _buildImageTag("Baseline: ${_formatDate(widget.earlierDate)}", Colors.black54),
                  ),
                ],
              ),
            ),
            Container(width: 2, color: Colors.white24),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(widget.latestCaptureId, BoxFit.contain),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildImageTag("Follow-up: ${_formatDate(widget.latestDate)}", AppTheme.primaryBlue.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        );

      case GhostOverlayMode.opacity:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Follow-up capture in background (visible when opacity < 1.0)
            _buildImage(widget.latestCaptureId, BoxFit.contain),
            // Baseline capture on top with variable opacity
            Opacity(
              opacity: _opacity.clamp(0.0, 1.0),
              child: _buildImage(widget.earlierCaptureId, BoxFit.contain),
            ),
          ],
        );

      case GhostOverlayMode.blink:
        return Stack(
          fit: StackFit.expand,
          children: [
            _blinkShowEarlier
                ? _buildImage(widget.earlierCaptureId, BoxFit.contain)
                : _buildImage(widget.latestCaptureId, BoxFit.contain),
          ],
        );

      case GhostOverlayMode.splitSwipe:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Baseline in background
            _buildImage(widget.earlierCaptureId, BoxFit.contain),
            // Follow-up on top clipped by splitRatio
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _splitRatio,
              child: ClipRect(
                child: SizedBox(
                  width: double.infinity,
                  child: _buildImage(widget.latestCaptureId, BoxFit.contain),
                ),
              ),
            ),
            // Divider line
            Align(
              alignment: Alignment(_splitRatio * 2 - 1, 0),
              child: Container(
                width: 2,
                color: Colors.white,
                child: const Center(
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Icon(Icons.code, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }


  Widget _buildCanvasBadges() {
    if (_mode == GhostOverlayMode.blink) {
      return Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _blinkShowEarlier ? Colors.blue.withValues(alpha: 0.85) : const Color(0xFF059669).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                _blinkShowEarlier ? "Active: Baseline" : "Active: Follow-up",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == GhostOverlayMode.opacity) {
      final int baselinePct = (_opacity * 100).round();
      final int followupPct = 100 - baselinePct;
      return Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Baseline: $baselinePct% • Follow-up: $followupPct%",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildImageTag(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildModeControls() {
    switch (_mode) {
      case GhostOverlayMode.opacity:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Follow-up (0%)",
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                ),
                Text(
                  "50/50 Blend",
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                Text(
                  "Baseline (100%)",
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            Slider(
              value: _opacity,
              min: 0.0,
              max: 1.0,
              activeColor: AppTheme.primaryBlue,
              onChanged: (val) => setState(() => _opacity = val),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuickActionButton("Solo Follow-up", () => setState(() => _opacity = 0.0)),
                const SizedBox(width: 8),
                _buildQuickActionButton("50% Blend", () => setState(() => _opacity = 0.5)),
                const SizedBox(width: 8),
                _buildQuickActionButton("Solo Baseline", () => setState(() => _opacity = 1.0)),
              ],
            ),
          ],
        );

      case GhostOverlayMode.blink:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleBlink,
                  icon: Icon(_isBlinking ? Icons.pause : Icons.play_arrow, size: 18),
                  label: Text(_isBlinking ? "Pause Blink" : "Start Blink"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBlinking ? const Color(0xFFF59E0B) : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _blinkShowEarlier = !_blinkShowEarlier;
                    });
                  },
                  child: const Text("Step Swap"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Blink Speed: ", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                _buildSpeedChip("Fast (400ms)", 400),
                const SizedBox(width: 6),
                _buildSpeedChip("Normal (800ms)", 800),
                const SizedBox(width: 6),
                _buildSpeedChip("Slow (1400ms)", 1400),
              ],
            ),
          ],
        );

      case GhostOverlayMode.splitSwipe:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Follow-up (Left)", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                Text("Baseline (Right)", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
            Slider(
              value: _splitRatio,
              min: 0.0,
              max: 1.0,
              activeColor: AppTheme.primaryBlue,
              onChanged: (val) => setState(() => _splitRatio = val),
            ),
          ],
        );

      case GhostOverlayMode.sideBySide:
        return Center(
          child: Text(
            "Pinch or double tap to zoom and pan both captures in synchronized space.",
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildQuickActionButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
    );
  }

  Widget _buildSpeedChip(String label, int ms) {
    final bool active = _blinkIntervalMs == ms;
    return InkWell(
      onTap: () => _setBlinkSpeed(ms),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? AppTheme.primaryBlue : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterGuidance() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Ghost Overlay supports visual comparison of photographs. It does not diagnose medical conditions or determine the medical significance of observed differences.",
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
