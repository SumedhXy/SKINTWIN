class SkinTwinResponse {
  final String publicId;
  final String name;
  final String bodyLocation;
  final String? bodySide;
  final String? description;
  final String status;
  final int captureCount;
  final String? baselineCaptureId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCaptureAt;

  SkinTwinResponse({
    required this.publicId,
    required this.name,
    required this.bodyLocation,
    this.bodySide,
    this.description,
    required this.status,
    required this.captureCount,
    this.baselineCaptureId,
    required this.createdAt,
    required this.updatedAt,
    this.lastCaptureAt,
  });

  factory SkinTwinResponse.fromJson(Map<String, dynamic> json) {
    return SkinTwinResponse(
      publicId: json['public_id'],
      name: json['name'],
      bodyLocation: json['body_location'],
      bodySide: json['body_side'],
      description: json['description'],
      status: json['status'],
      captureCount: json['capture_count'] ?? 0,
      baselineCaptureId: json['baseline_capture_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastCaptureAt: json['last_capture_at'] != null 
          ? DateTime.parse(json['last_capture_at']) 
          : null,
    );
  }
}

class CaptureResponse {
  final String id;
  final String skintwinPublicId;
  final String imageObjectKey;
  final String? imageHash;
  final DateTime capturedAt;
  final DateTime uploadedAt;
  final String? bodyLocation;
  final String qualityStatus;
  final double? qualityScore;
  final String? blurStatus;
  final String? lightingStatus;
  final String? resolutionStatus;
  final String? framingStatus;
  final bool comparisonEligible;
  final Map<String, dynamic>? qualityDetails;
  final DateTime? qualityAnalyzedAt;
  final bool referenceScaleAvailable;
  final String measurementStatus;
  final String? deviceMetadata;
  final String? notes;

  CaptureResponse({
    required this.id,
    required this.skintwinPublicId,
    required this.imageObjectKey,
    this.imageHash,
    required this.capturedAt,
    required this.uploadedAt,
    this.bodyLocation,
    required this.qualityStatus,
    this.qualityScore,
    this.blurStatus,
    this.lightingStatus,
    this.resolutionStatus,
    this.framingStatus,
    required this.comparisonEligible,
    this.qualityDetails,
    this.qualityAnalyzedAt,
    required this.referenceScaleAvailable,
    required this.measurementStatus,
    this.deviceMetadata,
    this.notes,
  });

  factory CaptureResponse.fromJson(Map<String, dynamic> json) {
    return CaptureResponse(
      id: json['id'],
      skintwinPublicId: json['skintwin_public_id'],
      imageObjectKey: json['image_object_key'],
      imageHash: json['image_hash'],
      capturedAt: DateTime.parse(json['captured_at']),
      uploadedAt: DateTime.parse(json['uploaded_at']),
      bodyLocation: json['body_location'],
      qualityStatus: json['quality_status'] ?? 'unknown',
      qualityScore: json['quality_score']?.toDouble(),
      blurStatus: json['blur_status'],
      lightingStatus: json['lighting_status'],
      resolutionStatus: json['resolution_status'],
      framingStatus: json['framing_status'],
      comparisonEligible: json['comparison_eligible'] ?? false,
      qualityDetails: json['quality_details'],
      qualityAnalyzedAt: json['quality_analyzed_at'] != null
          ? DateTime.parse(json['quality_analyzed_at'])
          : null,
      referenceScaleAvailable: json['reference_scale_available'] ?? false,
      measurementStatus: json['measurement_status'] ?? 'unknown',
      deviceMetadata: json['device_metadata'],
      notes: json['notes'],
    );
  }
}

class CaptureCoachCheck {
  final String category;
  final String status; // 'pass', 'warning', 'fail', 'unknown'
  final double? score;
  final String message;
  final Map<String, dynamic>? details;

  CaptureCoachCheck({
    required this.category,
    required this.status,
    this.score,
    required this.message,
    this.details,
  });

  factory CaptureCoachCheck.fromJson(Map<String, dynamic> json) {
    return CaptureCoachCheck(
      category: json['category'] ?? 'unknown',
      status: json['status'] ?? 'unknown',
      score: json['score']?.toDouble(),
      message: json['message'] ?? '',
      details: json['details'] != null ? Map<String, dynamic>.from(json['details']) : null,
    );
  }
}

class CaptureCoachResult {
  final String status; // 'ready', 'needs_adjustment', 'blocked', 'processing', 'unavailable'
  final bool canContinue;
  final double? qualityScore;
  final String primaryMessage;
  final List<String> suggestions;
  final List<CaptureCoachCheck> checks;
  final List<String> limitations;
  final bool hasBaselineComparison;

  CaptureCoachResult({
    required this.status,
    required this.canContinue,
    this.qualityScore,
    required this.primaryMessage,
    required this.suggestions,
    required this.checks,
    required this.limitations,
    required this.hasBaselineComparison,
  });

  factory CaptureCoachResult.fromJson(Map<String, dynamic> json) {
    var rawChecks = json['checks'] as List? ?? [];
    var checksList = rawChecks.map((c) => CaptureCoachCheck.fromJson(Map<String, dynamic>.from(c))).toList();

    var rawSuggestions = json['suggestions'] as List? ?? [];
    var suggestionsList = rawSuggestions.map((s) => s.toString()).toList();

    var rawLimitations = json['limitations'] as List? ?? [];
    var limitationsList = rawLimitations.map((l) => l.toString()).toList();

    return CaptureCoachResult(
      status: json['status'] ?? 'ready',
      canContinue: json['can_continue'] ?? true,
      qualityScore: json['quality_score']?.toDouble(),
      primaryMessage: json['primary_message'] ?? '',
      suggestions: suggestionsList,
      checks: checksList,
      limitations: limitationsList,
      hasBaselineComparison: json['has_baseline_comparison'] ?? false,
    );
  }

  CaptureCoachCheck? getCheck(String category) {
    try {
      return checks.firstWhere((c) => c.category == category);
    } catch (_) {
      return null;
    }
  }

  bool get isBlocked => status == 'blocked' || !canContinue;
  bool get needsAdjustment => status == 'needs_adjustment';
  bool get isReady => status == 'ready';
}

class TimelineResponse {
  final String skintwinPublicId;
  final String skintwinName;
  final String? baselineCaptureId;
  final int totalCaptures;
  final List<CaptureResponse> items;

  TimelineResponse({
    required this.skintwinPublicId,
    required this.skintwinName,
    this.baselineCaptureId,
    required this.totalCaptures,
    required this.items,
  });

  factory TimelineResponse.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    List<CaptureResponse> itemsList = 
        list.map((i) => CaptureResponse.fromJson(i)).toList();

    return TimelineResponse(
      skintwinPublicId: json['skintwin_public_id'],
      skintwinName: json['skintwin_name'],
      baselineCaptureId: json['baseline_capture_id'],
      totalCaptures: json['total_captures'] ?? 0,
      items: itemsList,
    );
  }
}

