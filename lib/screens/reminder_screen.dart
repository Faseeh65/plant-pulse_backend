import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/string_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class ReminderScreen extends StatefulWidget {
  final String? initialPlant;
  final String? initialDisease;
  final String? initialTreatment;

  const ReminderScreen({
    super.key,
    this.initialPlant,
    this.initialDisease,
    this.initialTreatment,
  });

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late Future<List<SprayReminder>> _future;
  final Set<String> _completing = {}; // IDs currently being "done"

  // Use Theme primary as default
  Color get _primary => Theme.of(context).primaryColor;
  Color get _green2 => const Color(0xFF2ECC71);
  Color get _amber => const Color(0xFFFFB300);
  Color get _red => const Color(0xFFFF5252);
  Color get _green => Theme.of(context).primaryColor;

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    
    // If opened with initial values, show add dialog automatically
    if (widget.initialPlant != null || widget.initialDisease != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddDialog(
          plant: widget.initialPlant,
          disease: widget.initialDisease,
          treatment: widget.initialTreatment,
        );
      });
    }
  }

  void _load() => setState(() {
        _future = ApiService().fetchActiveReminders(_userId);
      });

  // ── mark as done ────────────────────────────────────────────────────────────
  Future<void> _markDone(SprayReminder reminder) async {
    setState(() => _completing.add(reminder.id));
    try {
      final ok =
          await ApiService().markReminderComplete(reminder.id, _userId);
      if (ok) {
        // Cancel OS notification
        await NotificationService.instance.cancelReminder(reminder.notifId);
        if (mounted) {
          _showSnack('Reminder marked as done ✓', isSuccess: true);
          _load();
        }
      } else {
        if (mounted) _showSnack('Failed to update. Try again.');
      }
    } finally {
      if (mounted) setState(() => _completing.remove(reminder.id));
    }
  }

  // ── add reminder dialog ─────────────────────────────────────────────────────
  Future<void> _showAddDialog({String? plant, String? disease, String? treatment}) async {
    final plantCtrl     = TextEditingController(text: plant ?? 'Rice');
    final diseaseCtrl   = TextEditingController(text: disease ?? '');
    final treatmentCtrl = TextEditingController(text: treatment ?? '');
    DateTime? picked;

    final plants = ['Rice'];
    final diseases = {
      'bacterial_leaf_blight': 'Bacterial Leaf Blight',
      'brown_spot': 'Brown Spot',
      'leaf_blast': 'Rice Blast',
      'leaf_scald': 'Leaf Scald',
      'narrow_brown_spot': 'Narrow Brown Spot',
    };

    // Extract treatments from causal rules or hardcode common ones
    final treatments = {
      'bacterial_leaf_blight': 'Copper-based bactericides (e.g., Copper Oxychloride)',
      'brown_spot': 'Mancozeb or Propiconazole',
      'leaf_blast': 'Tricyclazole or Isoprothiolane',
      'leaf_scald': 'Benomyl or Thiophanate-methyl',
      'narrow_brown_spot': 'Propiconazole or Hexaconazole',
    };

    String? selectedPlant = plant ?? 'Rice';
    String? selectedDiseaseKey;

    // Try to match incoming disease name to keys
    if (disease != null) {
      selectedDiseaseKey = diseases.entries
          .where((e) => e.value.toLowerCase() == disease.toLowerCase() || e.key.toLowerCase() == disease.toLowerCase())
          .map((e) => e.key)
          .firstOrNull;
      
      if (selectedDiseaseKey != null && treatment == null) {
        treatmentCtrl.text = treatments[selectedDiseaseKey] ?? '';
      }
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: StatefulBuilder(builder: (ctx, setDlg) {
            return Center(
              child: SingleChildScrollView(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add_alarm_rounded, color: _primary, size: 28),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Set Treatment Plan',
                                style: GoogleFonts.poppins(
                                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Schedule your next spray action',
                                style: TextStyle(
                                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _dlgDropdown(
                          label: 'Select Crop',
                          icon: Icons.eco_outlined,
                          value: selectedPlant,
                          items: plants.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (val) => setDlg(() => selectedPlant = val),
                        ),
                        const SizedBox(height: 16),
                        _dlgDropdown(
                          label: 'Detected Disease',
                          icon: Icons.coronavirus_outlined,
                          value: selectedDiseaseKey,
                          items: diseases.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (val) {
                            setDlg(() {
                              selectedDiseaseKey = val;
                              diseaseCtrl.text = diseases[val!]!;
                              treatmentCtrl.text = treatments[val] ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _dlgField(treatmentCtrl, 'Treatment Method', Icons.medical_services_outlined, readOnly: false),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now().add(const Duration(hours: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date == null) return;
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time == null) return;
                            setDlg(() => picked = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_outlined, color: _primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    picked == null ? 'When to schedule?' : _fmt(picked!),
                                    style: TextStyle(
                                      color: picked == null
                                          ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.38)
                                          : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                                      fontSize: 14,
                                      fontWeight: picked == null ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded, color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.2)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (picked == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a time.')));
                                return;
                              }
                              Navigator.pop(ctx);
                              await _createReminder(
                                selectedPlant ?? 'Rice',
                                diseaseCtrl.text.trim(),
                                treatmentCtrl.text.trim(),
                                picked!,
                              );
                            },
                            child: const Text(
                              'CONFIRM SCHEDULE',
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _createReminder(String plant, String disease,
      String treatment, DateTime time) async {
    final recordId = await ApiService().createReminder(
      userId:        _userId,
      plantName:     plant,
      diseaseName:   disease,
      treatmentType: treatment,
      scheduledTime: time,
    );

    if (recordId != null) {
      // Schedule OS notification
      await NotificationService.instance.scheduleReminder(
        notifId:       recordId.hashCode.abs() % 2147483647,
        title:         '🌿 Spray Reminder — $plant',
        body:          '$disease treatment due: $treatment',
        scheduledTime: time, // Pass local time for scheduling
      );
      if (mounted) {
        _showSnack('Reminder scheduled for ${_fmt(time)} ✓', isSuccess: true);
        _load();
      }
    } else {
      if (mounted) _showSnack('Failed to schedule. Check connection.');
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  String _fmt(DateTime dt) {
    final pad  = (int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  ${pad(dt.hour)}:${pad(dt.minute)}';
  }

  String _countdown(DateTime target) {
    final diff   = target.difference(DateTime.now());
    if (diff.isNegative) return 'Due now';
    if (diff.inDays > 0) return 'in ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'in ${diff.inMinutes}m';
  }

  Color _urgencyColor(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.inHours < 2) return _red;
    if (diff.inHours < 24) return _amber;
    return _green;
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontWeight: FontWeight.w900)),
      backgroundColor: isSuccess ? _green2 : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _dlgField(TextEditingController ctrl, String label, IconData icon, {bool readOnly = false}) =>
      TextField(
        controller: ctrl,
        readOnly: readOnly,
        style: TextStyle(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), 
          fontSize: 14,
          height: 1.3,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _green, size: 18),
          hintText: label,
          hintStyle: TextStyle(
            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.38), 
            fontSize: 13,
            height: 1.3,
          ),
          filled: true,
          fillColor: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _green, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );

  Widget _dlgDropdown({
    required String label,
    required IconData icon,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required ValueChanged<dynamic> onChanged,
  }) =>
      DropdownButtonFormField<dynamic>(
        value: value,
        items: items,
        onChanged: onChanged,
        style: TextStyle(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _green, size: 18),
          labelText: label,
          labelStyle: TextStyle(
            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.38),
            fontSize: 13,
          ),
          filled: true,
          fillColor: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _green, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        dropdownColor: Theme.of(context).cardColor,
        icon: Icon(Icons.arrow_drop_down, color: _green),
      );

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.7), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Spray Reminders',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black), 
              fontWeight: FontWeight.w900, 
              height: 1.3,
              fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _green),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.black,
        icon: Icon(Icons.add_alarm_rounded),
        label: Text('Add Reminder',
            style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: _showAddDialog,
      ),
      body: FutureBuilder<List<SprayReminder>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: _green, strokeWidth: 2.5));
          }
          if (snap.hasError) return _errorState(snap.error.toString());
          final reminders = snap.data ?? [];
          if (reminders.isEmpty) return _emptyState();
          return _buildList(reminders);
        },
      ),
    );
  }

  Widget _buildList(List<SprayReminder> reminders) {
    return RefreshIndicator(
      color: _green,
      backgroundColor: Theme.of(context).cardColor,
      onRefresh: () async => _load(),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: reminders.length,
        itemBuilder: (ctx, i) => _reminderCard(reminders[i]),
      ),
    );
  }

  Widget _reminderCard(SprayReminder r) {
    final urgency     = _urgencyColor(r.scheduledTime);
    final isCompleting = _completing.contains(r.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: urgency.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: plant icon + name + countdown chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.eco_rounded, color: _green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.plantName.toDisplayDisease(),
                          style: TextStyle(
                              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(r.diseaseName.toDisplayDisease(),
                          style: TextStyle(
                              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
                              fontSize: 12)),
                    ],
                  ),
                ),
                // Countdown pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: urgency.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: urgency.withOpacity(0.3)),
                  ),
                  child: Text(
                    _countdown(r.scheduledTime),
                    style: TextStyle(
                        color: urgency,
                        fontSize: 11,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 12),

            // Row 2: treatment + scheduled time
            Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    color: _amber, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.treatmentType,
                      style: TextStyle(
                          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.7), fontSize: 13)),
                ),
                Icon(Icons.schedule_rounded,
                    color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.24), size: 14),
                const SizedBox(width: 4),
                Text(_fmt(r.scheduledTime.toLocal()),
                    style: TextStyle(
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.38), fontSize: 11)),
              ],
            ),

            const SizedBox(height: 14),

            // Mark as Done button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: isCompleting
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: _green, strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: BorderSide(color: _green, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        'Mark as Done',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 13, height: 1.3),
                      ),
                      onPressed: () => _markDone(r),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── states ───────────────────────────────────────────────────────────────────

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.07), shape: BoxShape.circle),
                child: Icon(Icons.notifications_none_rounded,
                    color: _green, size: 64),
              ),
              const SizedBox(height: 20),
              Text('No upcoming reminders',
                  style: TextStyle(
                      color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Tap ＋ Add Reminder to schedule\nyour next spray treatment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.4), fontSize: 14),
              ),
            ],
          ),
        ),
      );

  Widget _errorState(String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.24), size: 64),
              const SizedBox(height: 16),
              Text('Could not load reminders',
                  style: TextStyle(
                      color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                error.contains('503')
                    ? 'Database Offline: Please ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are added to your Railway Variables.'
                    : 'Check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.45), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: Icon(Icons.refresh),
                label: Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
}
