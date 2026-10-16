import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// 구글 플레이 "앱 내 업데이트"로 새 버전이 있는지 보고, 있으면 바로 업데이트한다.
/// 플레이 스토어로 설치한 안드로이드 앱에서만 동작한다 (adb로 직접 깐 앱·웹·테스트에서는 '새 버전 없음'으로 본다).
class UpdateService {
  const UpdateService();

  /// 새 버전이 있으면 그 버전 코드(모르면 0), 없으면 null
  Future<int?> availableVersion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return null;
      return info.availableVersionCode ?? 0;
    } catch (e) {
      // 플레이 스토어로 설치하지 않았거나 확인에 실패하면 우체통에 편지를 넣지 않는다
      if (kDebugMode) debugPrint('업데이트 확인 실패: $e');
      return null;
    }
  }

  /// 구글 플레이 업데이트 화면을 띄운다. 그 화면을 쓸 수 없으면 플레이 스토어의 앱 페이지를 연다.
  /// 업데이트를 시작했으면 true, 사용자가 취소했으면 false.
  Future<bool> update() async {
    try {
      final r = await InAppUpdate.performImmediateUpdate();
      return r == AppUpdateResult.success;
    } catch (e) {
      if (kDebugMode) debugPrint('앱 내 업데이트 실패, 스토어 열기: $e');
      final market = Uri.parse('market://details?id=com.sise_nongbu');
      final web = Uri.parse('https://play.google.com/store/apps/details?id=com.sise_nongbu');
      try {
        if (await launchUrl(market, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {}
      return launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }
}
