import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'skintwin_logo.dart';

class MobileSheets {
  static void showCreateSkinTwinSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateSkinTwinSheet(),
    );
  }

  static void showExportVaultSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExportVaultSheet(),
    );
  }
}

class CreateSkinTwinSheet extends StatefulWidget {
  const CreateSkinTwinSheet({super.key});

  @override
  State<CreateSkinTwinSheet> createState() => _CreateSkinTwinSheetState();
}

class _CreateSkinTwinSheetState extends State<CreateSkinTwinSheet> {
  String _selectedLocation = 'Upper Back';
  final TextEditingController _nameController = TextEditingController(text: 'New Finding 04');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const SkinTwinLogo(size: 32),
              const SizedBox(width: 10),
              Text(
                "Register New SkinTwin",
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Establish baseline photogrammetry for local vault tracking.",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Name Field
          Text("FINDING LABEL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Anatomical Location Chips
          Text("ANATOMICAL LOCATION", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Upper Back', 'Left Forearm', 'Right Clavicle', 'Left Shoulder', 'Torso'].map((loc) {
              final isSel = _selectedLocation == loc;
              return ChoiceChip(
                label: Text(loc, style: GoogleFonts.inter(fontSize: 12, color: isSel ? Colors.white : AppTheme.textDark)),
                selected: isSel,
                selectedColor: AppTheme.primaryBlue,
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedLocation = loc);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              Navigator.pushNamed(context, '/capture');
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text("Proceed to Guided Capture"),
          ),
        ],
      ),
    );
  }
}

class ExportVaultSheet extends StatelessWidget {
  const ExportVaultSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Encrypted Clinical Export", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  Text("PDF Vault Record · AES-256 Encrypted", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _buildExportRow("Total Registered Findings", "3 Active SkinTwins"),
                const Divider(height: 16, color: AppTheme.borderColor),
                _buildExportRow("Photogrammetry Baseline", "Calibrated 98% Registration"),
                const Divider(height: 16, color: AppTheme.borderColor),
                _buildExportRow("Local Vault Status", "Passcode & Biometric Locked"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Encrypted Clinical PDF generated & saved to device.")),
              );
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text("Generate Encrypted PDF"),
          ),
        ],
      ),
    );
  }

  Widget _buildExportRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      ],
    );
  }
}
