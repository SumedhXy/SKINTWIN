import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/models/provider_models.dart';

class ProviderDetailsScreen extends StatelessWidget {
  final ProviderResponse provider;

  const ProviderDetailsScreen({super.key, required this.provider});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Provider Profile",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety & Emergency Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.emergency_outlined, color: Color(0xFFEF4444), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Informational Directory Only",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C), fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "This directory is for informational discovery. For sudden skin changes, rapid growth, or medical emergencies, contact a licensed physician or emergency services immediately.",
                          style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 11, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (provider.isTestData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science_outlined, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Text(
                      "DEMO FIXTURE — Non-commercial simulation record",
                      style: GoogleFonts.inter(color: const Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Provider Hero Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppTheme.primaryBlue, size: 42),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.specialty,
                        style: GoogleFonts.inter(color: AppTheme.primaryBlue, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (provider.specialization != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            provider.specialization!,
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                      if (provider.qualifications != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            provider.qualifications!,
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                      if (provider.experienceYears != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${provider.experienceYears} years clinical experience',
                            style: GoogleFonts.inter(color: AppTheme.textDark, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bio / Description
            if (provider.profileDescription != null) ...[
              _buildSectionHeader("About & Clinical Focus"),
              Text(
                provider.profileDescription!,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textDark, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],

            // Services Offered Chips
            if (provider.services.isNotEmpty) ...[
              _buildSectionHeader("Services & Treatments"),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.services.map((service) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      service,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Practice & Consultation Details
            _buildSectionHeader("Practice Details"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.medical_services_outlined,
                    "Consultation Modes",
                    provider.consultationTypes.map((t) => t == 'telehealth' ? 'Video Consult' : 'In-Clinic Visit').join(', '),
                  ),
                  const Divider(height: 20, color: AppTheme.borderColor),
                  _buildDetailRow(
                    Icons.translate_outlined,
                    "Languages Spoken",
                    provider.languages.isNotEmpty ? provider.languages.join(', ') : 'English',
                  ),
                  if (provider.feeRange != null) ...[
                    const Divider(height: 20, color: AppTheme.borderColor),
                    _buildDetailRow(
                      Icons.payments_outlined,
                      "Consultation Fee",
                      provider.feeRange!,
                    ),
                  ],
                  if (provider.availability != null) ...[
                    const Divider(height: 20, color: AppTheme.borderColor),
                    _buildDetailRow(
                      Icons.event_available_outlined,
                      "Next Availability",
                      provider.availability!,
                      valueColor: AppTheme.successGreen,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Clinic Location & Contact
            _buildSectionHeader("Clinic & Directions"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.clinicName != null) ...[
                    Text(
                      provider.clinicName!,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.address,
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                  if (provider.distanceKm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 26),
                      child: Text(
                        "${provider.distanceKm!.toStringAsFixed(1)} km from selected search area",
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (provider.contactInformation != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call_outlined, size: 16),
                            label: const Text("Call Clinic"),
                            onPressed: () => _launchUrl("tel:${provider.contactInformation}"),
                          ),
                        ),
                      if (provider.contactInformation != null && (provider.mapUrl != null || provider.latitude != null))
                        const SizedBox(width: 10),
                      if (provider.mapUrl != null || (provider.latitude != null && provider.longitude != null))
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.directions_outlined, size: 16),
                            label: const Text("Directions"),
                            onPressed: () {
                              final url = provider.mapUrl ?? "https://maps.google.com/?q=${provider.latitude},${provider.longitude}";
                              _launchUrl(url);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data Verification & Integrity Notice
            _buildSectionHeader("Directory Verification"),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        provider.verificationStatus == 'verified' ? Icons.verified : Icons.info_outline,
                        size: 16,
                        color: provider.verificationStatus == 'verified' ? AppTheme.successGreen : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Status: ${provider.verificationStatus.replaceAll('_', ' ').toUpperCase()}",
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Data source: ${provider.dataSource}. Provider timings, consultation fees, and services should be verified directly with the clinic prior to scheduling.",
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Book Appointment Button
            if (provider.bookingUrl != null && !provider.isTestData && provider.verificationStatus == 'verified') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _launchUrl(provider.bookingUrl!),
                  child: Text(
                    "Book Official Appointment",
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Online booking unavailable. Contact clinic directly.",
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
