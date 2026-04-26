import 'dart:typed_data';
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
  static const _channelId   = 'plantpulse_reminders_v3';
  static const _channelName = 'Spray Alerts';
  static const _channelDesc = 'Urgent plant treatment alerts from PlantPulse';

  static final AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF6CFB7B),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    enableLights: true,
    ledColor: Color(0xFF6CFB7B),
    ledOnMs: 1000,
    ledOffMs: 500,
    playSound: true,
    audioAttributesUsage: AudioAttributesUsage.notification,
    styleInformation: BigTextStyleInformation(''),
  );

  static final NotificationDetails _notifDetails =
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
            importance: Importance.max,
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

    if (scheduledTime.toUtc().isBefore(DateTime.now().toUtc())) {
      debugPrint('⚠️ scheduledTime is in the past — skipping.');
      return false;
    }

    // Use UTC location for absolute time scheduling to avoid tz.local initialization issues
    final tzTime = tz.TZDateTime.from(scheduledTime.toUtc(), tz.getLocation('UTC'));

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