class ComparisonCreateRequest {
  final String earlierCaptureId;
  final String latestCaptureId;
  final Map<String, dynamic>? earlierPrompt;
  final Map<String, dynamic>? latestPrompt;

  ComparisonCreateRequest({
    required this.earlierCaptureId,
    required this.latestCaptureId,
    this.earlierPrompt,
    this.latestPrompt,
  });

  Map<String, dynamic> toJson() {
    return {
      'earlier_capture_id': earlierCaptureId,
      'latest_capture_id': latestCaptureId,
      if (earlierPrompt != null) 'earlier_prompt': earlierPrompt,
      if (latestPrompt != null) 'latest_prompt': latestPrompt,
    };
  }
}

class UncertaintyReasonItem {
  final String category;
  final String severity;
  final String message;

  UncertaintyReasonItem({
    required this.category,
    required this.severity,
    required this.message,
  });

  factory UncertaintyReasonItem.fromJson(Map<String, dynamic> json) {
    return UncertaintyReasonItem(
      category: json['category'] ?? 'general',
      severity: json['severity'] ?? 'low',
      message: json['message'] ?? '',
    );
  }
}

class ComponentStatusItem {
  final String name;
  final String status;
  final double? score;
  final String explanation;
  final String? limitation;
  final bool isFallback;

