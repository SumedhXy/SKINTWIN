import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_store.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/account_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final account = context.read<AccountProvider>();
      if (account.profile == null) account.loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Account ──────────────────────────────────────────────────────────
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _navTile(
                  icon: Icons.person_outline,
                  title: 'Edit Display Name',
                  subtitle: account.profile?.fullName ?? 'Not set',
                  onTap: () => _showEditNameSheet(context),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _navTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => _showChangePasswordSheet(context),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _navTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Clear session from this device',
                  iconColor: const Color(0xFFDC2626),
                  onTap: () => _signOut(context),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _navTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  subtitle: 'Permanently remove your account and data',
                  iconColor: const Color(0xFFDC2626),
                  titleColor: const Color(0xFFDC2626),
                  onTap: () => _showDeleteAccountFlow(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Privacy ──────────────────────────────────────────────────────────
          _sectionLabel('PRIVACY & DATA'),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
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

          // ── About ────────────────────────────────────────────────────────────
          _sectionLabel('ABOUT'),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _infoTile(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  value: '1.0.0',
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _infoTile(
                  icon: Icons.api_outlined,
                  title: 'API Version',
                  value: 'v1 — SkinTwin Backend',
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                _infoTile(
                  icon: Icons.shield_outlined,
                  title: 'Session Type',
                  value: 'Stateless JWT (30-min expiry)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Known limitations notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sign out clears your token from this device only. '
                    'Tokens expire automatically after 30 minutes. '
                    'See Privacy Settings for data management options.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Edit Name Sheet ────────────────────────────────────────────────────────

  void _showEditNameSheet(BuildContext context) {
    final account = context.read<AccountProvider>();
    final controller = TextEditingController(text: account.profile?.fullName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetWrapper(
        title: 'Edit Display Name',
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Your name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
                style: GoogleFonts.inter(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Consumer<AccountProvider>(
                builder: (ctx, acc, _) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: acc.isBusy
                      ? null
                      : () async {
                          final success = await ctx.read<AccountProvider>().updateName(controller.text);
                          if (success && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Display name updated.')),
                            );
                          } else if (ctx.mounted && acc.errorMessage != null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(acc.errorMessage!)),
                            );
                          }
                        },
                  child: acc.isBusy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Change Password Sheet ──────────────────────────────────────────────────

  void _showChangePasswordSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showCurrentPw = false;
    bool showNewPw = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _BottomSheetWrapper(
          title: 'Change Password',
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passwordField(
                  controller: currentCtrl,
                  label: 'Current password',
                  obscure: !showCurrentPw,
                  toggle: () => setModalState(() => showCurrentPw = !showCurrentPw),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: newCtrl,
                  label: 'New password (min 8 chars)',
                  obscure: !showNewPw,
                  toggle: () => setModalState(() => showNewPw = !showNewPw),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: confirmCtrl,
                  label: 'Confirm new password',
                  obscure: !showNewPw,
                  toggle: () => setModalState(() => showNewPw = !showNewPw),
                ),
                const SizedBox(height: 16),
                Consumer<AccountProvider>(
                  builder: (ctx2, acc, _) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: acc.isBusy
                        ? null
                        : () async {
                            if (newCtrl.text != confirmCtrl.text) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(content: Text('New passwords do not match.')),
                              );
                              return;
                            }
                            final success = await ctx2.read<AccountProvider>().changePassword(
                                  currentPassword: currentCtrl.text,
                                  newPassword: newCtrl.text,
                                );
                            if (success && ctx2.mounted) {
                              Navigator.pop(ctx2);
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(content: Text('Password changed successfully.')),
                              );
                            } else if (ctx2.mounted && acc.errorMessage != null) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                SnackBar(content: Text(acc.errorMessage!)),
                              );
                            }
                          },
                    child: acc.isBusy
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: toggle,
        ),
      ),
      style: GoogleFonts.inter(fontSize: 15),
    );
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign Out?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This will clear your session token from this device. '
          'You will need to sign in again.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppStore>().clearSessionData();
      await context.read<AuthProvider>().logout();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  // ─── Delete Account Flow ─────────────────────────────────────────────────────

  void _showDeleteAccountFlow(BuildContext context) {
    // Step 1: Explain consequences
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...[
              'Your account and profile',
              'All SkinTwins and their captures',
              'All comparisons and AI explanations',
              'All private image files',
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item, style: GoogleFonts.inter(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This action cannot be undone. '
                'Note: your session token remains valid until it expires '
                '(up to 30 minutes) even after deletion.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteAccountConfirmation(context);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _BottomSheetWrapper(
          title: 'Confirm Deletion',
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your password to permanently delete your account.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Your password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setModalState(() => obscure = !obscure),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 15),
                ),
                const SizedBox(height: 16),
                Consumer<AccountProvider>(
                  builder: (ctx2, acc, _) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: acc.state == AccountState.deletingAccount
                        ? null
                        : () async {
                            final success = await ctx2.read<AccountProvider>().deleteAccount(passwordCtrl.text);
                            if (success && ctx2.mounted) {
                              // Clear session and navigate to login
                              await ctx2.read<AuthProvider>().logout();
                              if (ctx2.mounted) {
                                Navigator.of(ctx2).pushNamedAndRemoveUntil('/', (route) => false);
                              }
                            } else if (ctx2.mounted && acc.errorMessage != null) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                SnackBar(content: Text(acc.errorMessage!)),
                              );
                            }
                          },
                    child: acc.state == AccountState.deletingAccount
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Delete My Account',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderColor),
    );
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
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryBlue),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor ?? AppTheme.textDark,
        ),
      ),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  Widget _infoTile({required IconData icon, required String title, required String value}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
    );
  }
}

// ─── Reusable Bottom Sheet Wrapper ─────────────────────────────────────────────

class _BottomSheetWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
