import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_store.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/account_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load the real profile from the backend on first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final account = context.watch<AccountProvider>();
    final profile = account.profile;

    final displayName = profile?.displayName ?? 'Loading…';
    final email = profile?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text('Settings', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      account.isLoading
                          ? Container(
                              height: 16,
                              width: 120,
                              decoration: BoxDecoration(
                                color: AppTheme.borderColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )
                          : Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              _buildStatCard('SkinTwins', '${store.twins.length}', Icons.bubble_chart),
              const SizedBox(width: 12),
              _buildStatCard('Captures', '${store.totalCaptures}', Icons.camera_alt),
              const SizedBox(width: 12),
              _buildStatCard(
                'Follow-ups',
                '${store.followUpDueCount}',
                Icons.warning_amber_rounded,
                color: store.followUpDueCount > 0 ? const Color(0xFFB45309) : AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Privacy notice — accurate, not a security claim
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your SkinTwin images are private by default.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only you can access your captures and comparisons. '
                        'Review Privacy Settings to understand how your data is handled.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Links
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _navTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account Settings',
                  subtitle: 'Edit name, change password, delete account',
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _navTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Settings',
                  subtitle: 'Data controls, export, and deletion',
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notifications section (UI-only reminder badge, no notification API yet)
          _sectionLabel('NOTIFICATIONS'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppTheme.primaryBlue),
              title: Text(
                'Capture Reminders',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Coming in a future update',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 32),

          // Sign Out — properly calls AuthProvider.logout() to clear the JWT token
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout, size: 18),
            label: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Text(
            'Signing out clears your session token from this device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This will clear your session from this device. '
          'You will need to sign in again to access your SkinTwins.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Properly clears the JWT token via AuthService.logout()
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color ?? AppTheme.primaryBlue),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
