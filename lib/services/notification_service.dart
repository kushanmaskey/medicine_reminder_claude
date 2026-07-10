import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'ringtone_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('FlutterTimezone timed out'),
      );
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) {},
    ).timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  static Future<bool> isPermissionGranted() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final settings = await ios.checkPermissions();
        return settings?.isEnabled ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final notifGranted = await android.requestNotificationsPermission() ?? true;
        final canExact = await android.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          await android.requestExactAlarmsPermission();
        }
        return notifGranted;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<AndroidScheduleMode> _resolveScheduleMode() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact;
    } catch (_) {
      return AndroidScheduleMode.inexact;
    }
  }

  // Channel ID for daily medication reminders. Use a versioned ID so that
  // previously cached channels (created with lower importance) are bypassed.
  static String _channelId(String? soundUri) {
    if (soundUri == null) return 'med_reminder_v2';
    return 'med_v2_${soundUri.hashCode.abs()}';
  }

  static AndroidNotificationSound? _androidSound(String? soundUri) {
    if (soundUri == null) return null;
    return UriAndroidNotificationSound(soundUri);
  }

  static Future<void> deleteOldChannel(String? oldSoundUri) async {
    if (oldSoundUri == null) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.deleteNotificationChannel(_channelId(oldSoundUri));
  }

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final soundUri = await RingtoneService.getSoundUri();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final scheduleMode = await _resolveScheduleMode();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId(soundUri),
          'Medication Reminders',
          channelDescription: 'Daily medication and prescription reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: _androidSound(soundUri),
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleOnceNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    final scheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final scheduleMode = await _resolveScheduleMode();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_v2',
          'Appointment Reminders',
          channelDescription: 'One-time appointment reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<int> getPendingCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return -1;
    }
  }

  /// Fires an immediate notification to test the permission + display pipeline.
  static Future<void> showTestNotification() async {
    await _plugin.show(
      999999,
      'Test Notification',
      'If you see this, notifications are working correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Schedules a notification 15 seconds from now to test zonedSchedule.
  static Future<void> scheduleTestNotification() async {
    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
    final scheduleMode = await _resolveScheduleMode();
    await _plugin.zonedSchedule(
      999998,
      'Scheduled Test',
      'Scheduled 15 s ago — notifications are working.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static int idFromString(String id) =>
      id.hashCode.abs() % 2147483647;
}
