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
