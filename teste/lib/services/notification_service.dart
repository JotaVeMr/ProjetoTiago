// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

/// Serviço de Notificação Local
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa o serviço de notificações (Android + iOS)
  Future<bool> init() async {
    tz.initializeTimeZones();

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

    // Criação manual do canal (obrigatório no Android 12+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'med_channel',
      'Medicamentos',
      description: 'Canal para lembretes de medicamentos',
      importance: Importance.max,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Permissões gerais
    await _requestPermissions();
    await requestExactAlarmPermission();

    return true;
  }

  /// Solicita permissão de notificação (Android e iOS)
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        print(" Permissão de notificação concedida!");
      } else {
        print(" Permissão de notificação negada!");
      }
    } else if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Solicita permissão de alarme exato (Android 12+)
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      try {
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt >= 31) {
          final status = await Permission.scheduleExactAlarm.request();
          if (status.isGranted) {
            print(" Permissão de alarme exato concedida!");
          } else {
            print(" Permissão de alarme exato negada!");
          }
        }
      } catch (e) {
        print("❌ Erro ao solicitar permissão de alarme exato: $e");
      }
    }
  }

  /// Helper: obtém versão do Android
  Future<int> _getAndroidSdkInt() async {
    try {
      const platform = MethodChannel('flutter/platform');
      final result = await platform.invokeMethod<int>('getSDKInt');
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Exibe uma notificação imediata
  Future<void> showInstantNotification(String title, String body) async {
        final androidDetails = AndroidNotificationDetails(
        'med_channel',
        'Medicamentos',
        channelDescription: 'Lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notificacao', // ícone pequeno vetorial branco
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'), // ícone colorido grande
        );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
      print('🔔 Notificação instantânea exibida com sucesso.');
    } catch (e) {
      print('❌ Erro ao exibir notificação instantânea: $e');
    }
  }

  /// Testa o sistema de notificações
  Future<void> testNotificationNow() async {
    await showInstantNotification(
      "Teste de notificação",
      "Seu sistema de notificações está funcionando!",
    );
  }

  /// Agenda uma notificação
  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledDateTime) async {
    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Medicamentos',
      channelDescription: 'Lembretes de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails();

    try {
      final now = DateTime.now();
      final diff = scheduledDateTime.difference(now);

      if (diff.isNegative) {
        print("⚠️ Horário já passou, notificação ignorada.");
        return;
      }

      print("⏰ Agendando notificação para: $scheduledDateTime");

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );

      print("✅ Notificação agendada com sucesso!");
    } catch (e) {
      print("❌ Erro ao agendar notificação: $e");
      print("⚙️ Tentando fallback com zonedSchedule() simples...");

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id + 1,
          title,
          body,
          tz.TZDateTime.from(scheduledDateTime, tz.local),
          NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
        );
        print("✅ Fallback zonedSchedule() funcionou!");
      } catch (e2) {
        print("❌ Falha também no fallback: $e2");
      }
    }
  }

  /// Cancela uma notificação específica
  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      print('🗑️ Notificação $id cancelada.');
    } catch (e) {
      print('❌ Erro ao cancelar notificação: $e');
    }
  }

  /// Cancela todas as notificações agendadas
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      print('🧹 Todas as notificações foram canceladas.');
    } catch (e) {
      print('❌ Erro ao cancelar todas as notificações: $e');
    }
  }
}
