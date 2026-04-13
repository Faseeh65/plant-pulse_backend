import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Singleton service that wraps flutter_local_notifications.
///
/// Call [NotificationService.instance.init()] once in main() before
/// runApp, then use [scheduleReminder] / [cancelReminder] freely.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Android notification channel ─────────────────────────────────────────
  static const _channelId   = 'plantpulse_reminders';
  static const _channelName = 'Spray Reminders';
  static const _channelDesc = 'Plant treatment alerts from PlantPulse';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF6CFB7B),
    enableVibration: true,
    playSound: true,
    styleInformation: BigTextStyleInformation(''),
  );

  static const NotificationDetails _notifDetails =
      NotificationDetails(android: _androidDetails);

  // ── init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the notification channel on Android 8+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );

    _initialized = true;
    debugPrint('✅ NotificationService initialized.');
  }

  // ── permission request ────────────────────────────────────────────────────

  /// Requests Android 13+ POST_NOTIFICATIONS permission.
  /// Returns true if granted. Safe to call multiple times.
  Future<bool> requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  // ── schedule ──────────────────────────────────────────────────────────────

  /// Schedules an exact-time OS notification for a spray reminder.
  ///
  /// [notifId]       – integer ID (use reminder hashCode or index).
  /// [title]         – notification title.
  /// [body]          – notification body text.
  /// [scheduledTime] – UTC DateTime when to fire. Must be in the future.
  Future<bool> scheduleReminder({
    required int notifId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!await requestPermission()) {
      debugPrint('⚠️ Notification permission denied.');
      return false;
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('⚠️ scheduledTime is in the past — skipping.');
      return false;
    }

    // Convert to TZDateTime in device's local timezone
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      tzTime,
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('✅ Reminder #$notifId scheduled for $tzTime');
    return true;
  }

  // ── cancel ────────────────────────────────────────────────────────────────

  /// Cancels a previously scheduled notification by its ID.
  Future<void> cancelReminder(int notifId) async {
    await _plugin.cancel(notifId);
    debugPrint('🗑️ Reminder #$notifId cancelled.');
  }

  /// Cancels every pending notification (e.g., on logout).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('🗑️ All reminders cancelled.');
  }

  // ── tap handler ───────────────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    // Navigate to reminder screen when tapped — handled by MaterialApp key
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }
}
