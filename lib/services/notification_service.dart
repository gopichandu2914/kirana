import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Default to Asia/Kolkata for the shopkeepers in India (Telugu/Hindi audience)
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // This payload will trigger the WhatsApp reorder logic
        if (details.payload == 'reorder_reminder') {
          // Logic to handle in the UI layer
        }
      },
    );

    // Create high importance channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'stock_alerts',
      'Stock Alerts',
      description: 'Notifications for critical stock levels',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'reorder_reminders',
      'Reorder Reminders',
      description: 'Scheduled reminders to check your reorder list',
      importance: Importance.high,
      playSound: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    // Request notification permission for Android 13+
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showStockAlert({required String itemName, required int quantity}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_alerts',
      'Stock Alerts',
      channelDescription: 'Notifications for critical stock levels',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      itemName.hashCode,
      '⚠️ Critical Stock Alert',
      '$itemName is very low: Only $quantity left!',
      platformDetails,
    );
  }

  Future<void> scheduleDailyReorderReminder(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reorder_reminders',
      'Reorder Reminders',
      channelDescription: 'Scheduled reminders to check your reorder list',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      1001, // Constant ID for daily reminder
      '🛒 Time to Order Stock!',
      'Review your reorder list and send it to your supplier.',
      scheduledDate,
      platformDetails,
      payload: 'reorder_reminder',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
