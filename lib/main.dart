import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // flutterfire configure로 생성
import 'services/notification_service.dart';
import 'viewmodels/view_models.dart';
import 'views/app_root.dart';
import 'widgets/common.dart';

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage m) async => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_onBackground);
  // 로그인은 앱 안의 로그인·회원가입 화면에서 처리한다 (AppRoot → AuthGate)
  final noti = NotificationService();
  await noti.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [notificationProvider.overrideWithValue(noti), prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      title: '시세 농부',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppRoot(),
    ),
  ));
}
