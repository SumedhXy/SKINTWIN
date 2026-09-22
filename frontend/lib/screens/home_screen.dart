import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/skin_visual_painter.dart';
import '../core/pressable_card.dart';
import '../core/skintwin_logo.dart';
import '../core/app_store.dart';
import '../core/providers/auth_provider.dart';
import '../core/widgets/authenticated_image.dart';
import 'skin_twins_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final store = context.watch<AppStore>();

    final fullName = auth.currentUser?['full_name'] as String? ??
        auth.currentUser?['name'] as String? ??
        store.profile?['name'] as String? ??
        '';
    final displayName = fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').first
        : 'there';

    final followUpCount = store.followUpDueCount;
    final totalTwins = store.twins.length;
    final totalCaptures = store.totalCaptures;

    final statusText = followUpCount > 0
        ? "$followUpCount Follow-up"
        : (totalTwins > 0 ? "Healthy" : "Getting Started");
    final statusColor = followUpCount > 0
        ? const Color(0xFFB45309)
        : const Color(0xFF047857);
    final statusBg = followUpCount > 0
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFECFDF5);
    final statusBorder = followUpCount > 0
        ? const Color(0xFFFDE68A)
        : const Color(0xFFA7F3D0);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const SkinTwinLogo(size: 38),
            const SizedBox(width: 12),
            Text(
              "SkinTwin",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3), width: 2),
              ),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.person, color: AppTheme.primaryBlue, size: 20),
              ),
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => store.refreshUserData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Greeting & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              "${_greeting()}, $displayName",
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                                letterSpacing: -0.6,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusText,
                                  style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalTwins == 0
                            ? "Keep track of your skin changes with calibrated precision."
                            : "Monitoring $totalTwins skin finding${totalTwins == 1 ? '' : 's'} with calibrated precision.",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Dark Luxury Hero Card
            PressableCard(
              onTap: () => Navigator.pushNamed(context, '/capture'),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: AppTheme.darkHeroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Glowing Ambient Blue Orb
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.center_focus_strong, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Guided Telemetry • Calibrated",
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Track a skin finding",
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Capture a new image or update an existing SkinTwin with standardized alignment.",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.pushNamed(context, '/capture'),
                                    icon: const Icon(Icons.photo_camera, size: 18),
                                    label: const Text("Start Capture"),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
                                  );
                                },
                                child: Text(
                                  "View SkinTwins",
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Overview Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "OVERVIEW",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("Live Local Vault", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3 Overview Cards Grid
            Row(
              children: [
                Expanded(
                  child: PressableCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
                      );
                    },
                    child: _buildOverviewCard(
                      title: "Active SkinTwins",
                      value: "$totalTwins",
                      subtitle: totalTwins == 0 ? "None registered" : "${store.activeCount} active",
                      icon: Icons.folder_shared_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressableCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
                      );
                    },
                    child: _buildOverviewCard(
                      title: "Total Captures",
                      value: "$totalCaptures",
                      subtitle: totalCaptures == 0 ? "No photos logged" : "Across all findings",
                      icon: Icons.photo_library_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PressableCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
                );
              },
              child: _buildAttentionCard(
                title: "Needs Attention",
                value: "$followUpCount",
                subtitle: followUpCount == 0 ? "All findings up to date" : "Routine check recommended",
                badgeText: followUpCount == 0 ? "All Clear" : "$followUpCount due",
              ),
            ),
            const SizedBox(height: 28),

            // Recent Activity Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Activity",
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: -0.4),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
                    );
                  },
                  child: Text("View All", style: GoogleFonts.inter(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Recent Activity Container
            if (store.twins.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.photo_camera_outlined, color: AppTheme.primaryBlue, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No activity recorded yet",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Capture your first skin finding to begin tracking longitudinal changes with calibrated consistency.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/capture'),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text("Capture First Finding"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _buildRealActivityTiles(context, store),
                ),
              ),
            const SizedBox(height: 24),

            // Privacy Banner
            PressableCard(
              onTap: () => Navigator.pushNamed(context, '/privacy'),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, const Color(0xFFEFF6FF).withValues(alpha: 0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.lock_outline, color: AppTheme.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your skin data stays private",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Your images and tracking information are encrypted in your local-first vault.",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRealActivityTiles(BuildContext context, AppStore store) {
    final tiles = <Widget>[];
    final twins = store.twins;

    for (int i = 0; i < twins.length && i < 5; i++) {
      final twin = twins[i];
      final captures = store.capturesFor(twin.publicId);
      final latestCapture = captures.isNotEmpty ? captures.first : null;
      final timeStr = latestCapture != null
          ? _formatRelativeTime(latestCapture.capturedAt)
          : _formatRelativeTime(twin.updatedAt);

      final badgeText = latestCapture != null
          ? (latestCapture.qualityScore != null
              ? "${(latestCapture.qualityScore! * 100).toInt()}% Quality"
              : (latestCapture.comparisonEligible ? "Calibrated" : "Logged"))
          : twin.status.replaceAll('_', ' ').toUpperCase();

      final badgeBg = (latestCapture?.comparisonEligible == true || twin.status == 'active')
          ? const Color(0xFFECFDF5)
          : const Color(0xFFEFF6FF);
      final badgeColor = (latestCapture?.comparisonEligible == true || twin.status == 'active')
          ? const Color(0xFF047857)
          : AppTheme.primaryBlue;

      if (i > 0) {
        tiles.add(const Divider(height: 1, color: AppTheme.borderColor));
      }

      tiles.add(
        ListTile(
          onTap: () {
            if (captures.length >= 2) {
              Navigator.pushNamed(context, '/compare', arguments: twin.publicId);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SkinTwinsScreen()),
              );
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: SizedBox(
            width: 46,
            height: 46,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: latestCapture != null
                  ? AuthenticatedImage(
                      captureId: latestCapture.id,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    )
                  : CustomPaint(
                      painter: SkinSpotPainter(
                        spotColor: const Color(0xFF8B4513),
                        label: twin.name,
                      ),
                    ),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  twin.name,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${twin.bodyLocation} • ${twin.captureCount} capture${twin.captureCount == 1 ? '' : 's'}",
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(badgeText, style: GoogleFonts.inter(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return tiles;
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildAttentionCard({
    required String title,
    required String value,
    required String subtitle,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.inter(color: const Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFB45309), letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }
}
