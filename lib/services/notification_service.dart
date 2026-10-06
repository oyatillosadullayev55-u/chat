import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Yangi xabar kelganda bildirishnoma ko'rsatadi.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 0;

  static Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      _id = (_id + 1) % 100000;
      await _plugin.show(
        _id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'messages',
            'Xabarlar',
            channelDescription: 'Yangi xabarlar',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}