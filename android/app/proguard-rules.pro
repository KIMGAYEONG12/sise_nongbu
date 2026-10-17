# 출시용 빌드의 코드 줄이기(R8)가 Firebase·구글 로그인 부품을 지우거나 이름을 바꾸지 않게 남겨 둔다.
# (이게 없으면 플레이 스토어 버전에서 앱을 다시 켤 때 저장된 로그인이 풀리거나,
#  "Could not instantiate ...Registrar" 경고와 함께 Firebase 일부가 동작하지 않았다)

# Firebase 전체 (로그인 정보 저장·복원, 컴포넌트 등록)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.firebase-auth-api.** { *; }
-keep class com.google.android.gms.internal.firebase_auth.** { *; }
-dontwarn com.google.firebase.**

# 구글 로그인 (Credential Manager · Play 서비스)
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn androidx.credentials.**

# 앱 내 업데이트 (Play Core)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# 리플렉션·직렬화에 필요한 정보
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
