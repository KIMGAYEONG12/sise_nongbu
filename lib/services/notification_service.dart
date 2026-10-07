import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/korean.dart';

class NotificationService {
  final _local = FlutterLocalNotificationsPlugin();
  static const _details = NotificationDetails(
      android: AndroidNotificationDetails('harvest', '수확 알림', importance: Importance.high, priority: Priority.high));

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await FirebaseMessaging.instance.requestPermission();
    // 포그라운드 FCM은 시스템이 알림을 띄우지 않으므로 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen((m) => _local.show(
        m.hashCode, m.notification?.title ?? '시세 농부', m.notification?.body ?? '', _details));
    // FCM 테스트 메시지용 토큰은 화면 대신 개발 중 터미널(flutter run)에만 찍는다
    if (kDebugMode) {
      fcmToken().then((t) => debugPrint('FCM 토큰: $t')).catchError((Object e) => debugPrint('FCM 토큰 오류: $e'));
    }
  }

  Future<String?> fcmToken() => FirebaseMessaging.instance.getToken();

  Future<void> scheduleHarvest(int plotIdx, String cropName, DateTime at) => _local.zonedSchedule(
        plotIdx, '수확 시간이에요!', '${withJosa(cropName, '을', '를')} 수확할 수 있어요', tz.TZDateTime.from(at, tz.local), _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

  Future<void> cancel(int plotIdx) => _local.cancel(plotIdx);
}