  ComponentStatusItem({
    required this.name,
    required this.status,
    this.score,
    required this.explanation,
    this.limitation,
    this.isFallback = false,
  });

  factory ComponentStatusItem.fromJson(Map<String, dynamic> json) {
    return ComponentStatusItem(
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
      score: json['score']?.toDouble(),
      explanation: json['explanation'] ?? '',
      limitation: json['limitation'],
      isFallback: json['is_fallback'] ?? false,
    );
  }
}

class SignalReliabilityItem {
  final String name;
  final String reliability;
  final bool uncertainty;
  final String? limitation;
  final String interpretation;

  SignalReliabilityItem({
    required this.name,
    required this.reliability,
    required this.uncertainty,
    this.limitation,
    required this.interpretation,
  });

  factory SignalReliabilityItem.fromJson(Map<String, dynamic> json) {
    return SignalReliabilityItem(
      name: json['name'] ?? '',
      reliability: json['reliability'] ?? 'moderate',
      uncertainty: json['uncertainty'] ?? false,
      limitation: json['limitation'],
      interpretation: json['interpretation'] ?? '',
    );
  }
}

class ReliabilityDetails {
  final String overallReliability;
  final double reliabilityScore;
  final bool uncertaintyPresent;
  final List<UncertaintyReasonItem> uncertaintyReasons;
  final List<String> affectedSignals;
  final List<String> limitations;
  final Map<String, ComponentStatusItem> componentStatuses;
  final Map<String, SignalReliabilityItem> signalReliabilities;
  final String disclaimer;

  ReliabilityDetails({
    required this.overallReliability,
    required this.reliabilityScore,
    required this.uncertaintyPresent,
    required this.uncertaintyReasons,
    required this.affectedSignals,
    required this.limitations,
    required this.componentStatuses,
    required this.signalReliabilities,
    required this.disclaimer,
  });

  factory ReliabilityDetails.fromJson(Map<String, dynamic> json) {
    final rawUnc = json['uncertainty_reasons'] as List? ?? [];
    final uncList = rawUnc.map((i) {
      if (i is Map<String, dynamic>) {
        return UncertaintyReasonItem.fromJson(i);
      }
      return UncertaintyReasonItem(category: 'general', severity: 'low', message: i.toString());
    }).toList();

    final rawComps = json['component_statuses'] as Map<String, dynamic>? ?? {};
    final compsMap = rawComps.map((k, v) => MapEntry(k, ComponentStatusItem.fromJson(Map<String, dynamic>.from(v))));

    final rawSignals = json['signal_reliabilities'] as Map<String, dynamic>? ?? {};
    final signalsMap = rawSignals.map((k, v) => MapEntry(k, SignalReliabilityItem.fromJson(Map<String, dynamic>.from(v))));

    return ReliabilityDetails(
      overallReliability: json['overall_reliability'] ?? 'moderate',
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble() ?? 0.0,
      uncertaintyPresent: json['uncertainty_present'] ?? false,
      uncertaintyReasons: uncList,
      affectedSignals: List<String>.from(json['affected_signals'] ?? []),
      limitations: List<String>.from(json['limitations'] ?? []),
      componentStatuses: compsMap,
      signalReliabilities: signalsMap,
      disclaimer: json['disclaimer'] ?? 'SkinTwin describes observable image differences only.',
    );
  }
}

class ComparisonResponse {
  final String id;
  final String skintwinPublicId;
  final String earlierCaptureId;
  final String latestCaptureId;
  final String processingStatus;
  final String? processingErrorCode;

