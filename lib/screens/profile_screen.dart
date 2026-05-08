import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

// Constants removed to use theme-aware colors via getters in State class.

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  // ── theme aware colors ──────────────────────────────────────────────
  Color get _green => Theme.of(context).primaryColor;
  Color get _bg    => Theme.of(context).scaffoldBackgroundColor;
  Color get _card  => Theme.of(context).cardColor;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textMuted   => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
  Color get _textHint    => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
  bool  get _isDark      => Theme.of(context).brightness == Brightness.dark;

  // ── controllers ─────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final _apiService   = ApiService();

  // ── state ────────────────────────────────────────────────────────────
  bool   _isSaving        = false;
  bool   _notifAllow      = true;
  bool   _showNotifMenu   = false;
  File?  _avatarFile;
  String _email           = '';
  String _avatarUrl       = '';

  // ── animations ──────────────────────────────────────────────────────
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadProfile();
    _loadNotifPref();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── data loading ─────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _email             = user.email ?? '';
      _nameCtrl.text     = user.userMetadata?['full_name']   ?? '';
      _phoneCtrl.text    = user.userMetadata?['phone']        ?? '';
      _locationCtrl.text = user.userMetadata?['location']     ?? '';
      _avatarUrl         = user.userMetadata?['avatar_url']   ?? '';
    });

    final cloudProfile = await _apiService.fetchUserProfile(user.id);
    if (cloudProfile != null && mounted) {
      setState(() {
        _nameCtrl.text     = cloudProfile['full_name'] ?? _nameCtrl.text;
        _phoneCtrl.text    = cloudProfile['phone']     ?? _phoneCtrl.text;
        _locationCtrl.text = cloudProfile['location']  ?? _locationCtrl.text;
        if (cloudProfile['avatar_url'] != null) {
          _avatarUrl = cloudProfile['avatar_url'];
        }
      });
    }
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notifAllow = prefs.getBool('notif_allow') ?? true);
  }

  // ── avatar picker ─────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  // ── save profile ──────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name' : _nameCtrl.text.trim(),
            'phone'     : _phoneCtrl.text.trim(),
            'location'  : _locationCtrl.text.trim(),
          },
        ),
      );

      final success = await _apiService.updateUserProfile(
        userId:   user.id,
        fullName: _nameCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        _showSnack('Profile updated successfully ✓', isSuccess: true);
      } else {
        _showSnack('Saved locally, but cloud sync failed.');
      }
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── notification pref ────────────────────────────────────────────────
  Future<void> _setNotif(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_allow', allow);
    setState(() {
      _notifAllow    = allow;
      _showNotifMenu = false;
    });
    _showSnack(allow ? 'Notifications enabled' : 'Notifications muted', isSuccess: allow);
  }

  // ── log out ───────────────────────────────────────────────────────────
  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _textPrimary.withValues(alpha: 0.1)),
        ),
        title: Text('Log Out', style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.w900)),
        content: Text(
          'Are you sure you want to log out of your session?',
          style: GoogleFonts.poppins(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log Out', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 13)),
      backgroundColor: isSuccess ? _green : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_showNotifMenu) setState(() => _showNotifMenu = false);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('PERSONAL INFORMATION'),
                          const SizedBox(height: 16),
                          _buildProfileForm(),
                          const SizedBox(height: 24),
                          _buildSaveButton(),
                          const SizedBox(height: 48),
                          _sectionLabel('SYSTEM PREFERENCES'),
                          const SizedBox(height: 16),
                          _buildSettingsCard(),
                          const SizedBox(height: 48),
                          _buildLogoutButton(),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'PlantPulse v1.0.0-PRO',
                              style: GoogleFonts.poppins(
                                color: _textPrimary.withValues(alpha: 0.1),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: _bg,
      elevation: 0,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: _textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _textPrimary.withValues(alpha: 0.1)),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: _textPrimary, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Header Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _isDark ? Color(0xFF1B2B1B) : _green.withValues(alpha: 0.1),
                    _bg,
                  ],
                ),
              ),
            ),
            // Floating Circles for depth
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withValues(alpha: 0.03),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildAvatarStack(),
                  const SizedBox(height: 20),
                  Text(
                    _nameCtrl.text.isEmpty ? 'New User' : _nameCtrl.text.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: GoogleFonts.poppins(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarStack() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _green.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: _green.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: _card,
              backgroundImage: _avatarFile != null
                  ? FileImage(_avatarFile!)
                  : (_avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) as ImageProvider : null),
              child: (_avatarFile == null && _avatarUrl.isEmpty)
                  ? Icon(Icons.person_rounded, color: _green, size: 50)
                  : null,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
                border: Border.all(color: _bg, width: 3),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _textPrimary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildField(
            controller: _nameCtrl,
            label: 'FULL NAME',
            icon: Icons.person_outline_rounded,
            hint: 'Enter name',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          _divider(),
          _buildReadonlyField(
            label: 'EMAIL ADDRESS',
            value: _email.isEmpty ? 'Not set' : _email,
            icon: Icons.alternate_email_rounded,
          ),
          _divider(),
          _buildField(
            controller: _phoneCtrl,
            label: 'PHONE NUMBER',
            icon: Icons.phone_android_rounded,
            hint: '+92 XXX XXXXXXX',
            keyboardType: TextInputType.phone,
          ),
          _divider(),
          _buildField(
            controller: _locationCtrl,
            label: 'REGIONAL LOCATION',
            icon: Icons.map_outlined,
            hint: 'City, Province',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _textPrimary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.language_rounded,
            label: 'Application Language',
            trailing: _languageToggle(context.watch<LocaleProvider>()),
          ),
          _divider(),
          _settingsTile(
            icon: Icons.auto_awesome_rounded,
            label: 'Visual Theme',
            trailing: _themeToggle(context.watch<ThemeProvider>()),
          ),
          _divider(),
          _settingsTile(
            icon: Icons.notifications_active_outlined,
            label: 'Smart Notifications',
            trailing: _buildNotifToggle(),
          ),
          if (_showNotifMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _textPrimary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _textPrimary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    _notifOption('Instant Alerts', Icons.flash_on_rounded, true),
                    Divider(height: 1, color: _textPrimary.withValues(alpha: 0.1)),
                    _notifOption('Silent Mode', Icons.notifications_paused_rounded, false),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: _isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _isSaving ? null : _saveProfile,
        child: _isSaving
            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _isDark ? Colors.black : Colors.white, strokeWidth: 3))
            : Text('SAVE CHANGES', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.power_settings_new_rounded, size: 20),
        label: Text('TERMINATE SESSION', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0)),
        onPressed: _logOut,
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
        ),
      );

  Widget _divider() => Divider(height: 1, color: _textPrimary.withValues(alpha: 0.05), indent: 78, endIndent: 20);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _green.withValues(alpha: 0.1), width: 1),
            ),
            child: Icon(icon, color: _green, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: GoogleFonts.poppins(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                labelText: label,
                labelStyle: GoogleFonts.poppins(color: _green.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                hintText: hint,
                hintStyle: GoogleFonts.poppins(color: _textPrimary.withValues(alpha: 0.15), fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonlyField({required String label, required String value, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _textPrimary.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _textPrimary.withValues(alpha: 0.3), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: GoogleFonts.poppins(color: _textHint, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.poppins(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.verified_user_rounded, color: _green.withValues(alpha: 0.2), size: 16),
        ],
      ),
    );
  }

  Widget _settingsTile({required IconData icon, required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: _textPrimary.withValues(alpha: 0.6), size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: GoogleFonts.poppins(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          trailing,
        ],
      ),
    );
  }

  Widget _buildNotifToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showNotifMenu = !_showNotifMenu),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _notifAllow ? _green.withValues(alpha: 0.1) : _textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _notifAllow ? _green.withValues(alpha: 0.3) : _textPrimary.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _notifAllow ? 'ENABLED' : 'MUTED',
              style: GoogleFonts.poppins(color: _notifAllow ? _green : _textMuted, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            Icon(_showNotifMenu ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _notifAllow ? _green : _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _notifOption(String label, IconData icon, bool value) {
    final active = _notifAllow == value;
    return InkWell(
      onTap: () => _setNotif(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? _green : _textMuted),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.poppins(color: active ? _textPrimary : _textMuted, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
            const Spacer(),
            if (active) Icon(Icons.check_circle_rounded, color: _green, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _themeToggle(ThemeProvider tp) {
    bool isDark = tp.isDarkMode;
    return GestureDetector(
      onTap: () => tp.toggleTheme(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _textPrimary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _toggleChip(Icons.light_mode_rounded, !isDark),
            _toggleChip(Icons.dark_mode_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _toggleChip(IconData icon, bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: active ? _green : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: active ? (_isDark ? Colors.black : Colors.white) : _textPrimary.withValues(alpha: 0.2)),
      );

  Widget _languageToggle(LocaleProvider lp) {
    bool isUrdu = lp.locale.languageCode == 'ur';
    return GestureDetector(
      onTap: () => lp.setLocale(isUrdu ? const Locale('en') : const Locale('ur')),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _textPrimary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _textToggleChip('EN', !isUrdu),
            _textToggleChip('UR', isUrdu),
          ],
        ),
      ),
    );
  }

  Widget _textToggleChip(String text, bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: active ? _green : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: active ? (_isDark ? Colors.black : Colors.white) : _textPrimary.withValues(alpha: 0.4))),
      );
}
