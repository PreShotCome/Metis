import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

/// Schedules and cancels local notifications for reminders. Each reminder's
/// database id doubles as its notification id.
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
  }

  static Future<void> schedule(Reminder r) async {
    if (!_ready || r.id == null) return;
    await cancel(r.id!);
    if (!r.isPending || r.dueAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      r.id!,
      r.title,
      r.notes.isEmpty ? 'Reminder from Metis' : r.notes,
      tz.TZDateTime.from(r.dueAt, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id);
  }
}
