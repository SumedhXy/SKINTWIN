import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/provider_models.dart';
import '../services/find_care_service.dart';

enum FindCareState {
  idle,
  loading,
  locationRequesting,
  locationAvailable,
  filtering,
  resultsLoaded,
  empty,
  failed,
}

class FindCareProvider extends ChangeNotifier {
  final FindCareService _service;
  bool _initialized = false;
  
  FindCareState _state = FindCareState.idle;
  FindCareState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ProviderResponse> _providers = [];
  List<ProviderResponse> get providers => _providers;

  List<String> _specialties = ['All'];
  List<String> get specialties => _specialties;

  PaginationInfo? _pagination;
  PaginationInfo? get pagination => _pagination;

  // Filter states
  String _selectedSpecialty = 'All';
  String get selectedSpecialty => _selectedSpecialty;

  String _selectedConsultationType = 'All';
  String get selectedConsultationType => _selectedConsultationType;

  // Location simulation / GPS
  double? _latitude;
  double? _longitude;
  String _currentCity = 'Unknown Location';
  String get currentCity => _currentCity;

  bool _isUsingGPS = false;
  bool get isUsingGPS => _isUsingGPS;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  String _sort = 'relevance';
  String get sort => _sort;
  double _radiusKm = 50.0;
  double get radiusKm => _radiusKm;
  String _selectedLanguage = 'All';
  String get selectedLanguage => _selectedLanguage;
  bool _requestInFlight = false;
  Timer? _searchDebounce;

  FindCareProvider({FindCareService? service, Geocoding? geocoder})
      : _service = service ?? FindCareService(),
        _geocoder = geocoder ?? (kIsWeb ? null : Geocoding());

  final Geocoding? _geocoder;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await fetchSpecialties();
    await searchProviders();
  }

  Future<void> requestRealLocation() async {
    _state = FindCareState.locationRequesting;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      
      _latitude = position.latitude;
      _longitude = position.longitude;
      _isUsingGPS = true;
      _state = FindCareState.locationAvailable;
      
      try {
        final placemarks = _geocoder == null
          ? <Placemark>[]
          : await _geocoder!.placemarkFromCoordinates(_latitude!, _longitude!);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _currentCity = '${place.locality ?? place.subAdministrativeArea ?? 'Unknown'}, ${place.administrativeArea ?? ''}'.trim();
        }
      } catch (e) {
        if (kDebugMode) print("Reverse geocoding failed: $e");
        _currentCity = "Current Location";
      }

      await searchProviders(resetPage: true);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = FindCareState.failed;
      notifyListeners();
    }
  }

  Future<void> searchOpenMapNearby() async {
    if (_latitude == null || _longitude == null) {
      _errorMessage = 'Use My Location first to search nearby OpenStreetMap listings.';
      _state = FindCareState.failed;
      notifyListeners();
      return;
    }
    _state = FindCareState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _service.searchOpenMapNearby(latitude: _latitude!, longitude: _longitude!, radiusKm: _radiusKm);
      _providers = response.providers;
      _pagination = response.pagination;
      _state = _providers.isEmpty ? FindCareState.empty : FindCareState.resultsLoaded;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = FindCareState.failed;
    }
    notifyListeners();
  }

  static const Map<String, ({double lat, double lon, String name})> popularCities = {
    'san francisco': (lat: 37.7749, lon: -122.4194, name: 'San Francisco, CA'),
    'new york': (lat: 40.7128, lon: -74.0060, name: 'New York, NY'),
    'oakland': (lat: 37.8044, lon: -122.2712, name: 'Oakland, CA'),
    'los angeles': (lat: 34.0522, lon: -118.2437, name: 'Los Angeles, CA'),
    'chicago': (lat: 41.8781, lon: -87.6298, name: 'Chicago, IL'),
    'london': (lat: 51.5074, lon: -0.1278, name: 'London, UK'),
    'bengaluru': (lat: 12.9716, lon: 77.5946, name: 'Bengaluru, India'),
    'mumbai': (lat: 19.0760, lon: 72.8777, name: 'Mumbai, India'),
    'delhi': (lat: 28.6139, lon: 77.2090, name: 'Delhi, India'),
  };

  void selectCity(String cityName, double lat, double lon) {
    _currentCity = cityName;
    _latitude = lat;
    _longitude = lon;
    _isUsingGPS = false;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  Future<void> setManualLocation(String query) async {
    _state = FindCareState.loading;
    notifyListeners();
    
    final lower = query.toLowerCase().trim();
    for (final entry in popularCities.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        _latitude = entry.value.lat;
        _longitude = entry.value.lon;
        _currentCity = entry.value.name;
        _isUsingGPS = false;
        await searchProviders(resetPage: true);
        return;
      }
    }

    try {
      if (_geocoder != null) {
        final locations = await _geocoder!.locationFromAddress(query);
        if (locations.isNotEmpty) {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
          _currentCity = query;
          _isUsingGPS = false;
          await searchProviders(resetPage: true);
          return;
        }
      }
      // Web or fallback: use search term
      _currentCity = query;
      _latitude = null;
      _longitude = null;
      _isUsingGPS = false;
      await searchProviders(resetPage: true);
    } catch (e) {
      _currentCity = query;
      _latitude = null;
      _longitude = null;
      _isUsingGPS = false;
      await searchProviders(resetPage: true);
    }
  }

  void simulateLocation(String city, double lat, double lon) {
    selectCity(city, lat, lon);
  }

  Future<void> fetchSpecialties() async {
    try {
      final res = await _service.getSpecialties();
      _specialties = res.specialties;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Failed to load specialties: $e");
    }
  }

  Future<void> searchProviders({bool resetPage = true}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    if (resetPage) {
      _providers.clear();
      _pagination = null;
      _state = FindCareState.loading;
      _errorMessage = null;
      notifyListeners();
    } else {
      if (_pagination != null && _pagination!.page * _pagination!.limit >= _pagination!.total) {
        return; // No more results
      }
      _state = FindCareState.loading;
      notifyListeners();
    }

    try {
      final pageToRequest = resetPage ? 1 : (_pagination?.page ?? 0) + 1;
      
      final res = await _service.searchProviders(
        latitude: _latitude,
        longitude: _longitude,
        specialty: _selectedSpecialty,
        consultationType: _selectedConsultationType,
        search: _searchQuery,
        language: _selectedLanguage,
        radiusKm: _radiusKm,
        sort: _sort,
        page: pageToRequest,
      );

      if (resetPage) {
        _providers = res.providers;
      } else {
        _providers.addAll(res.providers);
      }
      
      _pagination = res.pagination;
      
      if (_providers.isEmpty) {
        _state = FindCareState.empty;
      } else {
        _state = FindCareState.resultsLoaded;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = FindCareState.failed;
    } finally {
      _requestInFlight = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _searchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      searchProviders(resetPage: true);
    });
  }

  void updateSort(String value) {
    _sort = value;
    _state = FindCareState.filtering;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void updateAdvancedFilters({double? radiusKm, String? language}) {
    if (radiusKm != null) _radiusKm = radiusKm;
    if (language != null) _selectedLanguage = language;
    _state = FindCareState.filtering;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void updateFilters({String? specialty, String? consultationType}) {
    if (specialty != null) _selectedSpecialty = specialty;
    if (consultationType != null) _selectedConsultationType = consultationType;
    searchProviders(resetPage: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
