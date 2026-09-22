import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models/api_models.dart';
import '../core/services/capture_service.dart';
import '../core/providers/comparison_provider.dart';
import '../core/app_store.dart';
import '../core/widgets/authenticated_image.dart';
import '../core/widgets/ghost_overlay_viewer.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _twinId;
  TimelineResponse? _timeline;
  bool _isLoadingTimeline = true;
  String? _timelineError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_twinId == null) {
      final argId = ModalRoute.of(context)?.settings.arguments as String?;
      if (argId != null && argId.isNotEmpty) {
        _twinId = argId;
        _initSelectionAndFetch();
      } else {
        _resolveDefaultTwinAndFetch();
      }
    }
  }

  void _initSelectionAndFetch() {
    Future.microtask(() {
      if (!mounted || _twinId == null) return;
      context.read<ComparisonProvider>().startSelectionFlow(_twinId!);
      _fetchTimeline();
    });
  }

  Future<void> _resolveDefaultTwinAndFetch() async {
    setState(() {
      _isLoadingTimeline = true;
      _timelineError = null;
    });
    final store = context.read<AppStore>();
    if (store.twins.isEmpty) {
      await store.fetchTwins();
    }
    if (!mounted) return;

    if (store.twins.isNotEmpty) {
      final candidate = store.twins.firstWhere(
        (t) => t.captureCount >= 2,
        orElse: () => store.twins.first,
      );
      _twinId = candidate.publicId;
      _initSelectionAndFetch();
    } else {
      setState(() {
        _isLoadingTimeline = false;
        _timelineError = "No SkinTwins found. Create a SkinTwin first.";
      });
    }
  }

  Future<void> _fetchTimeline() async {
    if (_twinId == null) return;
    setState(() {
      _isLoadingTimeline = true;
      _timelineError = null;
    });
    try {
      final service = CaptureService();
      final timeline = await service.getTimeline(_twinId!);
      if (mounted) {
        setState(() {
          _timeline = timeline;
          _isLoadingTimeline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _timelineError = "Failed to load timeline: ${e.toString().replaceAll('Exception: ', '')}";
          _isLoadingTimeline = false;
        });
      }
    }
  }

  void _switchTwin(String newTwinId) {
    if (_twinId == newTwinId) return;
    setState(() {
      _twinId = newTwinId;
      _timeline = null;
    });
    _initSelectionAndFetch();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (_isLoadingTimeline) {
      return Scaffold(
        appBar: AppBar(title: const Text("SkinTwin Timeline")),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_timelineError != null || _timeline == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("SkinTwin Timeline"),
          actions: [
            if (store.twins.length > 1)
              PopupMenuButton<String>(
                icon: const Icon(Icons.swap_horiz),
                tooltip: "Switch Finding",
                onSelected: _switchTwin,
                itemBuilder: (context) => store.twins
                    .map((t) => PopupMenuItem(
                          value: t.publicId,
                          child: Text("${t.name} (${t.captureCount} captures)"),
                        ))
                    .toList(),
              ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.compare_arrows, size: 64, color: AppTheme.primaryBlue),
                const SizedBox(height: 16),
                Text(
                  store.twins.isEmpty ? "No SkinTwins Found" : "Select a SkinTwin to Compare",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  store.twins.isEmpty
                      ? "Create a SkinTwin finding and add photos to unlock longitudinal visual comparison."
                      : _timelineError ?? "Choose a finding with at least 2 captures to compare.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (store.twins.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/skin_twins'),
                    icon: const Icon(Icons.add),
                    label: const Text("Create SkinTwin"),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/capture', arguments: _twinId),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Add New Photo"),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Go Back"),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final provider = context.watch<ComparisonProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.state == ComparisonState.selectingCaptures
                  ? "Select Captures"
                  : "Comparison Results",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_timeline != null)
              Text(
                _timeline!.skintwinName,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
          ],
        ),
        actions: [
          if (store.twins.length > 1 && provider.state == ComparisonState.selectingCaptures)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
              tooltip: "Switch Finding",
              onSelected: _switchTwin,
              itemBuilder: (context) => store.twins
                  .map((t) => PopupMenuItem(
                        value: t.publicId,
                        child: Row(
                          children: [
                            if (t.publicId == _twinId)
                              const Icon(Icons.check, size: 16, color: AppTheme.primaryBlue)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text("${t.name} (${t.captureCount})"),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (provider.state == ComparisonState.completed ||
              provider.state == ComparisonState.resultsLoaded ||
              provider.state == ComparisonState.explanationLoading)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeleteComparison(context, provider),
            ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, ComparisonProvider provider) {
    if (provider.state == ComparisonState.selectingCaptures ||
        provider.state == ComparisonState.validatingSelection) {
      return _buildSelectionUI(context, provider);
    }

    if (provider.state == ComparisonState.processing) {
      return _buildProcessingUI();
    }

    if (provider.state == ComparisonState.failed) {
      return _buildFailedUI(provider);
    }

    return _buildResultsUI(context, provider);
  }

  // ==========================================
  // PHASE 6: CAPTURE SELECTION UI
  // ==========================================
  Widget _buildSelectionUI(BuildContext context, ComparisonProvider provider) {
    if (_timeline!.items.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.compare_arrows, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              Text(
                "2 Captures Required",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                "${_timeline?.skintwinName ?? 'This finding'} has ${_timeline!.items.length} capture so far.\nTake a second photo to compare changes over time.",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pushNamed(context, '/capture', arguments: _twinId),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take Follow-up Photo"),
              ),
            ],
          ),
        ),
      );
    }

    final earlier = provider.earlierCapture;
    final latest = provider.latestCapture;

    return Column(
      children: [
        if (provider.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            width: double.infinity,
            child: Text(
              provider.errorMessage!,
              style: GoogleFonts.inter(color: Colors.red.shade800, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _timeline!.items.length,
            itemBuilder: (context, index) {
              final capture = _timeline!.items[index];
              final isEarlier = earlier?.id == capture.id;
              final isLatest = latest?.id == capture.id;
              
              String badge = "";
              if (isEarlier) badge = "Earlier Capture";
              if (isLatest) badge = "Later Capture";

              return GestureDetector(
                onTap: () {
                  if (isEarlier) {
                    provider.selectEarlierCapture(latest!);
                    provider.selectLatestCapture(capture); // placeholder logic to deselect or swap
                  } else if (isLatest) {
                    // Do nothing or deselect
                  } else {
                    if (earlier == null) {
                      provider.selectEarlierCapture(capture);
                    } else if (latest == null) {
                      provider.selectLatestCapture(capture);
                    } else {
                      // Reset and start over if tapping a third
                      provider.startSelectionFlow(_twinId!);
                      provider.selectEarlierCapture(capture);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEarlier || isLatest ? AppTheme.primaryBlue : AppTheme.borderColor,
                      width: isEarlier || isLatest ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: AuthenticatedImage(captureId: capture.id),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _longDate(capture.capturedAt),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Quality: ${capture.qualityStatus.toUpperCase()}",
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            if (badge.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badge,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
            ],
          ),
          child: ElevatedButton(
            onPressed: earlier != null && latest != null
                ? () {
                    // Auto swap if chronologically wrong before submitting
                    if (earlier.capturedAt.isAfter(latest.capturedAt)) {
                      provider.selectEarlierCapture(latest);
                      provider.selectLatestCapture(earlier);
                    }
                    provider.submitComparison();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
            ),
            child: const Text("Confirm Comparison"),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PHASE 7: PROCESSING UI
  // ==========================================
  Widget _buildProcessingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryBlue),
          const SizedBox(height: 24),
          Text(
            "Analyzing observable image differences...",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Aligning captures and extracting measurements.\nThis may take a few moments.",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFailedUI(ComparisonProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Comparison could not be completed",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? "An unknown error occurred. Please try again.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.startSelectionFlow(_twinId!),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PHASE 8-10: MULTI-SIGNAL RESULTS UI
  // ==========================================
  Widget _buildResultsUI(BuildContext context, ComparisonProvider provider) {
    final result = provider.comparisonResult;
    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              Text(
                provider.state == ComparisonState.explanationLoading
                    ? "Preparing comparison explanation..."
                    : "No comparison result is available yet.",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        GhostOverlayViewer(
          earlierCaptureId: result.earlierCaptureId,
          latestCaptureId: result.latestCaptureId,
          earlierDate: provider.earlierCapture?.capturedAt ?? result.analyzedAt ?? result.createdAt,
          latestDate: provider.latestCapture?.capturedAt ?? result.createdAt,
          alignmentStatus: result.alignmentStatus,
          alignmentScore: result.alignmentScore,
          alignmentMethod: result.alignmentMethod,
          hasSegmentationMask: result.localizationStatus == 'segmented',
        ),
        const SizedBox(height: 24),

        // Multi-Signal Narrative UI
        _buildMultiSignalNarrative(provider, result),
      ],
    );
  }



  Widget _buildMultiSignalNarrative(ComparisonProvider provider, ComparisonResponse result) {
    if (provider.state == ComparisonState.explanationLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              "Generating Observable Change Narrative...",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              "Synthesizing observable Area, Shape, Color, Position, and Alignment signals.",
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final explanation = provider.aiExplanation;
    final overallRel = result.overallReliability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Overall Reliability Card
        _buildOverallReliabilityCard(result, provider),
        const SizedBox(height: 20),

        // 2. Insufficient Comparison State Banner (if insufficient)
        if (overallRel == 'insufficient') ...[
          _buildInsufficientComparisonBanner(result, provider),
          const SizedBox(height: 20),
        ],

        // 3. Component Status Breakdown (Image Quality, Alignment, Segmentation, Measurements)
        _buildComponentStatusBreakdown(result),
        const SizedBox(height: 20),

        // 4. Uncertainty Panel (when uncertainty present)
        if (result.reliabilityDetails?.uncertaintyPresent == true ||
            (result.uncertaintyReasons != null && result.uncertaintyReasons!.isNotEmpty) ||
            overallRel != 'high') ...[
          _buildUncertaintyPanel(result),
          const SizedBox(height: 20),
        ],

        // 5. Signal-Specific Reliability Cards
        _buildSignalCardsSection(result, explanation),
        const SizedBox(height: 20),

        // 6. AI Summary Context (if available)
        if (explanation != null) ...[
          _buildNarrativeSummaryCard(explanation.narrativeSummary, explanation.narrativeReliability, provider),
          const SizedBox(height: 20),
        ],

        // 7. Safety Disclaimer & Care Next Steps
        _buildSafetyAndCareCard(result, explanation, context),
        const SizedBox(height: 16),
      ],
    );
  }

  // =========================================================================
  // 1. OVERALL RELIABILITY CARD
  // =========================================================================
  Widget _buildOverallReliabilityCard(ComparisonResponse result, ComparisonProvider provider) {
    Color cardBg;
    Color borderColor;
    Color badgeBg;
    Color textColor;
    IconData icon;
    String statusTitle;
    String statusDescription;

    switch (result.overallReliability.toLowerCase()) {
      case 'high':
        cardBg = const Color(0xFFF8FAFC);
        borderColor = const Color(0xFFCBD5E1);
        badgeBg = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF334155);
        icon = Icons.verified_outlined;
        statusTitle = "Comparison Reliability: High";
        statusDescription = "Image quality, feature alignment, and region segmentation are well-matched for observable comparison.";
        break;
      case 'moderate':
        cardBg = const Color(0xFFF8FAFC);
        borderColor = const Color(0xFFCBD5E1);
        badgeBg = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF334155);
        icon = Icons.info_outline;
        statusTitle = "Comparison Reliability: Moderate";
        statusDescription = "Analysis completed. Minor lighting, capture angle, or fallback boundary variations may affect specific measurements.";
        break;
      case 'low':
        cardBg = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        badgeBg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        icon = Icons.warning_amber_rounded;
        statusTitle = "Comparison Reliability: Low";
        statusDescription = "Significant capture variations, lighting shifts, or low keypoint alignment limit comparison precision.";
        break;
      default:
        cardBg = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        badgeBg = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        icon = Icons.error_outline;
        statusTitle = "Insufficient Data for Reliable Comparison";
        statusDescription = "Images could not be compared reliably due to failed alignment, missing segmentation masks, or quality limitations.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: textColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    Text(
                      "Engineering Quality Assessment (Non-Diagnostic)",
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusDescription,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark, height: 1.4),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. INSUFFICIENT COMPARISON BANNER
  // =========================================================================
  Widget _buildInsufficientComparisonBanner(ComparisonResponse result, ComparisonProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Comparison Could Not Be Fully Completed",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "The images could not be compared reliably because region segmentation or alignment was unsuccessful. Quantitative measurements are unavailable.",
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7F1D1D), height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => provider.startSelectionFlow(_twinId!),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Select Different Captures"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. COMPONENT STATUS BREAKDOWN
  // =========================================================================
  Widget _buildComponentStatusBreakdown(ComparisonResponse result) {
    final relDetails = result.reliabilityDetails;
    final comps = relDetails?.componentStatuses ?? {};

    // Fallbacks if componentStatuses not yet populated
    final imgQ = comps['image_quality'] ?? ComponentStatusItem(
      name: "Image Quality",
      status: result.overallReliability == 'high' ? 'acceptable' : 'limited',
      explanation: "Image resolution and focus evaluated.",
    );
    final alignC = comps['alignment'] ?? ComponentStatusItem(
      name: "Alignment",
      status: result.alignmentStatus == 'aligned' ? 'high' : (result.alignmentStatus == 'partially_aligned' ? 'moderate' : 'low'),
      score: result.alignmentScore,
      explanation: "Feature keypoint matching and homography registration.",
    );
    final segC = comps['segmentation'] ?? ComponentStatusItem(
      name: "Segmentation",
      status: result.localizationStatus == 'segmented' ? (result.fallbackUsed ? 'moderate' : 'high') : 'unavailable',
      score: result.localizationConfidence,
      explanation: result.fallbackUsed
          ? "Fallback thresholding segmentation used. Boundary contours have higher variability."
          : "MedSAM neural segmentation isolated region boundaries.",
      isFallback: result.fallbackUsed,
    );
    final measC = comps['measurement'] ?? ComponentStatusItem(
      name: "Measurements",
      status: result.measurementStatus == 'measured' ? (result.overallReliability == 'high' ? 'high' : 'moderate') : 'unavailable',
      explanation: "Area, shape, color, position, and overlap metrics.",
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Analysis Component Status",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            "Evaluation of each engineering stage in the comparison pipeline:",
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          _buildComponentRow(imgQ, Icons.camera_alt_outlined),
          const Divider(height: 20, color: AppTheme.borderColor),
          _buildComponentRow(alignC, Icons.crop_rotate_outlined),
          const Divider(height: 20, color: AppTheme.borderColor),
          _buildComponentRow(segC, Icons.grain_outlined),
          const Divider(height: 20, color: AppTheme.borderColor),
          _buildComponentRow(measC, Icons.straighten_outlined),
        ],
      ),
    );
  }

  Widget _buildComponentRow(ComponentStatusItem comp, IconData icon) {
    Color badgeBg;
    Color badgeText;

    switch (comp.status.toLowerCase()) {
      case 'acceptable':
      case 'high':
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF334155);
        break;
      case 'limited':
      case 'moderate':
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        break;
      case 'poor':
      case 'low':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFF92400E);
        break;
      default:
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFF991B1B);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comp.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                  ),
                  if (comp.isFallback) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        "Fallback CV Used",
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      comp.status.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comp.explanation,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark, height: 1.3),
              ),
              if (comp.limitation != null && comp.limitation!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  "Note: ${comp.limitation!}",
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. UNCERTAINTY PANEL
  // =========================================================================
  Widget _buildUncertaintyPanel(ComparisonResponse result) {
    final reasons = result.uncertaintyReasonsStructured ?? [];
    final affected = result.affectedSignals ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Uncertainty Factors & Limitations",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Some observed differences may be influenced by image quality, lighting, alignment, or measurement limitations:",
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF78350F), height: 1.4),
          ),
          const SizedBox(height: 12),

          // Reasons List
          if (reasons.isNotEmpty) ...[
            ...reasons.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Text(
                          u.category.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          u.message,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ] else if (result.uncertaintyReasons != null && result.uncertaintyReasons!.isNotEmpty) ...[
            ...result.uncertaintyReasons!.map((reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(reason, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F))),
                      ),
                    ],
                  ),
                )),
          ],

          if (affected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Affected Signals:",
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                ),
                ...affected.map((sig) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        sig.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 5. SIGNAL CARDS
  // =========================================================================
  Widget _buildSignalCardsSection(ComparisonResponse result, AIExplanationResponse? explanation) {
    final signalsMap = result.reliabilityDetails?.signalReliabilities ?? {};
    final signalsList = explanation?.signals ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Observable Signal Breakdown",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
            ),
            Text(
              "5 Signals Evaluated",
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (signalsList.isNotEmpty) ...[
          ...signalsList.map((sig) {
            final sigRel = signalsMap[sig.name.toLowerCase().replaceAll(' ', '_')] ??
                signalsMap[sig.name.toLowerCase()] ??
                SignalReliabilityItem(
                  name: sig.name,
                  reliability: sig.reliability,
                  uncertainty: sig.reliability != 'high',
                  interpretation: sig.explanation,
                );
            return _buildDetailedSignalCard(sig, sigRel);
          }),
        ] else ...[
          // Direct fallback rendering from measurements
          _buildFallbackSignalCard("Area", result.areaChangePercent != null ? "${result.areaChangePercent! > 0 ? '+' : ''}${result.areaChangePercent!.toStringAsFixed(1)}%" : "Unavailable", signalsMap['area']),
          _buildFallbackSignalCard("Shape", "Contour moments evaluated", signalsMap['shape']),
          _buildFallbackSignalCard("Color", "Distribution evaluated", signalsMap['color']),
          _buildFallbackSignalCard("Position", "Centroid shift tracked", signalsMap['position']),
          _buildFallbackSignalCard("Segmentation Overlap", "IoU computed", signalsMap['overlap']),
        ],
      ],
    );
  }

  Widget _buildDetailedSignalCard(SignalItem signal, SignalReliabilityItem rel) {
    IconData icon;
    Color iconColor;

    switch (signal.name.toLowerCase()) {
      case 'area':
        icon = Icons.aspect_ratio;
        iconColor = const Color(0xFF2563EB);
        break;
      case 'shape':
        icon = Icons.polyline_outlined;
        iconColor = const Color(0xFF7C3AED);
        break;
      case 'color':
        icon = Icons.palette_outlined;
        iconColor = const Color(0xFF0D9488);
        break;
      case 'position':
        icon = Icons.center_focus_strong_outlined;
        iconColor = const Color(0xFFD97706);
        break;
      case 'segmentation overlap':
      case 'overlap':
        icon = Icons.layers_outlined;
        iconColor = const Color(0xFF4F46E5);
        break;
      default:
        icon = Icons.grain_outlined;
        iconColor = const Color(0xFF475569);
    }

    Color relBadgeBg;
    Color relBadgeText;
    switch (rel.reliability.toLowerCase()) {
      case 'high':
        relBadgeBg = const Color(0xFFF1F5F9);
        relBadgeText = const Color(0xFF334155);
        break;
      case 'moderate':
        relBadgeBg = const Color(0xFFF1F5F9);
        relBadgeText = const Color(0xFF475569);
        break;
      case 'low':
        relBadgeBg = const Color(0xFFFEF3C7);
        relBadgeText = const Color(0xFF92400E);
        break;
      default:
        relBadgeBg = const Color(0xFFFEE2E2);
        relBadgeText = const Color(0xFF991B1B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                    if (signal.changeValue != null)
                      Text(
                        "Measured Value: ${signal.changeValue} ${signal.changeUnit ?? ''}".trim(),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: relBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Reliability: ${rel.reliability.toUpperCase()}",
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: relBadgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            signal.explanation,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark, height: 1.4),
          ),
          if (rel.limitation != null && rel.limitation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rel.limitation!,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF78350F)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackSignalCard(String name, String value, SignalReliabilityItem? rel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Reliability: ${(rel?.reliability ?? 'moderate').toUpperCase()}",
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rel?.interpretation ?? value,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. NARRATIVE SUMMARY CARD
  // =========================================================================
  Widget _buildNarrativeSummaryCard(
    NarrativeSummary summary,
    NarrativeReliability rel,
    ComparisonProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Observable Comparison Summary",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppTheme.primaryBlue),
                onPressed: () => provider.regenerateExplanation(),
                tooltip: "Regenerate Narrative",
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary.title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 6),
          Text(
            summary.description,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark, height: 1.5),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. SAFETY AND NEXT STEPS CARD
  // =========================================================================
  Widget _buildSafetyAndCareCard(
    ComparisonResponse result,
    AIExplanationResponse? explanation,
    BuildContext context,
  ) {
    final disclaimer = explanation?.medicalDisclaimer ?? result.nonDiagnosticDisclaimer;
    final nextStep = explanation?.recommendedNextStep ??
        "Continue standardized tracking. If you notice concerning changes or have health concerns, consider consulting a qualified healthcare professional.";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Non-Diagnostic Safety Disclaimer",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disclaimer,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderColor),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_forward_outlined, color: Color(0xFF059669), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Guidance & Next Steps",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextStep,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/find-care');
              },
              icon: const Icon(Icons.local_hospital_outlined, size: 18),
              label: const Text("Find Dermatologists Nearby"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteComparison(BuildContext context, ComparisonProvider provider) async {
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Comparison?"),
        content: const Text(
          "This will remove the comparison record and its calculated data from your timeline.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteComparison();
      if (success && mounted) {
        nav.pop(); // Go back to timeline or SkinTwins screen
      }
    }
  }

  String _longDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
