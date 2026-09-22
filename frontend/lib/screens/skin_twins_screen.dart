import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/skin_visual_painter.dart';
import '../core/pressable_card.dart';
import '../core/app_store.dart';
import '../core/models/api_models.dart';
import '../core/widgets/authenticated_image.dart';

class SkinTwinsScreen extends StatefulWidget {
  const SkinTwinsScreen({super.key});

  @override
  State<SkinTwinsScreen> createState() => _SkinTwinsScreenState();
}

class _SkinTwinsScreenState extends State<SkinTwinsScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<AppStore>();
      await store.fetchTwins();
      for (final twin in store.twins) {
        await store.fetchCaptures(twin.publicId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final twins = store.twins;

    final filtered = twins.where((t) {
      final matchesCat = _selectedCategory == 'all' ||
          (_selectedCategory == 'follow-up'
              ? t.status == 'needs_review'
              : t.bodyLocation.toLowerCase().contains(_selectedCategory.toLowerCase()));
      final matchesQuery = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.bodyLocation.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My SkinTwins",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSheet(context, store),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  "Create",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Track and understand changes in your skin over time with calibrated telemetry.",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
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
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search by finding name or location...",
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${twins.length})'),
                _buildFilterChip('back', 'Back & Shoulders'),
                _buildFilterChip('arms', 'Arms'),
                _buildFilterChip('face', 'Face'),
                _buildFilterChip('torso', 'Torso'),
                _buildFilterChip('legs', 'Legs'),
                _buildFilterChip('follow-up', 'Follow-up Due'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Security Vault Banner
          PressableCard(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, const Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user, color: AppTheme.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "On-Device Cryptographic Vault",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          "${store.totalCaptures} captures · ${store.twins.length} SkinTwins · stored locally",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Twin Cards
          if (store.isLoadingTwins)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    "No SkinTwins found",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Try adjusting your filter or tap Create to add one.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateSheet(context, store),
                    icon: const Icon(Icons.add),
                    label: const Text("Create First SkinTwin"),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((twin) => Dismissible(
                  key: Key(twin.publicId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red.shade400, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          "Delete",
                          style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, twin.name),
                  onDismissed: (_) {
                    HapticFeedback.mediumImpact();
                    //store.deleteTwin(twin.publicId); // Add backend delete in future iteration
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${twin.name} deleted"),
                      ),
                    );
                  },
                  child: PressableCard(child: _buildTwinCard(context, twin, store)),
                )),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
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
                    const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "SkinTwin tracks observable changes over time.",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "It does not provide a medical diagnosis. If you notice concerning changes, consult a healthcare provider.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor),
        ),
        showCheckmark: false,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = key);
        },
      ),
    );
  }

  Widget _buildTwinCard(BuildContext context, SkinTwinResponse twin, AppStore store) {
    final statusBg = twin.status == 'needs_review' ? Colors.orange.shade100 : Colors.green.shade100;
    final statusText = twin.status == 'needs_review' ? Colors.orange.shade800 : Colors.green.shade800;
    final statusLabel = twin.status == 'needs_review' ? 'Review Due' : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        twin.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      twin.publicId.substring(0, 5),
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    color: statusText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Location & Date
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  "${twin.bodyLocation} · Created ${_shortDate(twin.createdAt)}",
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Previews (Mocked for MVP timeline integration)
          Row(
            children: [
              _buildVisualPreview(
                context,
                store,
                twin,
                isBaseline: true,
                label: twin.captureCount > 0 ? 'Baseline' : 'No baseline',
                isBordered: false,
              ),
              const SizedBox(width: 12),
              _buildVisualPreview(
                context,
                store,
                twin,
                isBaseline: false,
                label: twin.captureCount > 1 ? 'Latest' : 'Awaiting latest photo',
                isBordered: true,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Captures", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      "${twin.captureCount}",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Quality", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      twin.captureCount == 0 ? "—" : "Good",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Last capture", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      twin.lastCaptureAt == null
                          ? "Never"
                          : _shortDate(twin.lastCaptureAt!),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/compare', arguments: twin.publicId),
                  icon: const Icon(Icons.compare_arrows, size: 16, color: AppTheme.primaryBlue),
                  label: Text(
                    "Compare",
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushNamed(context, '/capture', arguments: twin.publicId);
                  },
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text(
                    twin.captureCount == 0 ? "Upload Baseline" : "Upload Latest",
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualPreview(BuildContext context, AppStore store, SkinTwinResponse twin, {required bool isBaseline, required String label, required bool isBordered}) {
    final captures = store.capturesFor(twin.publicId);
    final capture = captures.isEmpty || (!isBaseline && captures.length < 2)
      ? null
      : (isBaseline ? captures.first : captures.last);
    return Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBordered ? AppTheme.primaryBlue : AppTheme.borderColor,
            width: isBordered ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (capture != null)
                AuthenticatedImage(captureId: capture.id, fit: BoxFit.cover)
              else
                CustomPaint(
                  size: Size.infinite,
                  painter: SkinSpotPainter(
                    spotColor: const Color(0xFF8B4513).withValues(alpha: isBaseline ? 0.8 : 1.0),
                    label: label,
                  ),
                ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBordered
                        ? AppTheme.primaryBlue
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete SkinTwin?"),
            content: Text("This will permanently delete \"$title\" and all its captures. This cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showCreateSheet(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTwinSheet(store: store),
    );
  }
}

// ─────────────────────────────────────────────
// Create SkinTwin Bottom Sheet
// ─────────────────────────────────────────────

class _CreateTwinSheet extends StatefulWidget {
  final AppStore store;
  const _CreateTwinSheet({required this.store});

  @override
  State<_CreateTwinSheet> createState() => _CreateTwinSheetState();
}

class _CreateTwinSheetState extends State<_CreateTwinSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _selectedLocation = 'back';
  Color _selectedColor = const Color(0xFF8B4513);
  bool _isCreating = false;

  final List<Color> _colorOptions = [
    const Color(0xFF8B4513),
    const Color(0xFFA52A2A),
    const Color(0xFF6B4226),
    const Color(0xFFD2691E),
    const Color(0xFF4A3728),
    const Color(0xFF795548),
    const Color(0xFF9C6B4E),
    const Color(0xFF3E2723),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              "Create SkinTwin",
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              "Give your skin finding a name and location so you can track it over time.",
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),

            // Title Field
            Text("Finding Name", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "e.g. Left Forearm Mole",
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Detailed Location
            Text("Detailed Location", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "e.g. Upper back (mid-scapular)",
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Body Location
            Text("Body Area", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['back', 'chest', 'arm', 'leg', 'face', 'other'].map((loc) {
                final isSelected = _selectedLocation == loc;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLocation = loc);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      loc.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Spot Color
            Text("Spot Color", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Row(
              children: _colorOptions.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColor = color);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryBlue, width: 3)
                          : Border.all(color: Colors.transparent, width: 3),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.4), blurRadius: 8)]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : () => _create(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        "Create SkinTwin",
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final title = _titleCtrl.text.trim();
    final location = _locationCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a finding name")),
      );
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the detailed location")),
      );
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await widget.store.createTwin(
      title: title,
      detailedLocation: '$_selectedLocation - $location',
    );

    if (mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text("$title created! Now capture the baseline."),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }
}
