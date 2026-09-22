import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/pressable_card.dart';
import '../core/models/provider_models.dart';
import '../core/providers/find_care_provider.dart';
import 'provider_details_screen.dart';

class FindCareScreen extends StatefulWidget {
  const FindCareScreen({super.key});

  @override
  State<FindCareScreen> createState() => _FindCareScreenState();
}

class _FindCareScreenState extends State<FindCareScreen> {
  bool _showMap = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FindCareProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Find Dermatologists",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: _showMap ? "Show List View" : "Show Map View",
            icon: Icon(_showMap ? Icons.view_list_rounded : Icons.map_outlined, color: AppTheme.primaryBlue),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: "Filter options",
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textDark),
            onPressed: () => _showFilters(context, provider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.searchProviders(resetPage: true),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Location Bar with Quick City Switcher
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: provider.isUsingGPS
                          ? AppTheme.successGreen.withValues(alpha: 0.12)
                          : AppTheme.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isUsingGPS ? Icons.gps_fixed : Icons.location_on,
                      color: provider.isUsingGPS ? AppTheme.successGreen : AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.isUsingGPS ? "CURRENT LOCATION (GPS)" : "SELECTED CITY",
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: provider.isUsingGPS ? AppTheme.successGreen : AppTheme.primaryBlue,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.currentCity,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showLocationModal(context, provider),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text("Change"),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: provider.updateSearch,
                decoration: InputDecoration(
                  hintText: "Search doctors, clinics, conditions...",
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            provider.updateSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Symptom Safety Gate Guidance Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "SkinTwin helps you discover professional care options. It does not provide clinical diagnosis or physician rankings.",
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Interactive Map (when toggled or with GPS coordinates)
            if (_showMap && provider.providers.any((p) => p.latitude != null && p.longitude != null)) ...[
              _buildProviderMap(provider),
              const SizedBox(height: 16),
            ],

            // Specialty Pills Carousel
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.specialties.map((specialty) {
                  final isSel = provider.selectedSpecialty == specialty;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSel,
                      label: Text(
                        specialty,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSel ? AppTheme.primaryBlue : AppTheme.borderColor),
                      ),
                      showCheckmark: false,
                      onSelected: (val) {
                        HapticFeedback.selectionClick();
                        provider.updateFilters(specialty: specialty);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Consultation Mode Quick Chips & Sort Row
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickFilter(provider, 'All Modes', 'All'),
                        _quickFilter(provider, 'In-Clinic', 'in_person'),
                        _quickFilter(provider, 'Video Consult', 'telehealth'),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: provider.updateSort,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'relevance', child: Text('Recommended order')),
                    PopupMenuItem(value: 'distance', child: Text('Nearest first')),
                    PopupMenuItem(value: 'name', child: Text('Name A-Z')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 14, color: AppTheme.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          provider.sort == 'distance' ? 'Nearest' : (provider.sort == 'name' ? 'A-Z' : 'Sort'),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results Section
            if (provider.state == FindCareState.loading && provider.providers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (provider.state == FindCareState.failed)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 10),
                    Text(
                      provider.errorMessage ?? 'Unable to connect to care network',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => provider.searchProviders(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry Search'),
                    ),
                  ],
                ),
              )
            else if (provider.providers.isEmpty)
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_off_outlined, size: 36, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "No doctors or clinics found",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Try increasing your search radius or switching to a major city like San Francisco or New York.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        provider.updateFilters(specialty: 'All', consultationType: 'All');
                        provider.setManualLocation('San Francisco, CA');
                      },
                      child: const Text("Reset to San Francisco"),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${provider.providers.length} Healthcare Options Found",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                  ),
                  if (provider.providers.any((p) => p.isTestData))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        "DEMO DATA",
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...provider.providers.map((doc) => _buildPractoProviderCard(context, doc)),
            ],

            const SizedBox(height: 20),

            // Privacy Notice Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 20, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Privacy Guarantee: Your skin photos and comparison records remain in your encrypted local vault and are never shared automatically with healthcare listings.",
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPractoProviderCard(BuildContext context, ProviderResponse doc) {
    return PressableCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProviderDetailsScreen(provider: doc)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Details + Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.person, color: AppTheme.primaryBlue, size: 34),
                    ),
                    if (doc.consultationTypes.contains('telehealth'))
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              doc.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.isTestData)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                "MOCK",
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.specialty,
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (doc.qualifications != null || doc.experienceYears != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (doc.qualifications != null) doc.qualifications,
                              if (doc.experienceYears != null) "${doc.experienceYears} yrs exp.",
                            ].join(' • '),
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Clinic & Address Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (doc.clinicName != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.business_outlined, size: 15, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            doc.clinicName!,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doc.address,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.distanceKm != null)
                        Text(
                          "${doc.distanceKm!.toStringAsFixed(1)} km",
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Consultation Mode Chips
            Row(
              children: [
                if (doc.consultationTypes.contains('in_person'))
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_hospital_outlined, size: 13, color: AppTheme.primaryBlue),
                        const SizedBox(width: 4),
                        Text("In-Clinic", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                      ],
                    ),
                  ),
                if (doc.consultationTypes.contains('telehealth'))
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_outlined, size: 13, color: Color(0xFF047857)),
                        const SizedBox(width: 4),
                        Text("Video Consult", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                const Spacer(),
                if (doc.contactInformation != null)
                  IconButton(
                    icon: const Icon(Icons.call_outlined, color: AppTheme.primaryBlue, size: 20),
                    tooltip: "Call Clinic",
                    onPressed: () => _launchUrl("tel:${doc.contactInformation}"),
                  ),
                if (doc.mapUrl != null)
                  IconButton(
                    icon: const Icon(Icons.directions_outlined, color: AppTheme.primaryBlue, size: 20),
                    tooltip: "Get Directions",
                    onPressed: () => _launchUrl(doc.mapUrl!),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProviderDetailsScreen(provider: doc)),
                  );
                },
                child: Text(
                  doc.bookingUrl != null && !doc.isTestData ? "Book Appointment" : "View Profile & Details",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderMap(FindCareProvider provider) {
    final mappedProviders = provider.providers
        .where((item) => item.latitude != null && item.longitude != null)
        .toList();
    if (mappedProviders.isEmpty) return const SizedBox.shrink();

    final first = mappedProviders.first;
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(first.latitude!, first.longitude!),
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.skintwin.app',
          ),
          MarkerLayer(
            markers: mappedProviders.map((item) => Marker(
              point: LatLng(item.latitude!, item.longitude!),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProviderDetailsScreen(provider: item)),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryBlue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital, color: AppTheme.primaryBlue, size: 22),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickFilter(FindCareProvider provider, String label, String mode) {
    final selected = provider.selectedConsultationType == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? AppTheme.primaryBlue : AppTheme.borderColor),
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          provider.updateFilters(consultationType: mode);
        },
        showCheckmark: false,
      ),
    );
  }

  void _showLocationModal(BuildContext context, FindCareProvider provider) {
    String manualQuery = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Location",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Use My Location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text("Use Current GPS Location"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    provider.requestRealLocation();
                  },
                ),
              ),
              const SizedBox(height: 16),

              Text(
                "Or search city / locality:",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: "e.g., San Francisco, Oakland, New York...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.pop(sheetContext);
                    provider.setManualLocation(val.trim());
                  }
                },
                onChanged: (val) => manualQuery = val,
              ),
              const SizedBox(height: 16),

              Text(
                "Popular Cities:",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _cityChip(sheetContext, provider, "San Francisco", 37.7749, -122.4194),
                  _cityChip(sheetContext, provider, "Oakland", 37.8044, -122.2712),
                  _cityChip(sheetContext, provider, "New York", 40.7128, -74.0060),
                  _cityChip(sheetContext, provider, "Los Angeles", 34.0522, -118.2437),
                  _cityChip(sheetContext, provider, "London", 51.5074, -0.1278),
                  _cityChip(sheetContext, provider, "Bengaluru", 12.9716, 77.5946),
                ],
              ),
              const SizedBox(height: 16),

              if (manualQuery.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      provider.setManualLocation(manualQuery.trim());
                    },
                    child: const Text("Search This Location"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cityChip(BuildContext sheetContext, FindCareProvider provider, String city, double lat, double lon) {
    return ActionChip(
      avatar: const Icon(Icons.location_city, size: 14, color: AppTheme.primaryBlue),
      label: Text(city, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        Navigator.pop(sheetContext);
        provider.selectCity(city, lat, lon);
      },
    );
  }

  Future<void> _showFilters(BuildContext context, FindCareProvider provider) async {
    double radius = provider.radiusKm;
    String language = provider.selectedLanguage;
    final languages = <String>{'All', ...provider.providers.expand((item) => item.languages)}.toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter Options', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Distance Radius', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [5.0, 10.0, 25.0, 50.0, 100.0].map((val) {
                    final isSel = radius == val;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text("${val.toInt()} km"),
                      selectedColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold),
                      onSelected: (_) => setSheetState(() => radius = val),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Language Spoken', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButton<String>(
                    value: languages.contains(language) ? language : 'All',
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: languages.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setSheetState(() => language = value ?? language),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          provider.updateAdvancedFilters(radiusKm: 50.0, language: 'All');
                          provider.updateFilters(specialty: 'All', consultationType: 'All');
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Reset All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          provider.updateAdvancedFilters(radiusKm: radius, language: language);
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
