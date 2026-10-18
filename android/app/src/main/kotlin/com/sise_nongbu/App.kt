package com.sise_nongbu

import android.app.Application
import android.content.Context
import android.util.Log
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey

/**
 * 앱이 켜질 때 Firebase보다 먼저 로그인 저장용 암호화 열쇠가 멀쩡한지 확인한다.
 *
 * Firebase 로그인은 기기 보안 저장소(키스토어)의 열쇠로 암호화해서 저장된다. 앱을 지웠다 다시 깔면
 * 안드로이드 자동 백업이 옛 암호화 설정 파일만 되살리고 열쇠는 없어서
 * "Keystore cannot load the key … unable to encrypt data"가 나고, 로그인이 저장되지 않아
 * 앱을 켤 때마다 로그인 화면이 나왔다(갤럭시 탭에서 확인). 그럴 때 옛 설정을 지우면 Firebase가 새 열쇠를 만든다.
 */
class App : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // 콘텐츠 제공자(FirebaseInitProvider)보다 먼저 불린다
        try {
            repairAuthStorage(base)
        } catch (e: Exception) {
            Log.w(TAG, "로그인 저장소 점검 실패", e)
        }
    }

    private fun repairAuthStorage(context: Context) {
        val dir = File(context.applicationInfo.dataDir, "shared_prefs")
        val files = dir.listFiles { f -> f.name.startsWith(CRYPTO_PREFS) && f.name.endsWith(".xml") } ?: return
        if (files.isEmpty()) return
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        for (file in files) {
            val name = file.name.removeSuffix(".xml")
            val suffix = name.removePrefix(CRYPTO_PREFS)
            val alias = "firebear_main_key_id_for_storage_crypto.$suffix"
            if (keyWorks(keyStore, alias)) continue
            Log.w(TAG, "로그인 암호화 열쇠가 망가져서 새로 만들게 함: $suffix")
            context.deleteSharedPreferences(name)
            context.deleteSharedPreferences("com.google.firebase.auth.api.Store.$suffix")
            try {
                keyStore.deleteEntry(alias)
            } catch (_: Exception) {
            }
        }
    }

    private fun keyWorks(keyStore: KeyStore, alias: String): Boolean = try {
        val key = keyStore.getKey(alias, null) as? SecretKey
        if (key == null) {
            false
        } else {
            Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.ENCRYPT_MODE, key)
            true
        }
    } catch (_: Exception) {
        false
    }

    companion object {
        private const val TAG = "SiseNongbuApp"
        private const val CRYPTO_PREFS = "com.google.firebase.auth.api.crypto."
    }
}
