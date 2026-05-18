import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

/// Schedules and cancels local notifications for reminders. Each reminder's
/// database id doubles as its notification id. Every method is best-effort
/// and never throws — a notification problem must never block saving.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'metis_reminders',
      'Reminders',
      channelDescription: 'Scheduled reminder alerts',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Fall back to whatever timezone defaults to.
    }
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Best-effort scheduling. Tries an exact alarm, falls back to an inexact
  /// one if exact alarms are not permitted, and never throws.
  static Future<void> schedule(Reminder r) async {
    if (!_ready || r.id == null) return;
    await cancel(r.id!);
    if (!r.isPending || r.dueAt.isBefore(DateTime.now())) return;

    final when = tz.TZDateTime.from(r.dueAt, tz.local);
    final body = r.notes.isEmpty ? 'Reminder from Metis' : r.notes;
    try {
      await _plugin.zonedSchedule(
        r.id!, r.title, body, when, _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          r.id!, r.title, body, when, _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Give up silently — the reminder itself is still saved.
      }
    }
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
