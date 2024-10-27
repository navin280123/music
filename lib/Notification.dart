import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationServices {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> initNotificaiton() async {
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

  Future showCurrentlyPlayingNotification(
      {int id = 0, required String title, required String artist, String? albumArt}) async {
    return flutterLocalNotificationsPlugin.show(
        id, title, artist, await notificationDetails(albumArt),
        payload: 'currently_playing');
  }

  Future<NotificationDetails> notificationDetails(String? albumArt) async {
    final androidDetails = AndroidNotificationDetails(
      'currently_playing_channel', 'Currently Playing',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: albumArt != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(albumArt),
              largeIcon: FilePathAndroidBitmap(albumArt),
            )
          : null,
    );

    final iOSDetails = DarwinNotificationDetails();

    return NotificationDetails(android: androidDetails, iOS: iOSDetails);
  }
}
