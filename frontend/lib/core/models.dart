import 'package:flutter/material.dart';

/// Represents a single captured image for a SkinTwin
class SkinCapture {
  final String id;
  final DateTime capturedAt;
  final String? imagePath; // local file path or null if simulated
  final double alignmentScore; // 0.0 - 1.0
  final String note;

  SkinCapture({
    required this.id,
    required this.capturedAt,
    this.imagePath,
    required this.alignmentScore,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'capturedAt': capturedAt.toIso8601String(),
        'imagePath': imagePath,
        'alignmentScore': alignmentScore,
        'note': note,
      };

  factory SkinCapture.fromJson(Map<String, dynamic> json) => SkinCapture(
        id: json['id'],
        capturedAt: DateTime.parse(json['capturedAt']),
        imagePath: json['imagePath'],
        alignmentScore: (json['alignmentScore'] as num).toDouble(),
        note: json['note'] ?? '',
      );
}

/// Status of a SkinTwin
enum TwinStatus { active, followUpDue, captureNeeded, archived }

extension TwinStatusExt on TwinStatus {
  String get label {
    switch (this) {
      case TwinStatus.active:
        return 'Active';
      case TwinStatus.followUpDue:
        return 'Follow-up Due';
      case TwinStatus.captureNeeded:
        return 'Capture Needed';
      case TwinStatus.archived:
        return 'Archived';
    }
  }

  Color get badgeBg {
    switch (this) {
      case TwinStatus.active:
        return const Color(0xFFECFDF5);
      case TwinStatus.followUpDue:
        return const Color(0xFFFFFBEB);
      case TwinStatus.captureNeeded:
        return const Color(0xFFEFF6FF);
      case TwinStatus.archived:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get badgeText {
    switch (this) {
      case TwinStatus.active:
        return const Color(0xFF047857);
      case TwinStatus.followUpDue:
        return const Color(0xFFB45309);
      case TwinStatus.captureNeeded:
        return const Color(0xFF1D4ED8);
      case TwinStatus.archived:
        return const Color(0xFF64748B);
    }
  }
}

/// Body location categories
enum BodyLocation { face, head, back, torso, arms, legs, hands, feet, other }

extension BodyLocationExt on BodyLocation {
  String get label {
    switch (this) {
      case BodyLocation.face:
        return 'Face';
      case BodyLocation.head:
        return 'Head & Neck';
      case BodyLocation.back:
        return 'Back & Shoulders';
      case BodyLocation.torso:
        return 'Torso';
      case BodyLocation.arms:
        return 'Arms';
      case BodyLocation.legs:
        return 'Legs';
      case BodyLocation.hands:
        return 'Hands';
      case BodyLocation.feet:
        return 'Feet';
      case BodyLocation.other:
        return 'Other';
    }
  }

  String get filterKey => name;
}

/// Core SkinTwin entity — a tracked skin finding
class SkinTwin {
  final String id;
  String title;
  String detailedLocation; // e.g. "Upper back (mid-scapular)"
  BodyLocation bodyLocation;
  final DateTime createdAt;
  DateTime updatedAt;
  TwinStatus status;
  List<SkinCapture> captures;
  Color spotColor;
  bool isPinned;
  String notes;

  SkinTwin({
    required this.id,
    required this.title,
    required this.detailedLocation,
    required this.bodyLocation,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.captures,
    required this.spotColor,
    this.isPinned = false,
    this.notes = '',
  });

  String get shortId => 'ST-${id.substring(0, 4).toUpperCase()}';

  SkinCapture? get baselineCapture => captures.isEmpty ? null : captures.first;
  SkinCapture? get latestCapture => captures.length > 1 ? captures.last : null;

  int get captureCount => captures.length;

  /// Returns a human-readable date from createdAt
  String get createdLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays == 0) return 'Created Today';
    if (diff.inDays == 1) return 'Created Yesterday';
    if (diff.inDays < 7) return 'Created ${diff.inDays} days ago';
    return 'Created ${_monthDay(createdAt)}';
  }

  String _monthDay(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get lastCapturedLabel {
    if (captures.isEmpty) return 'No captures yet';
    final last = captures.last.capturedAt;
    final now = DateTime.now();
    final diff = now.difference(last);
    if (diff.inDays == 0) return 'Last captured today';
    if (diff.inDays == 1) return 'Last captured yesterday';
    return 'Last captured ${_monthDay(last)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detailedLocation': detailedLocation,
        'bodyLocation': bodyLocation.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'captures': captures.map((c) => c.toJson()).toList(),
        'spotColor': spotColor.toARGB32(),
        'isPinned': isPinned,
        'notes': notes,
      };

  factory SkinTwin.fromJson(Map<String, dynamic> json) => SkinTwin(
        id: json['id'],
        title: json['title'],
        detailedLocation: json['detailedLocation'],
        bodyLocation: BodyLocation.values.firstWhere(
          (e) => e.name == json['bodyLocation'],
          orElse: () => BodyLocation.other,
        ),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        status: TwinStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TwinStatus.captureNeeded,
        ),
        captures: (json['captures'] as List)
            .map((c) => SkinCapture.fromJson(c as Map<String, dynamic>))
            .toList(),
        spotColor: Color(json['spotColor'] as int),
        isPinned: json['isPinned'] ?? false,
        notes: json['notes'] ?? '',
      );
}

/// App-wide user profile
class UserProfile {
  String name;
  String email;
  String? avatarPath;
  DateTime joinedAt;
  bool notificationsEnabled;
  int captureReminderDays;

  UserProfile({
    required this.name,
    required this.email,
    this.avatarPath,
    required this.joinedAt,
    this.notificationsEnabled = true,
    this.captureReminderDays = 30,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'avatarPath': avatarPath,
        'joinedAt': joinedAt.toIso8601String(),
        'notificationsEnabled': notificationsEnabled,
        'captureReminderDays': captureReminderDays,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'],
        email: json['email'],
        avatarPath: json['avatarPath'],
        joinedAt: DateTime.parse(json['joinedAt']),
        notificationsEnabled: json['notificationsEnabled'] ?? true,
        captureReminderDays: json['captureReminderDays'] ?? 30,
      );
}
