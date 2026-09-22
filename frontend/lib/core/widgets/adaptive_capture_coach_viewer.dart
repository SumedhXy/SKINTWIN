import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/api_models.dart';

/// Pre-capture guidance card providing concise checklists to ensure consistent photos.
class AdaptiveCaptureCoachPreCaptureCard extends StatelessWidget {
  final bool hasBaseline;
  final VoidCallback? onDismiss;

  const AdaptiveCaptureCoachPreCaptureCard({
    super.key,
    this.hasBaseline = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_outlined, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Adaptive Capture Coach",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip(Icons.wb_sunny_outlined, "Use soft, uniform ambient lighting; avoid harsh direct glare."),
          _buildTip(Icons.vibration, "Hold steady and rest elbows if needed to avoid motion blur."),
          _buildTip(Icons.center_focus_strong, "Keep the skin finding centered inside the green viewfinder."),
          if (hasBaseline)
            _buildTip(Icons.compare, "Match the camera distance and angle of your baseline photo."),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comprehensive Post-Capture Review Sheet displaying prioritized feedback and checks.
class AdaptiveCaptureCoachReviewSheet extends StatelessWidget {
  final CaptureCoachResult coachResult;
  final VoidCallback onRetake;
  final VoidCallback onContinue;
  final bool isSaving;

  const AdaptiveCaptureCoachReviewSheet({
    super.key,
    required this.coachResult,
    required this.onRetake,
    required this.onContinue,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = coachResult.isBlocked
        ? const Color(0xFFEF4444)
        : coachResult.needsAdjustment
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    final statusIcon = coachResult.isBlocked
        ? Icons.cancel
        : coachResult.needsAdjustment
            ? Icons.warning_amber_rounded
            : Icons.check_circle;

    final statusLabel = coachResult.isBlocked
        ? "Action Required · Photo Blocked"
        : coachResult.needsAdjustment
            ? "Adjustment Recommended"
            : "Capture Ready for Comparison";

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (coachResult.qualityScore != null)
                          Text(
                            "Quality Score: ${(coachResult.qualityScore! * 100).toInt()}%",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Primary Prioritized Guidance Message
            Text(
              "Quality Assessment",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                coachResult.primaryMessage,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),

            // Actionable Suggestions
            if (coachResult.suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "Actionable Recommendations",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...coachResult.suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            s,
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 14),

            // Categorized Checks Breakdown
            Text(
              "Technical Checks",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...coachResult.checks.map((check) => _buildCheckRow(check)),

            const SizedBox(height: 16),

            // Non-Diagnostic Disclaimer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Capture Coach evaluates photographic consistency. It does not provide medical diagnosis or confirm biological change.",
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Retake Button
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('coach_retake_button'),
                    onPressed: isSaving ? null : onRetake,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(
                      "Retake Photo",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Continue / Use Photo Button
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('coach_continue_button'),
                    onPressed: (isSaving || coachResult.isBlocked)
                        ? null
                        : () => _handleContinueWithValidation(context),
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      coachResult.needsAdjustment ? "Use Anyway" : "Use This Photo",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coachResult.needsAdjustment
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleContinueWithValidation(BuildContext context) {
    if (coachResult.needsAdjustment) {
      // Show confirmation dialog for non-blocking override
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                "Proceed with Limitations?",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "This photo has minor quality or lighting differences that may reduce the reliability of future visual comparisons. Would you like to proceed?",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Retake", style: GoogleFonts.inter(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onContinue();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: Text("Proceed Anyway", style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      onContinue();
    }
  }

  Widget _buildCheckRow(CaptureCoachCheck check) {
    final (icon, color) = switch (check.status) {
      'pass' => (Icons.check_circle_outline, const Color(0xFF10B981)),
      'warning' => (Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
      'fail' => (Icons.highlight_off, const Color(0xFFEF4444)),
      _ => (Icons.help_outline, Colors.white38),
    };

    final title = switch (check.category) {
      'sharpness' => 'Sharpness & Focus',
      'lighting' => 'Lighting & Exposure',
      'resolution' => 'Image Resolution',
      'framing' => 'Finding Framing',
      'baseline_consistency' => 'Baseline Consistency',
      _ => check.category,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  check.message,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
