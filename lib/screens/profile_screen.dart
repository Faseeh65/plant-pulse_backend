import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/locale_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

// ─── constants ───────────────────────────────────────────────────────────────
const _green    = Color(0xFF6CFB7B);
const _green2   = Color(0xFF2ECC71);
const _textHint = Color(0xFF5A7A56);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotifPref();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── data loading ─────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Initial load from Auth metadata (fast)
    setState(() {
      _email             = user.email ?? '';
      _nameCtrl.text     = user.userMetadata?['full_name']   ?? '';
      _phoneCtrl.text    = user.userMetadata?['phone']        ?? '';
      _locationCtrl.text = user.userMetadata?['location']     ?? '';
      _avatarUrl         = user.userMetadata?['avatar_url']   ?? '';
    });

    // 2. Definitive load from Backend (reliable cloud sync)
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
      // 1. Update Auth metadata (for local display next launch)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name' : _nameCtrl.text.trim(),
            'phone'     : _phoneCtrl.text.trim(),
            'location'  : _locationCtrl.text.trim(),
          },
        ),
      );

      // 2. Sync to Backend Database (truth source)
      final success = await _apiService.updateUserProfile(
        userId:   user.id,
        fullName: _nameCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        _showSnack('Profile saved and synced successfully ✓', isSuccess: true);
      } else {
        _showSnack('Saved locally, but Cloud sync failed (Offline).');
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
    _showSnack(allow ? 'Notifications enabled' : 'Notifications muted',
        isSuccess: allow);
  }

  // ── log out ───────────────────────────────────────────────────────────
  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out', style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), fontWeight: FontWeight.w900)),
        content: Text(
          'Are you sure you want to log out?\nکیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟',
          style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  // ── snack helper ─────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontWeight: FontWeight.w900)),
      backgroundColor: isSuccess ? _green2 : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final bool isUrdu = locale.languageCode == 'ur';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_showNotifMenu) setState(() => _showNotifMenu = false);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF2E4D2E), // Deep Forest Green
                          Color(0xFF1A1A1A), // Dark Background
                        ],
                        stops: [0.0, 0.8],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // avatar
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [_green, _green2],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundColor: Theme.of(context).cardColor,
                                    backgroundImage: _avatarFile != null
                                        ? FileImage(_avatarFile!)
                                        : (_avatarUrl.isNotEmpty
                                            ? NetworkImage(_avatarUrl) as ImageProvider
                                            : null),
                                    child: (_avatarFile == null && _avatarUrl.isEmpty)
                                        ? Icon(Icons.person, color: _green, size: 46)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit, color: Colors.black, size: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _nameCtrl.text.isEmpty ? 'Your Name' : _nameCtrl.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Section: Edit Profile ─────────────────────
                        _sectionLabel('Edit Profile', 'پروفائل ترمیم'),
                        const SizedBox(height: 12),
                        _profileCard([
                          // Name
                          _editableField(
                            controller: _nameCtrl,
                            label: 'Full Name',
                            labelUrdu: 'پورا نام',
                            icon: Icons.person_outline,
                            hint: 'Enter your name',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Name required' : null,
                          ),
                          _divider(),
                          // Email (read-only)
                          _readonlyField(
                            label: 'Email Account',
                            labelUrdu: 'ای میل',
                            value: _email.isEmpty ? 'Not set' : _email,
                            icon: Icons.email_outlined,
                          ),
                          _divider(),
                          // Phone
                          _editableField(
                            controller: _phoneCtrl,
                            label: 'Mobile Number',
                            labelUrdu: 'موبائل نمبر',
                            icon: Icons.phone_outlined,
                            hint: '+92 3XX XXXXXXX',
                            keyboardType: TextInputType.phone,
                          ),
                          _divider(),
                          // Location
                          _editableField(
                            controller: _locationCtrl,
                            label: 'Location',
                            labelUrdu: 'مقام',
                            icon: Icons.location_on_outlined,
                            hint: 'City, Province',
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ── Save Button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_green, _green2],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x442ECC71),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _isSaving ? null : _saveProfile,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Save Changes  •  تبدیلیاں محفوظ کریں',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Section: Settings ─────────────────────────
                        _sectionLabel('Settings', 'ترتیبات'),
                        const SizedBox(height: 12),
                        _profileCard([
                          // Theme Toggle
                          _settingsTile(
                            icon: context.watch<ThemeProvider>().isDarkMode 
                                ? Icons.dark_mode_outlined 
                                : Icons.light_mode_outlined,
                            label: 'Theme',
                            labelUrdu: 'تھیم',
                            trailing: _themeToggle(context.watch<ThemeProvider>()),
                          ),
                          _divider(),
                          // Language
                          _settingsTile(
                            icon: Icons.language_outlined,
                            label: 'Language',
                            labelUrdu: 'زبان',
                            trailing: _languageToggle(isUrdu, locale),
                          ),
                          _divider(),
                          // Notification (with dropdown)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _settingsTile(
                                icon: Icons.notifications_none_outlined,
                                label: 'Notifications',
                                labelUrdu: 'اطلاعات',
                                trailing: GestureDetector(
                                  onTap: () => setState(() => _showNotifMenu = !_showNotifMenu),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _notifAllow
                                          ? Theme.of(context).primaryColor.withOpacity(0.15)
                                          : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _notifAllow ? Theme.of(context).primaryColor.withOpacity(0.4) : Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _notifAllow ? 'Allow' : 'Mute',
                                          style: TextStyle(
                                            color: _notifAllow ? Theme.of(context).primaryColor : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.54),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _showNotifMenu
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: _notifAllow ? Theme.of(context).primaryColor : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.38),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Dropdown menu
                              if (_showNotifMenu)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                    ),
                                    child: Column(
                                      children: [
                                        _notifOption('Allow', Icons.notifications_active_outlined, true),
                                        Divider(height: 1),
                                        _notifOption('Mute', Icons.notifications_off_outlined, false),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // ── Section: Account ──────────────────────────
                        _sectionLabel('Account', 'اکاؤنٹ'),
                        const SizedBox(height: 12),
                        _profileCard([
                          _navTile(
                            icon: Icons.person_outline,
                            label: 'My Profile',
                            labelUrdu: 'میری پروفائل',
                            onTap: () {
                              // Already on profile — scroll to top
                              _showSnack('You are viewing your profile', isSuccess: true);
                            },
                          ),
                          _divider(),
                          _navTile(
                            icon: Icons.settings_outlined,
                            label: 'App Settings',
                            labelUrdu: 'ایپ کی ترتیبات',
                            onTap: () => _showSnack('Advanced settings — جلد آ رہا ہے', isSuccess: true),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ── Log Out ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent, width: 1.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: Icon(Icons.logout_rounded, size: 20),
                            label: Text(
                              'Log Out  •  لاگ آؤٹ',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            onPressed: _logOut,
                          ),
                        ),

                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'PlantPulse v1.0.0',
                            style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.18), fontSize: 12),
                          ),
                        ),
                      ],
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

  // ─── builders ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String en, String ur) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          '$en  •  $ur',
          style: TextStyle(
            color: _green,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _profileCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(height: 1, color: Theme.of(context).dividerColor, indent: 16, endIndent: 16);

  Widget _editableField({
    required TextEditingController controller,
    required String label,
    required String labelUrdu,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _textHint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), fontSize: 14),
              decoration: InputDecoration(
                labelText: '$label • $labelUrdu',
                labelStyle: TextStyle(color: _textHint, fontSize: 12),
                hintText: hint,
                hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.2), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _green.withOpacity(0.5), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readonlyField({
    required String label,
    required String labelUrdu,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: _textHint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label • $labelUrdu',
                    style: TextStyle(color: _textHint, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.7), fontSize: 14)),
              ],
            ),
          ),
          Icon(Icons.lock_outline, color: _textHint, size: 14),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String labelUrdu,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: _textHint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$label • $labelUrdu',
                style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), fontSize: 14)),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required String labelUrdu,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: _textHint, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$label • $labelUrdu',
                  style: TextStyle(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), fontSize: 14)),
            ),
            Icon(Icons.chevron_right, color: _textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _notifOption(String label, IconData icon, bool value) {
    final active = _notifAllow == value;
    return InkWell(
      onTap: () => _setNotif(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? _green : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.54)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  color: active ? _green : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.7),
                  fontWeight: active ? FontWeight.w900 : FontWeight.normal,
                  fontSize: 14,
                )),
            const Spacer(),
            if (active)
              Icon(Icons.check_circle, color: _green, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _languageToggle(bool isUrdu, Locale locale) {
    return GestureDetector(
      onTap: () {
        final lp = context.read<LocaleProvider>();
        lp.setLocale(isUrdu ? const Locale('en') : const Locale('ur'));
        _showSnack(
          isUrdu ? 'Language set to English' : 'زبان اردو پر سیٹ ہو گئی',
          isSuccess: true,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        width: 80,
        decoration: BoxDecoration(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langChip('EN', !isUrdu),
            const SizedBox(width: 4),
            _langChip('اردو', isUrdu),
          ],
        ),
      ),
    );
  }

  Widget _langChip(String label, bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5) ?? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.54),
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.normal,
          ),
        ),
      );

  Widget _themeToggle(ThemeProvider tp) {
    bool isDark = tp.isDarkMode;
    return GestureDetector(
      onTap: () {
        tp.toggleTheme();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        width: 80,
        decoration: BoxDecoration(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: !isDark ? _green : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.light_mode,
                  size: 16,
                  color: !isDark ? Colors.black : Colors.grey),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? _green : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.dark_mode,
                  size: 16,
                  color: isDark ? Colors.black : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
