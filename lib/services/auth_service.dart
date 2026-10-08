import 'package:firebase_auth/firebase_auth.dart';

/// 이메일·Google·게스트(익명) 로그인을 감싼 얇은 서비스
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String email, String password, String nickname) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.updateDisplayName(nickname.trim());
  }

  /// Firebase 콘솔에서 Google 로그인이 켜져 있어야 한다.
  Future<void> signInWithGoogle() async {
    await _auth.signInWithProvider(GoogleAuthProvider());
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
    await user.linkWithProvider(GoogleAuthProvider());
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

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
    return '$e';
  }
}
