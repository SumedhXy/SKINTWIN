class ProviderResponse {
  final String id;
  final String name;
  final String specialty;
  final String? specialization;
  final String? qualifications;
  final int? experienceYears;
  final String? clinicName;
  final String address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? profileDescription;
  final List<String> services;
  final String? contactInformation;
  final String? appointmentInformation;
  final double? distanceKm;
  final List<String> consultationTypes;
  final List<String> languages;
  final String? feeRange;
  final String verificationStatus;
  final String dataSource;
  final String? bookingUrl;
  final bool isTestData;
  final String? availability;
  final String? rating;
  final String? recommendationReason;
  final String? mapUrl;

  ProviderResponse({
    required this.id,
    required this.name,
    required this.specialty,
    this.specialization,
    this.qualifications,
    this.experienceYears,
    this.clinicName,
    required this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.profileDescription,
    this.services = const [],
    this.contactInformation,
    this.appointmentInformation,
    this.distanceKm,
    required this.consultationTypes,
    required this.languages,
    this.feeRange,
    required this.verificationStatus,
    required this.dataSource,
    this.bookingUrl,
    required this.isTestData,
    this.availability,
    this.rating,
    this.recommendationReason,
    this.mapUrl,
  });

  factory ProviderResponse.fromJson(Map<String, dynamic> json) {
    return ProviderResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      specialization: json['specialization'] as String?,
      qualifications: json['qualifications'] as String?,
      experienceYears: json['experience_years'] as int?,
      clinicName: json['clinic_name'] as String?,
      address: json['address'] as String,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      profileDescription: json['profile_description'] as String?,
      services: (json['services'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contactInformation: json['contact_information'] as String?,
      appointmentInformation: json['appointment_information'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      consultationTypes: (json['consultation_types'] as List?)?.map((e) => e as String).toList() ?? [],
      languages: (json['languages'] as List?)?.map((e) => e as String).toList() ?? [],
      feeRange: json['fee_range'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      dataSource: json['data_source'] as String? ?? 'unknown',
      bookingUrl: json['booking_url'] as String?,
      isTestData: json['is_test_data'] as bool? ?? false,
      availability: json['availability'] as String?,
      rating: json['rating'] as String?,
      recommendationReason: json['recommendation_reason'] as String?,
      mapUrl: json['map_url'] as String?,
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
    );
  }
}

class ProviderListResponse {
  final List<ProviderResponse> providers;
  final PaginationInfo pagination;

  ProviderListResponse({
    required this.providers,
    required this.pagination,
  });

  factory ProviderListResponse.fromJson(Map<String, dynamic> json) {
    return ProviderListResponse(
      providers: (json['providers'] as List?)
              ?.map((e) => ProviderResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class SpecialtyListResponse {
  final List<String> specialties;

  SpecialtyListResponse({required this.specialties});

  factory SpecialtyListResponse.fromJson(Map<String, dynamic> json) {
    return SpecialtyListResponse(
      specialties: (json['specialties'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }
}
