import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../ai/ai_agent.dart';

/// AI 도우미에 사진으로 질문하기: 카메라로 찍거나 앨범에서 고른다.
/// 화면 코드가 플러그인에 묶이지 않도록 인터페이스로 두어서 테스트에서는 가짜로 바꿀 수 있다.
abstract class PhotoInput {
  /// [fromCamera]가 true면 카메라, 아니면 앨범. 취소하면 null. 못 가져오면 예외.
  Future<AiImage?> pick({required bool fromCamera});
}

class ImagePickerPhotoInput implements PhotoInput {
  ImagePickerPhotoInput([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// 카메라 앱이 열려 있는 동안 안드로이드가 우리 앱을 잠깐 닫았다면(메모리가 모자랄 때) 찍어 둔 사진을 되찾아 온다. 없으면 null.
  Future<AiImage?> recoverLost() async {
    try {
      final r = await _picker.retrieveLostData();
      if (r.isEmpty || r.files == null || r.files!.isEmpty) return null;
      final f = r.files!.first;
      return AiImage(await f.readAsBytes(), _mimeOf(f.name, f.mimeType));
    } catch (_) {
      return null;
    }
  }

  /// 사진은 AI에 보내기 좋은 크기(긴 변 1280px, 품질 80)로 줄여서 받는다 (속도·데이터 절약)
  @override
  Future<AiImage?> pick({required bool fromCamera}) async {
    final f = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80);
    if (f == null) return null;
    final Uint8List bytes = await f.readAsBytes();
    return AiImage(bytes, _mimeOf(f.name, f.mimeType));
  }

  static String _mimeOf(String name, String? mime) {
    if (mime != null && mime.startsWith('image/')) return mime;
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

/// 음성으로 질문하기 (기기의 음성 인식 사용). 말하는 동안 [onText]로 글이 계속 갱신된다.
abstract class VoiceInput {
  bool get isListening;

  /// 음성 인식을 쓸 수 있는 기기인지 (처음 한 번 준비한다. 마이크 권한을 물어볼 수 있다)
  Future<bool> init();

  /// 듣기 시작. [onText]에는 지금까지 알아들은 글과 끝났는지(final) 여부가 온다. 오류는 [onError]로 알린다.
  Future<void> start(
      {required void Function(String text, bool done) onText,
      required void Function(String message) onError});

  Future<void> stop();
}

class SpeechVoiceInput implements VoiceInput {
  SpeechVoiceInput([SpeechToText? speech]) : _speech = speech ?? SpeechToText();
  final SpeechToText _speech;
  bool _ready = false;
  void Function(String message)? _onError;

  /// 한국어 음성 팩이 없는 기기에서는 기기 기본 언어로 다시 시도한다 (한 번만)
  bool _useDefaultLocale = false;

  /// 마지막으로 듣기를 시작할 때 쓴 콜백 (언어를 바꿔 다시 시작할 때 쓴다)
  void Function(String text, bool done)? _lastOnText;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          // 한국어 음성 팩이 없거나 지원되지 않으면(error_language_*) 기기 기본 언어로 한 번 더 시도한다
          if (!_useDefaultLocale &&
              e.errorMsg.startsWith('error_language') &&
              _lastOnText != null) {
            _useDefaultLocale = true;
            _listen(_lastOnText!);
            return;
          }
          _onError?.call(_friendly(e.errorMsg));
        },
        onStatus: (_) {},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('음성 인식 준비 실패: $e');
      _ready = false;
    }
    return _ready;
  }

  /// 음성 인식 오류 코드를 알아듣기 쉬운 말로
  static String _friendly(String code) {
    switch (code) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return '말씀을 알아듣지 못했어요. 다시 한 번 말해 주세요';
      case 'error_permission':
        return '마이크 권한이 필요해요. 설정에서 마이크를 허용해 주세요';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return '한국어 음성 인식을 쓸 수 없어요. 기기 설정에서 한국어 음성 팩을 받아 주세요';
      case 'error_audio':
        return '마이크를 쓸 수 없어요. 기기의 마이크 설정을 확인해 주세요';
      case 'error_busy':
        return '음성 인식이 바빠요. 잠시 후 다시 눌러 주세요';
      case 'error_network':
      case 'error_network_timeout':
        return '인터넷 연결을 확인해 주세요';
      default:
        return '음성 인식에 문제가 생겼어요. 잠시 후 다시 해 주세요';
    }
  }

  @override
  Future<void> start(
      {required void Function(String text, bool done) onText,
      required void Function(String message) onError}) async {
    _onError = onError;
    _lastOnText = onText;
    _useDefaultLocale = false;
    if (!await init()) {
      // 마이크 권한을 거절했는지, 아예 음성 인식이 없는 기기인지 구분해서 알려준다
      var denied = false;
      try {
        denied = !await _speech.hasPermission;
      } catch (_) {}
      onError(
          denied ? _friendly('error_permission') : '이 기기에서는 음성 인식을 쓸 수 없어요');
      return;
    }
    await _listen(onText);
  }

  Future<void> _listen(void Function(String text, bool done) onText) async {
    try {
      await _speech.listen(
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: _useDefaultLocale ? null : 'ko_KR',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('음성 듣기 시작 실패: $e');
      _onError?.call('음성 인식을 시작하지 못했어요. 잠시 후 다시 눌러 주세요');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
