 import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Serviço de Notificação
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledDateTime) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'med_channel',
      'Medicamentos',
      channelDescription: 'Lembretes de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
    );
    final DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails();

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } on Exception catch (e) {
      print("Erro ao agendar a notificação: $e");
    }
  }
}