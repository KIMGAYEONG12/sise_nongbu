import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // flutterfire configure로 생성
import 'services/notification_service.dart';
import 'viewmodels/view_models.dart';
import 'views/app_root.dart';
import 'widgets/common.dart';
import 'widgets/phone_frame.dart';

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
      scrollBehavior: const NoStretchScrollBehavior(), // 끝까지 스크롤했을 때 화면이 고무줄처럼 늘어나지 않게
      builder: (context, child) {
        // 앱 전체 글씨를 10% 키움 (폰 설정의 글꼴 크기에 곱해진다)
        final scaled = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0) * 1.1),
          ),
          child: child!,
        );
        return kIsWeb ? PhoneFrame(child: scaled) : scaled; // 웹(PC)에서는 휴대폰 테두리 안에 표시
      },
      home: const AppRoot(),
    ),
  ));
}
