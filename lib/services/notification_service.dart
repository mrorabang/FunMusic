import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/song.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  static Future<void> showMediaNotification({
    required Song song,
    required bool isPlaying,
  }) async {
    try {
      if (!_isInitialized) await init();

      final androidDetails = AndroidNotificationDetails(
        'music_player_channel',
        'Phát nhạc trên nền',
        channelDescription: 'Điều khiển bài hát khi khóa màn hình và trên nền',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: isPlaying,
        autoCancel: false,
        showWhen: false,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.transport,
        styleInformation: MediaStyleInformation(
          htmlFormatContent: true,
          htmlFormatTitle: true,
        ),
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      );

      await _notifications.show(
        1001,
        song.title,
        song.artist,
        details,
      );
    } catch (e) {
      debugPrint('NotificationService.showMediaNotification error: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await _notifications.cancel(1001);
    } catch (_) {}
  }
}