  final String alignmentStatus;
  final double? alignmentScore;
  final int? matchCount;
  final int? inlierCount;
  final double? inlierRatio;
  final String? alignmentMethod;
  final String? alignmentErrorCode;

  final String localizationStatus;
  final double? localizationConfidence;
  final String? segmentationModel;
  final String? segmentationModelVersion;
  final String? segmentationErrorCode;

  final String inferenceMode;
  final bool weightsLoaded;
  final bool fallbackUsed;

  final double? earlierArea;
  final double? latestArea;
  final double? areaChangePercent;
  final Map<String, dynamic>? colorChangeMetrics;
  final Map<String, dynamic>? shapeChangeMetrics;
  final Map<String, dynamic>? boundaryChangeMetrics;
  final Map<String, dynamic>? positionChangeMetrics;

  final String comparisonStatus;
  final String measurementStatus;
  final String reliabilityStatus;
  final String overallReliability;
  final double? reliabilityScore;
  final List<String>? uncertaintyReasons;
  final List<UncertaintyReasonItem>? uncertaintyReasonsStructured;
  final List<String>? affectedSignals;
  final List<String>? limitations;
  final ReliabilityDetails? reliabilityDetails;
  final String? observableChangeSummary;
  final Map<String, dynamic>? observableMetrics;
  final Map<String, dynamic>? aiExplanation;
  final String comparisonVersion;
  final String nonDiagnosticDisclaimer;

  final DateTime? analyzedAt;
  final DateTime createdAt;

