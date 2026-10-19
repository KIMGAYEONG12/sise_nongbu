import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 이메일·Google·게스트(익명) 로그인을 감싼 얇은 서비스
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// 이메일로 회원가입한다. 지금 게스트로 놀고 있었다면 새 계정을 만들지 않고 그 게스트 계정을 이메일 계정으로 바꿔서
  /// 지금까지 키운 농장이 그대로 이어진다. 게스트 계정을 이어받았으면 true.
  Future<bool> signUp(String email, String password, String nickname) async {
    final cur = _auth.currentUser;
    if (cur != null && cur.isAnonymous) {
      await linkWithEmail(email, password, nickname);
      return true;
    }
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.updateDisplayName(nickname.trim());
    return false;
  }

  static Future<void>? _googleInit;

  /// Firebase 프로젝트의 웹 클라이언트 ID (google-services.json의 client_type 3, 공개해도 되는 값).
  /// 플러그인이 리소스(default_web_client_id)에서 자동으로 읽을 수도 있지만, 플레이 스토어용 빌드는 리소스 줄이기가
  /// 그 값을 지워 버려서 "clientConfigurationError"로 구글 로그인이 실패했다. 그래서 코드에 직접 넣는다.
  static const googleWebClientId = '641118692037-0nk84mc3sd42dr1rpo6meqkepl75kel7.apps.googleusercontent.com';

  /// 이 앱에서 전에 고른 Google 계정이 있으면 창 없이 조용히 가져온다. 없으면 null.
  Future<GoogleSignInAccount?> _quietGoogleAccount() async {
    final google = GoogleSignIn.instance;
    await (_googleInit ??= google.initialize(serverClientId: googleWebClientId));
    try {
      return await (google.attemptLightweightAuthentication() ?? Future<GoogleSignInAccount?>.value());
    } catch (_) {
      return null;
    }
  }

  /// 기기의 Google 계정으로 Firebase 자격 증명을 만든다. 계정 고르기 창은 처음 한 번만 나오고,
  /// 그 뒤로는 전에 고른 계정으로 바로 로그인한다 (로그아웃하면 다시 고른다).
  Future<AuthCredential> _googleCredential() async {
    final account = await _quietGoogleAccount() ?? await GoogleSignIn.instance.authenticate();
    return GoogleAuthProvider.credential(idToken: account.authentication.idToken);
  }

  /// Firebase 콘솔에서 Google 로그인이 켜져 있어야 한다.
  Future<void> signInWithGoogle() async {
    await _auth.signInWithCredential(await _googleCredential());
  }

  /// 앱을 켤 때 Firebase 로그인이 비어 있으면(일부 기기는 로그인 정보를 기기에 저장하지 못한다)
  /// 전에 고른 Google 계정으로 화면 없이 다시 로그인한다. 성공하면 true.
  Future<bool> signInWithGoogleQuietly() async {
    if (_auth.currentUser != null) return true;
    final account = await _quietGoogleAccount();
    final token = account?.authentication.idToken;
    if (token == null) return false;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: token));
    return true;
  }

  Future<void> signInAsGuest() async {
    await _auth.signInAnonymously();
  }

  /// 게스트(익명) 계정인지. 게스트는 앱을 지우거나 로그아웃하면 데이터를 다시 찾을 수 없다.
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// 로그인·연결 상태가 바뀔 때마다 알려주는 스트림 (게스트 → 정식 계정 연결도 포함)
  Stream<User?> get userChanges => _auth.userChanges();

  /// 게스트 계정을 이메일 계정으로 바꾼다. uid가 그대로라서 지금까지의 농장 데이터가 그대로 이어지고,
  /// 앱을 지웠다 다시 깔아도 같은 이메일로 로그인하면 데이터가 돌아온다.
  Future<void> linkWithEmail(String email, String password, String nickname) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.linkWithCredential(EmailAuthProvider.credential(email: email.trim(), password: password));
    if (nickname.trim().isNotEmpty) await user.updateDisplayName(nickname.trim());
  }

  /// 게스트 계정을 Google 계정으로 바꾼다 (농장 데이터 그대로 유지).
  Future<void> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.linkWithCredential(await _googleCredential());
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    // 다음 로그인 때 계정 고르기 창이 다시 나오고, 앱을 켤 때 조용히 다시 로그인되지 않도록 Google 쪽도 로그아웃한다.
    try {
      final google = GoogleSignIn.instance;
      await (_googleInit ??= google.initialize(serverClientId: googleWebClientId));
      await google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// 사용자에게 보여줄 한국어 오류 문구
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return '이메일 형식이 올바르지 않아요';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않아요';
        case 'email-already-in-use':
          return '이미 가입된 이메일이에요';
        case 'credential-already-in-use':
        case 'account-exists-with-different-credential':
          return '이미 다른 농장에 연결된 계정이에요. 그 계정으로 로그인하거나 다른 계정을 써 주세요';
        case 'provider-already-linked':
          return '이미 연결된 계정이에요';
        case 'requires-recent-login':
          return '보안을 위해 다시 로그인한 뒤 시도해 주세요';
        case 'no-current-user':
          return '로그인 상태가 아니에요';
        case 'weak-password':
          return '비밀번호가 너무 약해요. 6자 이상으로 해주세요';
        case 'network-request-failed':
          return '네트워크 연결을 확인해 주세요';
        case 'too-many-requests':
          return '시도가 너무 많아요. 잠시 후 다시 해주세요';
        case 'user-disabled':
          return '사용할 수 없는 계정이에요';
        case 'operation-not-allowed':
          return '이 로그인 방식이 Firebase 콘솔에서 아직 켜져 있지 않아요';
        case 'web-context-canceled':
        case 'canceled':
        case 'popup-closed-by-user':
          return '로그인을 취소했어요';
        default:
          return e.message ?? '로그인에 실패했어요 (${e.code})';
      }
    }
    if (e is GoogleSignInException) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return '로그인을 취소했어요';
        default:
          return 'Google 로그인에 실패했어요 (${e.code.name})';
      }
    }
    return '$e';
  }
}
