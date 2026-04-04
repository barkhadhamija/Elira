import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../utils/session_manager.dart';
import '../../utils/biometric_service.dart';
import '../../services/auth_service.dart';
import '../../providers/evidence_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _gpsConsent = false;
  bool _stealthMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final biometricEnabled = await SessionManager.getBiometricEnabled();
    final biometricAvailable = await BiometricService.isAvailable();
    final gpsConsent = await SessionManager.getGpsConsent();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = biometricEnabled;
      _biometricAvailable = biometricAvailable;
      _gpsConsent = gpsConsent;
      _loading = false;
    });
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColours.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColours.textDark,
          ),
        ),
        content: Text(
          'You will need to log in again to access your testimonies.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColours.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColours.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                color: AppColours.dangerRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SessionManager.clearSession();
      await AuthService.signOut();
      ref.read(appProvider.notifier).setLoggedIn(false);
      ref.read(appProvider.notifier).setPinVerified(false);
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColours.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear all data?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColours.textDark,
          ),
        ),
        content: Text(
          'This will reset your session, PIN and onboarding. For testing only — this cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColours.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColours.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear all',
              style: GoogleFonts.inter(
                color: AppColours.dangerRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await AuthService.signOut();
      ref.invalidate(evidenceProvider);
      ref.read(appProvider.notifier).setLoggedIn(false);
      ref.read(appProvider.notifier).setPinVerified(false);
      ref.read(appProvider.notifier).setGpsConsent(false);
      ref.read(appProvider.notifier).setContacts([]);
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.account_balance_outlined,
                      color: AppColours.brandBlue, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'ELIRA',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColours.brandBlue,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColours.brandBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        // ── Title ──────────────────────────────────────
                        _sectionBadge('SYSTEM CONFIGURATION'),
                        const SizedBox(height: 8),
                        Text(
                          'Settings',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColours.textDark,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Security ───────────────────────────────────
                        _sectionHeader('SECURITY'),
                        const SizedBox(height: 8),
                        _settingsCard([
                          _settingRow(
                            title: 'Biometric Authentication',
                            subtitle: 'Secure your records with FaceID or TouchID',
                            trailing: Switch(
                              value: _biometricEnabled,
                              onChanged: _biometricAvailable
                                  ? (val) async {
                                      await SessionManager
                                          .saveBiometricEnabled(val);
                                      if (mounted) {
                                        setState(
                                            () => _biometricEnabled = val);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          _divider(),
                          _settingRowArrow(
                            title: 'Two-Factor Auth',
                            subtitle:
                                'Extra verification layer for withdrawals',
                            onTap: () {},
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // ── Privacy ────────────────────────────────────
                        _sectionHeader('PRIVACY'),
                        const SizedBox(height: 8),
                        _settingsCard([
                          _settingRow(
                            title: 'GPS Consent',
                            subtitle:
                                'Include location metadata in forensic records',
                            trailing: Switch(
                              value: _gpsConsent,
                              onChanged: (val) async {
                                await SessionManager.setGpsConsent(val);
                                ref
                                    .read(appProvider.notifier)
                                    .setGpsConsent(val);
                                if (mounted) {
                                  setState(() => _gpsConsent = val);
                                }
                              },
                            ),
                          ),
                          _divider(),
                          _settingRow(
                            title: 'Stealth Mode',
                            subtitle: 'Hide ELIRA icon and notifications',
                            trailing: Switch(
                              value: _stealthMode,
                              onChanged: (val) =>
                                  setState(() => _stealthMode = val),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // ── Account ────────────────────────────────────
                        _sectionHeader('ACCOUNT'),
                        const SizedBox(height: 8),
                        _settingsCard([
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBBD0FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Aarav Sharma',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColours.textDark,
                                        ),
                                      ),
                                      Text(
                                        'Chief Auditor • ID-8829',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColours.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    'Edit',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColours.brandBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _divider(),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: const Icon(Icons.logout_rounded,
                                color: AppColours.dangerRed, size: 20),
                            title: Text(
                              'Sign Out',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColours.dangerRed,
                              ),
                            ),
                            onTap: _confirmSignOut,
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // ── Developer / Advanced ───────────────────────
                        _sectionHeader('DEVELOPER/ADVANCED'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColours.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColours.divider),
                          ),
                          child: Text(
                            'v4.2.8-STABLE | BUILD.881',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColours.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColours.dangerRed.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _confirmClearAll,
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline,
                                        color: AppColours.dangerRed, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Clear All Data',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColours.dangerRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Warning: This action is irreversible and will purge all local forensic records and cryptographic keys.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColours.dangerRed.withOpacity(0.7),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final tabs = [
      (Icons.home_outlined, 'HOME'),
      (Icons.folder_outlined, 'TESTIMONIES'),
      (Icons.settings_outlined, 'SETTINGS'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final (icon, label) = entry.value;
              final isActive = i == 2; // Settings is active
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == 0) context.go('/home');
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isActive
                            ? AppColours.brandBlue
                            : AppColours.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive
                              ? AppColours.brandBlue
                              : AppColours.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _sectionBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColours.accentLavenderSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColours.brandBlue,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColours.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          Icon(Icons.chevron_right, color: AppColours.textMuted, size: 16),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColours.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingRow({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColours.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColours.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _settingRowArrow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColours.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColours.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColours.divider,
    );
  }
}