  ComparisonResponse({
    required this.id,
    required this.skintwinPublicId,
    required this.earlierCaptureId,
    required this.latestCaptureId,
    required this.processingStatus,
    this.processingErrorCode,
    required this.alignmentStatus,
    this.alignmentScore,
    this.matchCount,
    this.inlierCount,
    this.inlierRatio,
    this.alignmentMethod,
    this.alignmentErrorCode,
    required this.localizationStatus,
    this.localizationConfidence,
    this.segmentationModel,
    this.segmentationModelVersion,
    this.segmentationErrorCode,
    required this.inferenceMode,
    required this.weightsLoaded,
    required this.fallbackUsed,
    this.earlierArea,
    this.latestArea,
    this.areaChangePercent,
    this.colorChangeMetrics,
    this.shapeChangeMetrics,
    this.boundaryChangeMetrics,
    this.positionChangeMetrics,
    required this.comparisonStatus,
    required this.measurementStatus,
    required this.reliabilityStatus,
    required this.overallReliability,
    this.reliabilityScore,
    this.uncertaintyReasons,
    this.uncertaintyReasonsStructured,
    this.affectedSignals,
    this.limitations,
    this.reliabilityDetails,
    this.observableChangeSummary,
    this.observableMetrics,
    this.aiExplanation,
    required this.comparisonVersion,
    required this.nonDiagnosticDisclaimer,
    this.analyzedAt,
    required this.createdAt,
  });

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) {
    ReliabilityDetails? relDetails;
    if (json['reliability_details'] != null && json['reliability_details'] is Map) {
      try {
        relDetails = ReliabilityDetails.fromJson(Map<String, dynamic>.from(json['reliability_details']));
      } catch (_) {}
    } else if (json['observable_metrics'] != null && json['observable_metrics'] is Map) {
      final obs = json['observable_metrics'] as Map;
      if (obs['reliability_details'] != null && obs['reliability_details'] is Map) {
        try {
          relDetails = ReliabilityDetails.fromJson(Map<String, dynamic>.from(obs['reliability_details']));
        } catch (_) {}
      }
    }

    String overallRel = json['overall_reliability'] ?? relDetails?.overallReliability ?? 'moderate';
    if (overallRel == 'moderate' && json['reliability_status'] != null) {
      final s = json['reliability_status'];
      if (s == 'reliable') overallRel = 'high';
      if (s == 'unreliable' || s == 'low') overallRel = 'low';
      if (s == 'unavailable' || s == 'insufficient') overallRel = 'insufficient';
    }

    List<UncertaintyReasonItem>? uncStruct;
    if (json['uncertainty_reasons_structured'] is List) {
      uncStruct = (json['uncertainty_reasons_structured'] as List)
          .map((i) => UncertaintyReasonItem.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    } else if (relDetails != null) {
      uncStruct = relDetails.uncertaintyReasons;
    }

    return ComparisonResponse(
      id: json['id'],
      skintwinPublicId: json['skintwin_public_id'],
      earlierCaptureId: json['earlier_capture_id'],
      latestCaptureId: json['latest_capture_id'],
      processingStatus: json['processing_status'] ?? 'unknown',
      processingErrorCode: json['processing_error_code'],
      alignmentStatus: json['alignment_status'] ?? 'not_evaluated',
      alignmentScore: json['alignment_score']?.toDouble(),
      matchCount: json['match_count'],
      inlierCount: json['inlier_count'],
      inlierRatio: json['inlier_ratio']?.toDouble(),
      alignmentMethod: json['alignment_method'],
      alignmentErrorCode: json['alignment_error_code'],
      localizationStatus: json['localization_status'] ?? 'not_evaluated',
      localizationConfidence: json['localization_confidence']?.toDouble(),
      segmentationModel: json['segmentation_model'],
      segmentationModelVersion: json['segmentation_model_version'],
      segmentationErrorCode: json['segmentation_error_code'],
      inferenceMode: json['inference_mode'] ?? 'unavailable',
      weightsLoaded: json['weights_loaded'] ?? false,
      fallbackUsed: json['fallback_used'] ?? true,
      earlierArea: json['earlier_area']?.toDouble(),
      latestArea: json['latest_area']?.toDouble(),
      areaChangePercent: json['area_change_percent']?.toDouble(),
      colorChangeMetrics: json['color_change_metrics'],
      shapeChangeMetrics: json['shape_change_metrics'],
      boundaryChangeMetrics: json['boundary_change_metrics'],
      positionChangeMetrics: json['position_change_metrics'],
      comparisonStatus: json['comparison_status'] ?? 'unavailable',
      measurementStatus: json['measurement_status'] ?? 'unavailable',
      reliabilityStatus: json['reliability_status'] ?? 'unavailable',
      overallReliability: overallRel,
      reliabilityScore: json['reliability_score']?.toDouble() ?? relDetails?.reliabilityScore,
      uncertaintyReasons: json['uncertainty_reasons'] != null 
          ? (json['uncertainty_reasons'] as List).map<String>((e) => e is Map ? (e['message'] ?? e.toString()).toString() : e.toString()).toList()
          : null,
      uncertaintyReasonsStructured: uncStruct,
      affectedSignals: json['affected_signals'] != null 
          ? List<String>.from(json['affected_signals']) 
          : relDetails?.affectedSignals,
      limitations: json['limitations'] != null 
          ? List<String>.from(json['limitations']) 
          : relDetails?.limitations,
      reliabilityDetails: relDetails,
      observableChangeSummary: json['observable_change_summary'],
      observableMetrics: json['observable_metrics'],
      aiExplanation: json['ai_explanation'],
      comparisonVersion: json['comparison_version'] ?? '1.0.0',
      nonDiagnosticDisclaimer: json['non_diagnostic_disclaimer'] ?? relDetails?.disclaimer ?? 'SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance.',
      analyzedAt: json['analyzed_at'] != null ? DateTime.parse(json['analyzed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ComparisonListResponse {
  final int total;
  final List<ComparisonResponse> items;

  ComparisonListResponse({required this.total, required this.items});

  factory ComparisonListResponse.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    return ComparisonListResponse(
      total: json['total'] ?? 0,
      items: list.map((i) => ComparisonResponse.fromJson(i)).toList(),
    );
  }
}

class NarrativeSummary {
  final String title;
  final String description;
  final String status;

  NarrativeSummary({
    required this.title,
    required this.description,
    required this.status,
  });

  factory NarrativeSummary.fromJson(Map<String, dynamic> json) {
    return NarrativeSummary(
      title: json['title'] ?? 'Observable Image Comparison',
      description: json['description'] ?? 'Observable image features compared across captures.',
      status: json['status'] ?? 'observable_difference',
    );
  }
}

class SignalItem {
  final String name;
  final dynamic baselineValue;
  final dynamic followupValue;
  final dynamic changeValue;
  final String? changeUnit;
  final String direction;
  final String status;
  final String reliability;
  final String explanation;

  SignalItem({
    required this.name,
    this.baselineValue,
    this.followupValue,
    this.changeValue,
    this.changeUnit,
    required this.direction,
    required this.status,
    required this.reliability,
    required this.explanation,
  });

  factory SignalItem.fromJson(Map<String, dynamic> json) {
    return SignalItem(
      name: json['name'] ?? 'Signal',
      baselineValue: json['baseline_value'],
      followupValue: json['followup_value'],
      changeValue: json['change_value'],
      changeUnit: json['change_unit'],
      direction: json['direction'] ?? 'unavailable',
      status: json['status'] ?? 'unavailable',
      reliability: json['reliability'] ?? 'moderate',
      explanation: json['explanation'] ?? '',
    );
  }
}

class NarrativeReliability {
  final String overall;
  final String qualityStatus;
  final String alignmentStatus;
  final String segmentationStatus;
  final List<String> limitations;

  NarrativeReliability({
    required this.overall,
    required this.qualityStatus,
    required this.alignmentStatus,
    required this.segmentationStatus,
    required this.limitations,
  });

  factory NarrativeReliability.fromJson(Map<String, dynamic> json) {
    return NarrativeReliability(
      overall: json['overall'] ?? 'moderate',
      qualityStatus: json['quality_status'] ?? 'acceptable',
      alignmentStatus: json['alignment_status'] ?? 'acceptable',
      segmentationStatus: json['segmentation_status'] ?? 'completed',
      limitations: List<String>.from(json['limitations'] ?? []),
    );
  }
}

class NarrativeUncertainty {
  final bool present;
  final String explanation;

  NarrativeUncertainty({
    required this.present,
    required this.explanation,
  });

  factory NarrativeUncertainty.fromJson(Map<String, dynamic> json) {
    return NarrativeUncertainty(
      present: json['present'] ?? false,
      explanation: json['explanation'] ?? '',
    );
  }
}

class ObservationItem {
  final String metric;
  final String status;
  final dynamic value;
  final String explanation;

  ObservationItem({
    required this.metric,
    required this.status,
    this.value,
    required this.explanation,
  });

  factory ObservationItem.fromJson(Map<String, dynamic> json) {
    return ObservationItem(
      metric: json['metric'] ?? 'unknown',
      status: json['status'] ?? 'unavailable',
      value: json['value'],
      explanation: json['explanation'] ?? '',
    );
  }
}

class ReliabilityExplanation {
  final String status;
  final String explanation;

  ReliabilityExplanation({required this.status, required this.explanation});

  factory ReliabilityExplanation.fromJson(Map<String, dynamic> json) {
    return ReliabilityExplanation(
      status: json['status'] ?? 'unavailable',
      explanation: json['explanation'] ?? '',
    );
  }
}

class ModelMetadataInfo {
  final String modelName;
  final String modelVersion;
  final String inferenceMode;

  ModelMetadataInfo({
    required this.modelName,
    required this.modelVersion,
    required this.inferenceMode,
  });

  factory ModelMetadataInfo.fromJson(Map<String, dynamic> json) {
    return ModelMetadataInfo(
      modelName: json['model_name'] ?? 'unknown',
      modelVersion: json['model_version'] ?? 'unknown',
      inferenceMode: json['inference_mode'] ?? 'unknown',
    );
  }
}

class AIExplanationResponse {
  final NarrativeSummary narrativeSummary;
  final List<SignalItem> signals;
  final NarrativeReliability narrativeReliability;
  final NarrativeUncertainty narrativeUncertainty;
  final String safetyMessage;
  final String recommendedNextStep;

  // Legacy fields
  final String summary;
  final List<ObservationItem> observations;
  final ReliabilityExplanation reliability;
  final List<String> limitations;
  final List<String> missingInformation;
  final List<String> recommendedNextSteps;
  final String medicalDisclaimer;
  final ModelMetadataInfo modelMetadata;

  AIExplanationResponse({
    required this.narrativeSummary,
    required this.signals,
    required this.narrativeReliability,
    required this.narrativeUncertainty,
    required this.safetyMessage,
    required this.recommendedNextStep,
    required this.summary,
    required this.observations,
    required this.reliability,
    required this.limitations,
    required this.missingInformation,
    required this.recommendedNextSteps,
    required this.medicalDisclaimer,
    required this.modelMetadata,
  });

  factory AIExplanationResponse.fromJson(Map<String, dynamic> json) {
    final narrativeSum = json['narrative_summary'] != null
        ? NarrativeSummary.fromJson(json['narrative_summary'])
        : NarrativeSummary(
            title: 'Observable Image Comparison',
            description: json['summary'] ?? 'Observable differences analyzed between captures.',
            status: 'observable_difference',
          );

    final rawSignals = json['signals'] as List?;
    final signalsList = rawSignals != null
        ? rawSignals.map((i) => SignalItem.fromJson(i)).toList()
        : (json['observations'] as List? ?? []).map((i) {
            final obs = ObservationItem.fromJson(i);
            return SignalItem(
              name: obs.metric.toUpperCase(),
              changeValue: obs.value,
              direction: obs.status == 'changed' ? 'differed' : (obs.status == 'unchanged' ? 'stable' : 'unavailable'),
              status: obs.status == 'changed' ? 'observable_difference' : 'stable',
              reliability: 'moderate',
              explanation: obs.explanation,
            );
          }).toList();

    final narrativeRel = json['narrative_reliability'] != null
        ? NarrativeReliability.fromJson(json['narrative_reliability'])
        : NarrativeReliability(
            overall: json['reliability']?['status'] == 'reliable' ? 'high' : 'moderate',
            qualityStatus: 'acceptable',
            alignmentStatus: 'acceptable',
            segmentationStatus: 'completed',
            limitations: List<String>.from(json['limitations'] ?? []),
          );

    final narrativeUnc = json['narrative_uncertainty'] != null
        ? NarrativeUncertainty.fromJson(json['narrative_uncertainty'])
        : NarrativeUncertainty(
            present: (json['limitations'] as List? ?? []).isNotEmpty,
            explanation: (json['limitations'] as List? ?? []).join('. '),
          );

    return AIExplanationResponse(
      narrativeSummary: narrativeSum,
      signals: signalsList,
      narrativeReliability: narrativeRel,
      narrativeUncertainty: narrativeUnc,
      safetyMessage: json['safety_message'] ?? 'This is an analysis of observable image differences and is not a medical diagnosis.',
      recommendedNextStep: json['recommended_next_step'] ??
          ((json['recommended_next_steps'] as List? ?? []).isNotEmpty
              ? json['recommended_next_steps'][0]
              : 'Continue standardized tracking. Consult a qualified healthcare professional for medical advice.'),
      summary: json['summary'] ?? '',
      observations: (json['observations'] as List? ?? [])
          .map((i) => ObservationItem.fromJson(i))
          .toList(),
      reliability: ReliabilityExplanation.fromJson(json['reliability'] ?? {}),
      limitations: List<String>.from(json['limitations'] ?? []),
      missingInformation: List<String>.from(json['missing_information'] ?? []),
      recommendedNextSteps: List<String>.from(json['recommended_next_steps'] ?? []),
      medicalDisclaimer: json['medical_disclaimer'] ?? 'Not a medical diagnosis.',
      modelMetadata: ModelMetadataInfo.fromJson(json['model_metadata'] ?? {}),
    );
  }
}
