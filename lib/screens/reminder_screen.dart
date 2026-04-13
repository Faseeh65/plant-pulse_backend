import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

// ─── theme tokens ─────────────────────────────────────────────────────────────
const _bg     = Color(0xFF0A1108);
const _card   = Color(0xFF152213);
const _border = Color(0xFF1E3A1A);
const _green  = Color(0xFF6CFB7B);
const _green2 = Color(0xFF2ECC71);
const _amber  = Color(0xFFFFB300);
const _red    = Color(0xFFFF5252);

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late Future<List<SprayReminder>> _future;
  final Set<String> _completing = {};   // IDs currently being "done"

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
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
  Future<void> _showAddDialog() async {
    final plantCtrl     = TextEditingController();
    final diseaseCtrl   = TextEditingController();
    final treatmentCtrl = TextEditingController();
    DateTime? picked;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          return Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.add_alarm_rounded,
                            color: _green, size: 22),
                        const SizedBox(width: 10),
                        const Text('New Reminder  •  نیا یاد دہانی',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const Spacer(),
                        GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 20)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _dlgField(plantCtrl, 'Plant Name  •  پودے کا نام',
                        Icons.eco_outlined),
                    const SizedBox(height: 12),
                    _dlgField(diseaseCtrl, 'Disease  •  بیماری',
                        Icons.coronavirus_outlined),
                    const SizedBox(height: 12),
                    _dlgField(treatmentCtrl, 'Treatment  •  علاج',
                        Icons.medical_services_outlined),
                    const SizedBox(height: 16),
                    // Date + time picker
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate:
                              DateTime.now().add(const Duration(hours: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: _green,
                                surface: _card,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: _green,
                                surface: _card,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (time == null) return;
                        setDlg(() => picked = DateTime(date.year,
                            date.month, date.day, time.hour, time.minute));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: _green, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              picked == null
                                  ? 'Select date & time  •  وقت منتخب کریں'
                                  : _fmt(picked!),
                              style: TextStyle(
                                color: picked == null
                                    ? Colors.white38
                                    : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (plantCtrl.text.isEmpty ||
                              diseaseCtrl.text.isEmpty ||
                              treatmentCtrl.text.isEmpty ||
                              picked == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all fields.'),
                                backgroundColor: _red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          await _createReminder(
                            plantCtrl.text.trim(),
                            diseaseCtrl.text.trim(),
                            treatmentCtrl.text.trim(),
                            picked!,
                          );
                        },
                        child: const Text(
                          'Schedule Reminder  •  یاد دہانی طے کریں',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
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
        scheduledTime: time.toUtc(),
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
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: isSuccess ? _green2 : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _dlgField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _green, size: 18),
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Spray Reminders  •  اسپرے کی یاد دہانی',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _green),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add Reminder',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddDialog,
      ),
      body: FutureBuilder<List<SprayReminder>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
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
      backgroundColor: _card,
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
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
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
                  child: const Icon(Icons.eco_rounded, color: _green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.plantName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(r.diseaseName,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
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
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),

            // Row 2: treatment + scheduled time
            Row(
              children: [
                const Icon(Icons.medical_services_outlined,
                    color: _amber, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.treatmentType,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
                const Icon(Icons.schedule_rounded,
                    color: Colors.white24, size: 14),
                const SizedBox(width: 4),
                Text(_fmt(r.scheduledTime.toLocal()),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),

            const SizedBox(height: 14),

            // Mark as Done button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: isCompleting
                  ? const Center(
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
                        side: const BorderSide(color: _green, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'Mark as Done  •  مکمل',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
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
                child: const Icon(Icons.notifications_none_rounded,
                    color: _green, size: 64),
              ),
              const SizedBox(height: 20),
              const Text('No upcoming reminders',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Tap ＋ Add Reminder to schedule\nyour next spray treatment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 14),
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
              const Icon(Icons.cloud_off_outlined,
                  color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text('Could not load reminders',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                error.contains('503')
                    ? 'Database Offline: Please ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are added to your Railway Variables.'
                    : 'Check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
}
