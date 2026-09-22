import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skintwin/core/models/provider_models.dart';
import 'package:skintwin/core/providers/find_care_provider.dart';
import 'package:skintwin/screens/provider_details_screen.dart';

void main() {
  group('Find Care Model Parsing Tests', () {
    test('ProviderResponse parses safely with all nulls', () {
      final Map<String, dynamic> json = {
        'id': 'p1',
        'name': 'Dr. Test',
        'specialty': 'Dermatology',
        'address': '123 Test St',
        'consultation_types': ['in_person'],
        'languages': [],
        'verification_status': 'verified',
        'data_source': 'test',
        'is_test_data': true,
      };

      final p = ProviderResponse.fromJson(json);

      expect(p.id, 'p1');
      expect(p.name, 'Dr. Test');
      expect(p.distanceKm, isNull);
      expect(p.feeRange, isNull);
      expect(p.bookingUrl, isNull);
      expect(p.availability, isNull);
      expect(p.isTestData, isTrue);
    });

    test('ProviderResponse parses with all fields present', () {
      final Map<String, dynamic> json = {
        'id': 'p2',
        'name': 'Dr. Mock',
        'specialty': 'Dermatology',
        'specialization': 'Pediatric Dermatology',
        'qualifications': 'MD, FAAD',
        'experience_years': 14,
        'clinic_name': 'UCSF Skin Center',
        'address': '456 Test Ave',
        'distance_km': 12.5,
        'consultation_types': ['telehealth', 'in_person'],
        'languages': ['English', 'Spanish'],
        'services': ['Mole Mapping', 'Acne Treatment'],
        'fee_range': r'$150 - $300',
        'verification_status': 'verified',
        'data_source': 'mock_fixtures',
        'booking_url': 'https://example.com',
        'is_test_data': true,
        'availability': 'Tomorrow, 10:00 AM',
        'rating': '4.9',
      };

      final p = ProviderResponse.fromJson(json);

      expect(p.distanceKm, 12.5);
      expect(p.specialization, 'Pediatric Dermatology');
      expect(p.qualifications, 'MD, FAAD');
      expect(p.experienceYears, 14);
      expect(p.clinicName, 'UCSF Skin Center');
      expect(p.services.length, 2);
      expect(p.consultationTypes.length, 2);
      expect(p.bookingUrl, 'https://example.com');
      expect(p.availability, 'Tomorrow, 10:00 AM');
    });

    test('ProviderListResponse pagination parses correctly', () {
      final json = {
        'providers': [],
        'pagination': {'page': 2, 'limit': 10, 'total': 25},
      };
      final res = ProviderListResponse.fromJson(json);
      expect(res.pagination.page, 2);
      expect(res.pagination.total, 25);
      expect(res.providers, isEmpty);
    });

    test('SpecialtyListResponse parses correctly', () {
      final json = {
        'specialties': ['All', 'Dermatology', 'Pediatric Dermatology', 'Surgery'],
      };
      final res = SpecialtyListResponse.fromJson(json);
      expect(res.specialties.length, 4);
      expect(res.specialties.first, 'All');
    });
  });

  group('Popular Cities Presets', () {
    test('Includes standard major cities', () {
      expect(FindCareProvider.popularCities.containsKey('san francisco'), isTrue);
      expect(FindCareProvider.popularCities.containsKey('new york'), isTrue);
      expect(FindCareProvider.popularCities.containsKey('oakland'), isTrue);
      expect(FindCareProvider.popularCities['san francisco']!.lat, 37.7749);
    });
  });

  group('FindCareState enum', () {
    test('All expected states exist', () {
      expect(FindCareState.values, containsAll([
        FindCareState.idle,
        FindCareState.loading,
        FindCareState.resultsLoaded,
        FindCareState.empty,
        FindCareState.failed,
      ]));
    });
  });

  group('ProviderDetailsScreen Widget Tests', () {
    testWidgets('Renders provider details, clinic info, and disclaimer correctly', (tester) async {
      final provider = ProviderResponse(
        id: 'prov_test_1',
        name: 'Dr. Jane Smith, MD',
        specialty: 'Board Certified Dermatologist',
        specialization: 'General Dermatology',
        qualifications: 'MD, FAAD',
        experienceYears: 12,
        clinicName: 'San Francisco Dermatology Institute',
        address: '100 Bush St, San Francisco, CA',
        distanceKm: 2.3,
        consultationTypes: ['in_person', 'telehealth'],
        languages: ['English'],
        services: ['Mole Mapping', 'Skin Cancer Screening'],
        verificationStatus: 'verified',
        dataSource: 'mock_fixtures',
        isTestData: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderDetailsScreen(provider: provider),
        ),
      );

      // Verify Doctor Details
      expect(find.text('Dr. Jane Smith, MD'), findsOneWidget);
      expect(find.text('Board Certified Dermatologist'), findsOneWidget);
      expect(find.text('San Francisco Dermatology Institute'), findsOneWidget);
      expect(find.text('Mole Mapping'), findsOneWidget);
      expect(find.text('Skin Cancer Screening'), findsOneWidget);

      // Verify Safety & Mock Disclaimers
      expect(find.text('Informational Directory Only'), findsOneWidget);
      expect(find.textContaining('DEMO FIXTURE'), findsOneWidget);
    });
  });
}
