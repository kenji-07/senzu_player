package dev.senzu.senzu_player

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

// ─────────────────────────────────────────────────────────────────────────────
// SenzuCastOptionsProvider
// Supplies Google Cast framework options at app startup.
// Declared in the host app's AndroidManifest.xml via:
//   <meta-data
//       android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
//       android:value="dev.senzu.senzu_player.SenzuCastOptionsProvider" />
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Provides the Google Cast [CastOptions] to the Cast framework.
 *
 * Replace [RECEIVER_APP_ID] with your own Receiver Application ID obtained
 * from the Google Cast Developer Console:
 * https://cast.google.com/u/0/publish
 */
class SenzuCastOptionsProvider : OptionsProvider {

    companion object {

        /** Default Media Receiver App ID. Replace with a custom receiver if needed. */
        private const val RECEIVER_APP_ID = "519C9F80"
    }

    override fun getCastOptions(context: Context): CastOptions {
        return CastOptions.Builder()
            .setReceiverApplicationId(RECEIVER_APP_ID)
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}
