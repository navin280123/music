
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationServices {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('music');
    var initializationSettingsIOS = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        onDidReceiveLocalNotification:
            (int id, String? title, String? body, String? payload) async {});
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {});
  }

  Future<void> showCurrentlyPlayingNotification({
    int id = 0,
    required String title,
    required String artist,
    required String position,
    required String duration,
    bool isPlaying = true,
  }) async {
    return flutterLocalNotificationsPlugin.show(
      id,
      title,
      '$artist - $position / $duration',
      await _notificationDetails(isPlaying),
      payload: 'currently_playing',
    );
  }

  Future<NotificationDetails> _notificationDetails(bool isPlaying) async {
    final androidDetails = AndroidNotificationDetails(
      'currently_playing_channel',
      'Currently Playing',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // Keep notification persistent
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'previous_action', // Unique ID for action
          'Previous', // Action title
          icon: DrawableResourceAndroidBitmap('previous'),
        ),
        AndroidNotificationAction(
          isPlaying ? 'pause_action' : 'play_action', // Toggle play/pause
          isPlaying ? 'Pause' : 'Play',
          icon: DrawableResourceAndroidBitmap(
              isPlaying ? 'pause' : 'play'), // Appropriate icon
        ),
        AndroidNotificationAction(
          'next_action',
          'Next',
          icon: DrawableResourceAndroidBitmap('next'),
        ),
      ],
      styleInformation:
          const DefaultStyleInformation(true, true), // No album art
    );

    final iOSDetails = DarwinNotificationDetails();

    return NotificationDetails(android: androidDetails, iOS: iOSDetails);
  }
}
