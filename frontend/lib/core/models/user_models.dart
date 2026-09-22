// user_models.dart — typed models for authenticated user profile and data export

/// Typed model for an authenticated user profile returned by the API.
class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final bool isActive;
  final String accountStatus;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
    required this.accountStatus,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      accountStatus: json['account_status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  /// Display name — falls back to the email prefix if full_name is not set.
  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!.trim();
    return email.split('@').first;
  }
}

/// Typed model for the /users/me/export response.
class UserExportData {
  final DateTime exportedAt;
  final UserProfile profile;
  final int totalSkinTwins;
  final int totalCaptures;
  final List<String> exportNotes;

  const UserExportData({
    required this.exportedAt,
    required this.profile,
    required this.totalSkinTwins,
    required this.totalCaptures,
    required this.exportNotes,
  });

  factory UserExportData.fromJson(Map<String, dynamic> json) {
    return UserExportData(
      exportedAt: DateTime.parse(json['exported_at'] as String),
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      totalSkinTwins: json['total_skintwins'] as int? ?? 0,
      totalCaptures: json['total_captures'] as int? ?? 0,
      exportNotes: (json['export_notes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
