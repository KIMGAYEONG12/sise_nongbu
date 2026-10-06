import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // flutterfire configure로 생성
import 'services/firestore_game_service.dart';
import 'services/notification_service.dart';
import 'viewmodels/view_models.dart';
import 'views/home_shell.dart';

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage m) async => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_onBackground);
  final cred = await FirebaseAuth.instance.signInAnonymously();
  final game = FirestoreGameService(FirebaseFirestore.instance, cred.user!.uid);
  await game.ensureUser();
  final noti = NotificationService();
  await noti.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [gameServiceProvider.overrideWithValue(game), notificationProvider.overrideWithValue(noti), prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      title: '시세 농부',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomeShell(),
    ),
  ));
}
