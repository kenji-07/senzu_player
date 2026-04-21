package dev.senzu.senzu_player

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.CastMediaControlIntent

class SenzuCastOptionsProvider : OptionsProvider {

    companion object {
        private var appId: String = CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID

        
        fun setAppId(id: String) {
            appId = id.ifBlank { CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID }
        }

       
        fun getAppId(): String = appId
    }

    override fun getCastOptions(context: Context): CastOptions {
        return CastOptions.Builder()
            .setReceiverApplicationId(appId)
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}